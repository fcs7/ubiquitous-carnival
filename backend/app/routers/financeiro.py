from datetime import date

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Financeiro
from app.schemas import FinanceiroCreate, FinanceiroOut, FinanceiroResumo

router = APIRouter(prefix="/financeiro", tags=["financeiro"])


@router.post("/", response_model=FinanceiroOut, status_code=201)
def criar_lancamento(payload: FinanceiroCreate, db: Session = Depends(get_db)):
    lancamento = Financeiro(**payload.model_dump())
    db.add(lancamento)
    db.commit()
    db.refresh(lancamento)
    return lancamento


@router.get("/", response_model=list[FinanceiroOut])
def listar_financeiro(status: str | None = None, db: Session = Depends(get_db)):
    q = db.query(Financeiro)
    if status:
        q = q.filter(Financeiro.status == status)
    return q.all()


@router.get("/resumo", response_model=FinanceiroResumo)
def resumo_financeiro(db: Session = Depends(get_db)):
    rows = (
        db.query(Financeiro.status, func.coalesce(func.sum(Financeiro.valor), 0))
        .group_by(Financeiro.status)
        .all()
    )
    totais = {r[0]: float(r[1]) for r in rows}
    pendente = totais.get("pendente", 0.0)
    pago = totais.get("pago", 0.0)
    return FinanceiroResumo(pendente=pendente, pago=pago, total=pendente + pago)


@router.patch("/{lancamento_id}/pagar", response_model=FinanceiroOut)
def marcar_pago(lancamento_id: int, db: Session = Depends(get_db)):
    lancamento = db.get(Financeiro, lancamento_id)
    if not lancamento:
        raise HTTPException(status_code=404, detail="Lancamento nao encontrado")
    lancamento.status = "pago"
    lancamento.data_pagamento = date.today()
    db.commit()
    db.refresh(lancamento)
    return lancamento
