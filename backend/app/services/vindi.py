import hashlib
import hmac
import json
from datetime import date

from sqlalchemy.orm import Session

from app.models import VindiBill, VindiCustomer, VindiProduct, VindiSubscription


def validar_signature(payload_bytes: bytes, signature: str, secret: str) -> bool:
    expected = hmac.new(secret.encode(), payload_bytes, hashlib.sha256).hexdigest()
    return hmac.compare_digest(expected, signature)


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
    db.commit()


def handle_bill_canceled(db: Session, data: dict) -> None:
    bill_data = data.get("bill", data)
    vindi_id = bill_data["id"]
    vb = db.query(VindiBill).filter(VindiBill.vindi_id == vindi_id).first()
    if not vb:
        return

    vb.status = "canceled"
    vb.dados_json = json.dumps(bill_data)
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
    """Vincula vindi_customer a cliente."""
    vc = db.get(VindiCustomer, vindi_customer_id)
    vc.cliente_id = cliente_id
    vc.status_sync = "vinculado"
    db.commit()
    return vc


def vincular_subscription(db: Session, vindi_subscription_id: int, processo_id: int) -> VindiSubscription:
    """Vincula subscription a processo."""
    vs = db.get(VindiSubscription, vindi_subscription_id)
    vs.processo_id = processo_id
    db.commit()
    return vs
