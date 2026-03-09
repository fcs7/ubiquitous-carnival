from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Documento, Processo, ProcessoParte
from app.schemas import (
    DocumentoOut, DriveItemOut, DriveOrganizarOut,
    DriveVincularRequest,
)
from app.services import google_drive
from app.services.google_drive import DriveServiceError

router = APIRouter(prefix="/documentos", tags=["documentos"])


def _handle_drive_error(e: DriveServiceError):
    msg = str(e)
    if "SEGURANCA" in msg:
        raise HTTPException(status_code=403, detail=msg)
    raise HTTPException(status_code=502, detail="Erro no Google Drive")


# ──────────────────────────────────────────────
# Leitura — Drive
# ──────────────────────────────────────────────
@router.get("/drive/pasta/{pasta_id}", response_model=list[DriveItemOut])
def listar_pasta_drive(pasta_id: str, apenas_pastas: bool = False):
    """Lista conteudo de uma pasta do Google Drive."""
    try:
        arquivos = google_drive.listar_pasta(pasta_id, apenas_pastas)
    except DriveServiceError as e:
        _handle_drive_error(e)
    return arquivos


@router.get("/drive/buscar", response_model=list[DriveItemOut])
def buscar_drive(q: str = Query(..., min_length=2), pasta_id: str | None = Query(None)):
    """Busca arquivos no Google Drive por nome."""
    try:
        arquivos = google_drive.buscar_arquivo(q, pasta_id)
    except DriveServiceError as e:
        _handle_drive_error(e)
    return arquivos


@router.get("/drive/metadados/{file_id}", response_model=DriveItemOut)
def metadados_drive(file_id: str):
    """Obtem metadados de um arquivo do Drive."""
    try:
        return google_drive.obter_metadados(file_id)
    except DriveServiceError as e:
        _handle_drive_error(e)


# ──────────────────────────────────────────────
# Vinculacao — banco local
# ──────────────────────────────────────────────
@router.post("/drive/vincular", response_model=DocumentoOut, status_code=201)
def vincular_arquivo_drive(payload: DriveVincularRequest, db: Session = Depends(get_db)):
    """Vincula um arquivo do Google Drive a um processo/cliente no banco."""
    if payload.processo_id:
        proc = db.query(Processo).filter(Processo.id == payload.processo_id).first()
        if not proc:
            raise HTTPException(404, f"Processo {payload.processo_id} nao encontrado")
    doc = Documento(
        nome=payload.nome,
        tipo="drive",
        categoria=payload.categoria,
        mime_type=payload.mime_type,
        tamanho_bytes=payload.tamanho_bytes,
        drive_file_id=payload.drive_file_id,
        drive_url=payload.drive_url,
        origem="drive",
        processo_id=payload.processo_id,
        cliente_id=payload.cliente_id,
    )
    db.add(doc)
    db.commit()
    db.refresh(doc)
    return doc


@router.get("/processo/{processo_id}", response_model=list[DocumentoOut])
def listar_documentos_processo(processo_id: int, db: Session = Depends(get_db)):
    """Lista documentos vinculados a um processo."""
    return (
        db.query(Documento)
        .filter(Documento.processo_id == processo_id)
        .order_by(Documento.created_at.desc())
        .all()
    )


@router.delete("/{documento_id}", status_code=204)
def desvincular_documento(documento_id: int, db: Session = Depends(get_db)):
    """Remove vinculo do banco. NAO apaga nada do Google Drive."""
    doc = db.query(Documento).filter(Documento.id == documento_id).first()
    if not doc:
        raise HTTPException(404, "Documento nao encontrado")
    db.delete(doc)
    db.commit()


# ──────────────────────────────────────────────
# Organizacao de pastas
# ──────────────────────────────────────────────
@router.post("/drive/organizar/{processo_id}", response_model=DriveOrganizarOut)
def organizar_pasta_processo(
    processo_id: int,
    simular: bool = Query(False, description="Modo dry-run: mostra o que seria feito sem modificar o Drive"),
    db: Session = Depends(get_db),
):
    """Cria estrutura de pastas no Drive para um processo (Processos/{cnj}/)."""
    proc = db.query(Processo).filter(Processo.id == processo_id).first()
    if not proc:
        raise HTTPException(404, f"Processo {processo_id} nao encontrado")

    # Buscar nome do primeiro cliente (autor) para nomear a pasta
    parte = (
        db.query(ProcessoParte)
        .filter(ProcessoParte.processo_id == processo_id)
        .first()
    )
    cliente_nome = None
    if parte and parte.cliente:
        cliente_nome = parte.cliente.nome

    if simular:
        resultado = google_drive.simular_organizacao(proc.cnj, cliente_nome)
        return DriveOrganizarOut(
            pasta_id="simulacao",
            pasta_nome=resultado["estrutura"],
            pasta_url=resultado["mensagem"],
        )

    try:
        pasta = google_drive.montar_pasta_processo(proc.cnj, cliente_nome)
    except DriveServiceError as e:
        _handle_drive_error(e)
    return DriveOrganizarOut(
        pasta_id=pasta["id"],
        pasta_nome=pasta.get("name", ""),
        pasta_url=pasta.get("webViewLink", ""),
    )


@router.post("/drive/mover", response_model=DriveItemOut)
def mover_arquivo_drive(file_id: str = Query(...), nova_pasta_id: str = Query(...)):
    """Move um arquivo para outra pasta no Drive. Valida escopo de seguranca."""
    try:
        return google_drive.mover_arquivo(file_id, nova_pasta_id)
    except DriveServiceError as e:
        _handle_drive_error(e)
