import json
import logging

from fastapi import APIRouter, Depends, Request, HTTPException
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.services.vindi import (
    handle_bill_canceled, handle_bill_created, handle_bill_paid,
    handle_charge_rejected, handle_customer_created, handle_customer_updated,
    handle_subscription_canceled, handle_subscription_created,
    validar_signature,
)

logger = logging.getLogger(__name__)

router = APIRouter(tags=["vindi-webhook"])

HANDLERS = {
    "customer_created": handle_customer_created,
    "customer_updated": handle_customer_updated,
    "bill_created": handle_bill_created,
    "bill_paid": handle_bill_paid,
    "bill_canceled": handle_bill_canceled,
    "subscription_created": handle_subscription_created,
    "subscription_canceled": handle_subscription_canceled,
    "charge_rejected": handle_charge_rejected,
}


@router.post("/webhooks/vindi")
async def receber_webhook_vindi(request: Request, db: Session = Depends(get_db)):
    body = await request.body()

    if not settings.vindi_webhook_secret:
        logger.warning("vindi_webhook_secret nao configurado — webhook rejeitado")
        raise HTTPException(status_code=503, detail="Webhook nao configurado")

    signature = request.headers.get("X-Vindi-Signature", "")
    if not validar_signature(body, signature, settings.vindi_webhook_secret):
        raise HTTPException(status_code=401, detail="Signature invalida")

    payload = json.loads(body)
    event_type = payload.get("event", {}).get("type", "")
    data = payload.get("event", {}).get("data", {})

    handler = HANDLERS.get(event_type)
    if handler:
        handler(db, data)

    return {"status": "ok"}
