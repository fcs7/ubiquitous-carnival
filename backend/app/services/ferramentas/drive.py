import logging
import re

from sqlalchemy.orm import Session
from app.models import Documento
from app.services.pdf_extractor import obter_texto_pdf, PdfExtractionError
from app.services.google_drive import obter_metadados, DriveServiceError

logger = logging.getLogger(__name__)


SCHEMA_LISTAR_DOCUMENTOS_PROCESSO = {
    "name": "listar_documentos_processo",
    "description": "Lista documentos e arquivos vinculados a um processo, incluindo links do Google Drive.",
    "input_schema": {
        "type": "object",
        "properties": {
            "processo_id": {
                "type": "integer",
                "description": "ID do processo no sistema",
            },
        },
        "required": ["processo_id"],
    },
}


def executar_listar_documentos_processo(input_data: dict, db: Session) -> str:
    processo_id = input_data.get("processo_id")
    if processo_id is None:
        return "Campo obrigatorio 'processo_id' nao informado."
    try:
        processo_id = int(processo_id)
    except (TypeError, ValueError):
        return "Campo 'processo_id' deve ser um numero inteiro."

    docs = (
        db.query(Documento)
        .filter(Documento.processo_id == processo_id)
        .order_by(Documento.created_at.desc())
        .all()
    )

    if not docs:
        return f"Nenhum documento vinculado ao processo ID {processo_id}."

    linhas = [f"DOCUMENTOS DO PROCESSO #{processo_id} ({len(docs)} encontrados):"]
    for doc in docs:
        origem = "Google Drive" if doc.origem == "drive" else "Local"
        link = doc.drive_url or doc.arquivo_path or "sem link"
        linhas.append(f"  [{origem}] {doc.nome} ({doc.mime_type}) — {doc.categoria or 'sem categoria'} — {link}")

    return "\n".join(linhas)


# ──────────────────────────────────────────────
# Ferramenta: ler_documento
# ──────────────────────────────────────────────
SCHEMA_LER_DOCUMENTO = {
    "name": "ler_documento",
    "description": (
        "Le o conteudo textual de um documento PDF armazenado no Google Drive. "
        "Use apos listar_documentos_processo para ler um documento especifico. "
        "Para documentos longos, use o parametro 'paginas' (ex: '1-5') para ler trechos."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "documento_id": {
                "type": "integer",
                "description": "ID do documento no sistema (obtido via listar_documentos_processo)",
            },
            "paginas": {
                "type": "string",
                "description": "Intervalo de paginas para ler (ex: '1-5', '10-20'). Opcional — sem informar, retorna as primeiras paginas.",
            },
        },
        "required": ["documento_id"],
    },
}


def _parse_paginas(paginas_str: str) -> tuple[int, int]:
    """Converte '3-5' em (3, 5). Retorna (inicio, fim)."""
    partes = paginas_str.strip().split("-")
    if len(partes) == 1:
        p = int(partes[0])
        return p, p
    return int(partes[0]), int(partes[1])


def executar_ler_documento(input_data: dict, db: Session) -> str:
    documento_id = input_data.get("documento_id")
    if documento_id is None:
        return "Campo obrigatorio 'documento_id' nao informado."
    try:
        documento_id = int(documento_id)
    except (TypeError, ValueError):
        return "Campo 'documento_id' deve ser um numero inteiro."

    doc = db.query(Documento).filter(Documento.id == documento_id).first()
    if not doc:
        return f"Documento ID {documento_id} nao encontrado."

    if not doc.drive_file_id:
        return f"Documento '{doc.nome}' nao esta no Google Drive (origem: {doc.origem})."

    # Parse paginas
    pagina_inicio = None
    pagina_fim = None
    paginas_str = input_data.get("paginas")
    if paginas_str:
        try:
            pagina_inicio, pagina_fim = _parse_paginas(paginas_str)
        except (ValueError, IndexError):
            return f"Formato de paginas invalido: '{paginas_str}'. Use formato '1-5' ou '3'."

    # Obter modifiedTime para cache
    try:
        meta = obter_metadados(doc.drive_file_id)
        modified_time = meta.get("modifiedTime", "")
    except DriveServiceError:
        modified_time = None

    # Extrair texto
    try:
        texto = obter_texto_pdf(
            doc.drive_file_id,
            modified_time=modified_time,
            pagina_inicio=pagina_inicio,
            pagina_fim=pagina_fim,
        )
    except (PdfExtractionError, DriveServiceError) as e:
        return f"Erro ao ler documento '{doc.nome}': {e}"

    if not texto.strip():
        return f"Documento '{doc.nome}' nao contem texto extraivel (pode ser escaneado/imagem)."

    header = f"DOCUMENTO: {doc.nome}"
    if paginas_str:
        header += f" (paginas {paginas_str})"
    header += f"\nCategoria: {doc.categoria or 'sem categoria'}"

    return f"{header}\n\n{texto}"


