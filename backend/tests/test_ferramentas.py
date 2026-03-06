from datetime import datetime, date
from app.models import Cliente, Processo, ProcessoParte, Movimento, Prazo, Financeiro
from app.services.ferramentas.processo import executar_buscar_processo, executar_listar_movimentos
from app.services.ferramentas.cliente import executar_buscar_cliente
from app.services.ferramentas.prazo import executar_calcular_prazo, executar_listar_prazos
from app.services.ferramentas.financeiro import executar_resumo_financeiro


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

    fin = Financeiro(
        processo_id=processo.id,
        cliente_id=cliente.id,
        tipo="honorario",
        descricao="Honorarios iniciais",
        valor=5000.00,
        status="pendente",
        data_vencimento=date(2026, 7, 15),
    )
    db.add(fin)
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


def test_resumo_financeiro(db):
    processo, _ = _criar_processo_completo(db)
    resultado = executar_resumo_financeiro({"processo_id": processo.id}, db)
    assert "R$" in resultado
    assert "PENDENTE" in resultado
    assert "honorario" in resultado
