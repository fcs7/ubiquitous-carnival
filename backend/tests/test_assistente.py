import json
from unittest.mock import patch, MagicMock

from app.models import Usuario, ToolExecution
from app.services.auth import criar_token
from app.services.providers.base import ProviderResponse, ToolCall


def _mock_provider_end_turn(text="Resposta do assistente"):
    mock_prov = MagicMock()
    mock_prov.chat.return_value = ProviderResponse(
        text=text,
        tool_calls=[],
        stop_reason="end_turn",
        input_tokens=100,
        output_tokens=50,
    )
    return mock_prov


def _mock_provider_with_tool_use():
    mock_prov = MagicMock()
    call_count = 0

    def chat_side_effect(**kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return ProviderResponse(
                text="Vou buscar o processo...",
                tool_calls=[ToolCall(id="toolu_ast_1", name="buscar_processo", input={"cnj": "0000001-23.2024.8.26.0100"})],
                stop_reason="tool_use",
                input_tokens=150,
                output_tokens=30,
            )
        return ProviderResponse(
            text="Encontrei o processo. O status eh ativo.",
            tool_calls=[],
            stop_reason="end_turn",
            input_tokens=200,
            output_tokens=60,
        )

    mock_prov.chat.side_effect = chat_side_effect
    mock_prov.format_assistant_with_tools.side_effect = lambda text, tcs: (
        [{"type": "text", "text": text}] +
        [{"type": "tool_use", "id": tc.id, "name": tc.name, "input": tc.input} for tc in tcs]
    )
    mock_prov.format_tool_result_message.side_effect = lambda tid, res: {
        "type": "tool_result", "tool_use_id": tid, "content": res,
    }
    return mock_prov, lambda: call_count


def test_historico_cria_conversa_automaticamente(client, usuario_teste):
    resp = client.get("/assistente/historico")
    assert resp.status_code == 200
    data = resp.json()
    assert "conversa_id" in data
    assert data["mensagens"] == []


def test_enviar_mensagem_assistente(client, usuario_teste):
    with patch("app.services.assistente.get_provider") as mock_get:
        mock_get.return_value = _mock_provider_end_turn("Posso ajudar com questoes juridicas.")

        resp = client.post(
            "/assistente/mensagens",
            json={"mensagem": "Ola, preciso de ajuda"},
        )

    assert resp.status_code == 200
    data = resp.json()
    assert data["resposta"] == "Posso ajudar com questoes juridicas."
    assert "conversa_id" in data
    assert data["tokens_input"] > 0


def test_reutiliza_mesma_conversa(client, usuario_teste):
    with patch("app.services.assistente.get_provider") as mock_get:
        mock_get.return_value = _mock_provider_end_turn("Primeira resposta")
        resp1 = client.post(
            "/assistente/mensagens",
            json={"mensagem": "Pergunta 1"},
        )

    with patch("app.services.assistente.get_provider") as mock_get:
        mock_get.return_value = _mock_provider_end_turn("Segunda resposta")
        resp2 = client.post(
            "/assistente/mensagens",
            json={"mensagem": "Pergunta 2"},
        )

    assert resp1.json()["conversa_id"] == resp2.json()["conversa_id"]


def test_assistente_com_tool_use(client, db, usuario_teste):
    mock_prov, get_call_count = _mock_provider_with_tool_use()

    with patch("app.services.assistente.get_provider", return_value=mock_prov):
        resp = client.post(
            "/assistente/mensagens",
            json={"mensagem": "Busque o processo 0000001-23.2024.8.26.0100"},
        )

    assert resp.status_code == 200
    data = resp.json()
    assert "processo" in data["resposta"].lower() or "ativo" in data["resposta"].lower()
    assert get_call_count() == 2

    # Verifica ToolExecution criado
    conversa_id = data["conversa_id"]
    tool_exec = db.query(ToolExecution).filter(ToolExecution.conversa_id == conversa_id).first()
    assert tool_exec is not None
    assert tool_exec.tool_name == "buscar_processo"


def test_conversa_assistente_nao_aparece_em_listagem(client, db, usuario_teste):
    """A conversa sentinela __assistente__ nao deve aparecer em GET /conversas/"""
    with patch("app.services.assistente.get_provider") as mock_get:
        mock_get.return_value = _mock_provider_end_turn("Ok")
        client.post(
            "/assistente/mensagens",
            json={"mensagem": "Teste"},
        )

    resp = client.get(f"/conversas/?usuario_id={usuario_teste.id}")
    assert resp.status_code == 200
    conversas = resp.json()
    for c in conversas:
        assert c["titulo"] != "__assistente__"


# ── Novos testes: multi-conversa ────────────────────


def _setup_agente(db, usuario):
    """Cria agente auxiliar para testes de multi-conversa."""
    import json as _json
    from app.models import AgenteConfig
    agente = AgenteConfig(
        usuario_id=usuario.id,
        nome="Agente Teste",
        descricao="Agente para testes",
        provider="anthropic",
        modelo="claude-haiku-4-5-20251001",
        ferramentas_habilitadas=_json.dumps([]),
        max_tokens=1024,
        max_iteracoes_tool=5,
    )
    db.add(agente)
    db.commit()
    db.refresh(agente)
    return agente


def test_criar_conversa_com_agente(client, db, usuario_teste):
    agente = _setup_agente(db, usuario_teste)

    resp = client.post(
        "/assistente/conversas",
        json={"agente_id": agente.id, "titulo": "Conversa de teste"},
    )
    assert resp.status_code == 201
    data = resp.json()
    assert data["agente_id"] == agente.id
    assert data["titulo"] == "Conversa de teste"
    assert data["usuario_id"] == usuario_teste.id


def test_listar_conversas(client, db, usuario_teste):
    agente = _setup_agente(db, usuario_teste)

    # Criar 2 conversas
    client.post(
        "/assistente/conversas",
        json={"agente_id": agente.id, "titulo": "Conversa A"},
    )
    client.post(
        "/assistente/conversas",
        json={"agente_id": agente.id, "titulo": "Conversa B"},
    )

    # Criar sentinel via mensagem legada (nao deve aparecer)
    with patch("app.services.assistente.get_provider") as mock_get:
        mock_get.return_value = _mock_provider_end_turn("Ok")
        client.post(
            "/assistente/mensagens",
            json={"mensagem": "Teste sentinel"},
        )

    resp = client.get("/assistente/conversas")
    assert resp.status_code == 200
    conversas = resp.json()
    assert len(conversas) == 2
    # Ordenado por updated_at DESC — B foi criada depois
    assert conversas[0]["titulo"] == "Conversa B"
    assert conversas[1]["titulo"] == "Conversa A"
    for c in conversas:
        assert c["titulo"] != "__assistente__"


def test_enviar_mensagem_conversa_especifica(client, db, usuario_teste):
    agente = _setup_agente(db, usuario_teste)

    # Criar conversa
    resp_conv = client.post(
        "/assistente/conversas",
        json={"agente_id": agente.id},
    )
    conversa_id = resp_conv.json()["id"]

    with patch("app.services.assistente.get_provider") as mock_get:
        mock_get.return_value = _mock_provider_end_turn("Resposta especifica")
        resp = client.post(
            "/assistente/mensagens",
            json={"mensagem": "Pergunta na conversa especifica", "conversa_id": conversa_id},
        )

    assert resp.status_code == 200
    assert resp.json()["conversa_id"] == conversa_id
    assert resp.json()["resposta"] == "Resposta especifica"


def test_enviar_mensagem_cria_nova_conversa(client, db, usuario_teste):
    """Backward compat: sem conversa_id usa sentinel __assistente__."""
    with patch("app.services.assistente.get_provider") as mock_get:
        mock_get.return_value = _mock_provider_end_turn("Ok legado")
        resp = client.post(
            "/assistente/mensagens",
            json={"mensagem": "Mensagem legada"},
        )

    assert resp.status_code == 200
    assert "conversa_id" in resp.json()


def test_titulo_automatico(client, db, usuario_teste):
    """Conversa criada sem titulo recebe titulo da primeira mensagem."""
    agente = _setup_agente(db, usuario_teste)

    resp_conv = client.post(
        "/assistente/conversas",
        json={"agente_id": agente.id},
    )
    conversa_id = resp_conv.json()["id"]
    assert resp_conv.json()["titulo"] is None

    with patch("app.services.assistente.get_provider") as mock_get:
        mock_get.return_value = _mock_provider_end_turn("Resposta")
        client.post(
            "/assistente/mensagens",
            json={"mensagem": "Quais os prazos pendentes desta semana?", "conversa_id": conversa_id},
        )

    # Verificar titulo gerado
    resp_det = client.get(f"/assistente/conversas/{conversa_id}")
    assert resp_det.status_code == 200
    assert resp_det.json()["titulo"] == "Quais os prazos pendentes desta semana?"


def test_deletar_conversa(client, db, usuario_teste):
    agente = _setup_agente(db, usuario_teste)

    resp_conv = client.post(
        "/assistente/conversas",
        json={"agente_id": agente.id, "titulo": "Para deletar"},
    )
    conversa_id = resp_conv.json()["id"]

    resp = client.delete(f"/assistente/conversas/{conversa_id}")
    assert resp.status_code == 204

    # Confirmar que nao existe mais
    resp_det = client.get(f"/assistente/conversas/{conversa_id}")
    assert resp_det.status_code == 404


def test_detalhe_conversa(client, db, usuario_teste):
    agente = _setup_agente(db, usuario_teste)

    resp_conv = client.post(
        "/assistente/conversas",
        json={"agente_id": agente.id, "titulo": "Detalhes"},
    )
    conversa_id = resp_conv.json()["id"]

    # Enviar mensagem para ter conteudo
    with patch("app.services.assistente.get_provider") as mock_get:
        mock_get.return_value = _mock_provider_end_turn("Resposta detalhada")
        client.post(
            "/assistente/mensagens",
            json={"mensagem": "Pergunta detalhe", "conversa_id": conversa_id},
        )

    resp = client.get(f"/assistente/conversas/{conversa_id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["titulo"] == "Detalhes"
    assert len(data["mensagens"]) == 2
    assert data["mensagens"][0]["role"] == "user"
    assert data["mensagens"][1]["role"] == "assistant"
