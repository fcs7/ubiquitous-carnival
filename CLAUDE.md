# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Muglia is an internal legal management system for a Brazilian law firm. It monitors ~1000 judicial processes via the DataJud CNJ API, translates legal updates with AI, notifies clients via WhatsApp, and provides an AI-powered legal chat (Claude API) for document generation.

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

# Run dev server (requires PostgreSQL and Redis via Docker)
docker compose up db redis -d
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
- `models.py` — 11 SQLAlchemy models. Key relationship: `ProcessoParte` is a N:N junction table between `Processo` and `Cliente` with a `papel` field (autor/reu/advogado)
- `database.py` — engine, session factory, `get_db` dependency
- `config.py` — pydantic-settings `Settings` class, reads from `.env`

**Services** (`backend/app/services/`):
- `datajud.py` — `TRIBUNAL_MAP` (90+ tribunals), `parse_cnj()` extracts tribunal from CNJ number, `consultar_processo()` queries DataJud Elasticsearch API
- `claude_chat.py` — orchestrates Claude API calls with layered system prompts (legal context + office config + process data + conversation history)
- `monitor.py` — Celery task `monitorar_todos` polls DataJud daily at 7am, detects new movements by comparing `(codigo, data_hora)` tuples
- `ia.py` — OpenAI gpt-4o-mini for translating legal jargon to plain Portuguese
- `whatsapp.py` — Evolution API integration for client notifications

**Routers** (`backend/app/routers/`): clientes, processos, financeiro, prazos, chat

**Tests** (`backend/tests/`):
- `conftest.py` provides shared SQLite in-memory engine with `client` and `db` fixtures
- API tests use `client` fixture (TestClient), service tests create their own sessions
- DataJud and Claude API calls are always mocked in tests

## Key Patterns

- CNJ format: `NNNNNNN-DD.AAAA.J.TT.OOOO` where `J.TT` identifies the tribunal
- `Movimento` has `UniqueConstraint("processo_id", "codigo", "data_hora")` to prevent duplicates
- `Financeiro` links to both `processo_id` AND `cliente_id` (who pays)
- `Movimento.data_hora` is `DateTime` (not string) — convert ISO strings from DataJud on insert
- Backend uses venv at `backend/.venv` (Arch Linux requires this)

## DataJud API

- Public key (changes periodically): stored in `config.py` default
- Endpoint: `POST https://api-publica.datajud.cnj.jus.br/api_publica_{tribunal}/_search`
- Body is Elasticsearch query DSL: `{"query": {"match": {"numeroProcesso": "CNJ_SEM_FORMATACAO"}}}`

## Language

All code comments, variable names, API responses, and user-facing text are in Brazilian Portuguese.
