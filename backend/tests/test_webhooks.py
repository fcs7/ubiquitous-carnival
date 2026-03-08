from unittest.mock import patch

from app.routers.webhooks import formatar_alertas, AlertmanagerPayload


PAYLOAD_FIRING = {
    "status": "firing",
    "alerts": [
        {
            "status": "firing",
            "labels": {
                "alertname": "ServicoIndisponivel",
                "severity": "critico",
                "instance": "backend:8000",
            },
            "annotations": {
                "summary": "Servico backend esta indisponivel",
                "description": "Detalhes do problema",
            },
            "startsAt": "2026-03-08T10:00:00Z",
            "endsAt": "0001-01-01T00:00:00Z",
        }
    ],
}

PAYLOAD_RESOLVED = {
    "status": "resolved",
    "alerts": [
        {
            "status": "resolved",
            "labels": {
                "alertname": "ServicoIndisponivel",
                "severity": "critico",
                "instance": "backend:8000",
            },
            "annotations": {
                "summary": "Servico backend voltou ao normal",
                "description": "",
            },
            "startsAt": "2026-03-08T10:00:00Z",
            "endsAt": "2026-03-08T10:15:00Z",
        }
    ],
}

PAYLOAD_MULTIPLOS = {
    "status": "firing",
    "alerts": [
        {
            "status": "firing",
            "labels": {"alertname": "CPU Alta", "severity": "warning", "instance": "backend:8000"},
            "annotations": {"summary": "CPU acima de 90%", "description": ""},
            "startsAt": "2026-03-08T09:00:00Z",
            "endsAt": "0001-01-01T00:00:00Z",
        },
        {
            "status": "firing",
            "labels": {"alertname": "Memoria Alta", "severity": "critical", "instance": "db:5432"},
            "annotations": {"summary": "Memoria acima de 95%", "description": ""},
            "startsAt": "2026-03-08T09:05:00Z",
            "endsAt": "0001-01-01T00:00:00Z",
        },
    ],
}


# --- Testes de formatacao ---


def test_formatar_alertas_firing():
    payload = AlertmanagerPayload(**PAYLOAD_FIRING)
    msg = formatar_alertas(payload)
    assert "ALERTA MUGLIA - DISPARANDO" in msg
    assert "ServicoIndisponivel" in msg
    assert "critico" in msg
    assert "backend:8000" in msg
    assert "Servico backend esta indisponivel" in msg
    assert "08/03/2026 10:00" in msg


def test_formatar_alertas_resolved():
    payload = AlertmanagerPayload(**PAYLOAD_RESOLVED)
    msg = formatar_alertas(payload)
    assert "ALERTA MUGLIA - RESOLVIDO" in msg
    assert "\u2705" in msg  # check mark


def test_formatar_alertas_multiplos():
    payload = AlertmanagerPayload(**PAYLOAD_MULTIPLOS)
    msg = formatar_alertas(payload)
    assert "CPU Alta" in msg
    assert "Memoria Alta" in msg
    assert "aviso" in msg  # warning -> aviso
    assert "critico" in msg  # critical -> critico


def test_formatar_severidade_ingles_para_portugues():
    payload = AlertmanagerPayload(**{
        "status": "firing",
        "alerts": [
            {
                "status": "firing",
                "labels": {"alertname": "Teste", "severity": "warning", "instance": "x"},
                "annotations": {"summary": "Teste", "description": ""},
                "startsAt": "2026-03-08T10:00:00Z",
                "endsAt": "0001-01-01T00:00:00Z",
            }
        ],
    })
    msg = formatar_alertas(payload)
    assert "aviso" in msg


# --- Testes do endpoint ---


@patch("app.routers.webhooks.settings")
@patch("app.routers.webhooks.enviar_mensagem", return_value=True)
def test_alertmanager_envia_com_sucesso(mock_enviar, mock_settings, client):
    mock_settings.alert_whatsapp_number = "5561999998888"
    resp = client.post("/webhooks/alertmanager", json=PAYLOAD_FIRING)
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "enviado"
    assert data["alertas"] == 1
    assert data["destino"] == "5561999998888"
    mock_enviar.assert_called_once()
    # Verificar conteudo da mensagem enviada
    msg_enviada = mock_enviar.call_args[0][1]
    assert "ServicoIndisponivel" in msg_enviada


@patch("app.routers.webhooks.settings")
@patch("app.routers.webhooks.enviar_mensagem", return_value=False)
def test_alertmanager_falha_envio(mock_enviar, mock_settings, client):
    mock_settings.alert_whatsapp_number = "5561999998888"
    resp = client.post("/webhooks/alertmanager", json=PAYLOAD_FIRING)
    assert resp.status_code == 502
    assert "Evolution API" in resp.json()["detail"]


@patch("app.routers.webhooks.settings")
def test_alertmanager_sem_numero_configurado(mock_settings, client):
    mock_settings.alert_whatsapp_number = ""
    resp = client.post("/webhooks/alertmanager", json=PAYLOAD_FIRING)
    assert resp.status_code == 422
    assert "ALERT_WHATSAPP_NUMBER" in resp.json()["detail"]


@patch("app.routers.webhooks.settings")
def test_alertmanager_payload_sem_alertas(mock_settings, client):
    mock_settings.alert_whatsapp_number = "5561999998888"
    resp = client.post("/webhooks/alertmanager", json={"status": "firing", "alerts": []})
    assert resp.status_code == 200
    assert resp.json()["status"] == "ignorado"


@patch("app.routers.webhooks.settings")
@patch("app.routers.webhooks.enviar_mensagem", return_value=True)
def test_alertmanager_multiplos_alertas(mock_enviar, mock_settings, client):
    mock_settings.alert_whatsapp_number = "5561999998888"
    resp = client.post("/webhooks/alertmanager", json=PAYLOAD_MULTIPLOS)
    assert resp.status_code == 200
    assert resp.json()["alertas"] == 2
    msg_enviada = mock_enviar.call_args[0][1]
    assert "CPU Alta" in msg_enviada
    assert "Memoria Alta" in msg_enviada


@patch("app.routers.webhooks.settings")
@patch("app.routers.webhooks.enviar_mensagem", return_value=True)
def test_alertmanager_resolved(mock_enviar, mock_settings, client):
    mock_settings.alert_whatsapp_number = "5561999998888"
    resp = client.post("/webhooks/alertmanager", json=PAYLOAD_RESOLVED)
    assert resp.status_code == 200
    msg_enviada = mock_enviar.call_args[0][1]
    assert "RESOLVIDO" in msg_enviada
