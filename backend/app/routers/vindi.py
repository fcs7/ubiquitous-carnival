from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Cliente, Processo, VindiBill, VindiCustomer, VindiSubscription
from app.schemas import (
    VindiBillOut, VindiCustomerDetailOut, VindiCustomerOut,
    VindiSubscriptionOut, VindiVincularCustomerRequest,
    VindiVincularSubscriptionRequest,
)
from app.services.vindi import vincular_customer, vincular_subscription

router = APIRouter(prefix="/vindi", tags=["vindi"])


@router.get("/customers", response_model=list[VindiCustomerOut])
def listar_customers(status_sync: str | None = None, db: Session = Depends(get_db)):
    q = db.query(VindiCustomer)
    if status_sync:
        q = q.filter(VindiCustomer.status_sync == status_sync)
    return q.order_by(VindiCustomer.created_at.desc()).all()


@router.get("/customers/{customer_id}", response_model=VindiCustomerDetailOut)
def detalhe_customer(customer_id: int, db: Session = Depends(get_db)):
    vc = db.get(VindiCustomer, customer_id)
    if not vc:
        raise HTTPException(status_code=404, detail="VindiCustomer nao encontrado")
    return vc


@router.post("/customers/{customer_id}/vincular", response_model=VindiCustomerOut)
def vincular_customer_endpoint(customer_id: int, body: VindiVincularCustomerRequest, db: Session = Depends(get_db)):
    vc = db.get(VindiCustomer, customer_id)
    if not vc:
        raise HTTPException(status_code=404, detail="VindiCustomer nao encontrado")

    if body.cliente_id is None:
        cliente = Cliente(
            nome=vc.nome,
            cpf_cnpj=vc.cpf_cnpj or f"vindi-{vc.vindi_id}",
            telefone=vc.telefone or "",
            email=vc.email,
        )
        db.add(cliente)
        db.flush()
        cliente_id = cliente.id
    else:
        cliente = db.get(Cliente, body.cliente_id)
        if not cliente:
            raise HTTPException(status_code=404, detail="Cliente nao encontrado")
        cliente_id = body.cliente_id

    return vincular_customer(db, customer_id, cliente_id)


@router.post("/customers/{customer_id}/ignorar", response_model=VindiCustomerOut)
def ignorar_customer(customer_id: int, db: Session = Depends(get_db)):
    vc = db.get(VindiCustomer, customer_id)
    if not vc:
        raise HTTPException(status_code=404, detail="VindiCustomer nao encontrado")
    vc.status_sync = "ignorado"
    db.commit()
    db.refresh(vc)
    return vc


@router.get("/subscriptions", response_model=list[VindiSubscriptionOut])
def listar_subscriptions(sem_processo: bool = False, db: Session = Depends(get_db)):
    q = db.query(VindiSubscription)
    if sem_processo:
        q = q.filter(VindiSubscription.processo_id.is_(None))
    return q.order_by(VindiSubscription.created_at.desc()).all()


@router.post("/subscriptions/{subscription_id}/vincular", response_model=VindiSubscriptionOut)
def vincular_subscription_endpoint(subscription_id: int, body: VindiVincularSubscriptionRequest, db: Session = Depends(get_db)):
    vs = db.get(VindiSubscription, subscription_id)
    if not vs:
        raise HTTPException(status_code=404, detail="VindiSubscription nao encontrada")
    processo = db.get(Processo, body.processo_id)
    if not processo:
        raise HTTPException(status_code=404, detail="Processo nao encontrado")
    return vincular_subscription(db, subscription_id, body.processo_id)


@router.get("/bills", response_model=list[VindiBillOut])
def listar_bills(status: str | None = None, db: Session = Depends(get_db)):
    q = db.query(VindiBill)
    if status:
        q = q.filter(VindiBill.status == status)
    return q.order_by(VindiBill.created_at.desc()).all()
