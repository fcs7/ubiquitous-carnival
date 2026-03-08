import redis
import httpx
from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.worker import celery_app

router = APIRouter(prefix="/api", tags=["status"])


def _verificar_postgres(db: Session) -> dict:
    """Verifica conexao com PostgreSQL executando SELECT 1."""
    try:
        db.execute(text("SELECT 1"))
        return {"nome": "PostgreSQL", "status": "ok", "detalhes": None}
    except Exception as e:
        return {"nome": "PostgreSQL", "status": "erro", "detalhes": str(e)}


def _verificar_redis() -> dict:
    """Verifica conexao com Redis via ping."""
    try:
        r = redis.Redis.from_url(settings.redis_url, socket_timeout=2)
        r.ping()
        return {"nome": "Redis", "status": "ok", "detalhes": None}
    except Exception as e:
        return {"nome": "Redis", "status": "erro", "detalhes": str(e)}


def _verificar_celery() -> dict:
    """Verifica se ha workers Celery ativos via inspect ping."""
    try:
        resultado = celery_app.control.inspect(timeout=2).ping()
        if resultado:
            return {"nome": "Celery Worker", "status": "ok", "detalhes": None}
        return {
            "nome": "Celery Worker",
            "status": "erro",
            "detalhes": "Nenhum worker ativo",
        }
    except Exception as e:
        return {"nome": "Celery Worker", "status": "erro", "detalhes": str(e)}


def _verificar_evolution() -> dict:
    """Verifica se a Evolution API esta respondendo."""
    try:
        resp = httpx.get(
            f"{settings.evolution_api_url}/",
            timeout=3,
        )
        if resp.is_success:
            return {"nome": "Evolution API", "status": "ok", "detalhes": None}
        return {
            "nome": "Evolution API",
            "status": "erro",
            "detalhes": f"HTTP {resp.status_code}",
        }
    except Exception as e:
        return {"nome": "Evolution API", "status": "erro", "detalhes": str(e)}


@router.get("/status")
def status_servicos(db: Session = Depends(get_db)):
    """Health check de todos os servicos do Muglia."""
    servicos = [
        _verificar_postgres(db),
        _verificar_redis(),
        _verificar_celery(),
        _verificar_evolution(),
    ]
    return {"servicos": servicos, "grafana_url": settings.grafana_url}
