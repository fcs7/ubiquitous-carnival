from unittest.mock import patch


@patch("app.routers.whatsapp.obter_status")
def test_status_evolution_ok(mock_status, client):
    mock_status.return_value = {"instance": {"state": "open"}}
    resp = client.get("/whatsapp/status")
    assert resp.status_code == 200
    assert resp.json()["instance"]["state"] == "open"


@patch("app.routers.whatsapp.obter_status", side_effect=Exception("offline"))
def test_status_evolution_fora(mock_status, client):
    resp = client.get("/whatsapp/status")
    assert resp.status_code == 503


@patch("app.routers.whatsapp.enviar_mensagem", return_value=True)
def test_enviar_teste(mock_enviar, client):
    resp = client.post("/whatsapp/enviar-teste", json={
        "telefone": "61999998888",
        "mensagem": "teste",
    })
    assert resp.status_code == 200
    assert resp.json()["status"] == "enviado"
    mock_enviar.assert_called_once_with("61999998888", "teste")


@patch("app.routers.whatsapp.enviar_mensagem", return_value=False)
def test_enviar_teste_falha(mock_enviar, client):
    resp = client.post("/whatsapp/enviar-teste", json={
        "telefone": "61999998888",
        "mensagem": "teste",
    })
    assert resp.status_code == 502


@patch("app.routers.whatsapp.criar_instancia")
def test_criar_instancia(mock_criar, client):
    mock_criar.return_value = {"instance": {"instanceName": "muglia", "status": "created"}}
    resp = client.post("/whatsapp/instancia")
    assert resp.status_code == 201
    assert resp.json()["instance"]["instanceName"] == "muglia"


@patch("app.routers.whatsapp.obter_qrcode")
def test_qrcode(mock_qr, client):
    mock_qr.return_value = {"base64": "data:image/png;base64,abc123"}
    resp = client.get("/whatsapp/qrcode")
    assert resp.status_code == 200
    assert "base64" in resp.json()


@patch("app.routers.whatsapp.listar_instancias")
def test_listar_instancias(mock_listar, client):
    mock_listar.return_value = [{"instanceName": "muglia"}]
    resp = client.get("/whatsapp/instancias")
    assert resp.status_code == 200
    assert len(resp.json()) == 1
