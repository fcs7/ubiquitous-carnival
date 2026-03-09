from datetime import datetime, date
from unittest.mock import patch, MagicMock
from app.models import Cliente, Processo, ProcessoParte, Movimento, Prazo, Documento
from app.services.ferramentas.processo import executar_buscar_processo, executar_listar_movimentos
from app.services.ferramentas.cliente import executar_buscar_cliente
from app.services.ferramentas.prazo import executar_calcular_prazo, executar_listar_prazos
from app.services.ferramentas.drive import executar_ler_documento, executar_buscar_em_documentos


def _criar_processo_completo(db):
    cliente = Cliente(nome="Joao Silva", cpf_cnpj="123.456.789-00", telefone="11999999999")
    db.add(cliente)
    db.flush()

    processo = Processo(
        cnj="0000001-23.2024.8.26.0100",
        numero_limpo="00000012320248260100",
        tribunal="TJSP",
        alias_tribunal="tjsp",
        classe_nome="Acao Civil",
        orgao_julgador="1a Vara Civel",
        grau="G1",
        status="ativo",
    )
    db.add(processo)
    db.flush()

    parte = ProcessoParte(processo_id=processo.id, cliente_id=cliente.id, papel="autor")
    db.add(parte)

    mov = Movimento(
        processo_id=processo.id,
        codigo=12345,
        nome="Distribuicao",
        data_hora=datetime(2024, 6, 15, 10, 30),
        resumo_ia="Processo distribuido para 1a Vara",
    )
    db.add(mov)

    prazo = Prazo(
        processo_id=processo.id,
        tipo="contestacao",
        descricao="Prazo para contestacao",
        data_limite=date(2026, 12, 31),
        status="pendente",
    )
    db.add(prazo)

    db.commit()

    return processo, cliente


def test_buscar_processo_existente(db):
    processo, cliente = _criar_processo_completo(db)
    resultado = executar_buscar_processo({"cnj": processo.cnj}, db)
    assert "PROCESSO:" in resultado
    assert "TJSP" in resultado
    assert "Joao Silva" in resultado
    assert "AUTOR" in resultado


def test_buscar_processo_inexistente(db):
    resultado = executar_buscar_processo({"cnj": "9999999-99.9999.9.99.9999"}, db)
    assert "nao encontrado" in resultado


def test_listar_movimentos(db):
    processo, _ = _criar_processo_completo(db)
    resultado = executar_listar_movimentos({"processo_id": processo.id}, db)
    assert "Distribuicao" in resultado
    assert "Resumo:" in resultado


def test_buscar_cliente_por_cpf(db):
    _criar_processo_completo(db)
    resultado = executar_buscar_cliente({"busca": "123.456.789-00"}, db)
    assert "Joao Silva" in resultado


def test_buscar_cliente_por_nome(db):
    _criar_processo_completo(db)
    resultado = executar_buscar_cliente({"busca": "Joao"}, db)
    assert "Joao Silva" in resultado


def test_calcular_prazo_uteis(db):
    resultado = executar_calcular_prazo({"data_inicio": "2026-03-09", "dias": 15}, db)
    assert "Vencimento:" in resultado
    assert "30/03/2026" in resultado


def test_calcular_prazo_corridos(db):
    resultado = executar_calcular_prazo({"data_inicio": "2026-03-09", "dias": 15, "tipo": "corridos"}, db)
    assert "24/03/2026" in resultado


def test_listar_prazos_pendentes(db):
    processo, _ = _criar_processo_completo(db)
    resultado = executar_listar_prazos({"processo_id": processo.id}, db)
    assert "contestacao" in resultado
    assert "PRAZOS PENDENTES" in resultado


# ──────────────────────────────────────────────
# T5 — buscar_cliente: busca vazia e multiplos resultados
# ──────────────────────────────────────────────
def test_buscar_cliente_busca_vazia(db):
    """busca vazia retorna mensagem de erro"""
    resultado = executar_buscar_cliente({"busca": ""}, db)
    assert "vazio" in resultado.lower()


