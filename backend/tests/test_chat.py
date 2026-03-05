from unittest.mock import patch, MagicMock

from app.models import Usuario, Conversa


def _criar_usuario(db):
    u = Usuario(nome="Adv Teste", email="adv@teste.com", oab="12345/SP")
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


def test_criar_conversa(client, db):
    usuario = _criar_usuario(db)
    resp = client.post("/conversas/", json={
        "titulo": "Teste conversa",
        "usuario_id": usuario.id,
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["titulo"] == "Teste conversa"
    assert data["usuario_id"] == usuario.id
    assert data["modelo_claude"] == "claude-haiku-4-5-20251001"


def test_criar_conversa_usuario_inexistente(client):
    resp = client.post("/conversas/", json={
        "titulo": "Teste",
        "usuario_id": 9999,
    })
    assert resp.status_code == 404


def test_listar_conversas(client, db):
    usuario = _criar_usuario(db)
    client.post("/conversas/", json={"titulo": "C1", "usuario_id": usuario.id})
    client.post("/conversas/", json={"titulo": "C2", "usuario_id": usuario.id})

    resp = client.get(f"/conversas/?usuario_id={usuario.id}")
    assert resp.status_code == 200
    assert len(resp.json()) == 2


def test_detalhe_conversa(client, db):
    usuario = _criar_usuario(db)
    resp = client.post("/conversas/", json={"titulo": "Detalhe", "usuario_id": usuario.id})
    cid = resp.json()["id"]

    resp = client.get(f"/conversas/{cid}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["titulo"] == "Detalhe"
    assert data["mensagens"] == []


def test_deletar_conversa(client, db):
    usuario = _criar_usuario(db)
    resp = client.post("/conversas/", json={"titulo": "Del", "usuario_id": usuario.id})
    cid = resp.json()["id"]

    resp = client.delete(f"/conversas/{cid}")
    assert resp.status_code == 204

    resp = client.get(f"/conversas/{cid}")
    assert resp.status_code == 404


def test_enviar_mensagem(client, db):
    usuario = _criar_usuario(db)
    resp = client.post("/conversas/", json={"titulo": "Chat", "usuario_id": usuario.id})
    cid = resp.json()["id"]

    # Mock da API Anthropic
    mock_response = MagicMock()
    mock_response.content = [MagicMock(text="Resposta do assistente juridico")]
    mock_response.usage = MagicMock(input_tokens=100, output_tokens=50)

    with patch("app.services.claude_chat.get_anthropic_client") as mock_get_client:
        mock_client = MagicMock()
        mock_client.messages.create.return_value = mock_response
        mock_get_client.return_value = mock_client

        resp = client.post(f"/conversas/{cid}/mensagens", json={
            "mensagem": "Qual o prazo para contestacao no CPC?",
        })

    assert resp.status_code == 200
    data = resp.json()
    assert data["resposta"] == "Resposta do assistente juridico"
    assert data["tokens_input"] == 100
    assert data["tokens_output"] == 50

    # Verifica que mensagens foram salvas
    resp = client.get(f"/conversas/{cid}")
    msgs = resp.json()["mensagens"]
    assert len(msgs) == 2
    assert msgs[0]["role"] == "user"
    assert msgs[1]["role"] == "assistant"
