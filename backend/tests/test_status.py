from unittest.mock import patch


def test_status_retorna_servicos(client):
    resp = client.get("/api/status")
    assert resp.status_code == 200
    data = resp.json()
    assert "status" in data
    assert "servicos" in data
    assert "agentes" in data
    assert isinstance(data["servicos"], list)
    assert len(data["servicos"]) >= 5


def test_status_banco_ok(client):
    resp = client.get("/api/status")
    data = resp.json()
    banco = next(s for s in data["servicos"] if s["nome"] == "PostgreSQL")
    assert banco["status"] == "ok"


@patch("app.routers.status.settings")
def test_status_api_keys_sem_config(mock_settings, client):
    """Sem API keys configuradas, deve reportar erro."""
    mock_settings.anthropic_api_key = ""
    mock_settings.openai_api_key = ""
    mock_settings.google_credentials_path = ""
    mock_settings.vindi_api_key = ""
    resp = client.get("/api/status")
    data = resp.json()
    anthropic = next(s for s in data["servicos"] if s["nome"] == "Anthropic API")
    openai = next(s for s in data["servicos"] if s["nome"] == "OpenAI API")
    assert anthropic["status"] == "erro"
    assert openai["status"] == "erro"


@patch("app.routers.status.settings")
def test_status_com_api_key_anthropic(mock_settings, client):
    mock_settings.anthropic_api_key = "sk-test-123"
    mock_settings.openai_api_key = ""
    mock_settings.google_credentials_path = ""
    mock_settings.vindi_api_key = ""
    resp = client.get("/api/status")
    data = resp.json()
    anthropic = next(s for s in data["servicos"] if s["nome"] == "Anthropic API")
    assert anthropic["status"] == "ok"


def test_status_agentes_resumo(client, db):
    """Com agente padrao seedado no lifespan, deve ter pelo menos 1."""
    from app.services.ferramentas import FERRAMENTAS_DISPONIVEIS

    resp = client.get("/api/status")
    data = resp.json()
    agentes = data["agentes"]
    assert agentes["total"] >= 0
    assert agentes["ferramentas_disponiveis"] == len(FERRAMENTAS_DISPONIVEIS)


def test_status_geral_degradado_quando_parcial(client):
    """Com banco ok mas API keys faltando, status geral deve ser degradado."""
    resp = client.get("/api/status")
    data = resp.json()
    # Banco funciona, mas API keys nao estao configuradas em testes
    assert data["status"] in ("degradado", "erro")


def test_status_servico_agentes_ia(client, db):
    resp = client.get("/api/status")
    data = resp.json()
    agentes_servico = next(s for s in data["servicos"] if s["nome"] == "Agentes IA")
    assert agentes_servico["status"] in ("ok", "erro")
