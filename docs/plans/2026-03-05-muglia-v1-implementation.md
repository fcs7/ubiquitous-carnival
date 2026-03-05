# Muglia v1 - Plano de Implementacao

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Sistema interno para monitorar ~1000 processos judiciais via DataJud, detectar mudancas, traduzir com IA e notificar clientes no WhatsApp.

**Architecture:** FastAPI backend com PostgreSQL para persistencia, Celery+Redis para polling diario da API DataJud, OpenAI para traduzir andamentos juridicos, Evolution API para WhatsApp. Tudo em Docker Compose no Proxmox.

**Tech Stack:** Python 3.14, FastAPI, SQLAlchemy, PostgreSQL, Celery, Redis, OpenAI, Docker Compose

---

## Fase 1: Infraestrutura e Banco de Dados

### Task 1: Estrutura do projeto e Docker Compose

**Files:**
- Create: `docker-compose.yml`
- Create: `backend/Dockerfile`
- Create: `backend/requirements.txt`
- Create: `backend/.env.example`
- Create: `.gitignore`

**Step 1: Criar .gitignore**

```
__pycache__/
*.pyc
.env
*.egg-info/
.venv/
```

**Step 2: Criar requirements.txt**

```
fastapi==0.115.12
uvicorn==0.34.3
sqlalchemy==2.0.41
psycopg2-binary==2.9.10
alembic==1.15.2
celery==5.5.2
redis==6.2.0
requests==2.32.5
openai==2.24.0
pydantic-settings==2.9.1
httpx==0.28.1
pytest==8.4.1
pytest-asyncio==1.0.0
```

**Step 3: Criar .env.example**

```
DATABASE_URL=postgresql://muglia:muglia@db:5432/muglia
REDIS_URL=redis://redis:6379/0
OPENAI_API_KEY=sk-sua-chave-aqui
DATAJUD_API_KEY=cDZHYzlZa0JadVREZDJCendQbXY6SkJlTzNjLV9TRENyQk1RdnFKZGRQdw==
DATAJUD_BASE_URL=https://api-publica.datajud.cnj.jus.br
EVOLUTION_API_URL=http://evolution:8080
EVOLUTION_API_KEY=sua-chave-evolution
```

**Step 4: Criar backend/Dockerfile**

```dockerfile
FROM python:3.14-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
```

**Step 5: Criar docker-compose.yml**

```yaml
services:
  db:
    image: postgres:17
    environment:
      POSTGRES_USER: muglia
      POSTGRES_PASSWORD: muglia
      POSTGRES_DB: muglia
    ports:
      - "5432:5432"
    volumes:
      - pgdata:/var/lib/postgresql/data

  redis:
    image: redis:7-alpine
    ports:
      - "6379:6379"

  backend:
    build: ./backend
    ports:
      - "8000:8000"
    env_file: ./backend/.env
    depends_on:
      - db
      - redis
    volumes:
      - ./backend:/app

  worker:
    build: ./backend
    command: celery -A app.worker worker --loglevel=info
    env_file: ./backend/.env
    depends_on:
      - db
      - redis
    volumes:
      - ./backend:/app

  beat:
    build: ./backend
    command: celery -A app.worker beat --loglevel=info
    env_file: ./backend/.env
    depends_on:
      - db
      - redis
    volumes:
      - ./backend:/app

volumes:
  pgdata:
```

**Step 6: Verificar que Docker Compose valida**

Run: `docker compose config --quiet && echo "OK"`
Expected: OK

**Step 7: Commit**

```bash
git init && git add -A && git commit -m "feat: estrutura do projeto com Docker Compose"
```

---

### Task 2: Models do banco de dados (SQLAlchemy)

**Files:**
- Create: `backend/app/__init__.py`
- Create: `backend/app/config.py`
- Create: `backend/app/database.py`
- Create: `backend/app/models.py`
- Create: `backend/app/main.py`
- Test: `backend/tests/test_models.py`

**Step 1: Criar backend/app/__init__.py**

Arquivo vazio.

**Step 2: Criar backend/app/config.py**

```python
from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://muglia:muglia@db:5432/muglia"
    redis_url: str = "redis://redis:6379/0"
    openai_api_key: str = ""
    datajud_api_key: str = "cDZHYzlZa0JadVREZDJCendQbXY6SkJlTzNjLV9TRENyQk1RdnFKZGRQdw=="
    datajud_base_url: str = "https://api-publica.datajud.cnj.jus.br"
    evolution_api_url: str = "http://evolution:8080"
    evolution_api_key: str = ""

    class Config:
        env_file = ".env"


settings = Settings()
```

**Step 3: Criar backend/app/database.py**

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, DeclarativeBase

from app.config import settings

