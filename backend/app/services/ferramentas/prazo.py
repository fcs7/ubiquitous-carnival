from datetime import date, timedelta
from sqlalchemy.orm import Session
from app.models import Prazo


SCHEMA_CALCULAR_PRAZO = {
    "name": "calcular_prazo",
    "description": "Calcula prazo processual em dias uteis a partir de uma data. Considera finais de semana (nao considera feriados).",
    "input_schema": {
        "type": "object",
        "properties": {
            "data_inicio": {
                "type": "string",
                "description": "Data de inicio no formato AAAA-MM-DD",
            },
            "dias": {
                "type": "integer",
                "description": "Quantidade de dias do prazo",
            },
            "tipo": {
                "type": "string",
                "enum": ["uteis", "corridos"],
                "description": "Tipo do prazo: uteis ou corridos (padrao: uteis)",
            },
        },
        "required": ["data_inicio", "dias"],
    },
}


def _dia_semana(d: date) -> str:
    nomes = ["segunda", "terca", "quarta", "quinta", "sexta", "sabado", "domingo"]
    return nomes[d.weekday()]


def executar_calcular_prazo(input_data: dict, db: Session) -> str:
    try:
        data_inicio = date.fromisoformat(input_data["data_inicio"])
    except (ValueError, KeyError):
        return "Data de inicio invalida. Use formato AAAA-MM-DD."

    dias = input_data.get("dias", 15)
    if not isinstance(dias, int) or dias <= 0:
        return "Numero de dias deve ser um inteiro positivo."

    tipo = input_data.get("tipo", "uteis")

    if tipo == "corridos":
        data_final = data_inicio + timedelta(days=dias)
    else:
        # Ajusta data de inicio para proximo dia util (CPC art. 224)
        data_inicio_efetiva = data_inicio
        while data_inicio_efetiva.weekday() >= 5:
            data_inicio_efetiva += timedelta(days=1)

        dias_contados = 0
        data_final = data_inicio_efetiva
        while dias_contados < dias:
            data_final += timedelta(days=1)
            if data_final.weekday() < 5:
                dias_contados += 1

    resultado = (
        f"CALCULO DE PRAZO:\n"
        f"  Inicio: {data_inicio.strftime('%d/%m/%Y')} ({_dia_semana(data_inicio)})\n"
    )
    if tipo == "uteis" and data_inicio != data_inicio_efetiva:
        resultado += f"  Inicio efetivo (proximo dia util): {data_inicio_efetiva.strftime('%d/%m/%Y')} ({_dia_semana(data_inicio_efetiva)})\n"
    resultado += (
        f"  Prazo: {dias} dias {tipo}\n"
        f"  Vencimento: {data_final.strftime('%d/%m/%Y')} ({_dia_semana(data_final)})\n"
        f"  Nota: calculo nao considera feriados"
    )
    return resultado


SCHEMA_LISTAR_PRAZOS = {
    "name": "listar_prazos",
    "description": "Lista prazos pendentes de um processo ou todos os prazos pendentes do escritorio.",
    "input_schema": {
        "type": "object",
        "properties": {
            "processo_id": {
                "type": "integer",
                "description": "ID do processo (opcional — se omitido, lista todos os prazos pendentes)",
            },
        },
    },
}


def executar_listar_prazos(input_data: dict, db: Session) -> str:
    q = db.query(Prazo).filter(Prazo.status == "pendente")
    processo_id = input_data.get("processo_id")
    if processo_id:
        q = q.filter(Prazo.processo_id == processo_id)

    prazos = q.order_by(Prazo.data_limite).limit(20).all()

    if not prazos:
        return "Nenhum prazo pendente encontrado."

    linhas = [f"PRAZOS PENDENTES ({len(prazos)}):"]
    for p in prazos:
        venc = p.data_limite.strftime("%d/%m/%Y")
        dias_restantes = (p.data_limite - date.today()).days
        urgencia = "VENCIDO" if dias_restantes < 0 else f"{dias_restantes}d restantes"
        linhas.append(f"  [{venc}] {p.tipo} — {p.descricao or 'Sem descricao'} ({urgencia})")

    return "\n".join(linhas)
