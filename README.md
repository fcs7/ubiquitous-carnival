# Muglia — Escritorio Virtual Juridico

Sistema interno para o escritorio Muglia. Assistentes IA configuraveis para gerar documentos juridicos, consultar processos e buscar em PDFs. Integra com Google Drive (documentos) e Vindi (cobrancas).

## Stack

| Camada | Tecnologia |
|--------|-----------|
| Backend | FastAPI + Python 3.14 |
| Banco | PostgreSQL 17 |
| IA | Claude API + OpenAI gpt-4o-mini |
| Documentos | Google Drive API + PyMuPDF (extracao PDF) |
| Cobrancas | Vindi (webhooks) |
| Frontend | Flutter (web + mobile) |
| Deploy | Docker Compose |

## Funcionalidades

- **Assistentes IA configuraveis** — agentes com tool-calling, memoria e streaming
- **8 ferramentas IA**: buscar processo, listar movimentos, buscar cliente, calcular prazo, listar prazos, listar documentos, ler PDF, buscar em PDFs
- **Extracao de PDFs** — baixa PDFs do Google Drive, extrai texto com PyMuPDF, cache local inteligente
- **Google Drive** — organiza documentos por processo, busca, vincula arquivos
- **Vindi** — sincroniza customers, subscriptions e bills via webhook
- **Chat juridico** — system prompt com contexto do processo + config do escritorio

## Desenvolvimento local

### Pre-requisitos

- Python 3.14+
- Docker e Docker Compose

### Setup

```bash
git clone <url-do-repo>
cd Muglia

# Subir banco
docker compose up db -d

# Configurar backend
cd backend
python -m venv .venv
.venv/bin/pip install -r requirements.txt

# Criar .env
cp .env.example .env
```

Conteudo minimo do `.env`:

```env
DATABASE_URL=postgresql://muglia:muglia@localhost:5432/muglia
ANTHROPIC_API_KEY=sua_chave_aqui
```

Variaveis opcionais:

```env
OPENAI_API_KEY=sua_chave_aqui
VINDI_WEBHOOK_SECRET=seu_secret_hmac
VINDI_API_KEY=sua_api_key
GOOGLE_CREDENTIALS_PATH=/caminho/para/credentials.json
GOOGLE_DRIVE_ROOT_FOLDER_ID=id_da_pasta_raiz
```

### Rodar

```bash
# Servidor dev
.venv/bin/uvicorn app.main:app --reload

# Tudo via Docker
docker compose up -d --build
```

API docs: `http://localhost:8000/docs`

## Testes

SQLite em memoria — nao precisa de banco externo. **131 testes passando**.

```bash
cd backend

# Todos os testes
.venv/bin/python -m pytest tests/ -v

# Teste especifico
.venv/bin/python -m pytest tests/test_ferramentas.py::test_ler_documento_sucesso -v
```

## Estrutura

```
backend/app/
  main.py                 # FastAPI app
  models.py               # SQLAlchemy models
  config.py               # Settings (pydantic-settings)
  routers/
    assistente.py          # Endpoint unificado do assistente IA
    agentes.py             # CRUD agentes configuraveis
    chat.py                # Conversas e mensagens
    clientes.py            # CRUD clientes
    processos.py           # CRUD processos + parse CNJ (90+ tribunais)
    documentos.py          # Google Drive integration
    prazos.py              # Prazos processuais
    vindi.py               # Gestao Vindi (vincular, listar)
    vindi_webhook.py       # Recebe webhooks do Vindi
    status.py              # GET /api/status — saude do sistema e agentes
  services/
    agente_chat.py         # Motor do agente IA (tool-calling loop)
    assistente.py          # Auto-cria agente + conversa
    claude_chat.py         # Chat juridico (Claude API)
    google_drive.py        # Google Drive API (CRUD + download seguro)
    pdf_extractor.py       # Extracao de texto de PDFs + cache local
    vindi.py               # Processamento webhooks Vindi
    ferramentas/           # Ferramentas do agente IA
      processo.py          # buscar_processo, listar_movimentos
      cliente.py           # buscar_cliente
      prazo.py             # calcular_prazo, listar_prazos
      drive.py             # listar_documentos, ler_documento, buscar_em_documentos
backend/tests/             # 131 testes (SQLite in-memory)
frontend/                  # Flutter app (web + mobile)
```

## Endpoints principais

### Assistente IA
- `POST /assistente/mensagem` — envia mensagem ao assistente (auto-cria agente/conversa)
- `GET /assistente/historico` — historico de conversas

### Agentes
- `POST /agentes/` — criar agente configuravel
- `GET /agentes/ferramentas` — listar ferramentas disponiveis

### Clientes
- `POST /clientes/` — criar cliente
- `GET /clientes/` — listar (busca por nome/CPF)

### Processos
- `POST /processos/` — cadastrar processo (parse CNJ automatico)
- `GET /processos/` — listar (filtro por status, busca por CNJ)

### Documentos (Google Drive)
- `GET /documentos/drive/pasta/{id}` — listar pasta
- `POST /documentos/vincular` — vincular arquivo do Drive a processo
- `POST /documentos/organizar/{processo_id}` — montar pasta no Drive

### Status do Sistema
- `GET /api/status` — verifica saude do banco, API keys, Google Drive, Vindi e agentes ativos

### Vindi
- `POST /webhooks/vindi` — recebe webhooks
- `POST /vindi/customers/{id}/vincular` — vincular customer a cliente
- `POST /vindi/subscriptions/{id}/vincular` — vincular subscription a processo

## Configuracao Vindi

1. Adicione `VINDI_WEBHOOK_SECRET` ao `.env`
2. Na dashboard Vindi: Configuracoes > Webhooks
3. URL: `https://seu-dominio.com/webhooks/vindi`
4. Eventos: `customer_created`, `customer_updated`, `bill_created`, `bill_paid`, `bill_canceled`, `subscription_created`, `subscription_canceled`, `charge_rejected`

## Configuracao Google Drive

1. Crie uma Service Account no Google Cloud Console
2. Compartilhe a pasta raiz do Drive com o email da Service Account
3. Configure no `.env`:

```env
GOOGLE_CREDENTIALS_PATH=/caminho/para/credentials.json
GOOGLE_DRIVE_ROOT_FOLDER_ID=id_da_pasta_raiz
```

O sistema valida que toda operacao esta dentro da pasta raiz configurada. Zero operacoes de delete.
