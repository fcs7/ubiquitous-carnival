from unittest.mock import MagicMock, patch

from app.models import AgenteConfig, Usuario


def _criar_usuario(db):
    u = Usuario(nome="Adv Teste", email="adv@mem.com", oab="99999/SP")
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


def _criar_agente(db, usuario_id):
    a = AgenteConfig(
        usuario_id=usuario_id,
        nome="Agente Memoria",
        provider="anthropic",
        modelo="claude-haiku-4-5-20251001",
    )
    db.add(a)
    db.commit()
    db.refresh(a)
    return a


def test_gerar_memoria_agente_inexistente(client):
    resp = client.post("/agentes/9999/gerar-memoria", json={
        "pasta_drive_id": "abc123",
    })
    assert resp.status_code == 404


@patch("app.services.memoria_agente._validar_dentro_raiz")
def test_gerar_memoria_pasta_fora_raiz(mock_validar, client, db):
    from app.services.google_drive import DriveServiceError
    mock_validar.side_effect = DriveServiceError("SEGURANCA: fora da raiz")

    usuario = _criar_usuario(db)
    agente = _criar_agente(db, usuario.id)

    resp = client.post(f"/agentes/{agente.id}/gerar-memoria", json={
        "pasta_drive_id": "pasta_fora",
    })
    assert resp.status_code == 403
    assert "SEGURANCA" in resp.json()["detail"]


@patch("app.services.memoria_agente._validar_dentro_raiz")
@patch("app.services.memoria_agente.listar_pasta")
def test_gerar_memoria_drive_falha(mock_listar, mock_validar, client, db):
    from app.services.google_drive import DriveServiceError
    mock_validar.return_value = None
    mock_listar.side_effect = DriveServiceError("Erro ao listar pasta: timeout")

    usuario = _criar_usuario(db)
    agente = _criar_agente(db, usuario.id)

    resp = client.post(f"/agentes/{agente.id}/gerar-memoria", json={
        "pasta_drive_id": "pasta_ok",
    })
    assert resp.status_code == 502
    assert "Google Drive" in resp.json()["detail"]


@patch("app.services.memoria_agente.PASTA_BASE")
@patch("app.services.memoria_agente._chamar_claude_para_memoria")
@patch("app.services.memoria_agente.baixar_conteudo_arquivo")
@patch("app.services.memoria_agente.listar_pasta")
@patch("app.services.memoria_agente._validar_dentro_raiz")
def test_gerar_memoria_sucesso(
    mock_validar, mock_listar, mock_baixar, mock_claude, mock_pasta_base,
    client, db, tmp_path,
):
    mock_validar.return_value = None
    mock_listar.return_value = [
        {"id": "file1", "name": "doc1.txt", "mimeType": "text/plain"},
        {"id": "file2", "name": "doc2.txt", "mimeType": "text/plain"},
    ]
    mock_baixar.side_effect = [
        ("doc1.txt", "Conteudo do documento 1 sobre direito trabalhista."),
        ("doc2.txt", "Conteudo do documento 2 sobre prazos processuais."),
    ]
    mock_claude.return_value = (
        {
            "index.md": "# Indice\n\n- **trabalhista.md** — Direito trabalhista\n- **prazos.md** — Prazos\n",
            "trabalhista.md": "# Direito Trabalhista\n\nConteudo...\n",
            "prazos.md": "# Prazos Processuais\n\nConteudo...\n",
        },
        1500,
    )
    mock_pasta_base.__truediv__ = lambda self, x: tmp_path / x

    usuario = _criar_usuario(db)
    agente = _criar_agente(db, usuario.id)

    resp = client.post(f"/agentes/{agente.id}/gerar-memoria", json={
        "pasta_drive_id": "pasta_valida",
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["arquivos_fonte"] == 2
    assert data["tokens_usados"] == 1500
    assert "index.md" in data["arquivos_gerados"]
    assert "trabalhista.md" in data["arquivos_gerados"]
    assert len(data["arquivos_gerados"]) == 3


def test_listar_memoria_vazia(client, db):
    usuario = _criar_usuario(db)
    agente = _criar_agente(db, usuario.id)

    resp = client.get(f"/agentes/{agente.id}/memoria")
    assert resp.status_code == 200
    assert resp.json() == []


def test_carregar_memoria_monta_bloco(tmp_path):
    from app.services import memoria_agente

    pasta_original = memoria_agente.PASTA_BASE
    try:
        memoria_agente.PASTA_BASE = tmp_path

        # Cria pasta do agente com arquivos .md
        pasta_agente = tmp_path / "42"
        pasta_agente.mkdir()
        (pasta_agente / "index.md").write_text("# Indice\n", encoding="utf-8")
        (pasta_agente / "tema.md").write_text("# Tema\n\nConteudo do tema.\n", encoding="utf-8")

        resultado = memoria_agente.carregar_memoria(42)

        assert "<memoria_agente>" in resultado
        assert "</memoria_agente>" in resultado
        assert "<arquivo nome='tema.md'>" in resultado
        assert "Conteudo do tema" in resultado
        # index.md nao deve aparecer no bloco
        assert "nome='index.md'" not in resultado
    finally:
        memoria_agente.PASTA_BASE = pasta_original
