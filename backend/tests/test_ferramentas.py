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
