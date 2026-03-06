import hashlib
import hmac
import json

from app.models import Financeiro, VindiBill, VindiCustomer, VindiSubscription


def _sign(body: bytes, secret: str) -> str:
    return hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()


def _webhook_payload(event_type: str, data: dict) -> dict:
    return {"event": {"type": event_type, "data": data}}


# ── Validacao HMAC ──────────────────────────────

def test_webhook_signature_invalida(client, monkeypatch):
    monkeypatch.setattr("app.config.settings.vindi_webhook_secret", "segredo123")
    body = json.dumps(_webhook_payload("customer_created", {"customer": {"id": 1, "name": "Teste"}}))
    r = client.post("/webhooks/vindi", content=body, headers={
        "Content-Type": "application/json",
        "X-Vindi-Signature": "assinatura_errada",
    })
    assert r.status_code == 401


def test_webhook_signature_valida(client, monkeypatch):
    monkeypatch.setattr("app.config.settings.vindi_webhook_secret", "segredo123")
    body = json.dumps(_webhook_payload("customer_created", {"customer": {"id": 1, "name": "Teste"}})).encode()
    sig = _sign(body, "segredo123")
    r = client.post("/webhooks/vindi", content=body, headers={
        "Content-Type": "application/json",
        "X-Vindi-Signature": sig,
    })
    assert r.status_code == 200


def test_webhook_sem_secret_aceita_tudo(client, monkeypatch):
    monkeypatch.setattr("app.config.settings.vindi_webhook_secret", "")
    body = json.dumps(_webhook_payload("customer_created", {"customer": {"id": 99, "name": "Sem Secret"}}))
    r = client.post("/webhooks/vindi", content=body, headers={"Content-Type": "application/json"})
    assert r.status_code == 200


# ── Customer created ────────────────────────────

def test_customer_created(client, db, monkeypatch):
    monkeypatch.setattr("app.config.settings.vindi_webhook_secret", "")
    payload = _webhook_payload("customer_created", {
        "customer": {"id": 42, "name": "Joao Silva", "email": "joao@test.com", "registry_code": "12345678901"},
    })
    r = client.post("/webhooks/vindi", json=payload)
    assert r.status_code == 200

    vc = db.query(VindiCustomer).filter_by(vindi_id=42).first()
    assert vc is not None
    assert vc.nome == "Joao Silva"
    assert vc.email == "joao@test.com"
    assert vc.cpf_cnpj == "12345678901"
    assert vc.status_sync == "pendente"


# ── Bill created sem vinculo ────────────────────

def test_bill_created_sem_vinculo(client, db, monkeypatch):
    monkeypatch.setattr("app.config.settings.vindi_webhook_secret", "")

    # Criar customer primeiro
    client.post("/webhooks/vindi", json=_webhook_payload("customer_created", {
        "customer": {"id": 10, "name": "Maria"},
    }))

    payload = _webhook_payload("bill_created", {
        "bill": {
            "id": 100,
            "customer": {"id": 10, "name": "Maria"},
            "amount": 500.00,
            "status": "pending",
            "due_at": "2026-04-01",
        },
    })
    r = client.post("/webhooks/vindi", json=payload)
    assert r.status_code == 200

    vb = db.query(VindiBill).filter_by(vindi_id=100).first()
    assert vb is not None
    assert float(vb.valor) == 500.00
    assert vb.financeiro_id is None  # sem vinculo, nao cria Financeiro


# ── Bill created com vinculo completo ───────────

def test_bill_created_com_vinculo_completo(client, db, monkeypatch):
    monkeypatch.setattr("app.config.settings.vindi_webhook_secret", "")
    from app.models import Cliente, Processo

    # Setup: cliente + processo
    cliente = Cliente(nome="Pedro", cpf_cnpj="111", telefone="11999")
    db.add(cliente)
    db.flush()

    processo = Processo(cnj="0000001-00.2026.8.26.0001", numero_limpo="00000010020268260001",
                        tribunal="TJSP", alias_tribunal="tjsp")
    db.add(processo)
    db.flush()

    # Customer vinculado
    from app.models import VindiCustomer as VC, VindiSubscription as VS
    vc = VC(vindi_id=20, nome="Pedro", cliente_id=cliente.id, status_sync="vinculado")
    db.add(vc)
    db.flush()

    vs = VS(vindi_id=200, vindi_customer_id=vc.id, processo_id=processo.id, status="active")
    db.add(vs)
    db.commit()

    payload = _webhook_payload("bill_created", {
        "bill": {
            "id": 300,
            "customer": {"id": 20, "name": "Pedro"},
            "subscription": {"id": 200},
            "amount": 1500.00,
            "status": "pending",
            "due_at": "2026-05-01",
        },
    })
    r = client.post("/webhooks/vindi", json=payload)
    assert r.status_code == 200

    vb = db.query(VindiBill).filter_by(vindi_id=300).first()
    assert vb is not None
    assert vb.financeiro_id is not None

    fin = db.get(Financeiro, vb.financeiro_id)
    assert fin.cliente_id == cliente.id
    assert fin.processo_id == processo.id
    assert fin.status == "pendente"
    assert float(fin.valor) == 1500.00


# ── Bill paid atualiza Financeiro ───────────────

def test_bill_paid(client, db, monkeypatch):
    monkeypatch.setattr("app.config.settings.vindi_webhook_secret", "")
    from app.models import Cliente, Processo
    from app.models import VindiCustomer as VC, VindiSubscription as VS

    cliente = Cliente(nome="Ana", cpf_cnpj="222", telefone="11888")
    db.add(cliente)
    db.flush()
    processo = Processo(cnj="0000002-00.2026.8.26.0001", numero_limpo="00000020020268260001",
                        tribunal="TJSP", alias_tribunal="tjsp")
    db.add(processo)
    db.flush()
    vc = VC(vindi_id=30, nome="Ana", cliente_id=cliente.id, status_sync="vinculado")
    db.add(vc)
    db.flush()
    vs = VS(vindi_id=300, vindi_customer_id=vc.id, processo_id=processo.id, status="active")
    db.add(vs)
    db.commit()

    # Cria bill
    client.post("/webhooks/vindi", json=_webhook_payload("bill_created", {
        "bill": {"id": 400, "customer": {"id": 30, "name": "Ana"}, "subscription": {"id": 300},
                 "amount": 800.00, "status": "pending", "due_at": "2026-06-01"},
    }))

    # Paga bill
    r = client.post("/webhooks/vindi", json=_webhook_payload("bill_paid", {
        "bill": {"id": 400, "paid_at": "2026-06-01"},
    }))
    assert r.status_code == 200

    vb = db.query(VindiBill).filter_by(vindi_id=400).first()
    assert vb.status == "paid"

    fin = db.get(Financeiro, vb.financeiro_id)
    assert fin.status == "pago"
    assert fin.data_pagamento is not None
