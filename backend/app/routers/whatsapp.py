from functools import wraps

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.services.whatsapp import (
    criar_instancia,
    enviar_mensagem,
    listar_instancias,
    obter_qrcode,
    obter_status,
)

router = APIRouter(prefix="/whatsapp", tags=["whatsapp"])


class MensagemTeste(BaseModel):
    telefone: str
    mensagem: str


def _evolution_call(func):
    """Converte falhas de conexao com Evolution API em HTTP 503."""
    @wraps(func)
    def wrapper(*args, **kwargs):
        try:
            return func(*args, **kwargs)
        except HTTPException:
            raise
        except Exception:
            raise HTTPException(503, "Evolution API indisponivel")
    return wrapper


@router.get("/status")
@_evolution_call
def status_whatsapp():
    return obter_status()


@router.get("/qrcode")
@_evolution_call
def qrcode_whatsapp():
    return obter_qrcode()


@router.post("/instancia", status_code=201)
@_evolution_call
def criar_instancia_whatsapp():
    return criar_instancia()


@router.get("/instancias")
@_evolution_call
def listar_instancias_whatsapp():
    return listar_instancias()


@router.post("/enviar-teste")
@_evolution_call
def enviar_teste(body: MensagemTeste):
    ok = enviar_mensagem(body.telefone, body.mensagem)
    if not ok:
        raise HTTPException(502, "Falha ao enviar mensagem")
    return {"status": "enviado"}
