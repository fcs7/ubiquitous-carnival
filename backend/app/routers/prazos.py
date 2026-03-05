from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Prazo
from app.schemas import PrazoOut

router = APIRouter(prefix="/prazos", tags=["prazos"])


@router.get("/", response_model=list[PrazoOut])
def listar_prazos(status: str = "pendente", db: Session = Depends(get_db)):
    return (
        db.query(Prazo)
        .filter(Prazo.status == status)
        .order_by(Prazo.data_limite)
        .all()
    )


@router.patch("/{prazo_id}/concluir", response_model=PrazoOut)
def concluir_prazo(prazo_id: int, db: Session = Depends(get_db)):
    prazo = db.get(Prazo, prazo_id)
    if not prazo:
        raise HTTPException(status_code=404, detail="Prazo nao encontrado")
    prazo.status = "concluido"
    db.commit()
    db.refresh(prazo)
    return prazo
