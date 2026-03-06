import json
from unittest.mock import patch, MagicMock

from app.models import Usuario, AgenteConfig, Conversa
from app.services.providers.base import ProviderResponse, ToolCall


def _setup_agente(db):
    usuario = Usuario(nome="Adv Teste", email="adv@chat.com", oab="12345/SP")
    db.add(usuario)
    db.flush()

    agente = AgenteConfig(
        usuario_id=usuario.id,
        nome="Agente Teste",
        instrucoes_sistema="Voce eh especialista em trabalhista",
        provider="anthropic",
        modelo="claude-sonnet-4-5-20250514",
        ferramentas_habilitadas=json.dumps(["buscar_processo"]),
    )
    db.add(agente)
    db.flush()

    conversa = Conversa(
        titulo="Chat com agente",
        usuario_id=usuario.id,
        agente_id=agente.id,
        modelo_claude=agente.modelo,
    )
    db.add(conversa)
    db.commit()
    db.refresh(conversa)
    return conversa


def _mock_provider_end_turn(text="Resposta do agente"):
    mock_prov = MagicMock()
    mock_prov.chat.return_value = ProviderResponse(
        text=text,
        tool_calls=[],
        stop_reason="end_turn",
        input_tokens=100,
        output_tokens=50,
    )
    mock_prov.format_assistant_with_tools.return_value = [{"type": "text", "text": text}]
    mock_prov.format_tool_result_message.side_effect = lambda tid, res: {
        "type": "tool_result", "tool_use_id": tid, "content": res,
    }
    return mock_prov