engine = create_engine(settings.database_url)
SessionLocal = sessionmaker(bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
```

**Step 4: Criar backend/app/models.py**

```python
from datetime import datetime, date
from sqlalchemy import String, Integer, Float, Boolean, DateTime, Date, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


class Cliente(Base):
    __tablename__ = "clientes"

    id: Mapped[int] = mapped_column(primary_key=True)
    nome: Mapped[str] = mapped_column(String(255))
    telefone: Mapped[str] = mapped_column(String(20))
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    processos: Mapped[list["Processo"]] = relationship(back_populates="cliente")


class Processo(Base):
    __tablename__ = "processos"

    id: Mapped[int] = mapped_column(primary_key=True)
    cnj: Mapped[str] = mapped_column(String(25), unique=True, index=True)
    numero_limpo: Mapped[str] = mapped_column(String(20), index=True)
    tribunal: Mapped[str] = mapped_column(String(10))
    alias_tribunal: Mapped[str] = mapped_column(String(20))
    classe_codigo: Mapped[int | None] = mapped_column(Integer, nullable=True)
    classe_nome: Mapped[str | None] = mapped_column(String(255), nullable=True)
    orgao_julgador: Mapped[str | None] = mapped_column(String(255), nullable=True)
    grau: Mapped[str | None] = mapped_column(String(10), nullable=True)
    data_ajuizamento: Mapped[str | None] = mapped_column(String(20), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="ativo")
    cliente_id: Mapped[int | None] = mapped_column(ForeignKey("clientes.id"), nullable=True)
    ultima_verificacao: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    cliente: Mapped["Cliente | None"] = relationship(back_populates="processos")
    movimentos: Mapped[list["Movimento"]] = relationship(back_populates="processo")
    financeiro: Mapped[list["Financeiro"]] = relationship(back_populates="processo")
    prazos: Mapped[list["Prazo"]] = relationship(back_populates="processo")


class Movimento(Base):
    __tablename__ = "movimentos"

    id: Mapped[int] = mapped_column(primary_key=True)
    processo_id: Mapped[int] = mapped_column(ForeignKey("processos.id"))
    codigo: Mapped[int] = mapped_column(Integer)
    nome: Mapped[str] = mapped_column(String(255))
    data_hora: Mapped[str] = mapped_column(String(30))
    complementos: Mapped[str | None] = mapped_column(Text, nullable=True)
    resumo_ia: Mapped[str | None] = mapped_column(Text, nullable=True)
    notificado: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    processo: Mapped["Processo"] = relationship(back_populates="movimentos")


class Financeiro(Base):
    __tablename__ = "financeiro"

    id: Mapped[int] = mapped_column(primary_key=True)
    processo_id: Mapped[int] = mapped_column(ForeignKey("processos.id"))
    tipo: Mapped[str] = mapped_column(String(50))  # honorario, custas, etc
    descricao: Mapped[str | None] = mapped_column(String(255), nullable=True)
    valor: Mapped[float] = mapped_column(Float)
    status: Mapped[str] = mapped_column(String(20), default="pendente")
    data_vencimento: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    processo: Mapped["Processo"] = relationship(back_populates="financeiro")


class Prazo(Base):
    __tablename__ = "prazos"

    id: Mapped[int] = mapped_column(primary_key=True)
    processo_id: Mapped[int] = mapped_column(ForeignKey("processos.id"))
    tipo: Mapped[str] = mapped_column(String(50))  # intimacao, audiencia, etc
    descricao: Mapped[str | None] = mapped_column(Text, nullable=True)
    data_limite: Mapped[date] = mapped_column(Date)
    status: Mapped[str] = mapped_column(String(20), default="pendente")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    processo: Mapped["Processo"] = relationship(back_populates="prazos")
```

**Step 5: Criar backend/app/main.py (minimo)**

```python
from fastapi import FastAPI
from app.database import engine, Base

app = FastAPI(title="Muglia", version="1.0.0")

Base.metadata.create_all(bind=engine)


@app.get("/health")
def health():
    return {"status": "ok"}
```

**Step 6: Escrever teste dos models**

Criar `backend/tests/__init__.py` (vazio) e `backend/tests/test_models.py`:

```python
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from app.database import Base
from app.models import Cliente, Processo, Movimento, Financeiro, Prazo


engine = create_engine("sqlite:///:memory:")
Session = sessionmaker(bind=engine)


def setup_module():
    Base.metadata.create_all(engine)


def test_criar_cliente_e_processo():
    session = Session()
    cliente = Cliente(nome="Joao Silva", telefone="61999998888")
    session.add(cliente)
    session.flush()

    processo = Processo(
        cnj="0702906-79.2026.8.07.0020",
        numero_limpo="07029067920268070020",
        tribunal="TJDFT",
        alias_tribunal="tjdft",
        cliente_id=cliente.id,
    )
    session.add(processo)
    session.flush()

    assert processo.id is not None
    assert processo.cliente.nome == "Joao Silva"
    session.rollback()


def test_criar_movimento():
    session = Session()
    processo = Processo(
        cnj="0000832-35.2018.4.01.3202",
        numero_limpo="00008323520184013202",
        tribunal="TRF1",
        alias_tribunal="trf1",
    )
    session.add(processo)
    session.flush()

    mov = Movimento(
        processo_id=processo.id,
        codigo=26,
        nome="Distribuicao",
        data_hora="2018-10-30T14:06:24.000Z",
        notificado=False,
    )
    session.add(mov)
    session.flush()

    assert mov.id is not None
    assert processo.movimentos[0].nome == "Distribuicao"
    session.rollback()
```

**Step 7: Rodar testes**

Run: `cd backend && pip install -r requirements.txt && python -m pytest tests/ -v`
Expected: 2 tests PASS

**Step 8: Commit**

```bash
git add -A && git commit -m "feat: models do banco (cliente, processo, movimento, financeiro, prazo)"
```

---

## Fase 2: Servico DataJud

### Task 3: Servico de consulta DataJud (mover logica do teste pra modulo)

**Files:**
- Create: `backend/app/services/__init__.py`
- Create: `backend/app/services/datajud.py`
- Test: `backend/tests/test_datajud.py`

**Step 1: Criar backend/app/services/datajud.py**

```python
import re
import requests
from app.config import settings


TRIBUNAL_MAP = {
    "5.00": "tst", "6.00": "tse", "3.00": "stj", "7.00": "stm",
    **{f"4.{t:02d}": f"trf{t}" for t in range(1, 7)},
    **{f"5.{t:02d}": f"trt{t}" for t in range(1, 25)},
    "8.01": "tjac", "8.02": "tjal", "8.03": "tjap", "8.04": "tjam",
    "8.05": "tjba", "8.06": "tjce", "8.07": "tjdft", "8.08": "tjes",
    "8.09": "tjgo", "8.10": "tjma", "8.11": "tjmt", "8.12": "tjms",
    "8.13": "tjmg", "8.14": "tjpa", "8.15": "tjpb", "8.16": "tjpr",
    "8.17": "tjpe", "8.18": "tjpi", "8.19": "tjrj", "8.20": "tjrn",
    "8.21": "tjrs", "8.22": "tjro", "8.23": "tjrr", "8.24": "tjsc",
    "8.25": "tjse", "8.26": "tjsp", "8.27": "tjto",
    "6.01": "tre-ac", "6.02": "tre-al", "6.03": "tre-ap", "6.04": "tre-am",
    "6.05": "tre-ba", "6.06": "tre-ce", "6.07": "tre-dft", "6.08": "tre-es",
    "6.09": "tre-go", "6.10": "tre-ma", "6.11": "tre-mt", "6.12": "tre-ms",
    "6.13": "tre-mg", "6.14": "tre-pa", "6.15": "tre-pb", "6.16": "tre-pr",
    "6.17": "tre-pe", "6.18": "tre-pi", "6.19": "tre-rj", "6.20": "tre-rn",
    "6.21": "tre-rs", "6.22": "tre-ro", "6.23": "tre-rr", "6.24": "tre-sc",
    "6.25": "tre-se", "6.26": "tre-sp", "6.27": "tre-to",
    "9.13": "tjmmg", "9.21": "tjmrs", "9.26": "tjmsp",
}

CNJ_REGEX = re.compile(r"^(\d{7})-(\d{2})\.(\d{4})\.(\d)\.(\d{2})\.(\d{4})$")


def parse_cnj(cnj: str) -> dict | None:
    """Extrai componentes do numero CNJ."""
    match = CNJ_REGEX.match(cnj.strip())
    if not match:
        return None
    j, tt = match.group(4), match.group(5)
    return {
        "cnj": cnj.strip(),
        "numero_limpo": cnj.replace("-", "").replace(".", ""),
        "codigo_tribunal": f"{j}.{tt}",
        "alias_tribunal": TRIBUNAL_MAP.get(f"{j}.{tt}"),
    }


def consultar_processo(numero_limpo: str, alias_tribunal: str) -> dict:
    """Consulta um processo na API DataJud. Retorna o _source do primeiro hit ou {}."""
    url = f"{settings.datajud_base_url}/api_publica_{alias_tribunal}/_search"
    headers = {
        "Authorization": f"APIKey {settings.datajud_api_key}",
        "Content-Type": "application/json",
    }
    body = {"query": {"match": {"numeroProcesso": numero_limpo}}}
    resp = requests.post(url, headers=headers, json=body, timeout=30)
    resp.raise_for_status()
    hits = resp.json().get("hits", {}).get("hits", [])
    if not hits:
        return {}
    return hits[0].get("_source", {})
```

**Step 2: Criar teste**

```python
from app.services.datajud import parse_cnj, TRIBUNAL_MAP


def test_parse_cnj_valido():
    result = parse_cnj("0702906-79.2026.8.07.0020")
    assert result["numero_limpo"] == "07029067920268070020"
    assert result["codigo_tribunal"] == "8.07"
    assert result["alias_tribunal"] == "tjdft"


def test_parse_cnj_trf1():
    result = parse_cnj("0000832-35.2018.4.01.3202")
    assert result["alias_tribunal"] == "trf1"


def test_parse_cnj_invalido():
    assert parse_cnj("12345") is None
    assert parse_cnj("") is None


def test_tribunal_map_cobertura():
    assert len(TRIBUNAL_MAP) >= 90
```

**Step 3: Rodar testes**

Run: `cd backend && python -m pytest tests/test_datajud.py -v`
Expected: 4 tests PASS

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: servico DataJud com parse CNJ e consulta API"
```

---

### Task 4: Servico de traducao com IA (OpenAI)

**Files:**
- Create: `backend/app/services/ia.py`
- Test: `backend/tests/test_ia.py`

**Step 1: Criar backend/app/services/ia.py**

```python
from openai import OpenAI
from app.config import settings

client = None


def get_client():
    global client
    if client is None:
        client = OpenAI(api_key=settings.openai_api_key)
    return client


def traduzir_movimento(nome: str, complementos: str = "") -> str:
    """Traduz um andamento juridico para linguagem simples."""
    prompt = f"""Traduza este andamento processual para linguagem simples que um leigo entenda.
Seja direto, maximo 2 frases. Nao use termos juridicos.

Andamento: {nome}
{f'Detalhes: {complementos}' if complementos else ''}

Traducao:"""

    try:
        resp = get_client().chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=150,
            temperature=0.3,
        )
        return resp.choices[0].message.content.strip()
    except Exception as e:
        return f"{nome} (traducao indisponivel)"
```

**Step 2: Criar teste (mock do OpenAI)**

```python
from unittest.mock import patch, MagicMock
from app.services.ia import traduzir_movimento


def test_traduzir_movimento_sucesso():
    mock_resp = MagicMock()
    mock_resp.choices = [MagicMock()]
    mock_resp.choices[0].message.content = "O processo foi distribuido para um juiz."

    with patch("app.services.ia.get_client") as mock_client:
        mock_client.return_value.chat.completions.create.return_value = mock_resp
        resultado = traduzir_movimento("Distribuicao", "competencia exclusiva")

    assert "distribuido" in resultado.lower()


def test_traduzir_movimento_erro():
    with patch("app.services.ia.get_client") as mock_client:
        mock_client.return_value.chat.completions.create.side_effect = Exception("API error")
        resultado = traduzir_movimento("Distribuicao")

    assert "Distribuicao" in resultado
    assert "indisponivel" in resultado
```

**Step 3: Rodar testes**

Run: `cd backend && python -m pytest tests/test_ia.py -v`
Expected: 2 tests PASS

**Step 4: Commit**

```bash
git add -A && git commit -m "feat: servico de traducao IA com OpenAI"
```

---

## Fase 3: API REST (FastAPI)

### Task 5: CRUD de Clientes

**Files:**
- Create: `backend/app/schemas.py`
- Create: `backend/app/routers/__init__.py`
- Create: `backend/app/routers/clientes.py`
- Test: `backend/tests/test_api_clientes.py`

**Step 1: Criar backend/app/schemas.py**

```python
from pydantic import BaseModel
from datetime import date


class ClienteCreate(BaseModel):
    nome: str
    telefone: str
    email: str | None = None


class ClienteOut(BaseModel):
    id: int
    nome: str
    telefone: str
    email: str | None

    class Config:
        from_attributes = True


class ProcessoCreate(BaseModel):
    cnj: str
    cliente_id: int | None = None


class ProcessoOut(BaseModel):
    id: int
    cnj: str
    tribunal: str
    classe_nome: str | None
    orgao_julgador: str | None
    status: str
    cliente_id: int | None

    class Config:
        from_attributes = True


class MovimentoOut(BaseModel):
    id: int
    codigo: int
    nome: str
    data_hora: str
    resumo_ia: str | None
    notificado: bool

    class Config:
        from_attributes = True


class FinanceiroCreate(BaseModel):
    processo_id: int
    tipo: str
    descricao: str | None = None
    valor: float
    data_vencimento: date | None = None


class FinanceiroOut(BaseModel):
    id: int
    processo_id: int
    tipo: str
    descricao: str | None
    valor: float
    status: str
    data_vencimento: date | None

    class Config:
        from_attributes = True


class PrazoOut(BaseModel):
    id: int
    processo_id: int
    tipo: str
    descricao: str | None
    data_limite: date
    status: str

    class Config:
        from_attributes = True
```

**Step 2: Criar backend/app/routers/clientes.py**

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Cliente
from app.schemas import ClienteCreate, ClienteOut

router = APIRouter(prefix="/clientes", tags=["clientes"])


@router.post("/", response_model=ClienteOut)
def criar_cliente(data: ClienteCreate, db: Session = Depends(get_db)):
    cliente = Cliente(**data.model_dump())
    db.add(cliente)
    db.commit()
    db.refresh(cliente)
    return cliente


@router.get("/", response_model=list[ClienteOut])
def listar_clientes(db: Session = Depends(get_db)):
    return db.query(Cliente).all()


@router.get("/{cliente_id}", response_model=ClienteOut)
def buscar_cliente(cliente_id: int, db: Session = Depends(get_db)):
    cliente = db.query(Cliente).filter(Cliente.id == cliente_id).first()
    if not cliente:
        raise HTTPException(status_code=404, detail="Cliente nao encontrado")
    return cliente
```

**Step 3: Registrar router no main.py — atualizar backend/app/main.py**

```python
from fastapi import FastAPI
from app.database import engine, Base
from app.routers import clientes

app = FastAPI(title="Muglia", version="1.0.0")

Base.metadata.create_all(bind=engine)

app.include_router(clientes.router)


@app.get("/health")
def health():
    return {"status": "ok"}
```

**Step 4: Escrever teste de API**

```python
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base, get_db
from app.main import app

engine = create_engine("sqlite:///:memory:")
TestSession = sessionmaker(bind=engine)
Base.metadata.create_all(engine)


def override_get_db():
    db = TestSession()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)


