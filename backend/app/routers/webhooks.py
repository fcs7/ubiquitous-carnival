import logging
from datetime import datetime

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from app.config import settings
from app.services.whatsapp import enviar_mensagem

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/webhooks", tags=["webhooks"])


# --- Schemas do Alertmanager ---


class AlertLabel(BaseModel):
    alertname: str = ""
    severity: str = ""
    instance: str = ""


class AlertAnnotation(BaseModel):
    summary: str = ""
    description: str = ""


class Alert(BaseModel):
    status: str
    labels: AlertLabel = AlertLabel()
    annotations: AlertAnnotation = AlertAnnotation()
    startsAt: str = ""
    endsAt: str = ""


class AlertmanagerPayload(BaseModel):
    status: str
    alerts: list[Alert] = []


# --- Helpers ---


def _formatar_horario(iso_str: str) -> str:
    """Converte ISO 8601 para formato legivel (dd/mm/aaaa HH:MM)."""
    if not iso_str or iso_str.startswith("0001"):
        return "N/A"
    try:
        dt = datetime.fromisoformat(iso_str.replace("Z", "+00:00"))
        return dt.strftime("%d/%m/%Y %H:%M")
    except (ValueError, TypeError):
        return iso_str


def _formatar_severidade(severity: str) -> str:
    """Traduz severidade para portugues."""
    mapa = {
        "critical": "critico",
        "critico": "critico",
        "warning": "aviso",
        "aviso": "aviso",
        "info": "informativo",
        "informativo": "informativo",
    }
    return mapa.get(severity.lower(), severity)


def formatar_alertas(payload: AlertmanagerPayload) -> str:
    """Formata payload do Alertmanager em mensagem legivel para WhatsApp."""
    disparando = payload.status == "firing"
    icone = "\U0001f6a8" if disparando else "\u2705"
    status_texto = "DISPARANDO" if disparando else "RESOLVIDO"

    linhas = [f"{icone} ALERTA MUGLIA - {status_texto}", ""]

    for alerta in payload.alerts:
        icone_alerta = "\u26a0\ufe0f" if alerta.status == "firing" else "\u2705"
        nome = alerta.labels.alertname or "Alerta desconhecido"
        severidade = _formatar_severidade(alerta.labels.severity) if alerta.labels.severity else "N/A"
        servico = alerta.labels.instance or "N/A"
        descricao = alerta.annotations.summary or alerta.annotations.description or "Sem descricao"
        inicio = _formatar_horario(alerta.startsAt)

        linhas.append(f"{icone_alerta} {nome}")
        linhas.append(f"Severidade: {severidade}")
        linhas.append(f"Servico: {servico}")
        linhas.append(f"Descricao: {descricao}")
        linhas.append(f"Inicio: {inicio}")
        linhas.append("")
        linhas.append("---")
        linhas.append("")

    # Remover ultimo separador vazio
    while linhas and linhas[-1] in ("", "---"):
        linhas.pop()

    return "\n".join(linhas)


# --- Endpoint ---


@router.post("/alertmanager", status_code=200)
def receber_alerta_alertmanager(payload: AlertmanagerPayload):
    """Recebe alertas do Alertmanager e envia via WhatsApp."""
    numero = settings.alert_whatsapp_number
    if not numero:
        logger.warning("ALERT_WHATSAPP_NUMBER nao configurado, alerta ignorado")
        raise HTTPException(
            status_code=422,
            detail="Numero de WhatsApp para alertas nao configurado (ALERT_WHATSAPP_NUMBER)",
        )

    if not payload.alerts:
        return {"status": "ignorado", "motivo": "nenhum alerta no payload"}

    mensagem = formatar_alertas(payload)
    logger.info("Enviando alerta para %s: %d alerta(s)", numero, len(payload.alerts))

    sucesso = enviar_mensagem(numero, mensagem)
    if not sucesso:
        logger.error("Falha ao enviar alerta via WhatsApp para %s", numero)
        raise HTTPException(
            status_code=502,
            detail="Falha ao enviar mensagem via WhatsApp (Evolution API)",
        )

    return {
        "status": "enviado",
        "alertas": len(payload.alerts),
        "destino": numero,
    }
