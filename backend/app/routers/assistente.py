from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas import (
    AssistenteConversaCreate,
    AssistenteHistoricoOut,
    AssistenteMensagemCreate,
    AssistenteResponse,
    ConversaDetailOut,
    ConversaOut,
    MensagemOut,
)
from app.services.assistente import (
    assistente_chat,
    carregar_historico_limitado,
    criar_conversa_assistente,
    deletar_conversa_assistente,
    get_or_create_conversa_assistente,
    listar_conversas_assistente,
)

router = APIRouter(prefix="/assistente", tags=["assistente"])


# ── Conversas CRUD ─────────────────────────────

@router.get("/conversas", response_model=list[ConversaOut])
def listar_conversas(
    usuario_id: int = 1,
    db: Session = Depends(get_db),
):
    return listar_conversas_assistente(db, usuario_id)


@router.post("/conversas", response_model=ConversaOut, status_code=201)
def criar_conversa(
    payload: AssistenteConversaCreate,
    usuario_id: int = 1,
    db: Session = Depends(get_db),
):
    try:
        conversa = criar_conversa_assistente(
            db, usuario_id, payload.agente_id, payload.titulo
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return conversa


@router.get("/conversas/{conversa_id}", response_model=ConversaDetailOut)
def detalhe_conversa(
    conversa_id: int,
    usuario_id: int = 1,
    db: Session = Depends(get_db),
):
    from app.models import Conversa

    conversa = (
        db.query(Conversa)
        .filter(Conversa.id == conversa_id, Conversa.usuario_id == usuario_id)
        .first()
    )
    if not conversa:
        raise HTTPException(status_code=404, detail="Conversa nao encontrada")
    return conversa


@router.delete("/conversas/{conversa_id}", status_code=204)
def deletar_conversa(
    conversa_id: int,
    usuario_id: int = 1,
    db: Session = Depends(get_db),
):
    try:
        deletar_conversa_assistente(db, usuario_id, conversa_id)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


# ── Mensagens ──────────────────────────────────

@router.post("/mensagens", response_model=AssistenteResponse)
def enviar_mensagem_assistente(
    payload: AssistenteMensagemCreate,
    usuario_id: int = 1,
    db: Session = Depends(get_db),
):
    try:
        resultado = assistente_chat(
            db,
            usuario_id,
            payload.mensagem,
            conversa_id=payload.conversa_id,
            agente_id=payload.agente_id,
        )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return resultado


# ── Historico legado (backward compat) ─────────

@router.get("/historico", response_model=AssistenteHistoricoOut)
def historico_assistente(
    usuario_id: int = 1,
    db: Session = Depends(get_db),
):
    conversa = get_or_create_conversa_assistente(db, usuario_id)
    db.commit()
    mensagens = conversa.mensagens
    return AssistenteHistoricoOut(
        conversa_id=conversa.id,
        mensagens=[MensagemOut.model_validate(m) for m in mensagens],
    )
