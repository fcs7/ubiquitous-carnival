from unittest.mock import patch, MagicMock
import pytest

from app.models import Processo, ProcessoParte, Cliente, Documento


MOCK_DRIVE_FILES = [
    {
        "id": "abc123",
        "name": "peticao_inicial.pdf",
        "mimeType": "application/pdf",
        "webViewLink": "https://drive.google.com/file/d/abc123/view",
        "modifiedTime": "2026-03-07T10:00:00Z",
        "size": "1024",
        "parents": ["pasta_pai_id"],
    },
    {
        "id": "def456",
        "name": "Subpastas",
        "mimeType": "application/vnd.google-apps.folder",
        "webViewLink": "https://drive.google.com/drive/folders/def456",
        "modifiedTime": "2026-03-06T08:00:00Z",
        "size": None,
        "parents": ["pasta_pai_id"],
    },
]

MOCK_PASTA_CRIADA = {
    "id": "nova_pasta_id",
    "name": "0001234-56.2024.8.26.0001 — Joao Silva",
    "mimeType": "application/vnd.google-apps.folder",
    "webViewLink": "https://drive.google.com/drive/folders/nova_pasta_id",
}


def _criar_processo(db):
    proc = Processo(
        cnj="0001234-56.2024.8.26.0001",
        numero_limpo="00012345620248260001",
        tribunal="TJSP",
        alias_tribunal="tjsp",
    )
    db.add(proc)
    db.commit()
    db.refresh(proc)
    return proc


def _criar_processo_com_cliente(db):
    proc = _criar_processo(db)
    cli = Cliente(nome="Joao Silva", cpf_cnpj="12345678901", telefone="11999990000")
    db.add(cli)
    db.commit()
    db.refresh(cli)
    parte = ProcessoParte(processo_id=proc.id, cliente_id=cli.id, papel="autor")
    db.add(parte)
    db.commit()
    return proc, cli


# ──────────────────────────────────────────────
# Testes de leitura do Drive
# ──────────────────────────────────────────────
@patch("app.routers.documentos.google_drive")
def test_listar_pasta_drive(mock_gd, client):
    mock_gd.listar_pasta.return_value = MOCK_DRIVE_FILES
    resp = client.get("/documentos/drive/pasta/pasta_pai_id")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 2
    assert data[0]["name"] == "peticao_inicial.pdf"
    mock_gd.listar_pasta.assert_called_once_with("pasta_pai_id", False)


@patch("app.routers.documentos.google_drive")
def test_listar_pasta_apenas_pastas(mock_gd, client):
    mock_gd.listar_pasta.return_value = [MOCK_DRIVE_FILES[1]]
    resp = client.get("/documentos/drive/pasta/pasta_pai_id?apenas_pastas=true")
    assert resp.status_code == 200
    assert len(resp.json()) == 1
    mock_gd.listar_pasta.assert_called_once_with("pasta_pai_id", True)


@patch("app.routers.documentos.google_drive")
def test_buscar_drive(mock_gd, client):
    mock_gd.buscar_arquivo.return_value = [MOCK_DRIVE_FILES[0]]
    resp = client.get("/documentos/drive/buscar?q=peticao")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) == 1
    assert data[0]["id"] == "abc123"


def test_buscar_drive_query_curta(client):
    resp = client.get("/documentos/drive/buscar?q=a")
    assert resp.status_code == 422


@patch("app.routers.documentos.google_drive")
def test_metadados_drive(mock_gd, client):
    mock_gd.obter_metadados.return_value = MOCK_DRIVE_FILES[0]
    resp = client.get("/documentos/drive/metadados/abc123")
    assert resp.status_code == 200
    assert resp.json()["name"] == "peticao_inicial.pdf"


