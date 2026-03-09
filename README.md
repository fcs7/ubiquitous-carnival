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
- **Dashboard com status em tempo real** — verifica saude do banco, APIs, Drive, Vindi e agentes

---

## Guia de Instalacao

### 1. Pre-requisitos

- **Git** instalado
- **Docker** e **Docker Compose** (v2+)
- **Python 3.14+** (para desenvolvimento local sem Docker)
- Uma conta no **Google Cloud** (para integracao Google Drive)
- Chave da **Anthropic API** (obrigatoria para o assistente IA)

### 2. Clonar o repositorio

```bash
git clone <url-do-repo>
cd Muglia
```

### 3. Configurar variaveis de ambiente

```bash
cd backend
cp .env.example .env
```

Edite o `.env` com seus dados:

```env
# ── Obrigatorias ──────────────────────────────
DATABASE_URL=postgresql://muglia:muglia@localhost:5432/muglia
ANTHROPIC_API_KEY=sk-ant-sua-chave-aqui

# ── Opcionais ─────────────────────────────────
OPENAI_API_KEY=sk-sua-chave-aqui
VINDI_WEBHOOK_SECRET=seu_secret_hmac
VINDI_API_KEY=sua_api_key
GOOGLE_CREDENTIALS_PATH=/run/secrets/google_credentials.json
GOOGLE_DRIVE_ROOT_FOLDER_ID=id_da_pasta_raiz
```

> Para obter a `ANTHROPIC_API_KEY`: acesse https://console.anthropic.com/settings/keys

### 4. Configurar Google Drive (passo a passo)

O sistema usa uma **Service Account** do Google para acessar o Drive sem login manual. Siga todos os passos:

#### 4.1. Criar projeto no Google Cloud

1. Acesse https://console.cloud.google.com/
2. Clique em **Selecionar projeto** (topo da pagina) > **Novo projeto**
3. Nome: `Muglia` (ou qualquer nome)
4. Clique em **Criar**
5. Selecione o projeto recem-criado

#### 4.2. Ativar a Google Drive API

1. No menu lateral: **APIs e servicos** > **Biblioteca**
2. Pesquise por **Google Drive API**
3. Clique no resultado e depois em **Ativar**

#### 4.3. Criar Service Account

1. No menu lateral: **IAM e administracao** > **Contas de servico**
2. Clique em **Criar conta de servico**
3. Preencha:
   - **Nome**: `muglia-drive`
   - **ID**: sera preenchido automaticamente
   - **Descricao**: `Acesso ao Drive para o sistema Muglia`
4. Clique em **Criar e continuar**
5. Em **Papeis**: pule (nao precisa de papel no projeto)
6. Clique em **Concluir**

#### 4.4. Gerar chave JSON

1. Na lista de contas de servico, clique no email da conta recem-criada (ex: `muglia-drive@muglia-123.iam.gserviceaccount.com`)
2. Va na aba **Chaves**
3. Clique em **Adicionar chave** > **Criar nova chave**
4. Selecione **JSON** e clique em **Criar**
5. O arquivo `credentials.json` sera baixado automaticamente
6. **Guarde este arquivo com seguranca** — ele da acesso ao Drive

#### 4.5. Posicionar o arquivo de credenciais

```bash
# Na raiz do projeto
mkdir -p secrets
mv ~/Downloads/*.json secrets/google_credentials.json
```

> O `docker-compose.yml` ja monta este arquivo em `/run/secrets/google_credentials.json` dentro do container.

> Para desenvolvimento local (sem Docker), ajuste `GOOGLE_CREDENTIALS_PATH` no `.env` para o caminho absoluto do arquivo:
> ```env
> GOOGLE_CREDENTIALS_PATH=/home/seu-usuario/Muglia/secrets/google_credentials.json
> ```

#### 4.6. Compartilhar pasta do Drive com a Service Account

1. Abra o **Google Drive** (https://drive.google.com) com a conta que tem os documentos do escritorio
2. Crie uma pasta raiz (ex: `Muglia Documentos`) ou use uma existente
3. Clique com botao direito na pasta > **Compartilhar**
4. Cole o **email da Service Account** (ex: `muglia-drive@muglia-123.iam.gserviceaccount.com`)
5. Permissao: **Editor**
6. Desmarque "Notificar pessoas" e clique em **Compartilhar**

#### 4.7. Obter o ID da pasta raiz

1. Abra a pasta no Google Drive
2. O ID esta na URL: `https://drive.google.com/drive/folders/ESTE_E_O_ID`
3. Copie o ID e coloque no `.env`:

```env
GOOGLE_DRIVE_ROOT_FOLDER_ID=1AbCdEfGhIjKlMnOpQrStUvWxYz
```

> **Seguranca**: o sistema valida que toda operacao esta dentro desta pasta raiz. Zero operacoes de delete sao permitidas.

### 5. Subir com Docker (recomendado)

```bash
cd Muglia  # raiz do projeto

# Subir tudo (banco + backend + frontend)
docker compose up -d --build

# Verificar se subiu
docker compose ps

# Ver logs do backend
docker compose logs backend -f
```

Acesse:
- **Frontend**: http://localhost:3000
- **API docs**: http://localhost:8000/docs
- **Health check**: http://localhost:8000/health
- **Status do sistema**: http://localhost:8000/api/status

### 6. Desenvolvimento local (sem Docker)

```bash
# Subir apenas o banco via Docker
docker compose up db -d

# Configurar backend
cd backend
python -m venv .venv
.venv/bin/pip install -r requirements.txt

# Rodar servidor dev (recarrega automaticamente)
.venv/bin/uvicorn app.main:app --reload
```

API docs: http://localhost:8000/docs

### 7. Verificar instalacao

Apos subir o sistema, acesse http://localhost:8000/api/status para verificar:

```json
{
  "status": "ok",
  "servicos": [
    {"nome": "PostgreSQL", "status": "ok"},
    {"nome": "Anthropic API", "status": "ok"},
    {"nome": "Google Drive", "status": "ok"},
    {"nome": "Agentes IA", "status": "ok", "detalhes": "1 ativo(s)"}
  ]
}
```

Se algum servico aparece com `"status": "erro"`, verifique a configuracao correspondente no `.env`.

---

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
  main.py                 # FastAPI app + CORS
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

---

## Configuracao Vindi

1. Adicione `VINDI_WEBHOOK_SECRET` e `VINDI_API_KEY` ao `.env`
2. Na dashboard Vindi: **Configuracoes** > **Webhooks**
3. URL: `https://seu-dominio.com/webhooks/vindi`
4. Eventos: `customer_created`, `customer_updated`, `bill_created`, `bill_paid`, `bill_canceled`, `subscription_created`, `subscription_canceled`, `charge_rejected`

---

## Troubleshooting

| Problema | Solucao |
|----------|---------|
| `GET /api/status` mostra PostgreSQL erro | Verifique se o container `db` esta rodando: `docker compose ps` |
| Google Drive com status erro | Verifique se `secrets/google_credentials.json` existe e se a pasta foi compartilhada com a Service Account |
| Anthropic API com status erro | Verifique `ANTHROPIC_API_KEY` no `.env` — obtenha em https://console.anthropic.com/settings/keys |
| Frontend nao carrega dados | Verifique se o backend esta rodando: `curl http://localhost:8000/health` |
| Agentes IA com status erro | O agente padrao e criado automaticamente na primeira execucao — verifique logs: `docker compose logs backend` |
