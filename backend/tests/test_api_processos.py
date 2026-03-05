from unittest.mock import patch


FAKE_DATAJUD_RESPONSE = {
    "classe": {"codigo": 1116, "nome": "Procedimento Comum Civel"},
    "orgaoJulgador": {"nome": "1a Vara Civel"},
    "grau": "G1",
    "dataAjuizamento": "2024-01-15T10:30:00",
    "movimentos": [
        {
            "codigo": 26,
            "nome": "Distribuicao",
            "dataHora": "2024-01-15T10:30:00",
            "complementosTabelados": [
                {"nome": "tipo", "valor": "sorteio"}
            ],
        },
        {
            "codigo": 60,
            "nome": "Expedicao de documento",
            "dataHora": "2024-02-20T14:00:00",
            "complementosTabelados": [],
        },
    ],
}

VALID_CNJ = "0000001-23.2024.8.26.0100"


@patch("app.routers.processos.consultar_processo", return_value=FAKE_DATAJUD_RESPONSE)
def test_cadastrar_processo(mock_datajud, client):
    resp = client.post("/processos/", json={"cnj": VALID_CNJ})
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["cnj"] == VALID_CNJ
    assert data["alias_tribunal"] == "tjsp"
    assert data["classe_codigo"] == 1116
    mock_datajud.assert_called_once()


def test_cnj_invalido_retorna_400(client):
    resp = client.post("/processos/", json={"cnj": "123-invalid"})
    assert resp.status_code == 400
    assert "invalido" in resp.json()["detail"].lower()


@patch("app.routers.processos.consultar_processo", return_value=FAKE_DATAJUD_RESPONSE)
def test_cnj_duplicado_retorna_409(mock_datajud, client):
    resp1 = client.post("/processos/", json={"cnj": VALID_CNJ})
    assert resp1.status_code == 201
    resp2 = client.post("/processos/", json={"cnj": VALID_CNJ})
    assert resp2.status_code == 409


@patch("app.routers.processos.consultar_processo", return_value=FAKE_DATAJUD_RESPONSE)
def test_listar_processos(mock_datajud, client):
    client.post("/processos/", json={"cnj": VALID_CNJ})
    resp = client.get("/processos/")
    assert resp.status_code == 200
    assert len(resp.json()) == 1


@patch("app.routers.processos.consultar_processo", return_value=FAKE_DATAJUD_RESPONSE)
def test_detalhe_processo(mock_datajud, client):
    r = client.post("/processos/", json={"cnj": VALID_CNJ})
    pid = r.json()["id"]
    resp = client.get(f"/processos/{pid}")
    assert resp.status_code == 200
    assert resp.json()["cnj"] == VALID_CNJ


@patch("app.routers.processos.consultar_processo", return_value=FAKE_DATAJUD_RESPONSE)
def test_listar_movimentos(mock_datajud, client):
    r = client.post("/processos/", json={"cnj": VALID_CNJ})
    pid = r.json()["id"]
    resp = client.get(f"/processos/{pid}/movimentos")
    assert resp.status_code == 200
    movs = resp.json()
    assert len(movs) == 2


@patch("app.routers.processos.consultar_processo", return_value=FAKE_DATAJUD_RESPONSE)
def test_filtrar_por_status(mock_datajud, client):
    client.post("/processos/", json={"cnj": VALID_CNJ})
    resp = client.get("/processos/?status=ativo")
    assert resp.status_code == 200
    assert len(resp.json()) == 1
    resp2 = client.get("/processos/?status=arquivado")
    assert len(resp2.json()) == 0


@patch("app.routers.processos.consultar_processo", return_value=FAKE_DATAJUD_RESPONSE)
def test_busca_por_cnj(mock_datajud, client):
    client.post("/processos/", json={"cnj": VALID_CNJ})
    resp = client.get("/processos/?busca=0000001")
    assert resp.status_code == 200
    assert len(resp.json()) == 1
