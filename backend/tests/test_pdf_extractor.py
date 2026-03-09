import os
import tempfile
from unittest.mock import patch, MagicMock

import fitz  # pymupdf

from app.services.pdf_extractor import (
    extrair_texto_pdf,
    PdfExtractionError,
    _cache_path,
    salvar_cache,
    carregar_cache,
)
from app.config import settings


def _criar_pdf_teste(texto: str, num_paginas: int = 1) -> bytes:
    """Cria um PDF em memoria com texto para testes."""
    doc = fitz.open()
    for i in range(num_paginas):
        page = doc.new_page()
        page.insert_text((72, 72), f"{texto} - pagina {i + 1}")
    pdf_bytes = doc.tobytes()
    doc.close()
    return pdf_bytes


def test_extrair_texto_pdf_basico():
    pdf_bytes = _criar_pdf_teste("Contrato de prestacao de servicos")
    texto = extrair_texto_pdf(pdf_bytes)
    assert "Contrato de prestacao de servicos" in texto
    assert "pagina 1" in texto


def test_extrair_texto_pdf_multiplas_paginas():
    pdf_bytes = _criar_pdf_teste("Clausula importante", num_paginas=5)
    texto = extrair_texto_pdf(pdf_bytes)
    assert "pagina 1" in texto
    assert "pagina 5" in texto


def test_extrair_texto_pdf_com_intervalo_paginas():
    pdf_bytes = _criar_pdf_teste("Texto do documento", num_paginas=10)
    texto = extrair_texto_pdf(pdf_bytes, pagina_inicio=3, pagina_fim=5)
    assert "pagina 3" in texto
    assert "pagina 5" in texto
    assert "pagina 1" not in texto
    assert "pagina 6" not in texto


def test_extrair_texto_pdf_vazio():
    """PDF sem texto (escaneado) retorna string vazia."""
    doc = fitz.open()
    doc.new_page()  # pagina em branco
    pdf_bytes = doc.tobytes()
    doc.close()
    texto = extrair_texto_pdf(pdf_bytes)
    assert texto.strip() == ""


def test_extrair_texto_pdf_bytes_invalidos():
    """Bytes que nao sao PDF levantam erro."""
    try:
        extrair_texto_pdf(b"isso nao e um pdf")
        assert False, "Deveria ter levantado PdfExtractionError"
    except PdfExtractionError:
        pass


def test_extrair_texto_pdf_truncamento():
    """Texto maior que max_chars e truncado."""
    pdf_bytes = _criar_pdf_teste("A" * 500, num_paginas=5)
    texto = extrair_texto_pdf(pdf_bytes, max_chars=100)
    assert len(texto) <= 150  # 100 + margem para aviso de truncamento
    assert "truncado" in texto.lower()


# --- Testes de cache local ---


def test_cache_salvar_e_carregar(tmp_path):
    """Cache salva e recupera texto corretamente."""
    with patch.object(settings, "pdf_cache_dir", str(tmp_path)):
        salvar_cache("abc123", "Texto do documento", "2026-03-08T10:00:00Z")
        resultado = carregar_cache("abc123", "2026-03-08T10:00:00Z")
        assert resultado == "Texto do documento"


def test_cache_invalido_por_modified_time(tmp_path):
    """Cache retorna None quando modified_time mudou."""
    with patch.object(settings, "pdf_cache_dir", str(tmp_path)):
        salvar_cache("abc123", "Texto antigo", "2026-03-08T10:00:00Z")
        resultado = carregar_cache("abc123", "2026-03-08T12:00:00Z")
        assert resultado is None


def test_cache_inexistente(tmp_path):
    """Cache retorna None para arquivo nao cacheado."""
    with patch.object(settings, "pdf_cache_dir", str(tmp_path)):
        resultado = carregar_cache("naoexiste", "2026-03-08T10:00:00Z")
        assert resultado is None
