from celery import Celery
from celery.schedules import crontab
from celery.signals import worker_init
from app.config import settings

celery_app = Celery("muglia", broker=settings.redis_url)

celery_app.conf.beat_schedule = {
    "monitorar-processos": {
        "task": "app.services.monitor.monitorar_todos",
        "schedule": crontab(hour=7, minute=0),
    },
}

celery_app.autodiscover_tasks(["app.services"])


@worker_init.connect
def setup_metricas(**kwargs):
    """Inicia servidor Prometheus ao inicializar o worker Celery."""
    from app.services.metrics import iniciar_servidor_metricas
    iniciar_servidor_metricas()
