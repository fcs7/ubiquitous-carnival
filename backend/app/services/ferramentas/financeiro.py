from sqlalchemy.orm import Session
from app.models import Financeiro


SCHEMA_RESUMO_FINANCEIRO = {
    "name": "resumo_financeiro",
    "description": "Resume a posicao financeira de um processo especifico. Mostra totais pendentes, pagos e lancamentos detalhados.",
    "input_schema": {
        "type": "object",
        "properties": {
            "processo_id": {
                "type": "integer",
                "description": "ID do processo",
            },
        },
        "required": ["processo_id"],
    },
}


def executar_resumo_financeiro(input_data: dict, db: Session) -> str:
    processo_id = input_data["processo_id"]

    lancamentos = (
        db.query(Financeiro)
        .filter(Financeiro.processo_id == processo_id)
        .order_by(Financeiro.data_vencimento)
        .all()
    )

    if not lancamentos:
        return f"Nenhum lancamento financeiro para o processo ID {processo_id}."

    total_pendente = sum(float(f.valor) for f in lancamentos if f.status == "pendente")
    total_pago = sum(float(f.valor) for f in lancamentos if f.status == "pago")

    linhas = [
        f"FINANCEIRO DO PROCESSO #{processo_id}:",
        f"  Total pendente: R$ {total_pendente:,.2f}",
        f"  Total pago: R$ {total_pago:,.2f}",
        f"  Total geral: R$ {total_pendente + total_pago:,.2f}",
        "",
        "LANCAMENTOS:",
    ]
    for f in lancamentos:
        venc = f.data_vencimento.strftime("%d/%m/%Y") if f.data_vencimento else "S/D"
        linhas.append(f"  [{f.status.upper()}] {f.tipo} — R$ {float(f.valor):,.2f} — Venc: {venc} — {f.descricao or ''}")

    return "\n".join(linhas)
