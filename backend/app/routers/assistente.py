from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.schemas import (
    AssistenteHistoricoOut,
    AssistenteMensagemCreate,
    AssistenteResponse,
    MensagemOut,
)
from app.services.assistente import (
    assistente_chat,
    carregar_historico_limitado,
    get_or_create_conversa_assistente,
)

router = APIRouter(prefix="/assistente", tags=["assistente"])


@router.post("/mensagens", response_model=AssistenteResponse)
def enviar_mensagem_assistente(
    payload: AssistenteMensagemCreate,
    usuario_id: int = 1,
    db: Session = Depends(get_db),
):
    try:
        resultado = assistente_chat(db, usuario_id, payload.mensagem)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return resultado


@router.get("/historico", response_model=AssistenteHistoricoOut)
def historico_assistente(
    usuario_id: int = 1,
    db: Session = Depends(get_db),
):
    conversa = get_or_create_conversa_assistente(db, usuario_id)
    db.commit()
    mensagens = (
        conversa.mensagens
    )
    return AssistenteHistoricoOut(
        conversa_id=conversa.id,
        mensagens=[MensagemOut.model_validate(m) for m in mensagens],
    )
