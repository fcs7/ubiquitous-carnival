import json
from unittest.mock import patch, MagicMock

from app.models import Usuario, ToolExecution
from app.services.providers.base import ProviderResponse, ToolCall


def _setup_usuario(db):
    usuario = Usuario(nome="Adv Assistente", email="adv@assist.com", oab="55555/SP")
    db.add(usuario)
    db.commit()
    db.refresh(usuario)
    return usuario


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


def test_historico_cria_conversa_automaticamente(client, db):
    usuario = _setup_usuario(db)
    resp = client.get(f"/assistente/historico?usuario_id={usuario.id}")
    assert resp.status_code == 200
    data = resp.json()
    assert "conversa_id" in data
    assert data["mensagens"] == []


def test_enviar_mensagem_assistente(client, db):
    usuario = _setup_usuario(db)

    with patch("app.services.assistente.get_provider") as mock_get:
        mock_get.return_value = _mock_provider_end_turn("Posso ajudar com questoes juridicas.")

        resp = client.post(
            f"/assistente/mensagens?usuario_id={usuario.id}",
            json={"mensagem": "Ola, preciso de ajuda"},
        )

    assert resp.status_code == 200
    data = resp.json()
    assert data["resposta"] == "Posso ajudar com questoes juridicas."
    assert "conversa_id" in data
    assert data["tokens_input"] > 0


def test_reutiliza_mesma_conversa(client, db):
    usuario = _setup_usuario(db)

    with patch("app.services.assistente.get_provider") as mock_get:
        mock_get.return_value = _mock_provider_end_turn("Primeira resposta")
        resp1 = client.post(
            f"/assistente/mensagens?usuario_id={usuario.id}",
            json={"mensagem": "Pergunta 1"},
        )

    with patch("app.services.assistente.get_provider") as mock_get:
        mock_get.return_value = _mock_provider_end_turn("Segunda resposta")
        resp2 = client.post(
            f"/assistente/mensagens?usuario_id={usuario.id}",
            json={"mensagem": "Pergunta 2"},
        )

    assert resp1.json()["conversa_id"] == resp2.json()["conversa_id"]


def test_assistente_com_tool_use(client, db):
    usuario = _setup_usuario(db)
    mock_prov, get_call_count = _mock_provider_with_tool_use()

    with patch("app.services.assistente.get_provider", return_value=mock_prov):
        resp = client.post(
            f"/assistente/mensagens?usuario_id={usuario.id}",
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


def test_usuario_inexistente(client, db):
    with patch("app.services.assistente.get_provider") as mock_get:
        mock_get.return_value = _mock_provider_end_turn()
        resp = client.post(
            "/assistente/mensagens?usuario_id=99999",
            json={"mensagem": "Ola"},
        )

    assert resp.status_code == 404


def test_conversa_assistente_nao_aparece_em_listagem(client, db):
    """A conversa sentinela __assistente__ nao deve aparecer em GET /conversas/"""
    usuario = _setup_usuario(db)

    with patch("app.services.assistente.get_provider") as mock_get:
        mock_get.return_value = _mock_provider_end_turn("Ok")
        client.post(
            f"/assistente/mensagens?usuario_id={usuario.id}",
            json={"mensagem": "Teste"},
        )

    resp = client.get(f"/conversas/?usuario_id={usuario.id}")
    assert resp.status_code == 200
    conversas = resp.json()
    for c in conversas:
        assert c["titulo"] != "__assistente__"
