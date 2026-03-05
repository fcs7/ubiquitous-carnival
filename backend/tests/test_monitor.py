"""Testes standalone do monitor de processos (sem conftest, SQLite in-memory)."""

from datetime import datetime
from unittest.mock import patch

import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.models import Processo, Movimento


# ── Setup SQLite in-memory ──────────────────────────────────────

engine = create_engine("sqlite://", echo=False)
TestSession = sessionmaker(bind=engine)


@pytest.fixture()
def db():
    Base.metadata.create_all(engine)
    session = TestSession()
    try:
        yield session
    finally:
        session.close()
        Base.metadata.drop_all(engine)


def _criar_processo(db) -> Processo:
    proc = Processo(
        cnj="0000001-23.2024.8.26.0100",
        numero_limpo="00000012320248260100",
        tribunal="TJSP",
        alias_tribunal="tjsp",
        status="ativo",
    )
    db.add(proc)
    db.commit()
    db.refresh(proc)
    return proc


MOVIMENTOS_DATAJUD = [
    {
        "codigo": 1,
        "nome": "Distribuicao",
        "dataHora": "2024-06-01T10:00:00",
        "complementosTabelados": [{"descricao": "Por sorteio"}],
    },
    {
        "codigo": 2,
        "nome": "Juntada de peticao",
        "dataHora": "2024-06-02T14:30:00",
        "complementosTabelados": [],
    },
]


@patch("app.services.monitor.traduzir_movimento", return_value="Resumo simples")
@patch(
    "app.services.monitor.consultar_processo",
    return_value={"movimentos": MOVIMENTOS_DATAJUD},
)
def test_detecta_movimentos_novos(mock_datajud, mock_ia, db):
    """Deve detectar e salvar 2 movimentos novos do DataJud."""
    from app.services.monitor import verificar_processo

    proc = _criar_processo(db)
    novos = verificar_processo(db, proc)

    assert len(novos) == 2
    # Verifica campos do primeiro movimento
    m1 = db.query(Movimento).filter_by(codigo=1).first()
    assert m1 is not None
    assert m1.nome == "Distribuicao"
    assert m1.data_hora == datetime(2024, 6, 1, 10, 0, 0)
    assert m1.complementos == "Por sorteio"
    assert m1.resumo_ia == "Resumo simples"
    assert m1.notificado is False

    # Verifica segunda
    m2 = db.query(Movimento).filter_by(codigo=2).first()
    assert m2 is not None
    assert m2.complementos is None  # lista vazia -> ""  -> None? Depende da lógica

    # ultima_verificacao deve ter sido atualizada
    db.refresh(proc)
    assert proc.ultima_verificacao is not None


@patch("app.services.monitor.traduzir_movimento", return_value="Resumo simples")
@patch(
    "app.services.monitor.consultar_processo",
    return_value={"movimentos": MOVIMENTOS_DATAJUD},
)
def test_nao_duplica_movimentos(mock_datajud, mock_ia, db):
    """Segunda chamada com mesmos movimentos nao deve criar duplicatas."""
    from app.services.monitor import verificar_processo

    proc = _criar_processo(db)

    novos1 = verificar_processo(db, proc)
    assert len(novos1) == 2

    novos2 = verificar_processo(db, proc)
    assert len(novos2) == 0

    total = db.query(Movimento).filter_by(processo_id=proc.id).count()
    assert total == 2