def test_criar_e_listar_clientes():
    resp = client.post("/clientes/", json={"nome": "Joao", "telefone": "61999998888"})
    assert resp.status_code == 200
    assert resp.json()["nome"] == "Joao"

    resp = client.get("/clientes/")
    assert len(resp.json()) >= 1


def test_buscar_cliente_inexistente():
    resp = client.get("/clientes/9999")
    assert resp.status_code == 404
```

**Step 5: Rodar testes**

Run: `cd backend && python -m pytest tests/test_api_clientes.py -v`
Expected: 2 tests PASS

**Step 6: Commit**

```bash
git add -A && git commit -m "feat: CRUD clientes com API REST"
```

---

### Task 6: Endpoint de cadastrar processo (com consulta DataJud)

**Files:**
- Create: `backend/app/routers/processos.py`
- Modify: `backend/app/main.py` (adicionar router)
- Test: `backend/tests/test_api_processos.py`

**Step 1: Criar backend/app/routers/processos.py**

```python
import json
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Processo, Movimento
from app.schemas import ProcessoCreate, ProcessoOut, MovimentoOut
from app.services.datajud import parse_cnj, consultar_processo

router = APIRouter(prefix="/processos", tags=["processos"])


@router.post("/", response_model=ProcessoOut)
def cadastrar_processo(data: ProcessoCreate, db: Session = Depends(get_db)):
    parsed = parse_cnj(data.cnj)
    if not parsed or not parsed["alias_tribunal"]:
        raise HTTPException(status_code=400, detail="CNJ invalido ou tribunal desconhecido")

    existente = db.query(Processo).filter(Processo.cnj == data.cnj).first()
    if existente:
        raise HTTPException(status_code=409, detail="Processo ja cadastrado")

    # Consulta DataJud
    dados_datajud = consultar_processo(parsed["numero_limpo"], parsed["alias_tribunal"])

    processo = Processo(
        cnj=data.cnj,
        numero_limpo=parsed["numero_limpo"],
        tribunal=dados_datajud.get("tribunal", parsed["alias_tribunal"].upper()),
        alias_tribunal=parsed["alias_tribunal"],
        classe_codigo=dados_datajud.get("classe", {}).get("codigo"),
        classe_nome=dados_datajud.get("classe", {}).get("nome"),
        orgao_julgador=dados_datajud.get("orgaoJulgador", {}).get("nome"),
        grau=dados_datajud.get("grau"),
        data_ajuizamento=dados_datajud.get("dataAjuizamento"),
        cliente_id=data.cliente_id,
    )
    db.add(processo)
    db.flush()

    # Salva movimentos iniciais
    for mov in dados_datajud.get("movimentos", []):
        complementos = json.dumps(mov.get("complementosTabelados", []), ensure_ascii=False)
        movimento = Movimento(
            processo_id=processo.id,
            codigo=mov.get("codigo", 0),
            nome=mov.get("nome", ""),
            data_hora=mov.get("dataHora", ""),
            complementos=complementos if complementos != "[]" else None,
        )
        db.add(movimento)

    db.commit()
    db.refresh(processo)
    return processo


