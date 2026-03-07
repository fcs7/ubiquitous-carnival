from sqlalchemy.orm import Session
from app.models import Documento


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
