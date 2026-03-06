from sqlalchemy.orm import Session
from app.models import Processo, Movimento, ProcessoParte


SCHEMA_BUSCAR_PROCESSO = {
    "name": "buscar_processo",
    "description": "Busca dados completos de um processo judicial pelo numero CNJ. Retorna tribunal, classe, orgao julgador, partes e status.",
    "input_schema": {
        "type": "object",
        "properties": {
            "cnj": {
                "type": "string",
                "description": "Numero CNJ no formato NNNNNNN-DD.AAAA.J.TT.OOOO",
            },
        },
        "required": ["cnj"],
    },
}


def executar_buscar_processo(input_data: dict, db: Session) -> str:
    cnj = input_data.get("cnj", "").strip()
    if not cnj:
        return "Numero CNJ nao informado."
    processo = db.query(Processo).filter(Processo.cnj == cnj).first()
    if not processo:
        return f"Processo com CNJ {cnj} nao encontrado no sistema."

    partes = (
        db.query(ProcessoParte)
        .filter(ProcessoParte.processo_id == processo.id)
        .all()
    )

    linhas = [
        f"PROCESSO: {processo.cnj}",
        f"Tribunal: {processo.tribunal} ({processo.alias_tribunal})",
        f"Classe: {processo.classe_nome or 'N/A'}",
        f"Orgao Julgador: {processo.orgao_julgador or 'N/A'}",
        f"Grau: {processo.grau or 'N/A'}",
        f"Status: {processo.status}",
    ]
    if processo.data_ajuizamento:
        linhas.append(f"Ajuizamento: {processo.data_ajuizamento.strftime('%d/%m/%Y')}")

    if partes:
        linhas.append("")
        linhas.append("PARTES:")
        for p in partes:
            if p.cliente:
                linhas.append(f"  {p.papel.upper()}: {p.cliente.nome} (CPF/CNPJ: {p.cliente.cpf_cnpj})")
            else:
                linhas.append(f"  {p.papel.upper()}: (cliente removido, ID {p.cliente_id})")

    return "\n".join(linhas)


SCHEMA_LISTAR_MOVIMENTOS = {
    "name": "listar_movimentos",
    "description": "Lista os ultimos movimentos/andamentos de um processo. Retorna data, nome e resumo IA de cada movimento.",
    "input_schema": {
        "type": "object",
        "properties": {
            "processo_id": {
                "type": "integer",
                "description": "ID do processo no sistema",
            },
            "limite": {
                "type": "integer",
                "description": "Quantidade maxima de movimentos (padrao 20)",
            },
        },
        "required": ["processo_id"],
    },
}


def executar_listar_movimentos(input_data: dict, db: Session) -> str:
    processo_id = input_data.get("processo_id")
    if processo_id is None:
        return "Campo obrigatorio 'processo_id' nao informado."
    try:
        processo_id = int(processo_id)
    except (TypeError, ValueError):
        return "Campo 'processo_id' deve ser um numero inteiro."
    limite = min(max(int(input_data.get("limite", 20)), 1), 100)

    movimentos = (
        db.query(Movimento)
        .filter(Movimento.processo_id == processo_id)
        .order_by(Movimento.data_hora.desc())
        .limit(limite)
        .all()
    )

    if not movimentos:
        return f"Nenhum movimento encontrado para o processo ID {processo_id}."

    linhas = [f"MOVIMENTOS DO PROCESSO (ultimos {len(movimentos)}):"]
    for m in movimentos:
        data_str = m.data_hora.strftime("%d/%m/%Y %H:%M")
        linhas.append(f"  [{data_str}] {m.nome}")
        if m.resumo_ia:
            linhas.append(f"    Resumo: {m.resumo_ia}")

    return "\n".join(linhas)