@router.get("/", response_model=list[ProcessoOut])
def listar_processos(status: str | None = None, db: Session = Depends(get_db)):
    query = db.query(Processo)
    if status:
        query = query.filter(Processo.status == status)
    return query.all()


@router.get("/{processo_id}", response_model=ProcessoOut)
def buscar_processo(processo_id: int, db: Session = Depends(get_db)):
    processo = db.query(Processo).filter(Processo.id == processo_id).first()
    if not processo:
        raise HTTPException(status_code=404, detail="Processo nao encontrado")
    return processo


@router.get("/{processo_id}/movimentos", response_model=list[MovimentoOut])
def listar_movimentos(processo_id: int, db: Session = Depends(get_db)):
    return (
        db.query(Movimento)
        .filter(Movimento.processo_id == processo_id)
        .order_by(Movimento.data_hora.desc())
        .all()
    )
```

**Step 2: Atualizar main.py para incluir router de processos**

```python
from fastapi import FastAPI
from app.database import engine, Base
from app.routers import clientes, processos

app = FastAPI(title="Muglia", version="1.0.0")

Base.metadata.create_all(bind=engine)

app.include_router(clientes.router)
app.include_router(processos.router)


@app.get("/health")
def health():
    return {"status": "ok"}
```

**Step 3: Escrever teste (mock da consulta DataJud)**

```python
from unittest.mock import patch
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base, get_db
from app.main import app

