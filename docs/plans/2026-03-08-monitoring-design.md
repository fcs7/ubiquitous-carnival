# Monitoramento Muglia — Design

## Decisoes

- Stack: Prometheus + Grafana + Alertmanager + cAdvisor + postgres-exporter + redis-exporter
- Alertas via WhatsApp (Evolution API ja existente)
- Instrumentacao FastAPI com prometheus-fastapi-instrumentator
- Instrumentacao Celery com prometheus-client (metricas de negocio)
- Grafana com dashboards pre-provisionados (zero config manual)
- Grafana na porta 3001 (frontend usa 3000)

## Arquitetura

### Novos containers (6)

| Servico           | Imagem                              | Porta  | Funcao                           |
|-------------------|-------------------------------------|--------|----------------------------------|
| prometheus        | prom/prometheus:latest              | 9090   | Coleta metricas                  |
| grafana           | grafana/grafana:latest              | 3001   | Dashboards                       |
| alertmanager      | prom/alertmanager:latest            | 9093   | Gerencia alertas                 |
| postgres-exporter | prometheuscommunity/postgres-exporter| 9187  | Metricas PostgreSQL              |
| redis-exporter    | oliver006/redis_exporter:latest     | 9121   | Metricas Redis                   |
| cadvisor          | gcr.io/cadvisor/cadvisor:latest     | 8081   | Metricas containers (CPU/mem)    |

### Instrumentacao do backend

- `prometheus-fastapi-instrumentator` — auto-metricas em todos endpoints (latencia, requests/s, erros)
- Endpoint `/metrics` exposto automaticamente
- Metricas custom: `muglia_processos_monitorados_total`, `muglia_movimentos_novos_total`

### Instrumentacao do Celery worker

- `prometheus-client` com HTTP server na porta 9100
- Metricas: `muglia_task_duration_seconds`, `muglia_task_errors_total`, `muglia_task_success_total`
- Metricas de negocio: `muglia_datajud_consultas_total`, `muglia_whatsapp_notificacoes_total`

### Alertas

Regras criticas:
- Servico down (backend, worker, evolution) > 1min
- Error rate backend > 10% por 5min
- Celery task failures > 5 em 10min
- Postgres connections > 80%
- Redis memory > 80%
- Container restart loop (> 3 restarts em 10min)
- Disk usage > 85%

### Webhook bridge (alertas → WhatsApp)

Endpoint novo no backend: `POST /webhooks/alertmanager`
- Recebe payload do Alertmanager
- Formata mensagem legivel
- Envia via Evolution API para numero configurado em .env (ALERT_WHATSAPP_NUMBER)

### Grafana Dashboards (4)

1. **Muglia Overview** — status geral, uptime, requests/s, erros, tasks celery
2. **FastAPI** — latencia por endpoint, error rate, requests por metodo
3. **Infraestrutura** — CPU, memoria, rede, disco por container (cAdvisor)
4. **Banco de Dados** — Postgres connections, queries, Redis keys, memory

### Arquivos a criar

```
monitoring/
  prometheus/
    prometheus.yml          # Config + scrape targets
    alerts.yml              # Regras de alerta
  alertmanager/
    alertmanager.yml        # Config + webhook receiver
  grafana/
    provisioning/
      datasources/
        prometheus.yml      # Datasource automatico
      dashboards/
        dashboards.yml      # Provisioning config
    dashboards/
      muglia-overview.json  # Dashboard geral
      fastapi.json          # Dashboard FastAPI
      infra.json            # Dashboard infra/cAdvisor
      database.json         # Dashboard Postgres + Redis
```

### Arquivos a modificar

- `docker-compose.yml` — adicionar 6 servicos + volumes
- `backend/requirements.txt` — adicionar prometheus-fastapi-instrumentator, prometheus-client
- `backend/app/main.py` — adicionar instrumentacao Prometheus
- `backend/app/worker.py` — adicionar metricas Celery (ou criar modulo metricas)
- Novo router: `backend/app/routers/webhooks.py` — endpoint alertmanager

## Plano de implementacao

### Task 1: Configs de monitoramento (independente)
Criar toda a arvore monitoring/ com prometheus.yml, alerts.yml, alertmanager.yml, grafana provisioning

### Task 2: Instrumentar FastAPI (independente)
Adicionar prometheus-fastapi-instrumentator no requirements e main.py

### Task 3: Instrumentar Celery worker (independente)
Adicionar prometheus-client, criar modulo de metricas, expor /metrics no worker

### Task 4: Dashboards Grafana (independente)
Criar os 4 dashboards JSON pre-provisionados

### Task 5: Webhook alertmanager → WhatsApp (independente)
Criar router webhooks.py no backend

### Task 6: Atualizar docker-compose.yml (depende de 1-5)
Adicionar todos os servicos novos, volumes, redes

### Task 7: Teste e verificacao (depende de 6)
docker compose config, testes unitarios do webhook
