"""Metricas Prometheus para o Celery worker do Muglia."""

from prometheus_client import Counter, Histogram, Gauge, start_http_server

# --- Metricas de tasks Celery ---

task_duration = Histogram(
    "muglia_task_duration_seconds",
    "Duracao das tasks Celery em segundos",
    ["task_name"],
)
task_success = Counter(
    "muglia_task_success_total",
    "Total de tasks executadas com sucesso",
    ["task_name"],
)
task_errors = Counter(
    "muglia_task_errors_total",
    "Total de tasks que falharam",
    ["task_name"],
)

# --- Metricas de negocio ---

datajud_consultas = Counter(
    "muglia_datajud_consultas_total",
    "Total de consultas ao DataJud",
    ["tribunal", "status"],  # status: sucesso/erro
)
movimentos_novos = Counter(
    "muglia_movimentos_novos_total",
    "Total de movimentos novos detectados",
)
whatsapp_notificacoes = Counter(
    "muglia_whatsapp_notificacoes_total",
    "Total de notificacoes WhatsApp enviadas",
    ["status"],  # status: sucesso/erro
)
processos_monitorados = Gauge(
    "muglia_processos_monitorados_total",
    "Numero total de processos sendo monitorados",
)


def iniciar_servidor_metricas(porta: int = 9100) -> None:
    """Inicia servidor HTTP para expor metricas na porta especificada."""
    start_http_server(porta)
