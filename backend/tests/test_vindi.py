from app.models import (
    Cliente, Financeiro, Processo, VindiBill, VindiCustomer, VindiSubscription,
)


def _setup_completo(db):
    """Cria cenario completo: cliente, processo, customer, subscription, bill."""
    cliente = Cliente(nome="Carlos", cpf_cnpj="333", telefone="11777")
    db.add(cliente)
    db.flush()

    processo = Processo(
        cnj="0000003-00.2026.8.26.0001", numero_limpo="00000030020268260001",
        tribunal="TJSP", alias_tribunal="tjsp",
    )
    db.add(processo)
    db.flush()

    vc = VindiCustomer(vindi_id=50, nome="Carlos Vindi", status_sync="pendente")
    db.add(vc)
    db.flush()

    vs = VindiSubscription(vindi_id=500, vindi_customer_id=vc.id, status="active")
    db.add(vs)
    db.flush()

    vb = VindiBill(vindi_id=5000, vindi_customer_id=vc.id, vindi_subscription_id=vs.id,
                   valor=2000.00, status="pending", data_vencimento=None)
    db.add(vb)
    db.commit()

    return cliente, processo, vc, vs, vb


def test_vincular_customer_a_cliente(client, db):
    cliente, processo, vc, vs, vb = _setup_completo(db)

    r = client.post(f"/vindi/customers/{vc.id}/vincular", json={"cliente_id": cliente.id})
    assert r.status_code == 200
    assert r.json()["status_sync"] == "vinculado"
    assert r.json()["cliente_id"] == cliente.id


def test_vincular_customer_cria_cliente_novo(client, db):
    vc = VindiCustomer(vindi_id=60, nome="Novo Cliente", email="novo@test.com",
                       cpf_cnpj="44444444444", telefone="11666", status_sync="pendente")
    db.add(vc)
    db.commit()

    r = client.post(f"/vindi/customers/{vc.id}/vincular", json={"cliente_id": None})
    assert r.status_code == 200
    assert r.json()["status_sync"] == "vinculado"

    novo_cliente = db.query(Cliente).filter_by(nome="Novo Cliente").first()
    assert novo_cliente is not None
    assert novo_cliente.cpf_cnpj == "44444444444"


def test_vincular_subscription_a_processo(client, db):
    cliente, processo, vc, vs, vb = _setup_completo(db)

    r = client.post(f"/vindi/subscriptions/{vs.id}/vincular", json={"processo_id": processo.id})
    assert r.status_code == 200
    assert r.json()["processo_id"] == processo.id


def test_vinculacao_retroativa_cria_financeiro(client, db):
    """Vincular customer + subscription com bills existentes cria Financeiro."""
    cliente, processo, vc, vs, vb = _setup_completo(db)

    # Vincula subscription a processo
    client.post(f"/vindi/subscriptions/{vs.id}/vincular", json={"processo_id": processo.id})

    # Vincula customer a cliente — deve criar Financeiro retroativamente
    client.post(f"/vindi/customers/{vc.id}/vincular", json={"cliente_id": cliente.id})

    db.refresh(vb)
    assert vb.financeiro_id is not None

    fin = db.get(Financeiro, vb.financeiro_id)
    assert fin.cliente_id == cliente.id
    assert fin.processo_id == processo.id
    assert float(fin.valor) == 2000.00


def test_ignorar_customer(client, db):
    vc = VindiCustomer(vindi_id=70, nome="Ignorado", status_sync="pendente")
    db.add(vc)
    db.commit()

    r = client.post(f"/vindi/customers/{vc.id}/ignorar")
    assert r.status_code == 200
    assert r.json()["status_sync"] == "ignorado"


def test_listar_customers_filtro(client, db):
    db.add(VindiCustomer(vindi_id=80, nome="A", status_sync="pendente"))
    db.add(VindiCustomer(vindi_id=81, nome="B", status_sync="vinculado"))
    db.commit()

    r = client.get("/vindi/customers?status_sync=pendente")
    assert r.status_code == 200
    assert len(r.json()) == 1
    assert r.json()[0]["nome"] == "A"


def test_listar_bills(client, db):
    vc = VindiCustomer(vindi_id=90, nome="Bills", status_sync="pendente")
    db.add(vc)
    db.flush()
    db.add(VindiBill(vindi_id=900, vindi_customer_id=vc.id, valor=100, status="pending"))
    db.add(VindiBill(vindi_id=901, vindi_customer_id=vc.id, valor=200, status="paid"))
    db.commit()

    r = client.get("/vindi/bills?status=paid")
    assert r.status_code == 200
    assert len(r.json()) == 1
    assert float(r.json()[0]["valor"]) == 200.0
