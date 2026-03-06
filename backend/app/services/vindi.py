import hashlib
import hmac
import json
from datetime import date

from sqlalchemy.orm import Session

from app.models import (
    Financeiro, VindiBill, VindiCustomer, VindiProduct, VindiSubscription,
)


def validar_signature(payload_bytes: bytes, signature: str, secret: str) -> bool:
    expected = hmac.new(secret.encode(), payload_bytes, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)


# ── Auto-criacao de Financeiro ──────────────────

def auto_criar_financeiro(db: Session, vindi_bill: VindiBill, vindi_customer: VindiCustomer, vindi_subscription: VindiSubscription | None) -> Financeiro | None:
    """Cria Financeiro se customer vinculado E subscription com processo."""
    if not vindi_customer.cliente_id:
        return None
    if not vindi_subscription or not vindi_subscription.processo_id:
        return None

    status_map = {"pending": "pendente", "paid": "pago", "canceled": "cancelado"}
    lancamento = Financeiro(
        processo_id=vindi_subscription.processo_id,
        cliente_id=vindi_customer.cliente_id,
        tipo="honorario",
        descricao=f"Vindi bill #{vindi_bill.vindi_id}",
        valor=vindi_bill.valor,
        status=status_map.get(vindi_bill.status, "pendente"),
        data_vencimento=vindi_bill.data_vencimento,
        data_pagamento=vindi_bill.data_pagamento,
    )
    db.add(lancamento)
    db.flush()
    vindi_bill.financeiro_id = lancamento.id
    return lancamento


# ── Handlers por evento ─────────────────────────

def _upsert_customer(db: Session, data: dict) -> VindiCustomer:
    customer_data = data.get("customer", data)
    vindi_id = customer_data["id"]
    vc = db.query(VindiCustomer).filter(VindiCustomer.vindi_id == vindi_id).first()
    if not vc:
        vc = VindiCustomer(vindi_id=vindi_id)
        db.add(vc)
    vc.nome = customer_data.get("name", "")
    vc.email = customer_data.get("email")
    vc.cpf_cnpj = customer_data.get("registry_code")
    vc.telefone = customer_data.get("phones", [{}])[0].get("number") if customer_data.get("phones") else None
    vc.dados_json = json.dumps(customer_data)
    db.flush()
    return vc


def handle_customer_created(db: Session, data: dict) -> None:
    _upsert_customer(db, data)
    db.commit()


def handle_customer_updated(db: Session, data: dict) -> None:
    _upsert_customer(db, data)
    db.commit()


def _upsert_product(db: Session, product_data: dict) -> VindiProduct | None:
    if not product_data:
        return None
    vindi_id = product_data["id"]
    vp = db.query(VindiProduct).filter(VindiProduct.vindi_id == vindi_id).first()
    if not vp:
        vp = VindiProduct(vindi_id=vindi_id)
        db.add(vp)
    vp.nome = product_data.get("name", "")
    vp.descricao = product_data.get("description")
    vp.valor = product_data.get("price")
    vp.dados_json = json.dumps(product_data)
    db.flush()
    return vp


def _parse_date(date_str: str | None) -> date | None:
    if not date_str:
        return None
    return date.fromisoformat(date_str[:10])


def handle_subscription_created(db: Session, data: dict) -> None:
    sub_data = data.get("subscription", data)
    vindi_id = sub_data["id"]
    vs = db.query(VindiSubscription).filter(VindiSubscription.vindi_id == vindi_id).first()
    if vs:
        return

    customer_data = sub_data.get("customer", {})
    vc = _upsert_customer(db, {"customer": customer_data}) if customer_data.get("id") else None

    product_data = sub_data.get("product", {})
    vp = _upsert_product(db, product_data) if product_data and product_data.get("id") else None

    vs = VindiSubscription(
        vindi_id=vindi_id,
        vindi_customer_id=vc.id if vc else None,
        vindi_product_id=vp.id if vp else None,
        status=sub_data.get("status", "active"),
        dados_json=json.dumps(sub_data),
    )
    db.add(vs)
    db.commit()