# ──────────────────────────────────────────────
# Testes de vinculacao
# ──────────────────────────────────────────────
def test_vincular_arquivo_drive(client, db):
    proc = _criar_processo(db)
    resp = client.post("/documentos/drive/vincular", json={
        "drive_file_id": "abc123",
        "drive_url": "https://drive.google.com/file/d/abc123/view",
        "nome": "peticao_inicial.pdf",
        "mime_type": "application/pdf",
        "tamanho_bytes": 1024,
        "processo_id": proc.id,
        "categoria": "peticao",
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["drive_file_id"] == "abc123"
    assert data["origem"] == "drive"
    assert data["tipo"] == "drive"
    assert data["processo_id"] == proc.id


def test_vincular_processo_inexistente(client):
    resp = client.post("/documentos/drive/vincular", json={
        "drive_file_id": "abc123",
        "drive_url": "https://drive.google.com/file/d/abc123/view",
        "nome": "doc.pdf",
        "mime_type": "application/pdf",
        "processo_id": 99999,
    })
    assert resp.status_code == 404


def test_listar_documentos_processo(client, db):
    proc = _criar_processo(db)
    # Vincular 2 documentos
    for i in range(2):
        doc = Documento(
            nome=f"doc_{i}.pdf", tipo="drive", mime_type="application/pdf",
            drive_file_id=f"id_{i}", drive_url=f"https://drive/{i}",
            origem="drive", processo_id=proc.id,
        )
        db.add(doc)
    db.commit()

    resp = client.get(f"/documentos/processo/{proc.id}")
    assert resp.status_code == 200
    assert len(resp.json()) == 2


def test_desvincular_documento(client, db):
    proc = _criar_processo(db)
    doc = Documento(
        nome="doc.pdf", tipo="drive", mime_type="application/pdf",
        drive_file_id="xyz", drive_url="https://drive/xyz",
        origem="drive", processo_id=proc.id,
    )
    db.add(doc)
    db.commit()
    db.refresh(doc)

    resp = client.delete(f"/documentos/{doc.id}")
    assert resp.status_code == 204

    # Confirmar que sumiu do banco
    assert db.query(Documento).filter(Documento.id == doc.id).first() is None


def test_desvincular_inexistente(client):
    resp = client.delete("/documentos/99999")
    assert resp.status_code == 404


# ──────────────────────────────────────────────
# Testes de organizacao de pastas
# ──────────────────────────────────────────────
@patch("app.routers.documentos.google_drive")
def test_organizar_pasta_processo(mock_gd, client, db):
    proc, cli = _criar_processo_com_cliente(db)
    mock_gd.montar_pasta_processo.return_value = MOCK_PASTA_CRIADA
    resp = client.post(f"/documentos/drive/organizar/{proc.id}")
    assert resp.status_code == 200
    data = resp.json()
    assert data["pasta_id"] == "nova_pasta_id"
    mock_gd.montar_pasta_processo.assert_called_once_with(proc.cnj, "Joao Silva")


@patch("app.routers.documentos.google_drive")
def test_organizar_simulacao(mock_gd, client, db):
    proc = _criar_processo(db)
    mock_gd.simular_organizacao.return_value = {
        "acao": "simulacao",
        "estrutura": "Processos/0001234-56.2024.8.26.0001/",
        "pasta_raiz_id": "raiz",
        "mensagem": "Nenhuma alteracao foi feita no Drive.",
    }
    resp = client.post(f"/documentos/drive/organizar/{proc.id}?simular=true")
    assert resp.status_code == 200
    data = resp.json()
    assert data["pasta_id"] == "simulacao"


def test_organizar_processo_inexistente(client):
    resp = client.post("/documentos/drive/organizar/99999")
    assert resp.status_code == 404


# ──────────────────────────────────────────────
# Testes de seguranca (Drive indisponivel / fora do escopo)
# ──────────────────────────────────────────────
@patch("app.routers.documentos.google_drive")
def test_drive_indisponivel_retorna_502(mock_gd, client):
    from app.services.google_drive import DriveServiceError
    mock_gd.listar_pasta.side_effect = DriveServiceError("API timeout")
    mock_gd.DriveServiceError = DriveServiceError
    resp = client.get("/documentos/drive/pasta/qualquer_id")
    assert resp.status_code == 502


@patch("app.routers.documentos.google_drive")
def test_drive_fora_escopo_retorna_403(mock_gd, client):
    from app.services.google_drive import DriveServiceError
    mock_gd.mover_arquivo.side_effect = DriveServiceError("SEGURANCA: arquivo fora da pasta raiz")
    mock_gd.DriveServiceError = DriveServiceError
    resp = client.post("/documentos/drive/mover?file_id=x&nova_pasta_id=y")
    assert resp.status_code == 403


# ──────────────────────────────────────────────
# Teste da ferramenta de agente
# ──────────────────────────────────────────────
def test_ferramenta_listar_documentos(db):
    proc = _criar_processo(db)
    doc = Documento(
        nome="contrato.pdf", tipo="drive", mime_type="application/pdf",
        drive_file_id="id1", drive_url="https://drive/id1",
        origem="drive", processo_id=proc.id, categoria="contrato",
    )
    db.add(doc)
    db.commit()

    from app.services.ferramentas.drive import executar_listar_documentos_processo
    resultado = executar_listar_documentos_processo({"processo_id": proc.id}, db)
    assert "contrato.pdf" in resultado
    assert "Google Drive" in resultado
    assert "1 encontrados" in resultado
    assert f"[ID:{doc.id}]" in resultado


def test_ferramenta_sem_documentos(db):
    from app.services.ferramentas.drive import executar_listar_documentos_processo
    resultado = executar_listar_documentos_processo({"processo_id": 999}, db)
    assert "Nenhum documento" in resultado


def test_ferramenta_sem_processo_id(db):
    from app.services.ferramentas.drive import executar_listar_documentos_processo
    resultado = executar_listar_documentos_processo({}, db)
    assert "obrigatorio" in resultado
