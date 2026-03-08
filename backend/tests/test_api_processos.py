VALID_CNJ = "0000001-23.2024.8.26.0100"


def test_cadastrar_processo(client):
    resp = client.post("/processos/", json={"cnj": VALID_CNJ})
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["cnj"] == VALID_CNJ
    assert data["alias_tribunal"] == "tjsp"


def test_cnj_invalido_retorna_400(client):
    resp = client.post("/processos/", json={"cnj": "123-invalid"})
    assert resp.status_code == 400
    assert "invalido" in resp.json()["detail"].lower()


def test_cnj_duplicado_retorna_409(client):
    resp1 = client.post("/processos/", json={"cnj": VALID_CNJ})
    assert resp1.status_code == 201
    resp2 = client.post("/processos/", json={"cnj": VALID_CNJ})
    assert resp2.status_code == 409


def test_listar_processos(client):
    client.post("/processos/", json={"cnj": VALID_CNJ})
    resp = client.get("/processos/")
    assert resp.status_code == 200
    assert len(resp.json()) == 1


def test_detalhe_processo(client):
    r = client.post("/processos/", json={"cnj": VALID_CNJ})
    pid = r.json()["id"]
    resp = client.get(f"/processos/{pid}")
    assert resp.status_code == 200
    assert resp.json()["cnj"] == VALID_CNJ


def test_filtrar_por_status(client):
    client.post("/processos/", json={"cnj": VALID_CNJ})
    resp = client.get("/processos/?status=ativo")
    assert resp.status_code == 200
    assert len(resp.json()) == 1
    resp2 = client.get("/processos/?status=arquivado")
    assert len(resp2.json()) == 0


def test_busca_por_cnj(client):
    client.post("/processos/", json={"cnj": VALID_CNJ})
    resp = client.get("/processos/?busca=0000001")
    assert resp.status_code == 200
    assert len(resp.json()) == 1
