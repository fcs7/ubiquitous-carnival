import os
from pathlib import Path

from fastapi import APIRouter, Depends
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import AgenteConfig

router = APIRouter(prefix="/api", tags=["status"])


def _checar_banco(db: Session) -> dict:
    """Testa conectividade com o banco executando SELECT 1."""
    try:
        db.execute(text("SELECT 1"))
        return {"nome": "PostgreSQL", "status": "ok", "detalhes": None}
    except Exception as e:
        return {"nome": "PostgreSQL", "status": "erro", "detalhes": str(e)}


def _checar_api_key(nome: str, chave: str) -> dict:
    """Verifica se a API key esta configurada (nao vazia)."""
    if chave and chave.strip():
        return {"nome": nome, "status": "ok", "detalhes": None}
    return {"nome": nome, "status": "erro", "detalhes": "API key nao configurada"}


def _checar_google_drive() -> dict:
    """Verifica se o arquivo de credenciais do Google Drive existe."""
    caminho = settings.google_credentials_path
    if caminho and Path(caminho).exists():
        return {"nome": "Google Drive", "status": "ok", "detalhes": None}
    if not caminho:
        return {"nome": "Google Drive", "status": "erro", "detalhes": "Caminho de credenciais nao configurado"}
    return {"nome": "Google Drive", "status": "erro", "detalhes": "Arquivo de credenciais nao encontrado"}


def _checar_vindi() -> dict:
    """Verifica se a API key do Vindi esta configurada."""
    if settings.vindi_api_key and settings.vindi_api_key.strip():
        return {"nome": "Vindi", "status": "ok", "detalhes": None}
    return {"nome": "Vindi", "status": "erro", "detalhes": "API key nao configurada"}


def _resumo_agentes(db: Session) -> dict:
    """Conta agentes totais e ativos."""
    from app.services.ferramentas import FERRAMENTAS_DISPONIVEIS

    total = db.query(AgenteConfig).count()
    ativos = db.query(AgenteConfig).filter(AgenteConfig.ativo == True).count()
    ferramentas = len(FERRAMENTAS_DISPONIVEIS)

    return {
        "total": total,
        "ativos": ativos,
        "ferramentas_disponiveis": ferramentas,
    }


@router.get("/status")
def status_sistema(db: Session = Depends(get_db)):
    servicos = [
        _checar_banco(db),
        _checar_api_key("Anthropic API", settings.anthropic_api_key),
        _checar_api_key("OpenAI API", settings.openai_api_key),
        _checar_google_drive(),
        _checar_vindi(),
    ]

    agentes = _resumo_agentes(db)

    # Agentes como servico adicional
    if agentes["ativos"] > 0:
        servicos.append({"nome": "Agentes IA", "status": "ok", "detalhes": f"{agentes['ativos']} ativo(s)"})
    else:
        servicos.append({"nome": "Agentes IA", "status": "erro", "detalhes": "Nenhum agente ativo"})

    # Status geral: ok se todos ok, degradado se parcial, erro se todos falharam
    falhas = sum(1 for s in servicos if s["status"] != "ok")
    if falhas == 0:
        status_geral = "ok"
    elif falhas == len(servicos):
        status_geral = "erro"
    else:
        status_geral = "degradado"

    return {
        "status": status_geral,
        "servicos": servicos,
        "agentes": agentes,
    }