def test_buscar_cliente_busca_espacos(db):
    """busca com apenas espacos retorna mensagem de erro"""
    resultado = executar_buscar_cliente({"busca": "   "}, db)
    assert "vazio" in resultado.lower()


def test_buscar_cliente_multiplos_resultados(db):
    """busca por nome parcial com multiplos matches lista todos"""
    for i, nome in enumerate(["Joao Silva", "Joao Santos", "Joao Souza"]):
        db.add(Cliente(nome=nome, cpf_cnpj=f"000.000.000-0{i}", telefone="11999999999"))
    db.commit()

    resultado = executar_buscar_cliente({"busca": "Joao"}, db)
    assert "3 clientes" in resultado or "Encontrados" in resultado


# ──────────────────────────────────────────────
# T6 — calcular_prazo: data invalida e dias=0
# ──────────────────────────────────────────────
def test_calcular_prazo_data_invalida(db):
    resultado = executar_calcular_prazo({"data_inicio": "invalido", "dias": 5}, db)
    assert "invalida" in resultado.lower()


def test_calcular_prazo_sem_data(db):
    resultado = executar_calcular_prazo({"dias": 5}, db)
    assert "invalida" in resultado.lower()


def test_calcular_prazo_dias_zero(db):
    resultado = executar_calcular_prazo({"data_inicio": "2026-03-06", "dias": 0}, db)
    assert "positivo" in resultado.lower()


def test_calcular_prazo_inicio_sabado(db):
    """prazo iniciando no sabado deve ajustar para segunda"""
    resultado = executar_calcular_prazo({"data_inicio": "2026-03-07", "dias": 1, "tipo": "uteis"}, db)
    assert "efetivo" in resultado.lower() or "dia util" in resultado.lower()


# ──────────────────────────────────────────────
# T7 — listar_prazos com prazo vencido
# ──────────────────────────────────────────────
def test_listar_prazos_vencido(db):
    """prazo com data no passado deve mostrar VENCIDO"""
    processo = Processo(
        cnj="0000001-23.2026.8.26.0100",
        numero_limpo="00000012320268260100",
        tribunal="TJSP",
        alias_tribunal="tjsp",
        status="ativo",
    )
    db.add(processo)
    db.commit()

    prazo = Prazo(
        processo_id=processo.id,
        tipo="contestacao",
        descricao="Prazo teste vencido",
        data_limite=date(2025, 1, 1),
        status="pendente",
    )
    db.add(prazo)
    db.commit()

    resultado = executar_listar_prazos({"processo_id": processo.id}, db)
    assert "VENCIDO" in resultado


# ──────────────────────────────────────────────
# Helpers para documentos
# ──────────────────────────────────────────────
def _criar_documento_pdf(db, processo):
    doc = Documento(
        nome="peticao_inicial.pdf",
        tipo="drive",
        categoria="peticao",
        mime_type="application/pdf",
        drive_file_id="drive_abc123",
        drive_url="https://drive.google.com/file/d/drive_abc123",
        origem="drive",
        processo_id=processo.id,
    )
    db.add(doc)
    db.commit()
    return doc


# ──────────────────────────────────────────────
# T8 — ler_documento
# ──────────────────────────────────────────────
def test_ler_documento_sucesso(db):
    processo, _ = _criar_processo_completo(db)
    doc = _criar_documento_pdf(db, processo)

    with patch("app.services.ferramentas.drive.obter_texto_pdf") as mock_pdf:
        with patch("app.services.ferramentas.drive.obter_metadados") as mock_meta:
            mock_meta.return_value = {"modifiedTime": "2026-03-08T10:00:00Z"}
            mock_pdf.return_value = "Texto da peticao inicial do autor Joao Silva"

            resultado = executar_ler_documento({"documento_id": doc.id}, db)
            assert "peticao_inicial.pdf" in resultado
            assert "Texto da peticao inicial" in resultado


