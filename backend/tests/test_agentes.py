from app.models import Usuario, AgenteConfig


def _criar_usuario(db):
    u = Usuario(nome="Adv Teste", email="adv@agente.com", oab="12345/SP")
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


def test_criar_agente(client, db):
    usuario = _criar_usuario(db)
    resp = client.post("/agentes/", json={
        "nome": "Agente Trabalhista",
        "usuario_id": usuario.id,
        "instrucoes_sistema": "Especialista em direito trabalhista",
        "modelo": "claude-sonnet-4-5-20250514",
        "ferramentas_habilitadas": ["buscar_processo", "buscar_cliente"],
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["nome"] == "Agente Trabalhista"
    assert data["ferramentas_habilitadas"] == ["buscar_processo", "buscar_cliente"]
    assert data["ativo"] is True


def test_listar_ferramentas_disponiveis(client):
    resp = client.get("/agentes/ferramentas/disponiveis")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) >= 5
    nomes = [f["nome"] for f in data]
    assert "buscar_processo" in nomes
    assert "buscar_cliente" in nomes
    assert "calcular_prazo" in nomes
    for f in data:
        assert "descricao_ui" in f
        assert "categoria" in f


def test_listar_agentes(client, db):
    usuario = _criar_usuario(db)
    client.post("/agentes/", json={"nome": "A1", "usuario_id": usuario.id})
    client.post("/agentes/", json={"nome": "A2", "usuario_id": usuario.id})

    resp = client.get(f"/agentes/?usuario_id={usuario.id}")
    assert resp.status_code == 200
    assert len(resp.json()) == 2


def test_detalhe_agente(client, db):
    usuario = _criar_usuario(db)
    resp = client.post("/agentes/", json={"nome": "Detalhe", "usuario_id": usuario.id})
    aid = resp.json()["id"]

    resp = client.get(f"/agentes/{aid}")
    assert resp.status_code == 200
    assert resp.json()["nome"] == "Detalhe"


def test_atualizar_agente(client, db):
    usuario = _criar_usuario(db)
    resp = client.post("/agentes/", json={"nome": "V1", "usuario_id": usuario.id})
    aid = resp.json()["id"]

    resp = client.put(f"/agentes/{aid}", json={
        "nome": "V2",
        "ferramentas_habilitadas": ["buscar_processo", "resumo_financeiro"],
        "instrucoes_sistema": "Foco em financeiro",
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["nome"] == "V2"
    assert "resumo_financeiro" in data["ferramentas_habilitadas"]


def test_deletar_agente(client, db):
    usuario = _criar_usuario(db)
    resp = client.post("/agentes/", json={"nome": "Del", "usuario_id": usuario.id})
    aid = resp.json()["id"]

    resp = client.delete(f"/agentes/{aid}")
    assert resp.status_code == 204

    resp = client.get(f"/agentes/{aid}")
    assert resp.status_code == 404


def test_agente_inexistente(client):
    resp = client.get("/agentes/9999")
    assert resp.status_code == 404


def test_criar_conversa_com_agente(client, db):
    usuario = _criar_usuario(db)
    resp = client.post("/agentes/", json={"nome": "Agente", "usuario_id": usuario.id})
    aid = resp.json()["id"]

    resp = client.post("/conversas/", json={
        "titulo": "Chat com agente",
        "usuario_id": usuario.id,
        "agente_id": aid,
    })
    assert resp.status_code == 201
    assert resp.json()["agente_id"] == aid
