import os
import tempfile
from unittest.mock import patch, MagicMock

import fitz  # pymupdf

from app.services.pdf_extractor import (
    extrair_texto_pdf,
    obter_texto_pdf,
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


# --- Testes do orquestrador obter_texto_pdf ---


def test_obter_texto_pdf_com_cache(tmp_path):
    """Se cache existe e esta atualizado, nao chama Drive."""
    with patch.object(settings, "pdf_cache_dir", str(tmp_path)):
        salvar_cache("file123", "Texto cacheado", "2026-03-08T10:00:00Z")

        with patch("app.services.google_drive.baixar_bytes_arquivo") as mock_baixar:
            resultado = obter_texto_pdf("file123", modified_time="2026-03-08T10:00:00Z")
            assert resultado == "Texto cacheado"
            mock_baixar.assert_not_called()


def test_obter_texto_pdf_sem_cache(tmp_path):
    """Sem cache, baixa do Drive, extrai e salva cache."""
    pdf_bytes = _criar_pdf_teste("Peticao inicial do autor")

    with patch.object(settings, "pdf_cache_dir", str(tmp_path)):
        with patch("app.services.google_drive.baixar_bytes_arquivo") as mock_baixar:
            mock_baixar.return_value = (pdf_bytes, {"modifiedTime": "2026-03-08T10:00:00Z"})

            resultado = obter_texto_pdf("file456")
            assert "Peticao inicial do autor" in resultado
            mock_baixar.assert_called_once_with("file456")

            # Cache deve ter sido salvo
            cache = carregar_cache("file456", "2026-03-08T10:00:00Z")
            assert cache is not None
            assert "Peticao inicial do autor" in cache


def test_obter_texto_pdf_com_paginas(tmp_path):
    """Paginacao nao usa cache (pode ser intervalo diferente)."""
    pdf_bytes = _criar_pdf_teste("Texto do auto", num_paginas=20)

    with patch.object(settings, "pdf_cache_dir", str(tmp_path)):
        with patch("app.services.google_drive.baixar_bytes_arquivo") as mock_baixar:
            mock_baixar.return_value = (pdf_bytes, {"modifiedTime": "2026-03-08T10:00:00Z"})

            resultado = obter_texto_pdf("file789", pagina_inicio=5, pagina_fim=8)
            assert "pagina 5" in resultado
            assert "pagina 8" in resultado
            assert "pagina 1" not in resultado


def test_cache_path_traversal_prevention(tmp_path):
    """file_id com caracteres de path traversal e sanitizado."""
    with patch.object(settings, "pdf_cache_dir", str(tmp_path)):
        salvar_cache("../../etc/passwd", "Texto malicioso", "2026-03-08T10:00:00Z")
        # Arquivo deve estar DENTRO do cache_dir, nao fora
        assert not os.path.exists("/etc/passwd.txt")
        resultado = carregar_cache("../../etc/passwd", "2026-03-08T10:00:00Z")
        assert resultado == "Texto malicioso"
