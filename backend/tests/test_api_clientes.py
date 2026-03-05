def _cliente_payload(**kwargs):
    base = {
        "nome": "Maria Silva",
        "cpf_cnpj": "123.456.789-00",
        "telefone": "11999990000",
    }
    base.update(kwargs)
    return base


def test_criar_cliente(client):
    resp = client.post("/clientes/", json=_cliente_payload())
    assert resp.status_code == 201
    data = resp.json()
    assert data["nome"] == "Maria Silva"
    assert data["cpf_cnpj"] == "123.456.789-00"
    assert data["id"] is not None


def test_listar_clientes(client):
    client.post("/clientes/", json=_cliente_payload())
    client.post("/clientes/", json=_cliente_payload(
        nome="Joao Santos", cpf_cnpj="987.654.321-00", telefone="11888880000"
    ))
    resp = client.get("/clientes/")
    assert resp.status_code == 200
    assert len(resp.json()) == 2


def test_buscar_por_nome(client):
    client.post("/clientes/", json=_cliente_payload())
    client.post("/clientes/", json=_cliente_payload(
        nome="Joao Santos", cpf_cnpj="987.654.321-00", telefone="11888880000"
    ))
    resp = client.get("/clientes/", params={"busca": "Maria"})
    assert resp.status_code == 200
    resultados = resp.json()
    assert len(resultados) == 1
    assert resultados[0]["nome"] == "Maria Silva"


def test_buscar_por_cpf(client):
    client.post("/clientes/", json=_cliente_payload())
    resp = client.get("/clientes/", params={"busca": "123.456"})
    assert resp.status_code == 200
    assert len(resp.json()) == 1


def test_detalhe_cliente(client):
    resp_create = client.post("/clientes/", json=_cliente_payload())
    cid = resp_create.json()["id"]
    resp = client.get(f"/clientes/{cid}")
    assert resp.status_code == 200
    assert resp.json()["nome"] == "Maria Silva"


def test_atualizar_cliente(client):
    resp_create = client.post("/clientes/", json=_cliente_payload())
    cid = resp_create.json()["id"]
    resp = client.put(f"/clientes/{cid}", json={"nome": "Maria S. Oliveira"})
    assert resp.status_code == 200
    assert resp.json()["nome"] == "Maria S. Oliveira"


def test_deletar_cliente(client):
    resp_create = client.post("/clientes/", json=_cliente_payload())
    cid = resp_create.json()["id"]
    resp = client.delete(f"/clientes/{cid}")
    assert resp.status_code == 204
    resp = client.get(f"/clientes/{cid}")
    assert resp.status_code == 404


def test_cliente_inexistente_retorna_404(client):
    resp = client.get("/clientes/9999")
    assert resp.status_code == 404
    assert resp.json()["detail"] == "Cliente nao encontrado"