engine = create_engine("sqlite:///:memory:")
TestSession = sessionmaker(bind=engine)
Base.metadata.create_all(engine)


def override_get_db():
    db = TestSession()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)

MOCK_DATAJUD = {
    "tribunal": "TRF1",
    "classe": {"codigo": 436, "nome": "Procedimento do Juizado Especial Civel"},
    "orgaoJulgador": {"nome": "Tefe", "codigo": 16403},
    "grau": "JE",
    "dataAjuizamento": "20181029000000",
    "movimentos": [
        {"codigo": 26, "nome": "Distribuicao", "dataHora": "2018-10-30T14:06:24.000Z", "complementosTabelados": []},
    ],
}


@patch("app.routers.processos.consultar_processo", return_value=MOCK_DATAJUD)
def test_cadastrar_processo(mock_consulta):
    resp = client.post("/processos/", json={"cnj": "0000832-35.2018.4.01.3202"})
    assert resp.status_code == 200
    assert resp.json()["tribunal"] == "TRF1"
    assert resp.json()["classe_nome"] == "Procedimento do Juizado Especial Civel"


@patch("app.routers.processos.consultar_processo", return_value=MOCK_DATAJUD)
def test_cnj_duplicado(mock_consulta):
    client.post("/processos/", json={"cnj": "0000832-35.2018.4.01.3202"})
    resp = client.post("/processos/", json={"cnj": "0000832-35.2018.4.01.3202"})
    assert resp.status_code == 409


