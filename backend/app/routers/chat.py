from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Conversa, Usuario
from app.schemas import (
    ConversaCreate,
    ConversaOut,
    ConversaDetailOut,
    MensagemCreate,
    ChatResponse,
)
from app.services.claude_chat import chat as claude_chat

router = APIRouter(prefix="/conversas", tags=["chat"])


@router.post("/", response_model=ConversaOut, status_code=201)
def criar_conversa(payload: ConversaCreate, db: Session = Depends(get_db)):
    usuario = db.query(Usuario).filter(Usuario.id == payload.usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario nao encontrado")

    conversa = Conversa(
        titulo=payload.titulo,
        usuario_id=payload.usuario_id,
        processo_id=payload.processo_id,
        modelo_claude=payload.modelo_claude,
    )
    db.add(conversa)
    db.commit()
    db.refresh(conversa)
    return conversa


@router.get("/", response_model=list[ConversaOut])
def listar_conversas(usuario_id: int | None = None, db: Session = Depends(get_db)):
    q = db.query(Conversa)
    if usuario_id is not None:
        q = q.filter(Conversa.usuario_id == usuario_id)
    return q.order_by(Conversa.updated_at.desc()).all()


@router.get("/{conversa_id}", response_model=ConversaDetailOut)
def detalhe_conversa(conversa_id: int, db: Session = Depends(get_db)):
    conversa = db.query(Conversa).filter(Conversa.id == conversa_id).first()
    if not conversa:
        raise HTTPException(status_code=404, detail="Conversa nao encontrada")
    return conversa


@router.post("/{conversa_id}/mensagens", response_model=ChatResponse)
def enviar_mensagem(
    conversa_id: int,
    payload: MensagemCreate,
    db: Session = Depends(get_db),
):
    try:
        resultado = claude_chat(
            db=db,
            conversa_id=conversa_id,
            mensagem_usuario=payload.mensagem,
            modelo=payload.modelo,
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return resultado


@router.delete("/{conversa_id}", status_code=204)
def deletar_conversa(conversa_id: int, db: Session = Depends(get_db)):
    conversa = db.query(Conversa).filter(Conversa.id == conversa_id).first()
    if not conversa:
        raise HTTPException(status_code=404, detail="Conversa nao encontrada")
    db.delete(conversa)
    db.commit()