def _mock_provider_with_tool_use():
    """Provider que retorna tool_use na 1a chamada e end_turn na 2a."""
    mock_prov = MagicMock()
    call_count = 0

    def chat_side_effect(**kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return ProviderResponse(
                text="Vou buscar o processo...",
                tool_calls=[ToolCall(id="toolu_123", name="buscar_processo", input={"cnj": "0000001-23.2024.8.26.0100"})],
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


def test_chat_agente_simples_sem_tools(client, db):
    conversa = _setup_agente(db)

    with patch("app.services.agente_chat.get_provider") as mock_get:
        mock_get.return_value = _mock_provider_end_turn("Resposta direta")

        resp = client.post(f"/conversas/{conversa.id}/mensagens", json={
            "mensagem": "Qual o prazo de contestacao?",
        })

    assert resp.status_code == 200
    data = resp.json()
    assert data["resposta"] == "Resposta direta"


def test_chat_agente_com_tool_use(client, db):
    conversa = _setup_agente(db)
    mock_prov, get_call_count = _mock_provider_with_tool_use()

    with patch("app.services.agente_chat.get_provider") as mock_get:
        mock_get.return_value = mock_prov

        resp = client.post(f"/conversas/{conversa.id}/mensagens", json={
            "mensagem": "Busque o processo 0000001-23.2024.8.26.0100",
        })

    assert resp.status_code == 200
    data = resp.json()
    assert "ativo" in data["resposta"].lower() or "processo" in data["resposta"].lower()
    assert get_call_count() == 2


def test_conversa_sem_agente_usa_chat_antigo(client, db):
    usuario = Usuario(nome="Adv Sem Agente", email="adv@sem.com", oab="99999/SP")
    db.add(usuario)
    db.commit()
    db.refresh(usuario)

    resp = client.post("/conversas/", json={
        "titulo": "Sem agente",
        "usuario_id": usuario.id,
    })
    cid = resp.json()["id"]

    with patch("app.services.claude_chat.get_provider") as mock_get:
        mock_prov = MagicMock()
        mock_prov.chat.return_value = ProviderResponse(
            text="Resposta simples",
            tool_calls=[],
            stop_reason="end_turn",
            input_tokens=80,
            output_tokens=40,
        )
        mock_get.return_value = mock_prov

        resp = client.post(f"/conversas/{cid}/mensagens", json={
            "mensagem": "Oi",
        })

    assert resp.status_code == 200
    assert resp.json()["resposta"] == "Resposta simples"


def test_stream_mensagem_agente(client, db):
    conversa = _setup_agente(db)

    with patch("app.services.agente_chat.get_provider") as mock_get:
        mock_get.return_value = _mock_provider_end_turn("Resposta stream")

        with client.stream("POST", f"/conversas/{conversa.id}/mensagens/stream", json={
            "mensagem": "Teste streaming",
        }) as resp:
            assert resp.status_code == 200
            lines = []
            for line in resp.iter_lines():
                if line.startswith("data: "):
                    lines.append(json.loads(line[6:]))

    assert any(e["tipo"] == "texto" for e in lines)
    assert any(e["tipo"] == "fim" for e in lines)


# ──────────────────────────────────────────────
# T1 — Loop para apos max_iteracoes_tool
# ──────────────────────────────────────────────
def test_chat_agente_para_apos_max_iteracoes(client, db):
    """loop de tool_use para apos atingir max_iteracoes_tool"""
    usuario = Usuario(nome="Loop Teste", email="loop@t.com", oab="11111/SP")
    db.add(usuario)
    db.flush()

    agente = AgenteConfig(
        usuario_id=usuario.id,
        nome="Agente Loop",
        provider="anthropic",
        modelo="claude-sonnet-4-5-20250514",
        ferramentas_habilitadas=json.dumps(["buscar_processo"]),
        max_tokens=1024,
        max_iteracoes_tool=2,
    )
    db.add(agente)
    db.flush()

    conversa = Conversa(
        titulo="Test Loop",
        usuario_id=usuario.id,
        agente_id=agente.id,
        modelo_claude=agente.modelo,
    )
    db.add(conversa)
    db.commit()
    db.refresh(conversa)

    # Provider que SEMPRE retorna tool_use (nunca end_turn)
    tool_response = ProviderResponse(
        text="Buscando...",
        stop_reason="tool_use",
        tool_calls=[ToolCall(id="tc1", name="buscar_processo", input={"cnj": "0000001-23.2024.8.26.0100"})],
        input_tokens=100,
        output_tokens=30,
    )

    mock_prov = MagicMock()
    mock_prov.chat.return_value = tool_response
    mock_prov.format_assistant_with_tools.side_effect = lambda text, tcs: (
        [{"type": "text", "text": text}] +
        [{"type": "tool_use", "id": tc.id, "name": tc.name, "input": tc.input} for tc in tcs]
    )
    mock_prov.format_tool_result_message.side_effect = lambda tid, res: {
        "type": "tool_result", "tool_use_id": tid, "content": res,
    }

    with patch("app.services.agente_chat.get_provider", return_value=mock_prov):
        with patch("app.services.agente_chat._executar_ferramenta", return_value="Resultado mock"):
            resp = client.post(f"/conversas/{conversa.id}/mensagens", json={
                "mensagem": "teste loop",
            })

    assert resp.status_code == 200
    # Provider chamado exatamente max_iteracoes_tool vezes (2)
    assert mock_prov.chat.call_count == 2


# ──────────────────────────────────────────────
# T2 — Excecao no executor de ferramenta
# ──────────────────────────────────────────────
def test_chat_agente_ferramenta_com_erro(client, db):
    """excecao no executor de ferramenta nao interrompe o chat"""
    conversa = _setup_agente(db)

    mock_prov = MagicMock()
    call_count = 0

    def chat_side_effect(**kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return ProviderResponse(
                text="Vou buscar...",
                tool_calls=[ToolCall(id="tc_err", name="buscar_processo", input={"cnj": "123"})],
                stop_reason="tool_use",
                input_tokens=100,
                output_tokens=30,
            )
        return ProviderResponse(
            text="Nao consegui buscar, mas posso ajudar de outra forma.",
            tool_calls=[],
            stop_reason="end_turn",
            input_tokens=150,
            output_tokens=40,
        )

    mock_prov.chat.side_effect = chat_side_effect
    mock_prov.format_assistant_with_tools.side_effect = lambda text, tcs: (
        [{"type": "text", "text": text}] +
        [{"type": "tool_use", "id": tc.id, "name": tc.name, "input": tc.input} for tc in tcs]
    )
    mock_prov.format_tool_result_message.side_effect = lambda tid, res: {
        "type": "tool_result", "tool_use_id": tid, "content": res,
    }

    def executor_que_falha(inp, sess):
        raise RuntimeError("DB caiu")

    with patch("app.services.agente_chat.get_provider", return_value=mock_prov):
        with patch("app.services.agente_chat.FERRAMENTAS_DISPONIVEIS", {
            "buscar_processo": {
                "schema": {"name": "buscar_processo"},
                "executor": executor_que_falha,
            },
        }):
            resp = client.post(f"/conversas/{conversa.id}/mensagens", json={
                "mensagem": "busque o processo 123",
            })

    assert resp.status_code == 200
    data = resp.json()
    assert data["resposta"]  # nao esta vazio — chat continuou

    from app.models import ToolExecution
    tool_exec = db.query(ToolExecution).filter(ToolExecution.conversa_id == conversa.id).first()
    assert tool_exec is not None
    assert tool_exec.erro is not None


# ──────────────────────────────────────────────
# T3 — Ferramenta desconhecida
# ──────────────────────────────────────────────
def test_chat_agente_ferramenta_desconhecida(client, db):
    """tool_use com ferramenta inexistente retorna mensagem de erro"""
    conversa = _setup_agente(db)

    mock_prov = MagicMock()
    call_count = 0

    def chat_side_effect(**kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return ProviderResponse(
                text="Vou usar uma ferramenta...",
                tool_calls=[ToolCall(id="tc_unk", name="ferramenta_que_nao_existe", input={"x": 1})],
                stop_reason="tool_use",
                input_tokens=100,
                output_tokens=30,
            )
        return ProviderResponse(
            text="Ferramenta nao disponivel, respondendo diretamente.",
            tool_calls=[],
            stop_reason="end_turn",
            input_tokens=150,
            output_tokens=40,
        )

    mock_prov.chat.side_effect = chat_side_effect
    mock_prov.format_assistant_with_tools.side_effect = lambda text, tcs: (
        [{"type": "text", "text": text}] +
        [{"type": "tool_use", "id": tc.id, "name": tc.name, "input": tc.input} for tc in tcs]
    )
    mock_prov.format_tool_result_message.side_effect = lambda tid, res: {
        "type": "tool_result", "tool_use_id": tid, "content": res,
    }

    with patch("app.services.agente_chat.get_provider", return_value=mock_prov):
        resp = client.post(f"/conversas/{conversa.id}/mensagens", json={
            "mensagem": "use ferramenta desconhecida",
        })

    assert resp.status_code == 200
    data = resp.json()
    assert data["resposta"]  # nao vazio

    from app.models import ToolExecution
    tool_exec = db.query(ToolExecution).filter(
        ToolExecution.conversa_id == conversa.id,
        ToolExecution.tool_name == "ferramenta_que_nao_existe",
    ).first()
    assert tool_exec is not None
    # output_json contem a mensagem de "nao disponivel"
    assert tool_exec.output_json is not None
    assert "nao disponivel" in tool_exec.output_json


# ──────────────────────────────────────────────
# T4 — ToolExecution eh registrado
# ──────────────────────────────────────────────
def test_tool_execution_registrado(client, db):
    """ToolExecution eh salvo no banco apos usar ferramenta"""
    conversa = _setup_agente(db)
    mock_prov, get_call_count = _mock_provider_with_tool_use()

    with patch("app.services.agente_chat.get_provider", return_value=mock_prov):
        resp = client.post(f"/conversas/{conversa.id}/mensagens", json={
            "mensagem": "Busque o processo 0000001-23.2024.8.26.0100",
        })

    assert resp.status_code == 200

    from app.models import ToolExecution
    execucoes = db.query(ToolExecution).filter(ToolExecution.conversa_id == conversa.id).all()
    assert len(execucoes) > 0

    exec_ = execucoes[0]
    assert exec_.tool_name == "buscar_processo"
    assert exec_.tool_use_id == "toolu_123"
    assert exec_.input_json  # nao vazio
    assert exec_.output_json  # nao vazio (ferramenta retornou algo)
    assert exec_.duracao_ms is not None