def test_cnj_invalido():
    resp = client.post("/processos/", json={"cnj": "12345"})
    assert resp.status_code == 400
```

**Step 4: Rodar testes**

Run: `cd backend && python -m pytest tests/test_api_processos.py -v`
Expected: 3 tests PASS

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: cadastro de processos com consulta DataJud automatica"
```

---

### Task 7: Endpoints de financeiro e prazos

**Files:**
- Create: `backend/app/routers/financeiro.py`
- Create: `backend/app/routers/prazos.py`
- Modify: `backend/app/main.py` (adicionar routers)
- Test: `backend/tests/test_api_financeiro.py`

**Step 1: Criar backend/app/routers/financeiro.py**

```python
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Financeiro
from app.schemas import FinanceiroCreate, FinanceiroOut

router = APIRouter(prefix="/financeiro", tags=["financeiro"])


@router.post("/", response_model=FinanceiroOut)
def criar_lancamento(data: FinanceiroCreate, db: Session = Depends(get_db)):
    lancamento = Financeiro(**data.model_dump())
    db.add(lancamento)
    db.commit()
    db.refresh(lancamento)
    return lancamento


@router.get("/", response_model=list[FinanceiroOut])
def listar_lancamentos(status: str | None = None, db: Session = Depends(get_db)):
    query = db.query(Financeiro)
    if status:
        query = query.filter(Financeiro.status == status)
    return query.order_by(Financeiro.data_vencimento).all()


@router.patch("/{lancamento_id}/pagar")
def marcar_pago(lancamento_id: int, db: Session = Depends(get_db)):
    lancamento = db.query(Financeiro).filter(Financeiro.id == lancamento_id).first()
    if not lancamento:
        raise HTTPException(status_code=404, detail="Lancamento nao encontrado")
    lancamento.status = "pago"
    db.commit()
    return {"ok": True}
```

**Step 2: Criar backend/app/routers/prazos.py**

```python
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Prazo
from app.schemas import PrazoOut

router = APIRouter(prefix="/prazos", tags=["prazos"])


@router.get("/", response_model=list[PrazoOut])
def listar_prazos(status: str = "pendente", db: Session = Depends(get_db)):
    return (
        db.query(Prazo)
        .filter(Prazo.status == status)
        .order_by(Prazo.data_limite)
        .all()
    )
```

**Step 3: Atualizar main.py**

```python
from fastapi import FastAPI
from app.database import engine, Base
from app.routers import clientes, processos, financeiro, prazos

app = FastAPI(title="Muglia", version="1.0.0")

Base.metadata.create_all(bind=engine)

app.include_router(clientes.router)
app.include_router(processos.router)
app.include_router(financeiro.router)
app.include_router(prazos.router)


@app.get("/health")
def health():
    return {"status": "ok"}
```

**Step 4: Teste rapido**

```python
from unittest.mock import patch
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base, get_db
from app.main import app

engine = create_engine("sqlite:///:memory:")
TestSession = sessionmaker(bind=engine)
Base.metadata.create_all(engine)


def override_get_db():
    db = TestSession()
    try:
        yield db
    finally:
        db.close()


app.dependency_overrides[get_db] = override_get_db
client = TestClient(app)

MOCK_DATAJUD = {
    "tribunal": "TRF1",
    "classe": {"codigo": 436, "nome": "JEC"},
    "orgaoJulgador": {"nome": "Tefe"},
    "grau": "JE",
    "dataAjuizamento": "20181029",
    "movimentos": [],
}


@patch("app.routers.processos.consultar_processo", return_value=MOCK_DATAJUD)
def test_financeiro_fluxo(mock):
    client.post("/processos/", json={"cnj": "0000832-35.2018.4.01.3202"})
    resp = client.post("/financeiro/", json={
        "processo_id": 1,
        "tipo": "honorario",
        "valor": 5000.0,
        "data_vencimento": "2026-04-01",
    })
    assert resp.status_code == 200
    assert resp.json()["status"] == "pendente"

    resp = client.patch("/financeiro/1/pagar")
    assert resp.json()["ok"] is True
```

**Step 5: Rodar testes**

Run: `cd backend && python -m pytest tests/test_api_financeiro.py -v`
Expected: PASS

**Step 6: Commit**

```bash
git add -A && git commit -m "feat: endpoints de financeiro e prazos"
```

---

## Fase 4: Worker de Monitoramento