# ──────────────────────────────────────────────
# Ferramenta: buscar_em_documentos
# ──────────────────────────────────────────────
SCHEMA_BUSCAR_EM_DOCUMENTOS = {
    "name": "buscar_em_documentos",
    "description": (
        "Busca um termo dentro do conteudo de documentos PDF. "
        "Retorna trechos dos documentos que contem o termo buscado. "
        "Pode buscar em um processo especifico ou em todos os documentos."
    ),
    "input_schema": {
        "type": "object",
        "properties": {
            "termo": {
                "type": "string",
                "description": "Termo ou frase para buscar dentro dos documentos",
            },
            "processo_id": {
                "type": "integer",
                "description": "ID do processo para restringir a busca. Opcional — sem informar, busca em todos.",
            },
        },
        "required": ["termo"],
    },
}


def executar_buscar_em_documentos(input_data: dict, db: Session) -> str:
    from app.config import settings as _settings

    termo = input_data.get("termo", "").strip()
    if not termo:
        return "Campo obrigatorio 'termo' nao informado."

    processo_id = input_data.get("processo_id")

    query = db.query(Documento).filter(
        Documento.drive_file_id.isnot(None),
        Documento.mime_type == "application/pdf",
    )
    if processo_id:
        query = query.filter(Documento.processo_id == int(processo_id))

    docs = query.order_by(Documento.created_at.desc()).limit(_settings.pdf_busca_max_docs).all()

    if not docs:
        return "Nenhum documento PDF encontrado para busca."

    matches = []
    erros = 0

    for doc in docs:
        try:
            meta = obter_metadados(doc.drive_file_id)
            modified_time = meta.get("modifiedTime", "")
        except DriveServiceError:
            modified_time = None

        try:
            texto = obter_texto_pdf(doc.drive_file_id, modified_time=modified_time)
        except (PdfExtractionError, DriveServiceError):
            erros += 1
            continue

        if not texto:
            continue

        # Busca case-insensitive
        padrao = re.compile(re.escape(termo), re.IGNORECASE)
        match = padrao.search(texto)
        if match:
            inicio = max(0, match.start() - 200)
            fim = min(len(texto), match.end() + 200)
            trecho = texto[inicio:fim].strip()
            if inicio > 0:
                trecho = "..." + trecho
            if fim < len(texto):
                trecho = trecho + "..."

            matches.append({
                "doc_id": doc.id,
                "nome": doc.nome,
                "categoria": doc.categoria or "sem categoria",
                "trecho": trecho,
            })

    if not matches:
        msg = f"Nenhum documento contem o termo '{termo}'."
        if erros:
            msg += f" ({erros} documentos nao puderam ser lidos)"
        return msg

    linhas = [f"BUSCA POR '{termo}' — {len(matches)} resultado(s) em {len(docs)} documentos:"]
    for m in matches:
        linhas.append(f"\n  [{m['doc_id']}] {m['nome']} ({m['categoria']})")
        linhas.append(f"  Trecho: {m['trecho']}")

    if erros:
        linhas.append(f"\n({erros} documentos nao puderam ser lidos)")

    return "\n".join(linhas)
