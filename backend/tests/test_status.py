from unittest.mock import patch, MagicMock


def test_status_tudo_ok(client):
    """Todos os servicos respondendo normalmente."""
    mock_redis = MagicMock()
    mock_redis.ping.return_value = True

    mock_inspect = MagicMock()
    mock_inspect.ping.return_value = {"worker1": {"ok": "pong"}}

    mock_celery = MagicMock()
    mock_celery.control.inspect.return_value = mock_inspect

    mock_resp = MagicMock()
    mock_resp.is_success = True
    mock_resp.status_code = 200

    with (
        patch("app.routers.status.redis.Redis.from_url", return_value=mock_redis),
        patch("app.routers.status.celery_app", mock_celery),
        patch("app.routers.status.httpx.get", return_value=mock_resp),
    ):
        resp = client.get("/api/status")

    assert resp.status_code == 200
    dados = resp.json()
    assert "servicos" in dados
    assert "grafana_url" in dados
    assert len(dados["servicos"]) == 4
    for servico in dados["servicos"]:
        assert servico["status"] == "ok"
        assert servico["detalhes"] is None


def test_status_postgres_erro(client):
    """PostgreSQL falhando, demais servicos ok."""
    mock_redis = MagicMock()
    mock_redis.ping.return_value = True

    mock_inspect = MagicMock()
    mock_inspect.ping.return_value = {"worker1": {"ok": "pong"}}

    mock_celery = MagicMock()
    mock_celery.control.inspect.return_value = mock_inspect

    mock_resp = MagicMock()
    mock_resp.is_success = True

    with (
        patch(
            "app.routers.status._verificar_postgres",
            return_value={
                "nome": "PostgreSQL",
                "status": "erro",
                "detalhes": "Connection refused",
            },
        ),
        patch("app.routers.status.redis.Redis.from_url", return_value=mock_redis),
        patch("app.routers.status.celery_app", mock_celery),
        patch("app.routers.status.httpx.get", return_value=mock_resp),
    ):
        resp = client.get("/api/status")

    assert resp.status_code == 200
    dados = resp.json()
    pg = next(s for s in dados["servicos"] if s["nome"] == "PostgreSQL")
    assert pg["status"] == "erro"
    assert pg["detalhes"] == "Connection refused"

    # Demais servicos continuam ok
    for servico in dados["servicos"]:
        if servico["nome"] != "PostgreSQL":
            assert servico["status"] == "ok"


def test_status_redis_erro(client):
    """Redis falhando, demais servicos ok."""
    mock_redis = MagicMock()
    mock_redis.ping.side_effect = Exception("Connection refused")

    mock_inspect = MagicMock()
    mock_inspect.ping.return_value = {"worker1": {"ok": "pong"}}

    mock_celery = MagicMock()
    mock_celery.control.inspect.return_value = mock_inspect

    mock_resp = MagicMock()
    mock_resp.is_success = True

    with (
        patch("app.routers.status.redis.Redis.from_url", return_value=mock_redis),
        patch("app.routers.status.celery_app", mock_celery),
        patch("app.routers.status.httpx.get", return_value=mock_resp),
    ):
        resp = client.get("/api/status")

    assert resp.status_code == 200
    dados = resp.json()
    redis_svc = next(s for s in dados["servicos"] if s["nome"] == "Redis")
    assert redis_svc["status"] == "erro"
    assert "Connection refused" in redis_svc["detalhes"]


def test_status_celery_sem_worker(client):
    """Nenhum worker Celery ativo."""
    mock_redis = MagicMock()
    mock_redis.ping.return_value = True

    mock_inspect = MagicMock()
    mock_inspect.ping.return_value = None

    mock_celery = MagicMock()
    mock_celery.control.inspect.return_value = mock_inspect

    mock_resp = MagicMock()
    mock_resp.is_success = True

    with (
        patch("app.routers.status.redis.Redis.from_url", return_value=mock_redis),
        patch("app.routers.status.celery_app", mock_celery),
        patch("app.routers.status.httpx.get", return_value=mock_resp),
    ):
        resp = client.get("/api/status")

    assert resp.status_code == 200
    dados = resp.json()
    celery_svc = next(s for s in dados["servicos"] if s["nome"] == "Celery Worker")
    assert celery_svc["status"] == "erro"
    assert celery_svc["detalhes"] == "Nenhum worker ativo"


def test_status_evolution_erro(client):
    """Evolution API fora do ar."""
    mock_redis = MagicMock()
    mock_redis.ping.return_value = True

    mock_inspect = MagicMock()
    mock_inspect.ping.return_value = {"worker1": {"ok": "pong"}}

    mock_celery = MagicMock()
    mock_celery.control.inspect.return_value = mock_inspect

    with (
        patch("app.routers.status.redis.Redis.from_url", return_value=mock_redis),
        patch("app.routers.status.celery_app", mock_celery),
        patch(
            "app.routers.status.httpx.get",
            side_effect=Exception("Connection refused"),
        ),
    ):
        resp = client.get("/api/status")

    assert resp.status_code == 200
    dados = resp.json()
    evo = next(s for s in dados["servicos"] if s["nome"] == "Evolution API")
    assert evo["status"] == "erro"
    assert "Connection refused" in evo["detalhes"]