### Task 8: Celery worker — polling diario + deteccao de mudancas

**Files:**
- Create: `backend/app/worker.py`
- Create: `backend/app/services/monitor.py`
- Test: `backend/tests/test_monitor.py`

**Step 1: Criar backend/app/worker.py**

```python
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

# Registra as tasks
celery_app.autodiscover_tasks(["app.services"])
```

**Step 2: Criar backend/app/services/monitor.py**

```python
import json
from datetime import datetime
from app.worker import celery_app
from app.database import SessionLocal
from app.models import Processo, Movimento
from app.services.datajud import consultar_processo
from app.services.ia import traduzir_movimento


def verificar_processo(db, processo: Processo) -> list[Movimento]:
    """Consulta DataJud e retorna lista de movimentos novos."""
    dados = consultar_processo(processo.numero_limpo, processo.alias_tribunal)
    if not dados:
        return []

    movimentos_existentes = {
        (m.codigo, m.data_hora) for m in processo.movimentos
    }

    novos = []
    for mov in dados.get("movimentos", []):
        chave = (mov.get("codigo", 0), mov.get("dataHora", ""))
        if chave not in movimentos_existentes:
            complementos = json.dumps(mov.get("complementosTabelados", []), ensure_ascii=False)
            comp_texto = ", ".join(
                f"{c.get('nome', '')}: {c.get('valor', '')}"
                for c in mov.get("complementosTabelados", [])
                if c.get("valor")
            )
            resumo = traduzir_movimento(mov.get("nome", ""), comp_texto)

            movimento = Movimento(
                processo_id=processo.id,
                codigo=mov.get("codigo", 0),
                nome=mov.get("nome", ""),
                data_hora=mov.get("dataHora", ""),
                complementos=complementos if complementos != "[]" else None,
                resumo_ia=resumo,
                notificado=False,
            )
            db.add(movimento)
            novos.append(movimento)

    if novos:
        processo.ultima_verificacao = datetime.utcnow()
        db.commit()

    return novos


@celery_app.task(name="app.services.monitor.monitorar_todos")
def monitorar_todos():
    """Task Celery: verifica todos os processos ativos."""
    db = SessionLocal()
    try:
        processos = db.query(Processo).filter(Processo.status == "ativo").all()
        total_novos = 0
        for processo in processos:
            try:
                novos = verificar_processo(db, processo)
                total_novos += len(novos)
            except Exception as e:
                print(f"Erro ao verificar {processo.cnj}: {e}")
        return f"Verificados {len(processos)} processos, {total_novos} movimentos novos"
    finally:
        db.close()
```

**Step 3: Escrever teste do monitor**

```python
from unittest.mock import patch, MagicMock
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.database import Base
from app.models import Processo, Movimento
from app.services.monitor import verificar_processo

engine = create_engine("sqlite:///:memory:")
Session = sessionmaker(bind=engine)
Base.metadata.create_all(engine)


MOCK_DATAJUD_COM_MOVIMENTOS = {
    "movimentos": [
        {"codigo": 26, "nome": "Distribuicao", "dataHora": "2024-01-01T10:00:00.000Z", "complementosTabelados": []},
        {"codigo": 51, "nome": "Conclusao", "dataHora": "2024-02-01T10:00:00.000Z", "complementosTabelados": []},
    ]
}


@patch("app.services.monitor.traduzir_movimento", return_value="Traducao teste")
@patch("app.services.monitor.consultar_processo", return_value=MOCK_DATAJUD_COM_MOVIMENTOS)
def test_detecta_movimentos_novos(mock_consulta, mock_ia):
    db = Session()
    processo = Processo(
        cnj="0000832-35.2018.4.01.3202",
        numero_limpo="00008323520184013202",
        tribunal="TRF1",
        alias_tribunal="trf1",
    )
    db.add(processo)
    db.flush()

    novos = verificar_processo(db, processo)
    assert len(novos) == 2
    assert novos[0].resumo_ia == "Traducao teste"
    db.rollback()


@patch("app.services.monitor.traduzir_movimento", return_value="Traducao teste")
@patch("app.services.monitor.consultar_processo", return_value=MOCK_DATAJUD_COM_MOVIMENTOS)
def test_nao_duplica_movimentos(mock_consulta, mock_ia):
    db = Session()
    processo = Processo(
        cnj="0000832-35.2018.4.01.3202",
        numero_limpo="00008323520184013202",
        tribunal="TRF1",
        alias_tribunal="trf1",
    )
    db.add(processo)
    db.flush()

    # Primeira verificacao: 2 novos
    novos1 = verificar_processo(db, processo)
    assert len(novos1) == 2

    # Segunda verificacao: 0 novos (ja existem)
    novos2 = verificar_processo(db, processo)
    assert len(novos2) == 0
    db.rollback()
```

**Step 4: Rodar testes**

Run: `cd backend && python -m pytest tests/test_monitor.py -v`
Expected: 2 tests PASS

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: worker Celery com monitoramento diario e deteccao de mudancas"
```

---

## Fase 5: Notificacao WhatsApp

### Task 9: Servico de notificacao WhatsApp (Evolution API)

**Files:**
- Create: `backend/app/services/whatsapp.py`
- Modify: `backend/app/services/monitor.py` (integrar notificacao)
- Test: `backend/tests/test_whatsapp.py`

**Step 1: Criar backend/app/services/whatsapp.py**

```python
import requests
from app.config import settings


