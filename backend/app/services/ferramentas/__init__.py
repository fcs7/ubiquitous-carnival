from app.services.ferramentas.processo import (
    SCHEMA_BUSCAR_PROCESSO, executar_buscar_processo,
    SCHEMA_LISTAR_MOVIMENTOS, executar_listar_movimentos,
)
from app.services.ferramentas.cliente import (
    SCHEMA_BUSCAR_CLIENTE, executar_buscar_cliente,
)
from app.services.ferramentas.prazo import (
    SCHEMA_CALCULAR_PRAZO, executar_calcular_prazo,
    SCHEMA_LISTAR_PRAZOS, executar_listar_prazos,
)
from app.services.ferramentas.financeiro import (
    SCHEMA_RESUMO_FINANCEIRO, executar_resumo_financeiro,
)
from app.services.ferramentas.drive import (
    SCHEMA_LISTAR_DOCUMENTOS_PROCESSO, executar_listar_documentos_processo,
)

FERRAMENTAS_DISPONIVEIS: dict[str, dict] = {
    "buscar_processo": {
        "schema": SCHEMA_BUSCAR_PROCESSO,
        "executor": executar_buscar_processo,
        "descricao_ui": "Consulta dados completos de um processo pelo numero CNJ",
        "categoria": "processo",
    },
    "listar_movimentos": {
        "schema": SCHEMA_LISTAR_MOVIMENTOS,
        "executor": executar_listar_movimentos,
        "descricao_ui": "Lista os ultimos movimentos/andamentos de um processo",
        "categoria": "processo",
    },
    "buscar_cliente": {
        "schema": SCHEMA_BUSCAR_CLIENTE,
        "executor": executar_buscar_cliente,
        "descricao_ui": "Busca dados de um cliente por nome ou CPF/CNPJ",
        "categoria": "cliente",
    },
    "calcular_prazo": {
        "schema": SCHEMA_CALCULAR_PRAZO,
        "executor": executar_calcular_prazo,
        "descricao_ui": "Calcula prazo processual em dias uteis a partir de uma data",
        "categoria": "prazo",
    },
    "listar_prazos": {
        "schema": SCHEMA_LISTAR_PRAZOS,
        "executor": executar_listar_prazos,
        "descricao_ui": "Lista prazos pendentes de um processo",
        "categoria": "prazo",
    },
    "resumo_financeiro": {
        "schema": SCHEMA_RESUMO_FINANCEIRO,
        "executor": executar_resumo_financeiro,
        "descricao_ui": "Resume posicao financeira de um processo especifico",
        "categoria": "financeiro",
    },
    "listar_documentos_processo": {
        "schema": SCHEMA_LISTAR_DOCUMENTOS_PROCESSO,
        "executor": executar_listar_documentos_processo,
        "descricao_ui": "Lista documentos e arquivos vinculados a um processo",
        "categoria": "documento",
    },
}