def handle_subscription_canceled(db: Session, data: dict) -> None:
    sub_data = data.get("subscription", data)
    vindi_id = sub_data["id"]
    vs = db.query(VindiSubscription).filter(VindiSubscription.vindi_id == vindi_id).first()
    if vs:
        vs.status = "canceled"
        vs.dados_json = json.dumps(sub_data)
        db.commit()


def handle_bill_created(db: Session, data: dict) -> None:
    bill_data = data.get("bill", data)
    vindi_id = bill_data["id"]

    vb = db.query(VindiBill).filter(VindiBill.vindi_id == vindi_id).first()
    if vb:
        return

    customer_data = bill_data.get("customer", {})
    vc = _upsert_customer(db, {"customer": customer_data}) if customer_data.get("id") else None

    sub_data = bill_data.get("subscription", {})
    vs = None
    if sub_data and sub_data.get("id"):
        vs = db.query(VindiSubscription).filter(VindiSubscription.vindi_id == sub_data["id"]).first()

    vb = VindiBill(
        vindi_id=vindi_id,
        vindi_customer_id=vc.id if vc else None,
        vindi_subscription_id=vs.id if vs else None,
        valor=bill_data.get("amount", 0),
        status=bill_data.get("status", "pending"),
        data_vencimento=_parse_date(bill_data.get("due_at")),
        dados_json=json.dumps(bill_data),
    )
    db.add(vb)
    db.flush()

    if vc and vs:
        auto_criar_financeiro(db, vb, vc, vs)

    db.commit()


def handle_bill_paid(db: Session, data: dict) -> None:
    bill_data = data.get("bill", data)
    vindi_id = bill_data["id"]
    vb = db.query(VindiBill).filter(VindiBill.vindi_id == vindi_id).first()
    if not vb:
        return

    vb.status = "paid"
    vb.data_pagamento = _parse_date(bill_data.get("paid_at")) or date.today()
    vb.dados_json = json.dumps(bill_data)

    if vb.financeiro_id:
        fin = db.get(Financeiro, vb.financeiro_id)
        if fin:
            fin.status = "pago"
            fin.data_pagamento = vb.data_pagamento

    db.commit()


def handle_bill_canceled(db: Session, data: dict) -> None:
    bill_data = data.get("bill", data)
    vindi_id = bill_data["id"]
    vb = db.query(VindiBill).filter(VindiBill.vindi_id == vindi_id).first()
    if not vb:
        return

    vb.status = "canceled"
    vb.dados_json = json.dumps(bill_data)

    if vb.financeiro_id:
        fin = db.get(Financeiro, vb.financeiro_id)
        if fin:
            fin.status = "cancelado"

    db.commit()


def handle_charge_rejected(db: Session, data: dict) -> None:
    charge_data = data.get("charge", data)
    bill_data = charge_data.get("bill", {})
    if bill_data and bill_data.get("id"):
        vb = db.query(VindiBill).filter(VindiBill.vindi_id == bill_data["id"]).first()
        if vb:
            vb.status = "rejected"
            vb.dados_json = json.dumps(charge_data)
            db.commit()


# ── Vinculacao ──────────────────────────────────

def vincular_customer(db: Session, vindi_customer_id: int, cliente_id: int) -> VindiCustomer:
    """Vincula vindi_customer a cliente e processa bills pendentes."""
    vc = db.get(VindiCustomer, vindi_customer_id)
    vc.cliente_id = cliente_id
    vc.status_sync = "vinculado"

    for bill in vc.bills:
        if bill.financeiro_id:
            continue
        vs = bill.vindi_subscription
        if vs and vs.processo_id:
            auto_criar_financeiro(db, bill, vc, vs)

    db.commit()
    return vc


def vincular_subscription(db: Session, vindi_subscription_id: int, processo_id: int) -> VindiSubscription:
    """Vincula subscription a processo e processa bills pendentes."""
    vs = db.get(VindiSubscription, vindi_subscription_id)
    vs.processo_id = processo_id

    vc = vs.vindi_customer
    if vc and vc.cliente_id:
        for bill in vs.bills:
            if bill.financeiro_id:
                continue
            auto_criar_financeiro(db, bill, vc, vs)

    db.commit()
    return vs
