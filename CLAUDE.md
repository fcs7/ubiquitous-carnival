# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Muglia is an internal legal management system for a Brazilian law firm focused on **AI-powered legal assistants**. It manages clients, judicial processes, financial records (Vindi integration), documents (Google Drive), and provides configurable AI agents (Claude/OpenAI) for legal document generation and consultations.

## Commands

### Backend (FastAPI)

```bash
# Run all tests (from backend/)
cd backend && .venv/bin/python -m pytest tests/ -v

# Run single test file
.venv/bin/python -m pytest tests/test_api_clientes.py -v

# Run single test
.venv/bin/python -m pytest tests/test_api_clientes.py::test_criar_cliente -v

# Install dependencies
cd backend && python -m venv .venv && .venv/bin/pip install -r requirements.txt

# Run dev server (requires PostgreSQL via Docker)
docker compose up db -d
.venv/bin/uvicorn app.main:app --reload

# Run everything
docker compose up -d --build
```

### Frontend (Flutter) — NOT YET SET UP

```bash
cd frontend && flutter pub get
flutter run -d chrome    # web
flutter run              # mobile
```

## Architecture

**Backend** (`backend/app/`):
- `main.py` — FastAPI app, registers all routers, creates tables on startup
- `models.py` — SQLAlchemy models (Usuario, Cliente, Processo, ProcessoParte, Movimento, Prazo, Financeiro, Documento, Conversa, Mensagem, ConfigEscritorio, Vindi*, AgenteConfig, ToolExecution)
- `database.py` — engine, session factory, `get_db` dependency
- `config.py` — pydantic-settings `Settings` class, reads from `.env`

**Services** (`backend/app/services/`):
- `claude_chat.py` — orchestrates Claude API calls with layered system prompts (legal context + office config + process data + conversation history)
- `agente_chat.py` — configurable AI agent with tool-calling loop, memory, and streaming
- `assistente.py` — unified assistant endpoint (auto-creates agent + conversation)
- `vindi.py` — Vindi webhook handlers for syncing customers, subscriptions, bills -> Financeiro
- `google_drive.py` — Google Drive integration for document management
- `ferramentas/` — AI agent tools: buscar_processo, listar_movimentos, buscar_cliente, calcular_prazo, listar_prazos, resumo_financeiro, listar_documentos_processo

**Routers** (`backend/app/routers/`): agentes, assistente, chat, clientes, documentos, financeiro, prazos, processos, vindi, vindi_webhook

**Tests** (`backend/tests/`):
- `conftest.py` provides shared SQLite in-memory engine with `client` and `db` fixtures
- API tests use `client` fixture (TestClient), service tests create their own sessions
- Claude API calls are always mocked in tests

## Key Patterns

- CNJ format: `NNNNNNN-DD.AAAA.J.TT.OOOO` where `J.TT` identifies the tribunal
- `parse_cnj()` and `TRIBUNAL_MAP` are in `routers/processos.py` (90+ tribunals)
- `Movimento` has `UniqueConstraint("processo_id", "codigo", "data_hora")` to prevent duplicates
- `Financeiro` links to both `processo_id` AND `cliente_id` (who pays)
- Vindi webhook auto-creates `Financeiro` when customer+subscription are linked
- Backend uses venv at `backend/.venv` (Arch Linux requires this)
- Always run git commands from project root `/home/fcs/Documents/Muglia/`, not from `backend/`
- All test files must use shared `conftest.py` fixtures (`client`, `db`) — never create per-file engines
- `datetime.utcnow()` is deprecated in Python 3.14 — use `datetime.now(UTC)` in new code
- Flutter is NOT installed yet — install before frontend tasks: `sudo snap install flutter --classic`
- Custom dev agents available in `.claude/agents/` (backend, frontend, juridico, devops, testes)

## Removed Features

DataJud monitoring, Celery/Redis workers, WhatsApp/Evolution notifications, Prometheus/Grafana metrics, and Tags were removed. Process data is now managed manually + via Vindi sync.

## Language

All code comments, variable names, API responses, and user-facing text are in Brazilian Portuguese.
