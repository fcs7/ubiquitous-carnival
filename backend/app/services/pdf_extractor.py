"""Extracao de texto de arquivos PDF usando PyMuPDF."""
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
