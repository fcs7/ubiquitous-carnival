from datetime import datetime

from sqlalchemy.orm import Session

from app.models import Processo, Movimento
from app.services.datajud import consultar_processo
from app.services.ia import traduzir_movimento
from app.database import SessionLocal


def verificar_processo(db: Session, processo: Processo) -> list[Movimento]:
    """Consulta DataJud e salva movimentos novos para o processo."""
    dados = consultar_processo(processo.numero_limpo, processo.alias_tribunal)
    movimentos_api = dados.get("movimentos", [])

    # Set de (codigo, data_hora) ja existentes no banco
    existentes = {
        (m.codigo, m.data_hora)
        for m in db.query(Movimento.codigo, Movimento.data_hora)
        .filter(Movimento.processo_id == processo.id)
        .all()
    }

    novos: list[Movimento] = []
    for mov in movimentos_api:
        codigo = mov.get("codigo", 0)
        data_hora_str = mov.get("dataHora", "")
        # Converter ISO string para datetime
        try:
            data_hora = datetime.fromisoformat(data_hora_str)
        except (ValueError, TypeError):
            continue

        if (codigo, data_hora) in existentes:
            continue

        nome = mov.get("nome", "")
        complementos_list = mov.get("complementosTabelados", [])
        complementos = "; ".join(
            c.get("descricao", "") for c in complementos_list
        ) if complementos_list else ""

        resumo = traduzir_movimento(nome, complementos)

        movimento = Movimento(
            processo_id=processo.id,
            codigo=codigo,
            nome=nome,
            data_hora=data_hora,
            complementos=complementos or None,
            resumo_ia=resumo,
            notificado=False,
        )
        db.add(movimento)
        novos.append(movimento)

    processo.ultima_verificacao = datetime.utcnow()
    db.commit()
    return novos


def monitorar_todos() -> str:
    """Task Celery: verifica todos os processos ativos."""
    db = SessionLocal()
    try:
        processos = db.query(Processo).filter(Processo.status == "ativo").all()
        total_novos = 0
        for proc in processos:
            novos = verificar_processo(db, proc)
            total_novos += len(novos)
        return f"Verificados {len(processos)} processos, {total_novos} movimentos novos."
    finally:
        db.close()


# Registrar como task Celery (import condicional para nao quebrar testes)
try:
    from app.worker import celery_app
    monitorar_todos = celery_app.task(name="app.services.monitor.monitorar_todos")(monitorar_todos)
except Exception:
    pass
