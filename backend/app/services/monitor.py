import logging
import time
from datetime import datetime, timezone

from sqlalchemy.orm import Session

from app.models import Processo, Movimento, ProcessoParte, Cliente
from app.services.datajud import consultar_processo
from app.services.ia import traduzir_movimento
from app.services.whatsapp import enviar_mensagem, formatar_notificacao
from app.services.metrics import (
    datajud_consultas,
    movimentos_novos,
    whatsapp_notificacoes,
    processos_monitorados,
    task_duration,
    task_success,
    task_errors,
)
from app.database import SessionLocal

logger = logging.getLogger(__name__)

PAPEIS_NOTIFICAVEIS = ["autor", "advogado"]


def verificar_processo(db: Session, processo: Processo) -> list[Movimento]:
    """Consulta DataJud e salva movimentos novos para o processo."""
    tribunal = processo.alias_tribunal or "desconhecido"
    try:
        dados = consultar_processo(processo.numero_limpo, processo.alias_tribunal)
        datajud_consultas.labels(tribunal=tribunal, status="sucesso").inc()
    except Exception:
        datajud_consultas.labels(tribunal=tribunal, status="erro").inc()
        raise
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

    # Registrar metricas de movimentos novos detectados
    if novos:
        movimentos_novos.inc(len(novos))

    # Notificar clientes do escritorio via WhatsApp (apenas autor/advogado)
    if novos:
        partes = (
            db.query(Cliente)
            .join(ProcessoParte, ProcessoParte.cliente_id == Cliente.id)
            .filter(
                ProcessoParte.processo_id == processo.id,
                ProcessoParte.papel.in_(PAPEIS_NOTIFICAVEIS),
            )
            .all()
        )
        for mov in novos:
            msg = formatar_notificacao(processo.cnj, mov.resumo_ia or mov.nome)
            enviou = False
            for cliente in partes:
                if not cliente.telefone:
                    continue
                try:
                    if enviar_mensagem(cliente.telefone, msg):
                        enviou = True
                        whatsapp_notificacoes.labels(status="sucesso").inc()
                    else:
                        whatsapp_notificacoes.labels(status="erro").inc()
                except Exception:
                    whatsapp_notificacoes.labels(status="erro").inc()
                    logger.warning(
                        "Falha ao enviar WhatsApp para %s (processo %s)",
                        cliente.telefone, processo.cnj, exc_info=True,
                    )
            mov.notificado = enviou or not partes

    processo.ultima_verificacao = datetime.now(timezone.utc)
    db.commit()
    return novos


def monitorar_todos() -> str:
    """Task Celery: verifica todos os processos ativos."""
    nome_task = "monitorar_todos"
    inicio = time.monotonic()
    db = SessionLocal()
    try:
        processos = db.query(Processo).filter(Processo.status == "ativo").all()
        processos_monitorados.set(len(processos))
        total_novos = 0
        for proc in processos:
            novos = verificar_processo(db, proc)
            total_novos += len(novos)
        task_success.labels(task_name=nome_task).inc()
        return f"Verificados {len(processos)} processos, {total_novos} movimentos novos."
    except Exception:
        task_errors.labels(task_name=nome_task).inc()
        raise
    finally:
        task_duration.labels(task_name=nome_task).observe(time.monotonic() - inicio)
        db.close()


# Registrar como task Celery (import condicional para nao quebrar testes)
try:
    from app.worker import celery_app
    monitorar_todos = celery_app.task(name="app.services.monitor.monitorar_todos")(monitorar_todos)
except Exception:
    pass
