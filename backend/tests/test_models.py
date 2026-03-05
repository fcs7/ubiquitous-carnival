from datetime import datetime, date
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.database import Base
from app.models import (
    Usuario, Cliente, Processo, ProcessoParte,
    Movimento, Prazo, Financeiro, Documento,
    Conversa, Mensagem, ConfigEscritorio,
)

engine = create_engine("sqlite:///:memory:")
Session = sessionmaker(bind=engine)


def setup_module():
    Base.metadata.create_all(engine)


def test_criar_usuario():
    session = Session()
    usuario = Usuario(nome="Dr. Muglia", email="muglia@escritorio.com", oab="DF12345")
    session.add(usuario)
    session.flush()
    assert usuario.id is not None
    assert usuario.oab == "DF12345"
    session.rollback()


def test_criar_cliente_com_cpf():
    session = Session()
    cliente = Cliente(nome="Joao Silva", cpf_cnpj="123.456.789-00", telefone="61999998888", estado_civil="solteiro")
    session.add(cliente)
    session.flush()
    assert cliente.id is not None
    assert cliente.cpf_cnpj == "123.456.789-00"
    session.rollback()


def test_processo_com_multiplas_partes():
    session = Session()
    autor = Cliente(nome="Joao Autor", cpf_cnpj="111.111.111-11", telefone="61999991111", estado_civil="casado")
    reu = Cliente(nome="Maria Re", cpf_cnpj="222.222.222-22", telefone="61999992222", estado_civil="solteiro")
    session.add_all([autor, reu])
    session.flush()

    processo = Processo(
        cnj="0702906-79.2026.8.07.0020",
        numero_limpo="07029067920268070020",
        tribunal="TJDFT",
        alias_tribunal="tjdft",
    )
    session.add(processo)
    session.flush()

    parte_autor = ProcessoParte(processo_id=processo.id, cliente_id=autor.id, papel="autor")
    parte_reu = ProcessoParte(processo_id=processo.id, cliente_id=reu.id, papel="reu")
    session.add_all([parte_autor, parte_reu])
    session.flush()

    assert len(processo.partes) == 2
    papeis = {p.papel for p in processo.partes}
    assert papeis == {"autor", "reu"}
    session.rollback()


def test_movimento_com_datetime():
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
        data_hora=datetime(2018, 10, 30, 14, 6, 24),
        notificado=False,
    )
    session.add(mov)
    session.flush()

    assert isinstance(mov.data_hora, datetime)
    assert processo.movimentos[0].nome == "Distribuicao"
    session.rollback()


def test_financeiro_vincula_processo_e_cliente():
    session = Session()
    cliente = Cliente(nome="Joao", cpf_cnpj="333.333.333-33", telefone="61999993333", estado_civil="divorciado")
    session.add(cliente)
    session.flush()

    processo = Processo(
        cnj="0000001-00.2024.8.07.0001",
        numero_limpo="00000010020248070001",
        tribunal="TJDFT",
        alias_tribunal="tjdft",
    )
    session.add(processo)
    session.flush()

    fin = Financeiro(
        processo_id=processo.id,
        cliente_id=cliente.id,
        tipo="honorario",
        valor=5000.00,
        data_vencimento=date(2026, 4, 1),
    )
    session.add(fin)
    session.flush()

    assert fin.processo_id == processo.id
    assert fin.cliente_id == cliente.id
    assert fin.status == "pendente"
    session.rollback()


def test_conversa_com_mensagens():
    session = Session()
    usuario = Usuario(nome="Dr. Muglia", email="muglia2@test.com")
    session.add(usuario)
    session.flush()

    conversa = Conversa(usuario_id=usuario.id, titulo="Peticao Inicial")
    session.add(conversa)
    session.flush()

    msg1 = Mensagem(conversa_id=conversa.id, role="user", conteudo="Gere uma peticao inicial")
    msg2 = Mensagem(conversa_id=conversa.id, role="assistant", conteudo="Aqui esta a peticao...")
    session.add_all([msg1, msg2])
    session.flush()

    assert len(conversa.mensagens) == 2
    assert conversa.mensagens[0].role == "user"
    assert conversa.mensagens[1].role == "assistant"
    session.rollback()


def test_documento():
    session = Session()
    doc = Documento(
        nome="modelo_peticao.docx",
        tipo="modelo",
        categoria="peticao",
        arquivo_path="/uploads/modelo_peticao.docx",
        mime_type="application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        tamanho_bytes=45000,
    )
    session.add(doc)
    session.flush()
    assert doc.tipo == "modelo"
    session.rollback()


def test_config_escritorio():
    session = Session()
    config = ConfigEscritorio(
        chave="nome_escritorio",
        valor="Muglia Advocacia",
        descricao="Nome oficial do escritorio",
    )
    session.add(config)
    session.flush()
    assert config.chave == "nome_escritorio"
    session.rollback()
