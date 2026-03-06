# Muglia — Sistema Juridico

Sistema interno do escritorio Muglia para gestao de processos judiciais, clientes, financeiro e comunicacao.

## O que faz

- Monitora ~1000 processos via API DataJud (CNJ) diariamente
- Traduz andamentos juridicos para linguagem simples com IA
- Notifica clientes por WhatsApp automaticamente
- Chat juridico com Claude API para gerar documentos
- Recebe cobranças do Vindi via webhook e vincula ao financeiro
- Sistema de tags para organizar qualquer entidade

## Stack

| Camada | Tecnologia |
|--------|-----------|
| Backend | FastAPI + Python 3.14 |
| Banco | PostgreSQL 17 |
| Fila | Celery + Redis |
| IA | Claude API (chat/docs) + OpenAI gpt-4o-mini (traducao) |
| WhatsApp | Evolution API |
| Cobranças | Vindi (webhooks) |
| Frontend | Flutter (web + mobile) |
| Deploy | Docker Compose |

## Estrutura

```
backend/
  app/
    main.py              # FastAPI app, registra routers
    models.py            # 17 models SQLAlchemy
    schemas.py           # Pydantic schemas (entrada/saida)
    database.py          # Engine, session, get_db
    config.py            # Variaveis de ambiente
    routers/
      clientes.py        # CRUD clientes
      processos.py       # CRUD processos + consulta DataJud
      financeiro.py      # Lancamentos financeiros
      prazos.py          # Prazos processuais
      chat.py            # Chat juridico com Claude
      vindi_webhook.py   # Recebe webhooks do Vindi
      vindi.py           # Gestao Vindi (vincular, listar)
      tags.py            # Tags polimoricas
    services/
      datajud.py         # Consulta API DataJud (90+ tribunais)
      monitor.py         # Celery task: monitoramento diario
      ia.py              # Traducao de andamentos (OpenAI)
      claude_chat.py     # Chat juridico (Claude API)
      whatsapp.py        # Notificacoes WhatsApp (Evolution)
      vindi.py           # Processamento webhooks Vindi
  tests/                 # Testes automatizados
  Dockerfile
  requirements.txt
frontend/                # Flutter app (web + mobile)
docker-compose.yml       # Sobe tudo com um comando
```

---

## Desenvolvimento local

### Pre-requisitos

- Python 3.14+
- Docker e Docker Compose
- Git

### 1. Clonar o repositorio

```bash
git clone <url-do-repo>
cd Muglia
```

### 2. Subir banco e Redis

```bash
docker compose up db redis -d
```

Isso inicia:
- PostgreSQL na porta 5432 (usuario: `muglia`, senha: `muglia`, banco: `muglia`)
- Redis na porta 6379

### 3. Configurar o backend

```bash
cd backend

# Criar ambiente virtual
python -m venv .venv

# Ativar (Linux/Mac)
source .venv/bin/activate

# Instalar dependencias
pip install -r requirements.txt
```

### 4. Criar arquivo .env

```bash
cp .env.example .env   # ou crie manualmente
```

Conteudo minimo do `.env`:

```env
DATABASE_URL=postgresql://muglia:muglia@localhost:5432/muglia
REDIS_URL=redis://localhost:6379/0
ANTHROPIC_API_KEY=sua_chave_aqui
OPENAI_API_KEY=sua_chave_aqui
```

Variaveis opcionais:

```env
# WhatsApp (Evolution API)
EVOLUTION_API_URL=http://localhost:8080
EVOLUTION_API_KEY=sua_chave

# Vindi (cobranças)
VINDI_WEBHOOK_SECRET=seu_secret_hmac
VINDI_API_KEY=sua_api_key

# DataJud (ja tem default no codigo)
DATAJUD_API_KEY=chave_publica_cnj
```

### 5. Rodar o servidor

```bash
.venv/bin/uvicorn app.main:app --reload
```

