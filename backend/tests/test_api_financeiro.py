import pytest
from app.models import Cliente, Processo


@pytest.fixture(autouse=True)
def seed_data(db):
    cliente = Cliente(
        id=1, nome="Teste Silva", cpf_cnpj="111.222.333-44", telefone="11999990000"
    )
    processo = Processo(
        id=1,
        cnj="0000001-00.2025.8.26.0100",
        numero_limpo="00000010020258260100",
        tribunal="TJSP",
        alias_tribunal="tjsp",
    )
    db.add_all([cliente, processo])
    db.commit()


def test_criar_lancamento(client):
    resp = client.post("/financeiro/", json={
        "processo_id": 1,
        "cliente_id": 1,
        "tipo": "honorario",
        "descricao": "Honorarios iniciais",
        "valor": 5000.00,
        "data_vencimento": "2025-06-15",
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["tipo"] == "honorario"
    assert data["valor"] == 5000.00
    assert data["status"] == "pendente"


def test_listar_por_status(client):
    client.post("/financeiro/", json={
        "processo_id": 1, "cliente_id": 1,
        "tipo": "custas", "valor": 200.00,
    })
    client.post("/financeiro/", json={
        "processo_id": 1, "cliente_id": 1,
        "tipo": "honorario", "valor": 3000.00,
    })
    resp = client.get("/financeiro/?status=pendente")
    assert resp.status_code == 200
    assert len(resp.json()) == 2


def test_marcar_como_pago(client):
    r = client.post("/financeiro/", json={
        "processo_id": 1, "cliente_id": 1,
        "tipo": "custas", "valor": 150.00,
    })
    lid = r.json()["id"]
    resp = client.patch(f"/financeiro/{lid}/pagar")
    assert resp.status_code == 200
    data = resp.json()
    assert data["status"] == "pago"
    assert data["data_pagamento"] is not None


def test_marcar_pago_404(client):
    resp = client.patch("/financeiro/9999/pagar")
    assert resp.status_code == 404


def test_resumo_financeiro(client):
    r1 = client.post("/financeiro/", json={
        "processo_id": 1, "cliente_id": 1,
        "tipo": "honorario", "valor": 1000.00,
    })
    client.post("/financeiro/", json={
        "processo_id": 1, "cliente_id": 1,
        "tipo": "custas", "valor": 500.00,
    })
    lid = r1.json()["id"]
    client.patch(f"/financeiro/{lid}/pagar")

    resp = client.get("/financeiro/resumo")
    assert resp.status_code == 200
    data = resp.json()
    assert data["pago"] == 1000.00
    assert data["pendente"] == 500.00
    assert data["total"] == 1500.00
