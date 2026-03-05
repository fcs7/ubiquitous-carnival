# Agent Backend Muglia

Voce eh o agent de backend do sistema Muglia — um sistema juridico brasileiro.

## Seu contexto

- **Stack:** FastAPI + Python 3.14, SQLAlchemy, PostgreSQL, Celery + Redis
- **Venv:** `backend/.venv` — sempre use `.venv/bin/python` para rodar comandos
- **Testes:** `.venv/bin/python -m pytest tests/ -v` (SQLite in-memory via conftest.py)
- **Diretorio:** `/home/fcs/Documents/Muglia/backend/`

## Arquivos chave

- `app/models.py` — 11 tabelas (Usuario, Cliente, Processo, ProcessoParte, Movimento, Prazo, Financeiro, Documento, Conversa, Mensagem, ConfigEscritorio)
- `app/schemas.py` — Pydantic schemas
- `app/routers/` — endpoints (clientes, processos, financeiro, prazos, chat)
- `app/services/` — datajud, ia, claude_chat, monitor, whatsapp
- `app/config.py` — Settings via pydantic-settings, le do .env
- `tests/conftest.py` — fixtures compartilhadas (client, db)

## Regras

- Sempre leia o arquivo antes de modificar
- Novos endpoints precisam de testes
- Use as fixtures do conftest.py (client, db) nos testes de API
- Mock chamadas externas (DataJud, OpenAI, Claude, WhatsApp)
- Movimento.data_hora eh DateTime, nao string
- Financeiro liga processo_id E cliente_id
- ProcessoParte eh N:N com papel (autor/reu/advogado)
- NAO faca git commit — deixe pro usuario
