from celery import Celery
from celery.schedules import crontab
from app.config import settings

celery_app = Celery("muglia", broker=settings.redis_url)

celery_app.conf.beat_schedule = {
    "monitorar-processos": {
        "task": "app.services.monitor.monitorar_todos",
        "schedule": crontab(hour=7, minute=0),
    },
}

celery_app.autodiscover_tasks(["app.services"])