O servidor sobe em `http://localhost:8000`. As tabelas do banco sao criadas automaticamente no startup.

- Documentacao da API: `http://localhost:8000/docs`
- Health check: `http://localhost:8000/health`

### 6. Rodar com Docker Compose (tudo junto)

Se preferir subir tudo de uma vez (backend + banco + redis + worker):

```bash
# Na raiz do projeto
docker compose up -d --build
```

---

## Testes

Os testes usam SQLite em memoria — nao precisam de banco externo.

```bash
cd backend

# Rodar todos os testes
.venv/bin/python -m pytest tests/ -v

# Rodar um arquivo especifico
.venv/bin/python -m pytest tests/test_tags.py -v

# Rodar um teste especifico
.venv/bin/python -m pytest tests/test_vindi_webhook.py::test_bill_paid -v
```

Atualmente: **70 testes passando**.

---

## Endpoints principais

### Clientes
- `POST /clientes/` — criar cliente
- `GET /clientes/` — listar clientes
- `GET /clientes/{id}` — detalhe do cliente

### Processos
- `POST /processos/` — cadastrar processo (consulta DataJud automaticamente)
- `GET /processos/` — listar processos (filtro por status, busca por CNJ)
- `GET /processos/{id}` — detalhe com partes e movimentos

### Financeiro
- `POST /financeiro/` — criar lancamento
- `GET /financeiro/` — listar lancamentos (filtro por status)
- `GET /financeiro/resumo` — totais (pendente, pago, total)

### Prazos
- `POST /prazos/` — criar prazo
- `GET /prazos/` — listar prazos

### Chat Juridico
- `POST /conversas/` — criar conversa
- `POST /conversas/{id}/mensagens` — enviar mensagem (resposta via Claude API)

### Vindi (cobranças)
- `POST /webhooks/vindi` — recebe webhooks do Vindi
- `GET /vindi/customers` — listar customers do Vindi
- `POST /vindi/customers/{id}/vincular` — vincular customer a cliente
- `POST /vindi/subscriptions/{id}/vincular` — vincular subscription a processo
- `GET /vindi/bills` — listar bills

### Tags
- `POST /tags/` — criar tag
- `GET /tags/` — listar tags
- `POST /tags/aplicar` — aplicar tag a qualquer entidade
- `GET /tags/entidade/{tipo}/{id}` — listar tags de uma entidade

---

## Configuracao Vindi

Para receber webhooks do Vindi:

1. Adicione `VINDI_WEBHOOK_SECRET` ao `.env`
2. Na dashboard do Vindi, va em Configuracoes > Webhooks
3. URL: `https://seu-dominio.com/webhooks/vindi`
4. Eventos: `customer_created`, `customer_updated`, `bill_created`, `bill_paid`, `bill_canceled`, `subscription_created`, `subscription_canceled`, `charge_rejected`
5. Copie o Secret e coloque em `VINDI_WEBHOOK_SECRET`

### Fluxo Vindi

1. Vindi envia webhook → dados salvos em tabelas espelho (`vindi_customers`, `vindi_bills`, etc.)
2. Usuario vincula `vindi_customer` a um `cliente` do Muglia
3. Usuario vincula `vindi_subscription` a um `processo`
4. Quando ambos estao vinculados, novas bills geram lancamentos em `financeiro` automaticamente
5. Quando bill e paga no Vindi, o lancamento financeiro e atualizado para "pago"

---

## Monitoramento de processos

O worker Celery roda diariamente as 7h:

1. Consulta todos os processos ativos na API DataJud
2. Detecta novos movimentos (compara por codigo + data/hora)
3. Traduz os andamentos para linguagem simples (OpenAI)
4. Notifica os clientes por WhatsApp (Evolution API)

Para rodar o worker manualmente:

```bash
cd backend
.venv/bin/celery -A app.worker worker --loglevel=info
.venv/bin/celery -A app.worker beat --loglevel=info
```
