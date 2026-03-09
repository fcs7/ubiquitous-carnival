"""Extracao de texto de arquivos PDF usando PyMuPDF, com cache local."""
import json
import os

import fitz  # pymupdf

from app.config import settings


class PdfExtractionError(Exception):
    """Erro ao extrair texto de PDF."""


def extrair_texto_pdf(
    pdf_bytes: bytes,
    pagina_inicio: int | None = None,
    pagina_fim: int | None = None,
    max_chars: int | None = None,
) -> str:
    """Extrai texto de bytes de um PDF.

    Args:
        pdf_bytes: conteudo binario do PDF
        pagina_inicio: pagina inicial (1-indexed, inclusive)
        pagina_fim: pagina final (1-indexed, inclusive)
        max_chars: limite de caracteres (default: settings.pdf_max_chars)

    Returns:
        Texto extraido do PDF.
    """
    if max_chars is None:
        max_chars = settings.pdf_max_chars

    try:
        doc = fitz.open(stream=pdf_bytes, filetype="pdf")
    except Exception as e:
        raise PdfExtractionError(f"Falha ao abrir PDF: {e}") from e

    try:
        total_paginas = len(doc)
        inicio = (pagina_inicio or 1) - 1  # converter para 0-indexed
        fim = pagina_fim or total_paginas

        # garantir limites validos
        inicio = max(0, min(inicio, total_paginas))
        fim = max(inicio, min(fim, total_paginas))

        partes = []
        for i in range(inicio, fim):
            texto_pagina = doc[i].get_text()
            if texto_pagina.strip():
                partes.append(texto_pagina)

        texto = "\n".join(partes)

        if len(texto) > max_chars:
            texto = texto[:max_chars] + "\n\n[TEXTO TRUNCADO — documento tem mais conteudo]"

        return texto
    finally:
        doc.close()


# --- Cache local de PDFs extraidos ---


def _cache_path(file_id: str) -> str:
    """Caminho do arquivo de texto em cache."""
    return os.path.join(settings.pdf_cache_dir, f"{file_id}.txt")


def _meta_path(file_id: str) -> str:
    """Caminho do arquivo de metadados do cache."""
    return os.path.join(settings.pdf_cache_dir, f"{file_id}.meta.json")


def salvar_cache(file_id: str, texto: str, modified_time: str) -> None:
    """Salva texto extraido em cache local.

    Args:
        file_id: identificador unico do arquivo (Google Drive ID)
        texto: texto extraido do PDF
        modified_time: data de modificacao do arquivo original (para invalidacao)
    """
    os.makedirs(settings.pdf_cache_dir, exist_ok=True)
    with open(_cache_path(file_id), "w", encoding="utf-8") as f:
        f.write(texto)
    with open(_meta_path(file_id), "w", encoding="utf-8") as f:
        json.dump({"modified_time": modified_time}, f)


def carregar_cache(file_id: str, modified_time: str) -> str | None:
    """Carrega texto do cache se existir e estiver atualizado.

    Args:
        file_id: identificador unico do arquivo
        modified_time: data de modificacao atual do arquivo

    Returns:
        Texto cacheado ou None se cache inexistente/desatualizado.
    """
    meta = _meta_path(file_id)
    cache = _cache_path(file_id)
    if not os.path.exists(meta) or not os.path.exists(cache):
        return None
    with open(meta, encoding="utf-8") as f:
        dados = json.load(f)
    if dados.get("modified_time") != modified_time:
        return None
    with open(cache, encoding="utf-8") as f:
        return f.read()
