from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.database import Base
from app.models import Cliente, Processo, Movimento, Financeiro, Prazo


engine = create_engine("sqlite:///:memory:")
Session = sessionmaker(bind=engine)


def setup_module():
    Base.metadata.create_all(engine)


def test_criar_cliente_e_processo():
    session = Session()
    cliente = Cliente(nome="Joao Silva", telefone="61999998888")
    session.add(cliente)
    session.flush()

    processo = Processo(
        cnj="0702906-79.2026.8.07.0020",
        numero_limpo="07029067920268070020",
        tribunal="TJDFT",
        alias_tribunal="tjdft",
        cliente_id=cliente.id,
    )
    session.add(processo)
    session.flush()

    assert processo.id is not None
    assert processo.cliente.nome == "Joao Silva"
    session.rollback()


def test_criar_movimento():
    session = Session()
    processo = Processo(
        cnj="0000832-35.2018.4.01.3202",
        numero_limpo="00008323520184013202",
        tribunal="TRF1",
        alias_tribunal="trf1",
    )
    session.add(processo)
    session.flush()

    mov = Movimento(
        processo_id=processo.id,
        codigo=26,
        nome="Distribuicao",
        data_hora="2018-10-30T14:06:24.000Z",
        notificado=False,
    )
    session.add(mov)
    session.flush()

    assert mov.id is not None
    assert processo.movimentos[0].nome == "Distribuicao"
    session.rollback()
