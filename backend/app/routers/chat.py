from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from fastapi.responses import StreamingResponse

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
        agente_id=payload.agente_id,
    )
    db.add(conversa)
    db.commit()
    db.refresh(conversa)
    return conversa


@router.get("/", response_model=list[ConversaOut])
def listar_conversas(usuario_id: int | None = None, db: Session = Depends(get_db)):
    q = db.query(Conversa).filter(Conversa.titulo != "__assistente__")
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
    conversa = db.query(Conversa).filter(Conversa.id == conversa_id).first()
    if not conversa:
        raise HTTPException(status_code=404, detail="Conversa nao encontrada")

    try:
        if conversa.agente_id:
            from app.services.agente_chat import chat_com_agente
            resultado = chat_com_agente(
                db=db,
                conversa_id=conversa_id,
                mensagem_usuario=payload.mensagem,
            )
        else:
            resultado = claude_chat(
                db=db,
                conversa_id=conversa_id,
                mensagem_usuario=payload.mensagem,
                modelo=payload.modelo,
            )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return resultado


@router.post("/{conversa_id}/mensagens/stream")
def stream_mensagem(
    conversa_id: int,
    payload: MensagemCreate,
    db: Session = Depends(get_db),
):
    conversa = db.query(Conversa).filter(Conversa.id == conversa_id).first()
    if not conversa:
        raise HTTPException(status_code=404, detail="Conversa nao encontrada")

    if not conversa.agente_id:
        raise HTTPException(status_code=400, detail="Streaming so disponivel para conversas com agente")

    from app.services.agente_chat import chat_com_agente_stream
    return StreamingResponse(
        chat_com_agente_stream(db, conversa_id, payload.mensagem),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


@router.delete("/{conversa_id}", status_code=204)
def deletar_conversa(conversa_id: int, db: Session = Depends(get_db)):
    conversa = db.query(Conversa).filter(Conversa.id == conversa_id).first()
    if not conversa:
        raise HTTPException(status_code=404, detail="Conversa nao encontrada")
    db.delete(conversa)
    db.commit()