def test_ler_documento_com_paginas(db):
    processo, _ = _criar_processo_completo(db)
    doc = _criar_documento_pdf(db, processo)

    with patch("app.services.ferramentas.drive.obter_texto_pdf") as mock_pdf:
        with patch("app.services.ferramentas.drive.obter_metadados") as mock_meta:
            mock_meta.return_value = {"modifiedTime": "2026-03-08T10:00:00Z"}
            mock_pdf.return_value = "Texto das paginas 3 a 5"

            resultado = executar_ler_documento({"documento_id": doc.id, "paginas": "3-5"}, db)
            assert "Texto das paginas 3 a 5" in resultado
            mock_pdf.assert_called_once_with(
                "drive_abc123",
                modified_time="2026-03-08T10:00:00Z",
                pagina_inicio=3,
                pagina_fim=5,
            )


def test_ler_documento_inexistente(db):
    resultado = executar_ler_documento({"documento_id": 9999}, db)
    assert "nao encontrado" in resultado.lower()


def test_ler_documento_sem_drive(db):
    processo, _ = _criar_processo_completo(db)
    doc = Documento(
        nome="arquivo_local.pdf",
        tipo="upload",
        mime_type="application/pdf",
        origem="local",
        processo_id=processo.id,
    )
    db.add(doc)
    db.commit()

    resultado = executar_ler_documento({"documento_id": doc.id}, db)
    assert "google drive" in resultado.lower() or "drive" in resultado.lower()


# ──────────────────────────────────────────────
# T9 — buscar_em_documentos
# ──────────────────────────────────────────────
def test_buscar_em_documentos_encontra(db):
    processo, _ = _criar_processo_completo(db)
    doc = _criar_documento_pdf(db, processo)

    with patch("app.services.ferramentas.drive.obter_texto_pdf") as mock_pdf:
        with patch("app.services.ferramentas.drive.obter_metadados") as mock_meta:
            mock_meta.return_value = {"modifiedTime": "2026-03-08T10:00:00Z"}
            mock_pdf.return_value = "O autor requer a rescisao do contrato conforme clausula quinta"

            resultado = executar_buscar_em_documentos(
                {"termo": "rescisao", "processo_id": processo.id}, db,
            )
            assert "peticao_inicial.pdf" in resultado
            assert "rescisao" in resultado.lower()


def test_buscar_em_documentos_nao_encontra(db):
    processo, _ = _criar_processo_completo(db)
    doc = _criar_documento_pdf(db, processo)

    with patch("app.services.ferramentas.drive.obter_texto_pdf") as mock_pdf:
        with patch("app.services.ferramentas.drive.obter_metadados") as mock_meta:
            mock_meta.return_value = {"modifiedTime": "2026-03-08T10:00:00Z"}
            mock_pdf.return_value = "Texto sem o termo buscado"

            resultado = executar_buscar_em_documentos(
                {"termo": "rescisao", "processo_id": processo.id}, db,
            )
            assert "nenhum" in resultado.lower()


def test_buscar_em_documentos_sem_termo(db):
    resultado = executar_buscar_em_documentos({"processo_id": 1}, db)
    assert "obrigatorio" in resultado.lower() or "termo" in resultado.lower()


def test_buscar_em_documentos_sem_processo(db):
    """Busca global (sem processo_id) deve funcionar."""
    processo, _ = _criar_processo_completo(db)
    doc = _criar_documento_pdf(db, processo)

    with patch("app.services.ferramentas.drive.obter_texto_pdf") as mock_pdf:
        with patch("app.services.ferramentas.drive.obter_metadados") as mock_meta:
            mock_meta.return_value = {"modifiedTime": "2026-03-08T10:00:00Z"}
            mock_pdf.return_value = "Contrato de locacao residencial"

            resultado = executar_buscar_em_documentos({"termo": "locacao"}, db)
            assert "peticao_inicial.pdf" in resultado