def enviar_mensagem(telefone: str, mensagem: str) -> bool:
    """Envia mensagem via Evolution API. Retorna True se enviou."""
    url = f"{settings.evolution_api_url}/message/sendText/muglia"
    headers = {
        "apikey": settings.evolution_api_key,
        "Content-Type": "application/json",
    }
    body = {
        "number": telefone,
        "text": mensagem,
    }
    try:
        resp = requests.post(url, headers=headers, json=body, timeout=10)
        return resp.status_code == 200 or resp.status_code == 201
    except Exception:
        return False


def formatar_notificacao(cnj: str, resumo: str) -> str:
    """Formata a mensagem de notificacao para o cliente."""
    return f"Atualizacao no processo {cnj}:\n\n{resumo}\n\n- Escritorio Muglia"
```

**Step 2: Adicionar notificacao no monitor.py — ao final de verificar_processo, apos db.commit():**

Adicionar antes do `return novos`:

```python
    # Notifica cliente via WhatsApp
    if novos and processo.cliente and processo.cliente.telefone:
        from app.services.whatsapp import enviar_mensagem, formatar_notificacao
        for mov in novos:
            msg = formatar_notificacao(processo.cnj, mov.resumo_ia or mov.nome)
            if enviar_mensagem(processo.cliente.telefone, msg):
                mov.notificado = True
        db.commit()
```

**Step 3: Teste**

```python
from unittest.mock import patch, MagicMock
from app.services.whatsapp import formatar_notificacao, enviar_mensagem


def test_formatar_notificacao():
    msg = formatar_notificacao("0000832-35.2018.4.01.3202", "O juiz deu uma decisao.")
    assert "0000832-35.2018.4.01.3202" in msg
    assert "O juiz deu uma decisao." in msg
    assert "Muglia" in msg


@patch("app.services.whatsapp.requests.post")
def test_enviar_mensagem_sucesso(mock_post):
    mock_post.return_value = MagicMock(status_code=201)
    assert enviar_mensagem("61999998888", "teste") is True


@patch("app.services.whatsapp.requests.post")
def test_enviar_mensagem_erro(mock_post):
    mock_post.side_effect = Exception("Connection error")
    assert enviar_mensagem("61999998888", "teste") is False
```

**Step 4: Rodar testes**

Run: `cd backend && python -m pytest tests/test_whatsapp.py -v`
Expected: 3 tests PASS

**Step 5: Commit**

```bash
git add -A && git commit -m "feat: notificacao WhatsApp via Evolution API"
```

---

## Fase 6: Subir e Testar

### Task 10: Subir tudo com Docker Compose e testar fluxo completo

**Step 1: Criar backend/.env a partir do .env.example**

```bash
cp backend/.env.example backend/.env
# Editar com chaves reais (OPENAI_API_KEY, EVOLUTION_API_KEY)
```

**Step 2: Subir containers**

Run: `docker compose up -d --build`
Expected: 5 containers rodando (db, redis, backend, worker, beat)

**Step 3: Verificar health**

Run: `curl http://localhost:8000/health`
Expected: `{"status":"ok"}`

**Step 4: Testar fluxo completo via curl**

```bash
# Criar cliente
curl -X POST http://localhost:8000/clientes/ \
  -H "Content-Type: application/json" \
  -d '{"nome": "Joao Silva", "telefone": "61999998888"}'

# Cadastrar processo real
curl -X POST http://localhost:8000/processos/ \
  -H "Content-Type: application/json" \
  -d '{"cnj": "0000832-35.2018.4.01.3202", "cliente_id": 1}'

# Ver movimentos
curl http://localhost:8000/processos/1/movimentos

# Criar lancamento financeiro
curl -X POST http://localhost:8000/financeiro/ \
  -H "Content-Type: application/json" \
  -d '{"processo_id": 1, "tipo": "honorario", "valor": 5000, "data_vencimento": "2026-04-01"}'
```

**Step 5: Verificar docs da API**

Abrir `http://localhost:8000/docs` no navegador — Swagger UI com todos os endpoints.

**Step 6: Commit final**

```bash
git add -A && git commit -m "feat: Muglia v1 completo - monitoramento, IA, WhatsApp"
```

---

## Resumo das Tasks

| Task | Descricao | Fase |
|------|-----------|------|
| 1 | Estrutura do projeto + Docker Compose | Infraestrutura |
| 2 | Models do banco (SQLAlchemy) | Infraestrutura |
| 3 | Servico DataJud (parse CNJ + consulta) | DataJud |
| 4 | Servico de traducao IA (OpenAI) | DataJud |
| 5 | CRUD Clientes (API REST) | API |
| 6 | Cadastro de processos (com DataJud) | API |
| 7 | Financeiro e prazos (API REST) | API |
| 8 | Worker Celery (monitoramento diario) | Worker |
| 9 | Notificacao WhatsApp (Evolution API) | Notificacao |
| 10 | Subir e testar fluxo completo | Deploy |
