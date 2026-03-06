# Agentes Juridicos Configuraveis — Plano de Implementacao

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Permitir que advogados criem e configurem agentes de IA juridicos via UI. Quando um chat novo eh iniciado com um agente, o agente pode chamar ferramentas autonomamente (buscar processos, clientes, calcular prazos, gerar resumos financeiros) com streaming SSE.

**Architecture:** Anthropic Client SDK com tool use (function calling). O agente eh uma config no banco (system prompt, modelo, ferramentas habilitadas). O service `agente_chat.py` implementa o tool loop: chama `client.messages.stream()` com `tools=[]`, executa ferramentas quando Claude pede, e repete ateh `stop_reason="end_turn"`. Resultados streamam para o frontend via SSE.

**Tech Stack:** FastAPI, SQLAlchemy, Anthropic SDK (`anthropic==0.52.0` ja instalado), SSE via `StreamingResponse`

---

### Task 1: Model AgenteConfig + ToolExecution + FK em Conversa

**Files:**
- Modify: `backend/app/models.py` (append apos TagEntidade, + FK em Conversa, + relationship em Usuario)

**Step 1: Write the failing test**

Create `backend/tests/test_agentes.py`:

```python
from app.models import Usuario, AgenteConfig


def _criar_usuario(db):
    u = Usuario(nome="Adv Teste", email="adv@agente.com", oab="12345/SP")
    db.add(u)
    db.commit()
    db.refresh(u)
    return u


def test_criar_agente(client, db):
    usuario = _criar_usuario(db)
    resp = client.post("/agentes/", json={
        "nome": "Agente Trabalhista",
        "usuario_id": usuario.id,
        "instrucoes_sistema": "Especialista em direito trabalhista",
        "modelo_claude": "claude-sonnet-4-5-20250514",
        "ferramentas_habilitadas": ["buscar_processo", "buscar_cliente"],
    })
    assert resp.status_code == 201
    data = resp.json()
    assert data["nome"] == "Agente Trabalhista"
    assert data["ferramentas_habilitadas"] == ["buscar_processo", "buscar_cliente"]
    assert data["ativo"] is True
```

**Step 2: Run test to verify it fails**

Run: `cd backend && .venv/bin/python -m pytest tests/test_agentes.py::test_criar_agente -v`
Expected: FAIL (ImportError ou 404 — model/router nao existem)

**Step 3: Add models to `backend/app/models.py`**

Append after `TagEntidade` class:

```python
# ──────────────────────────────────────────────
# Agentes configuraveis
# ──────────────────────────────────────────────
class AgenteConfig(Base):
    __tablename__ = "agentes_config"

    id: Mapped[int] = mapped_column(primary_key=True)
    usuario_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id"), index=True)
    nome: Mapped[str] = mapped_column(String(100))
    descricao: Mapped[str | None] = mapped_column(Text, nullable=True)
    instrucoes_sistema: Mapped[str | None] = mapped_column(Text, nullable=True)
    modelo_claude: Mapped[str] = mapped_column(String(50), default="claude-sonnet-4-5-20250514")
    ferramentas_habilitadas: Mapped[str] = mapped_column(Text, default="[]")  # JSON list[str]
    contexto_referencia: Mapped[str | None] = mapped_column(Text, nullable=True)
    max_tokens: Mapped[int] = mapped_column(Integer, default=4096)
    max_iteracoes_tool: Mapped[int] = mapped_column(Integer, default=10)
    ativo: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC))

    usuario: Mapped["Usuario"] = relationship(back_populates="agentes_config")
    conversas: Mapped[list["Conversa"]] = relationship(back_populates="agente_config")


class ToolExecution(Base):
    __tablename__ = "tool_executions"

    id: Mapped[int] = mapped_column(primary_key=True)
    conversa_id: Mapped[int] = mapped_column(ForeignKey("conversas.id", ondelete="CASCADE"), index=True)
    tool_name: Mapped[str] = mapped_column(String(100))
    tool_use_id: Mapped[str] = mapped_column(String(100))
    input_json: Mapped[str] = mapped_column(Text)
    output_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    erro: Mapped[str | None] = mapped_column(Text, nullable=True)
    duracao_ms: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))

    conversa: Mapped["Conversa"] = relationship()
```

Add to `Conversa` class (after `modelo_claude` line):
```python
    agente_id: Mapped[int | None] = mapped_column(ForeignKey("agentes_config.id"), nullable=True, index=True)
```

Add relationship to `Conversa`:
```python
    agente_config: Mapped["AgenteConfig | None"] = relationship(back_populates="conversas")
```

Add relationship to `Usuario`:
```python
    agentes_config: Mapped[list["AgenteConfig"]] = relationship(back_populates="usuario")
```

**Step 4: Run test to verify model is importable (still fails on router)**

Run: `cd backend && .venv/bin/python -c "from app.models import AgenteConfig, ToolExecution; print('OK')"`
Expected: OK

---

### Task 2: Schemas Pydantic para Agentes

**Files:**
- Modify: `backend/app/schemas.py` (append ao final)

**Step 1: Add schemas to `backend/app/schemas.py`**

Append after `TagEntidadeOut`:

```python
# -- Agentes --
class AgenteConfigCreate(BaseModel):
    nome: str
    usuario_id: int
    descricao: str | None = None
    instrucoes_sistema: str | None = None
    modelo_claude: str = "claude-sonnet-4-5-20250514"
    ferramentas_habilitadas: list[str] = []
    contexto_referencia: str | None = None
    max_tokens: int = 4096
    max_iteracoes_tool: int = 10


class AgenteConfigUpdate(BaseModel):
    nome: str | None = None
    descricao: str | None = None
    instrucoes_sistema: str | None = None
    modelo_claude: str | None = None
    ferramentas_habilitadas: list[str] | None = None
    contexto_referencia: str | None = None
    max_tokens: int | None = None
    max_iteracoes_tool: int | None = None
    ativo: bool | None = None


class AgenteConfigOut(BaseModel):
    id: int
    usuario_id: int
    nome: str
    descricao: str | None
    instrucoes_sistema: str | None
    modelo_claude: str
    ferramentas_habilitadas: list[str]
    contexto_referencia: str | None
    max_tokens: int
    max_iteracoes_tool: int
    ativo: bool
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}

    @classmethod
    def from_orm_with_tools(cls, obj):
        """Converte ferramentas_habilitadas de JSON string para list."""
        import json
        data = {c.key: getattr(obj, c.key) for c in obj.__table__.columns}
        data["ferramentas_habilitadas"] = json.loads(data.get("ferramentas_habilitadas", "[]"))
        return cls(**data)


class FerramentaDisponivel(BaseModel):
    nome: str
    descricao_ui: str
    categoria: str
```

Modify `ConversaCreate` to accept `agente_id`:
```python
class ConversaCreate(BaseModel):
    titulo: str | None = None
    processo_id: int | None = None
    usuario_id: int
    modelo_claude: str = "claude-haiku-4-5-20251001"
    agente_id: int | None = None
```

Modify `ConversaOut` to include `agente_id`:
```python
class ConversaOut(BaseModel):
    id: int
    titulo: str | None
    usuario_id: int
    processo_id: int | None
    modelo_claude: str
    agente_id: int | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}
```

**Step 2: Verify imports**

Run: `cd backend && .venv/bin/python -c "from app.schemas import AgenteConfigCreate, AgenteConfigOut, FerramentaDisponivel; print('OK')"`
Expected: OK

---

### Task 3: Router CRUD Agentes

**Files:**
- Create: `backend/app/routers/agentes.py`
- Modify: `backend/app/main.py` (registrar router)

**Step 1: Create `backend/app/routers/agentes.py`**

```python
import json

from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import AgenteConfig, Usuario
from app.schemas import (
    AgenteConfigCreate,
    AgenteConfigOut,
    AgenteConfigUpdate,
    FerramentaDisponivel,
)

router = APIRouter(prefix="/agentes", tags=["agentes"])


@router.get("/ferramentas/disponiveis", response_model=list[FerramentaDisponivel])
def listar_ferramentas_disponiveis():
    from app.services.ferramentas import FERRAMENTAS_DISPONIVEIS
    return [
        FerramentaDisponivel(nome=k, descricao_ui=v["descricao_ui"], categoria=v["categoria"])
        for k, v in FERRAMENTAS_DISPONIVEIS.items()
    ]


@router.post("/", response_model=AgenteConfigOut, status_code=201)
def criar_agente(payload: AgenteConfigCreate, db: Session = Depends(get_db)):
    usuario = db.query(Usuario).filter(Usuario.id == payload.usuario_id).first()
    if not usuario:
        raise HTTPException(status_code=404, detail="Usuario nao encontrado")

    agente = AgenteConfig(
        usuario_id=payload.usuario_id,
        nome=payload.nome,
        descricao=payload.descricao,
        instrucoes_sistema=payload.instrucoes_sistema,
        modelo_claude=payload.modelo_claude,
        ferramentas_habilitadas=json.dumps(payload.ferramentas_habilitadas),
        contexto_referencia=payload.contexto_referencia,
        max_tokens=payload.max_tokens,
        max_iteracoes_tool=payload.max_iteracoes_tool,
    )
    db.add(agente)
    db.commit()
    db.refresh(agente)
    return AgenteConfigOut.from_orm_with_tools(agente)


@router.get("/", response_model=list[AgenteConfigOut])
def listar_agentes(usuario_id: int | None = None, db: Session = Depends(get_db)):
    q = db.query(AgenteConfig)
    if usuario_id is not None:
        q = q.filter(AgenteConfig.usuario_id == usuario_id)
    agentes = q.order_by(AgenteConfig.updated_at.desc()).all()
    return [AgenteConfigOut.from_orm_with_tools(a) for a in agentes]


@router.get("/{agente_id}", response_model=AgenteConfigOut)
def detalhe_agente(agente_id: int, db: Session = Depends(get_db)):
    agente = db.query(AgenteConfig).filter(AgenteConfig.id == agente_id).first()
    if not agente:
        raise HTTPException(status_code=404, detail="Agente nao encontrado")
    return AgenteConfigOut.from_orm_with_tools(agente)


@router.put("/{agente_id}", response_model=AgenteConfigOut)
def atualizar_agente(agente_id: int, payload: AgenteConfigUpdate, db: Session = Depends(get_db)):
    agente = db.query(AgenteConfig).filter(AgenteConfig.id == agente_id).first()
    if not agente:
        raise HTTPException(status_code=404, detail="Agente nao encontrado")

    update_data = payload.model_dump(exclude_unset=True)
    if "ferramentas_habilitadas" in update_data:
        update_data["ferramentas_habilitadas"] = json.dumps(update_data["ferramentas_habilitadas"])

    for key, value in update_data.items():
        setattr(agente, key, value)

    db.commit()
    db.refresh(agente)
    return AgenteConfigOut.from_orm_with_tools(agente)


@router.delete("/{agente_id}", status_code=204)
def deletar_agente(agente_id: int, db: Session = Depends(get_db)):
    agente = db.query(AgenteConfig).filter(AgenteConfig.id == agente_id).first()
    if not agente:
        raise HTTPException(status_code=404, detail="Agente nao encontrado")
    db.delete(agente)
    db.commit()
```

**Step 2: Register router in `backend/app/main.py`**

Add to imports:
```python
from app.routers import agentes, chat, clientes, financeiro, prazos, processos, tags, vindi, vindi_webhook
```

Add before `chat.router`:
```python
app.include_router(agentes.router)
```

**Step 3: Update `backend/app/routers/chat.py` to accept `agente_id`**

In `criar_conversa`, add `agente_id` to the `Conversa()` constructor:
```python
    conversa = Conversa(
        titulo=payload.titulo,
        usuario_id=payload.usuario_id,
        processo_id=payload.processo_id,
        modelo_claude=payload.modelo_claude,
        agente_id=payload.agente_id,
    )
```

**Step 4: Run test**

Run: `cd backend && .venv/bin/python -m pytest tests/test_agentes.py::test_criar_agente -v`
Expected: FAIL (ferramentas module nao existe ainda — ImportError no endpoint `disponiveis`)

Nota: O teste `test_criar_agente` vai passar pois nao chama `/ferramentas/disponiveis`. Se der import error no startup, crie o modulo vazio primeiro (Task 4).

---

### Task 4: Registry de Ferramentas — Estrutura base

**Files:**
- Create: `backend/app/services/ferramentas/__init__.py`
- Create: `backend/app/services/ferramentas/processo.py`
- Create: `backend/app/services/ferramentas/cliente.py`
- Create: `backend/app/services/ferramentas/prazo.py`
- Create: `backend/app/services/ferramentas/financeiro.py`

**Step 1: Write failing test for ferramentas**

Add to `backend/tests/test_agentes.py`:

```python
def test_listar_ferramentas_disponiveis(client):
    resp = client.get("/agentes/ferramentas/disponiveis")
    assert resp.status_code == 200
    data = resp.json()
    assert len(data) >= 5
    nomes = [f["nome"] for f in data]
    assert "buscar_processo" in nomes
    assert "buscar_cliente" in nomes
    assert "calcular_prazo" in nomes
    for f in data:
        assert "descricao_ui" in f
        assert "categoria" in f
```

**Step 2: Create `backend/app/services/ferramentas/__init__.py`**

```python
from app.services.ferramentas.processo import (
    SCHEMA_BUSCAR_PROCESSO, executar_buscar_processo,
    SCHEMA_LISTAR_MOVIMENTOS, executar_listar_movimentos,
)
from app.services.ferramentas.cliente import (
    SCHEMA_BUSCAR_CLIENTE, executar_buscar_cliente,
)
from app.services.ferramentas.prazo import (
    SCHEMA_CALCULAR_PRAZO, executar_calcular_prazo,
    SCHEMA_LISTAR_PRAZOS, executar_listar_prazos,
)
from app.services.ferramentas.financeiro import (
    SCHEMA_RESUMO_FINANCEIRO, executar_resumo_financeiro,
)

FERRAMENTAS_DISPONIVEIS: dict[str, dict] = {
    "buscar_processo": {
        "schema": SCHEMA_BUSCAR_PROCESSO,
        "executor": executar_buscar_processo,
        "descricao_ui": "Consulta dados completos de um processo pelo numero CNJ",
        "categoria": "processo",
    },
    "listar_movimentos": {
        "schema": SCHEMA_LISTAR_MOVIMENTOS,
        "executor": executar_listar_movimentos,
        "descricao_ui": "Lista os ultimos movimentos/andamentos de um processo",
        "categoria": "processo",
    },
    "buscar_cliente": {
        "schema": SCHEMA_BUSCAR_CLIENTE,
        "executor": executar_buscar_cliente,
        "descricao_ui": "Busca dados de um cliente por nome ou CPF/CNPJ",
        "categoria": "cliente",
    },
    "calcular_prazo": {
        "schema": SCHEMA_CALCULAR_PRAZO,
        "executor": executar_calcular_prazo,
        "descricao_ui": "Calcula prazo processual em dias uteis a partir de uma data",
        "categoria": "prazo",
    },
    "listar_prazos": {
        "schema": SCHEMA_LISTAR_PRAZOS,
        "executor": executar_listar_prazos,
        "descricao_ui": "Lista prazos pendentes de um processo",
        "categoria": "prazo",
    },
    "resumo_financeiro": {
        "schema": SCHEMA_RESUMO_FINANCEIRO,
        "executor": executar_resumo_financeiro,
        "descricao_ui": "Resume posicao financeira de um processo ou cliente",
        "categoria": "financeiro",
    },
}
```

**Step 3: Create `backend/app/services/ferramentas/processo.py`**

```python
from sqlalchemy.orm import Session
from app.models import Processo, Movimento, ProcessoParte


SCHEMA_BUSCAR_PROCESSO = {
    "name": "buscar_processo",
    "description": "Busca dados completos de um processo judicial pelo numero CNJ. Retorna tribunal, classe, orgao julgador, partes e status.",
    "input_schema": {
        "type": "object",
        "properties": {
            "cnj": {
                "type": "string",
                "description": "Numero CNJ no formato NNNNNNN-DD.AAAA.J.TT.OOOO",
            },
        },
        "required": ["cnj"],
    },
}


def executar_buscar_processo(input_data: dict, db: Session) -> str:
    cnj = input_data.get("cnj", "").strip()
    processo = db.query(Processo).filter(Processo.cnj == cnj).first()
    if not processo:
        return f"Processo com CNJ {cnj} nao encontrado no sistema."

    partes = (
        db.query(ProcessoParte)
        .filter(ProcessoParte.processo_id == processo.id)
        .all()
    )

    linhas = [
        f"PROCESSO: {processo.cnj}",
        f"Tribunal: {processo.tribunal} ({processo.alias_tribunal})",
        f"Classe: {processo.classe_nome or 'N/A'}",
        f"Orgao Julgador: {processo.orgao_julgador or 'N/A'}",
        f"Grau: {processo.grau or 'N/A'}",
        f"Status: {processo.status}",
    ]
    if processo.data_ajuizamento:
        linhas.append(f"Ajuizamento: {processo.data_ajuizamento.strftime('%d/%m/%Y')}")

    if partes:
        linhas.append("")
        linhas.append("PARTES:")
        for p in partes:
            cliente = p.cliente
            linhas.append(f"  {p.papel.upper()}: {cliente.nome} (CPF/CNPJ: {cliente.cpf_cnpj})")

    return "\n".join(linhas)


SCHEMA_LISTAR_MOVIMENTOS = {
    "name": "listar_movimentos",
    "description": "Lista os ultimos movimentos/andamentos de um processo. Retorna data, nome e resumo IA de cada movimento.",
    "input_schema": {
        "type": "object",
        "properties": {
            "processo_id": {
                "type": "integer",
                "description": "ID do processo no sistema",
            },
            "limite": {
                "type": "integer",
                "description": "Quantidade maxima de movimentos (padrao 20)",
            },
        },
        "required": ["processo_id"],
    },
}


def executar_listar_movimentos(input_data: dict, db: Session) -> str:
    processo_id = input_data["processo_id"]
    limite = input_data.get("limite", 20)

    movimentos = (
        db.query(Movimento)
        .filter(Movimento.processo_id == processo_id)
        .order_by(Movimento.data_hora.desc())
        .limit(limite)
        .all()
    )

    if not movimentos:
        return f"Nenhum movimento encontrado para o processo ID {processo_id}."

    linhas = [f"MOVIMENTOS DO PROCESSO (ultimos {len(movimentos)}):"]
    for m in movimentos:
        data_str = m.data_hora.strftime("%d/%m/%Y %H:%M")
        linhas.append(f"  [{data_str}] {m.nome}")
        if m.resumo_ia:
            linhas.append(f"    Resumo: {m.resumo_ia}")

    return "\n".join(linhas)
```

**Step 4: Create `backend/app/services/ferramentas/cliente.py`**

```python
from sqlalchemy.orm import Session
from app.models import Cliente


SCHEMA_BUSCAR_CLIENTE = {
    "name": "buscar_cliente",
    "description": "Busca dados de um cliente por nome ou CPF/CNPJ. Retorna dados pessoais, contato e endereco.",
    "input_schema": {
        "type": "object",
        "properties": {
            "busca": {
                "type": "string",
                "description": "Nome parcial ou CPF/CNPJ do cliente",
            },
        },
        "required": ["busca"],
    },
}


def executar_buscar_cliente(input_data: dict, db: Session) -> str:
    busca = input_data.get("busca", "").strip()
    if not busca:
        return "Parametro de busca vazio."

    # Tenta por CPF/CNPJ exato primeiro
    cliente = db.query(Cliente).filter(Cliente.cpf_cnpj == busca).first()
    if not cliente:
        # Busca por nome parcial
        clientes = (
            db.query(Cliente)
            .filter(Cliente.nome.ilike(f"%{busca}%"))
            .limit(5)
            .all()
        )
        if not clientes:
            return f"Nenhum cliente encontrado para '{busca}'."
        if len(clientes) == 1:
            cliente = clientes[0]
        else:
            linhas = [f"Encontrados {len(clientes)} clientes:"]
            for c in clientes:
                linhas.append(f"  ID {c.id}: {c.nome} (CPF/CNPJ: {c.cpf_cnpj})")
            return "\n".join(linhas)

    linhas = [
        f"CLIENTE: {cliente.nome}",
        f"CPF/CNPJ: {cliente.cpf_cnpj}",
        f"Telefone: {cliente.telefone}",
    ]
    if cliente.email:
        linhas.append(f"Email: {cliente.email}")
    if cliente.endereco:
        linhas.append(f"Endereco: {cliente.endereco}")
        if cliente.cidade:
            linhas.append(f"Cidade: {cliente.cidade}/{cliente.uf} CEP: {cliente.cep or 'N/A'}")
    if cliente.profissao:
        linhas.append(f"Profissao: {cliente.profissao}")
    if cliente.estado_civil:
        linhas.append(f"Estado Civil: {cliente.estado_civil}")

    return "\n".join(linhas)
```

**Step 5: Create `backend/app/services/ferramentas/prazo.py`**

```python
from datetime import date, timedelta
from sqlalchemy.orm import Session
from app.models import Prazo


SCHEMA_CALCULAR_PRAZO = {
    "name": "calcular_prazo",
    "description": "Calcula prazo processual em dias uteis a partir de uma data. Considera finais de semana (nao considera feriados).",
    "input_schema": {
        "type": "object",
        "properties": {
            "data_inicio": {
                "type": "string",
                "description": "Data de inicio no formato AAAA-MM-DD",
            },
            "dias": {
                "type": "integer",
                "description": "Quantidade de dias do prazo",
            },
            "tipo": {
                "type": "string",
                "enum": ["uteis", "corridos"],
                "description": "Tipo do prazo: uteis ou corridos (padrao: uteis)",
            },
        },
        "required": ["data_inicio", "dias"],
    },
}


def executar_calcular_prazo(input_data: dict, db: Session) -> str:
    try:
        data_inicio = date.fromisoformat(input_data["data_inicio"])
    except (ValueError, KeyError):
        return "Data de inicio invalida. Use formato AAAA-MM-DD."

    dias = input_data.get("dias", 15)
    tipo = input_data.get("tipo", "uteis")

    if tipo == "corridos":
        data_final = data_inicio + timedelta(days=dias)
    else:
        dias_contados = 0
        data_final = data_inicio
        while dias_contados < dias:
            data_final += timedelta(days=1)
            if data_final.weekday() < 5:  # seg-sex
                dias_contados += 1

    return (
        f"CALCULO DE PRAZO:\n"
        f"  Inicio: {data_inicio.strftime('%d/%m/%Y')} ({_dia_semana(data_inicio)})\n"
        f"  Prazo: {dias} dias {tipo}\n"
        f"  Vencimento: {data_final.strftime('%d/%m/%Y')} ({_dia_semana(data_final)})\n"
        f"  Nota: calculo nao considera feriados"
    )


def _dia_semana(d: date) -> str:
    nomes = ["segunda", "terca", "quarta", "quinta", "sexta", "sabado", "domingo"]
    return nomes[d.weekday()]


SCHEMA_LISTAR_PRAZOS = {
    "name": "listar_prazos",
    "description": "Lista prazos pendentes de um processo ou todos os prazos pendentes do escritorio.",
    "input_schema": {
        "type": "object",
        "properties": {
            "processo_id": {
                "type": "integer",
                "description": "ID do processo (opcional — se omitido, lista todos os prazos pendentes)",
            },
        },
    },
}


def executar_listar_prazos(input_data: dict, db: Session) -> str:
    q = db.query(Prazo).filter(Prazo.status == "pendente")
    processo_id = input_data.get("processo_id")
    if processo_id:
        q = q.filter(Prazo.processo_id == processo_id)

    prazos = q.order_by(Prazo.data_limite).limit(20).all()

    if not prazos:
        return "Nenhum prazo pendente encontrado."

    linhas = [f"PRAZOS PENDENTES ({len(prazos)}):"]
    for p in prazos:
        venc = p.data_limite.strftime("%d/%m/%Y")
        dias_restantes = (p.data_limite - date.today()).days
        urgencia = "VENCIDO" if dias_restantes < 0 else f"{dias_restantes}d restantes"
        linhas.append(f"  [{venc}] {p.tipo} — {p.descricao or 'Sem descricao'} ({urgencia})")

    return "\n".join(linhas)
```

**Step 6: Create `backend/app/services/ferramentas/financeiro.py`**

```python
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models import Financeiro


SCHEMA_RESUMO_FINANCEIRO = {
    "name": "resumo_financeiro",
    "description": "Resume a posicao financeira de um processo especifico. Mostra totais pendentes, pagos e lancamentos detalhados.",
    "input_schema": {
        "type": "object",
        "properties": {
            "processo_id": {
                "type": "integer",
                "description": "ID do processo",
            },
        },
        "required": ["processo_id"],
    },
}


def executar_resumo_financeiro(input_data: dict, db: Session) -> str:
    processo_id = input_data["processo_id"]

    lancamentos = (
        db.query(Financeiro)
        .filter(Financeiro.processo_id == processo_id)
        .order_by(Financeiro.data_vencimento)
        .all()
    )

    if not lancamentos:
        return f"Nenhum lancamento financeiro para o processo ID {processo_id}."

    total_pendente = sum(float(f.valor) for f in lancamentos if f.status == "pendente")
    total_pago = sum(float(f.valor) for f in lancamentos if f.status == "pago")

    linhas = [
        f"FINANCEIRO DO PROCESSO #{processo_id}:",
        f"  Total pendente: R$ {total_pendente:,.2f}",
        f"  Total pago: R$ {total_pago:,.2f}",
        f"  Total geral: R$ {total_pendente + total_pago:,.2f}",
        "",
        "LANCAMENTOS:",
    ]
    for f in lancamentos:
        venc = f.data_vencimento.strftime("%d/%m/%Y") if f.data_vencimento else "S/D"
        linhas.append(f"  [{f.status.upper()}] {f.tipo} — R$ {float(f.valor):,.2f} — Venc: {venc} — {f.descricao or ''}")

    return "\n".join(linhas)
```

**Step 7: Run tests**

Run: `cd backend && .venv/bin/python -m pytest tests/test_agentes.py -v`
Expected: PASS (ambos testes)

**Step 8: Commit**

```bash
git add backend/app/models.py backend/app/schemas.py backend/app/routers/agentes.py backend/app/routers/chat.py backend/app/main.py backend/app/services/ferramentas/ backend/tests/test_agentes.py
git commit -m "feat: modelo AgenteConfig + registry ferramentas juridicas + CRUD agentes"
```

---

### Task 5: Testes unitarios das ferramentas

**Files:**
- Create: `backend/tests/test_ferramentas.py`

**Step 1: Write tests**

```python
from datetime import datetime, date
from app.models import Cliente, Processo, ProcessoParte, Movimento, Prazo, Financeiro
from app.services.ferramentas.processo import executar_buscar_processo, executar_listar_movimentos
from app.services.ferramentas.cliente import executar_buscar_cliente
from app.services.ferramentas.prazo import executar_calcular_prazo, executar_listar_prazos
from app.services.ferramentas.financeiro import executar_resumo_financeiro


def _criar_processo_completo(db):
    cliente = Cliente(nome="Joao Silva", cpf_cnpj="123.456.789-00", telefone="11999999999")
    db.add(cliente)
    db.flush()

    processo = Processo(
        cnj="0000001-23.2024.8.26.0100",
        numero_limpo="00000012320248260100",
        tribunal="TJSP",
        alias_tribunal="tjsp",
        classe_nome="Acao Civil",
        orgao_julgador="1a Vara Civel",
        grau="G1",
        status="ativo",
    )
    db.add(processo)
    db.flush()

    parte = ProcessoParte(processo_id=processo.id, cliente_id=cliente.id, papel="autor")
    db.add(parte)

    mov = Movimento(
        processo_id=processo.id,
        codigo=12345,
        nome="Distribuicao",
        data_hora=datetime(2024, 6, 15, 10, 30),
        resumo_ia="Processo distribuido para 1a Vara",
    )
    db.add(mov)

    prazo = Prazo(
        processo_id=processo.id,
        tipo="contestacao",
        descricao="Prazo para contestacao",
        data_limite=date(2026, 12, 31),
        status="pendente",
    )
    db.add(prazo)

    fin = Financeiro(
        processo_id=processo.id,
        cliente_id=cliente.id,
        tipo="honorario",
        descricao="Honorarios iniciais",
        valor=5000.00,
        status="pendente",
        data_vencimento=date(2026, 7, 15),
    )
    db.add(fin)
    db.commit()

    return processo, cliente


def test_buscar_processo_existente(db):
    processo, cliente = _criar_processo_completo(db)
    resultado = executar_buscar_processo({"cnj": processo.cnj}, db)
    assert "PROCESSO:" in resultado
    assert "TJSP" in resultado
    assert "Joao Silva" in resultado
    assert "AUTOR" in resultado


def test_buscar_processo_inexistente(db):
    resultado = executar_buscar_processo({"cnj": "9999999-99.9999.9.99.9999"}, db)
    assert "nao encontrado" in resultado


def test_listar_movimentos(db):
    processo, _ = _criar_processo_completo(db)
    resultado = executar_listar_movimentos({"processo_id": processo.id}, db)
    assert "Distribuicao" in resultado
    assert "Resumo:" in resultado


def test_buscar_cliente_por_cpf(db):
    _criar_processo_completo(db)
    resultado = executar_buscar_cliente({"busca": "123.456.789-00"}, db)
    assert "Joao Silva" in resultado


def test_buscar_cliente_por_nome(db):
    _criar_processo_completo(db)
    resultado = executar_buscar_cliente({"busca": "Joao"}, db)
    assert "Joao Silva" in resultado


def test_calcular_prazo_uteis(db):
    resultado = executar_calcular_prazo({"data_inicio": "2026-03-09", "dias": 15}, db)
    assert "Vencimento:" in resultado
    assert "30/03/2026" in resultado  # 15 dias uteis a partir de 09/03 (segunda)


def test_calcular_prazo_corridos(db):
    resultado = executar_calcular_prazo({"data_inicio": "2026-03-09", "dias": 15, "tipo": "corridos"}, db)
    assert "24/03/2026" in resultado


def test_listar_prazos_pendentes(db):
    processo, _ = _criar_processo_completo(db)
    resultado = executar_listar_prazos({"processo_id": processo.id}, db)
    assert "contestacao" in resultado
    assert "PRAZOS PENDENTES" in resultado


def test_resumo_financeiro(db):
    processo, _ = _criar_processo_completo(db)
    resultado = executar_resumo_financeiro({"processo_id": processo.id}, db)
    assert "R$" in resultado
    assert "PENDENTE" in resultado
    assert "honorario" in resultado
```

**Step 2: Run tests**

Run: `cd backend && .venv/bin/python -m pytest tests/test_ferramentas.py -v`
Expected: PASS (todos)

**Step 3: Commit**

```bash
git add backend/tests/test_ferramentas.py
git commit -m "test: testes unitarios para ferramentas juridicas (processo, cliente, prazo, financeiro)"
```

---

### Task 6: Service `agente_chat.py` — Tool loop com streaming

**Files:**
- Create: `backend/app/services/agente_chat.py`

**Step 1: Write failing test**

Create `backend/tests/test_agente_chat.py`:

```python
import json
from unittest.mock import patch, MagicMock

from app.models import Usuario, AgenteConfig, Conversa, Mensagem


def _setup_agente(db):
    usuario = Usuario(nome="Adv Teste", email="adv@chat.com", oab="12345/SP")
    db.add(usuario)
    db.flush()

    agente = AgenteConfig(
        usuario_id=usuario.id,
        nome="Agente Teste",
        instrucoes_sistema="Voce eh especialista em trabalhista",
        modelo_claude="claude-sonnet-4-5-20250514",
        ferramentas_habilitadas=json.dumps(["buscar_processo"]),
    )
    db.add(agente)
    db.flush()

    conversa = Conversa(
        titulo="Chat com agente",
        usuario_id=usuario.id,
        agente_id=agente.id,
        modelo_claude=agente.modelo_claude,
    )
    db.add(conversa)
    db.commit()
    db.refresh(conversa)
    return conversa


def _mock_response_end_turn(text="Resposta do agente"):
    """Mock de resposta simples sem tool use."""
    mock_response = MagicMock()
    mock_response.stop_reason = "end_turn"
    text_block = MagicMock()
    text_block.type = "text"
    text_block.text = text
    mock_response.content = [text_block]
    mock_response.usage = MagicMock(input_tokens=100, output_tokens=50)
    return mock_response


def _mock_response_tool_use(tool_name, tool_input):
    """Mock de resposta com tool use."""
    mock_response = MagicMock()
    mock_response.stop_reason = "tool_use"
    tool_block = MagicMock()
    tool_block.type = "tool_use"
    tool_block.name = tool_name
    tool_block.id = "toolu_test123"
    tool_block.input = tool_input
    text_block = MagicMock()
    text_block.type = "text"
    text_block.text = "Vou buscar o processo..."
    mock_response.content = [text_block, tool_block]
    mock_response.usage = MagicMock(input_tokens=150, output_tokens=30)
    return mock_response


def test_chat_agente_simples_sem_tools(client, db):
    """Agente responde sem chamar ferramentas."""
    conversa = _setup_agente(db)

    with patch("app.services.agente_chat.get_anthropic_client") as mock_get:
        mock_client = MagicMock()
        mock_client.messages.create.return_value = _mock_response_end_turn("Resposta direta")
        mock_get.return_value = mock_client

        resp = client.post(f"/conversas/{conversa.id}/mensagens", json={
            "mensagem": "Qual o prazo de contestacao?",
        })

    assert resp.status_code == 200
    data = resp.json()
    assert data["resposta"] == "Resposta direta"


def test_chat_agente_com_tool_use(client, db):
    """Agente chama ferramenta e depois responde."""
    conversa = _setup_agente(db)

    call_count = 0

    def create_side_effect(**kwargs):
        nonlocal call_count
        call_count += 1
        if call_count == 1:
            return _mock_response_tool_use("buscar_processo", {"cnj": "0000001-23.2024.8.26.0100"})
        return _mock_response_end_turn("Encontrei o processo. O status eh ativo.")

    with patch("app.services.agente_chat.get_anthropic_client") as mock_get:
        mock_client = MagicMock()
        mock_client.messages.create.side_effect = create_side_effect
        mock_get.return_value = mock_client

        resp = client.post(f"/conversas/{conversa.id}/mensagens", json={
            "mensagem": "Busque o processo 0000001-23.2024.8.26.0100",
        })

    assert resp.status_code == 200
    data = resp.json()
    assert "processo" in data["resposta"].lower() or "ativo" in data["resposta"].lower()
    # Verifica que houve 2 chamadas a API (1 tool_use + 1 end_turn)
    assert call_count == 2


def test_conversa_sem_agente_usa_chat_antigo(client, db):
    """Conversa sem agente_id usa o service antigo."""
    usuario = Usuario(nome="Adv Sem Agente", email="adv@sem.com", oab="99999/SP")
    db.add(usuario)
    db.commit()
    db.refresh(usuario)

    resp = client.post("/conversas/", json={
        "titulo": "Sem agente",
        "usuario_id": usuario.id,
    })
    cid = resp.json()["id"]

    mock_response = MagicMock()
    mock_response.content = [MagicMock(text="Resposta simples")]
    mock_response.usage = MagicMock(input_tokens=80, output_tokens=40)

    with patch("app.services.claude_chat.get_anthropic_client") as mock_get:
        mock_client = MagicMock()
        mock_client.messages.create.return_value = mock_response
        mock_get.return_value = mock_client

        resp = client.post(f"/conversas/{cid}/mensagens", json={
            "mensagem": "Oi",
        })

    assert resp.status_code == 200
    assert resp.json()["resposta"] == "Resposta simples"
```

**Step 2: Create `backend/app/services/agente_chat.py`**

```python
import json
import time
from sqlalchemy.orm import Session

from app.models import Conversa, Mensagem, AgenteConfig, ToolExecution
from app.services.claude_chat import (
    get_anthropic_client,
    SYSTEM_PROMPT_JURIDICO,
    montar_config_escritorio,
    montar_contexto_processo,
    carregar_historico,
)
from app.services.ferramentas import FERRAMENTAS_DISPONIVEIS


def montar_system_prompt_agente(agente: AgenteConfig, db: Session, processo_id: int | None) -> str:
    """Combina prompt base + instrucoes customizadas + config escritorio + contexto processo."""
    parts = [SYSTEM_PROMPT_JURIDICO]

    if agente.instrucoes_sistema:
        parts.append(f"\nINSTRUCOES ADICIONAIS DO AGENTE '{agente.nome}':\n{agente.instrucoes_sistema}")

    if agente.contexto_referencia:
        parts.append(f"\nCONTEXTO DE REFERENCIA:\n{agente.contexto_referencia}")

    parts.append(montar_config_escritorio(db))

    if processo_id:
        parts.append(montar_contexto_processo(db, processo_id))

    return "\n".join(parts)


def _obter_tool_schemas(ferramentas_habilitadas: list[str]) -> list[dict]:
    """Retorna os schemas das ferramentas habilitadas para o agente."""
    schemas = []
    for nome in ferramentas_habilitadas:
        if nome in FERRAMENTAS_DISPONIVEIS:
            schemas.append(FERRAMENTAS_DISPONIVEIS[nome]["schema"])
    return schemas


def _executar_ferramenta(tool_name: str, tool_input: dict, tool_use_id: str, db: Session, conversa_id: int) -> str:
    """Executa uma ferramenta e registra no banco."""
    inicio = time.time()
    erro = None
    resultado = ""

    try:
        if tool_name not in FERRAMENTAS_DISPONIVEIS:
            resultado = f"Ferramenta '{tool_name}' nao disponivel."
        else:
            executor = FERRAMENTAS_DISPONIVEIS[tool_name]["executor"]
            resultado = executor(tool_input, db)
    except Exception as e:
        erro = str(e)
        resultado = f"Erro ao executar ferramenta: {e}"

    duracao = int((time.time() - inicio) * 1000)

    log = ToolExecution(
        conversa_id=conversa_id,
        tool_name=tool_name,
        tool_use_id=tool_use_id,
        input_json=json.dumps(tool_input, ensure_ascii=False),
        output_json=resultado if not erro else None,
        erro=erro,
        duracao_ms=duracao,
    )
    db.add(log)
    db.flush()

    return resultado


def chat_com_agente(
    db: Session,
    conversa_id: int,
    mensagem_usuario: str,
) -> dict:
    """Chat com agente que pode usar ferramentas. Loop sincrono."""
    conversa = db.query(Conversa).filter(Conversa.id == conversa_id).first()
    if not conversa:
        raise ValueError("Conversa nao encontrada")

    agente = conversa.agente_config
    if not agente:
        raise ValueError("Conversa nao tem agente configurado")

    ferramentas = json.loads(agente.ferramentas_habilitadas)
    tool_schemas = _obter_tool_schemas(ferramentas)

    system_prompt = montar_system_prompt_agente(agente, db, conversa.processo_id)
    historico = carregar_historico(db, conversa_id)
    historico.append({"role": "user", "content": mensagem_usuario})

    client = get_anthropic_client()
    iteracao = 0
    texto_acumulado = ""
    total_input = 0
    total_output = 0

    while iteracao < agente.max_iteracoes_tool:
        kwargs = {
            "model": agente.modelo_claude,
            "max_tokens": agente.max_tokens,
            "system": system_prompt,
            "messages": historico,
        }
        if tool_schemas:
            kwargs["tools"] = tool_schemas

        response = client.messages.create(**kwargs)

        total_input += response.usage.input_tokens
        total_output += response.usage.output_tokens

        if response.stop_reason == "end_turn":
            # Extrai texto da resposta final
            for block in response.content:
                if hasattr(block, "text"):
                    texto_acumulado += block.text
            break

        if response.stop_reason == "tool_use":
            # Processa blocos de texto + tool_use
            assistant_content = []
            for block in response.content:
                if hasattr(block, "text") and block.type == "text":
                    texto_acumulado += block.text
                    assistant_content.append({"type": "text", "text": block.text})
                elif block.type == "tool_use":
                    assistant_content.append({
                        "type": "tool_use",
                        "id": block.id,
                        "name": block.name,
                        "input": block.input,
                    })

            # Adiciona resposta do assistente ao historico
            historico.append({"role": "assistant", "content": assistant_content})

            # Executa ferramentas e coleta resultados
            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    resultado = _executar_ferramenta(
                        block.name, block.input, block.id, db, conversa_id
                    )
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": resultado,
                    })

            historico.append({"role": "user", "content": tool_results})

        iteracao += 1

    # Salva mensagens
    msg_user = Mensagem(
        conversa_id=conversa_id,
        role="user",
        conteudo=mensagem_usuario,
        tokens_input=total_input,
    )
    msg_assistant = Mensagem(
        conversa_id=conversa_id,
        role="assistant",
        conteudo=texto_acumulado,
        tokens_output=total_output,
    )
    db.add_all([msg_user, msg_assistant])
    db.commit()

    return {
        "resposta": texto_acumulado,
        "modelo": agente.modelo_claude,
        "tokens_input": total_input,
        "tokens_output": total_output,
    }
```

**Step 3: Update `backend/app/routers/chat.py` to use agente_chat**

Replace the `enviar_mensagem` function:

```python
from app.services.agente_chat import chat_com_agente

@router.post("/{conversa_id}/mensagens", response_model=ChatResponse)
def enviar_mensagem(
    conversa_id: int,
    payload: MensagemCreate,
    db: Session = Depends(get_db),
):
    conversa = db.query(Conversa).filter(Conversa.id == conversa_id).first()
    if not conversa:
        raise HTTPException(status_code=404, detail="Conversa nao encontrada")

    try:
        if conversa.agente_id:
            resultado = chat_com_agente(
                db=db,
                conversa_id=conversa_id,
                mensagem_usuario=payload.mensagem,
            )
        else:
            resultado = claude_chat(
                db=db,
                conversa_id=conversa_id,
                mensagem_usuario=payload.mensagem,
                modelo=payload.modelo,
            )
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))
    return resultado
```

Add import `Conversa` to the imports at top:
```python
from app.models import Conversa, Usuario
```

**Step 4: Run tests**

Run: `cd backend && .venv/bin/python -m pytest tests/test_agente_chat.py tests/test_chat.py -v`
Expected: PASS (todos — novos E antigos)

**Step 5: Commit**

```bash
git add backend/app/services/agente_chat.py backend/app/routers/chat.py backend/tests/test_agente_chat.py
git commit -m "feat: service agente_chat com tool loop + integracao no router chat"
```

---

### Task 7: Endpoint SSE streaming

**Files:**
- Modify: `backend/app/services/agente_chat.py` (adicionar funcao streaming)
- Modify: `backend/app/routers/chat.py` (adicionar endpoint SSE)

**Step 1: Write failing test**

Add to `backend/tests/test_agente_chat.py`:

```python
def test_stream_mensagem_agente(client, db):
    """Testa endpoint SSE streaming."""
    conversa = _setup_agente(db)

    with patch("app.services.agente_chat.get_anthropic_client") as mock_get:
        mock_client = MagicMock()
        mock_client.messages.create.return_value = _mock_response_end_turn("Resposta stream")
        mock_get.return_value = mock_client

        with client.stream("POST", f"/conversas/{conversa.id}/mensagens/stream", json={
            "mensagem": "Teste streaming",
        }) as resp:
            assert resp.status_code == 200
            lines = []
            for line in resp.iter_lines():
                if line.startswith("data: "):
                    lines.append(json.loads(line[6:]))

    assert any(e["tipo"] == "texto" for e in lines)
    assert any(e["tipo"] == "fim" for e in lines)
```

**Step 2: Add streaming function to `backend/app/services/agente_chat.py`**

Append after `chat_com_agente`:

```python
def chat_com_agente_stream(
    db: Session,
    conversa_id: int,
    mensagem_usuario: str,
):
    """Chat com agente — versao generator para SSE."""
    conversa = db.query(Conversa).filter(Conversa.id == conversa_id).first()
    if not conversa:
        yield f"data: {json.dumps({'tipo': 'erro', 'mensagem': 'Conversa nao encontrada'})}\n\n"
        return

    agente = conversa.agente_config
    if not agente:
        yield f"data: {json.dumps({'tipo': 'erro', 'mensagem': 'Agente nao configurado'})}\n\n"
        return

    ferramentas = json.loads(agente.ferramentas_habilitadas)
    tool_schemas = _obter_tool_schemas(ferramentas)

    system_prompt = montar_system_prompt_agente(agente, db, conversa.processo_id)
    historico = carregar_historico(db, conversa_id)
    historico.append({"role": "user", "content": mensagem_usuario})

    client = get_anthropic_client()
    iteracao = 0
    texto_acumulado = ""
    total_input = 0
    total_output = 0

    while iteracao < agente.max_iteracoes_tool:
        kwargs = {
            "model": agente.modelo_claude,
            "max_tokens": agente.max_tokens,
            "system": system_prompt,
            "messages": historico,
        }
        if tool_schemas:
            kwargs["tools"] = tool_schemas

        response = client.messages.create(**kwargs)

        total_input += response.usage.input_tokens
        total_output += response.usage.output_tokens

        if response.stop_reason == "end_turn":
            for block in response.content:
                if hasattr(block, "text"):
                    texto_acumulado += block.text
                    yield f"data: {json.dumps({'tipo': 'texto', 'conteudo': block.text}, ensure_ascii=False)}\n\n"
            break

        if response.stop_reason == "tool_use":
            assistant_content = []
            for block in response.content:
                if hasattr(block, "text") and block.type == "text":
                    texto_acumulado += block.text
                    assistant_content.append({"type": "text", "text": block.text})
                    yield f"data: {json.dumps({'tipo': 'texto', 'conteudo': block.text}, ensure_ascii=False)}\n\n"
                elif block.type == "tool_use":
                    assistant_content.append({
                        "type": "tool_use",
                        "id": block.id,
                        "name": block.name,
                        "input": block.input,
                    })
                    yield f"data: {json.dumps({'tipo': 'tool_inicio', 'tool': block.name})}\n\n"

            historico.append({"role": "assistant", "content": assistant_content})

            tool_results = []
            for block in response.content:
                if block.type == "tool_use":
                    resultado = _executar_ferramenta(
                        block.name, block.input, block.id, db, conversa_id
                    )
                    tool_results.append({
                        "type": "tool_result",
                        "tool_use_id": block.id,
                        "content": resultado,
                    })
                    yield f"data: {json.dumps({'tipo': 'tool_resultado', 'tool': block.name})}\n\n"

            historico.append({"role": "user", "content": tool_results})

        iteracao += 1

    # Salva mensagens
    msg_user = Mensagem(
        conversa_id=conversa_id,
        role="user",
        conteudo=mensagem_usuario,
        tokens_input=total_input,
    )
    msg_assistant = Mensagem(
        conversa_id=conversa_id,
        role="assistant",
        conteudo=texto_acumulado,
        tokens_output=total_output,
    )
    db.add_all([msg_user, msg_assistant])
    db.commit()

    yield f"data: {json.dumps({'tipo': 'fim', 'tokens_input': total_input, 'tokens_output': total_output})}\n\n"
```

**Step 3: Add SSE endpoint to `backend/app/routers/chat.py`**

```python
from fastapi.responses import StreamingResponse
from app.services.agente_chat import chat_com_agente, chat_com_agente_stream

@router.post("/{conversa_id}/mensagens/stream")
def stream_mensagem(
    conversa_id: int,
    payload: MensagemCreate,
    db: Session = Depends(get_db),
):
    conversa = db.query(Conversa).filter(Conversa.id == conversa_id).first()
    if not conversa:
        raise HTTPException(status_code=404, detail="Conversa nao encontrada")

    if not conversa.agente_id:
        raise HTTPException(status_code=400, detail="Streaming so disponivel para conversas com agente")

    return StreamingResponse(
        chat_com_agente_stream(db, conversa_id, payload.mensagem),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )
```

**Step 4: Run all tests**

Run: `cd backend && .venv/bin/python -m pytest tests/ -v`
Expected: PASS (todos)

**Step 5: Commit**

```bash
git add backend/app/services/agente_chat.py backend/app/routers/chat.py backend/tests/test_agente_chat.py
git commit -m "feat: endpoint SSE streaming para chat com agente + tool events"
```

---

### Task 8: Testes CRUD completos do router agentes

**Files:**
- Modify: `backend/tests/test_agentes.py`

**Step 1: Add remaining CRUD tests**

Append to `backend/tests/test_agentes.py`:

```python
def test_listar_agentes(client, db):
    usuario = _criar_usuario(db)
    client.post("/agentes/", json={"nome": "A1", "usuario_id": usuario.id})
    client.post("/agentes/", json={"nome": "A2", "usuario_id": usuario.id})

    resp = client.get(f"/agentes/?usuario_id={usuario.id}")
    assert resp.status_code == 200
    assert len(resp.json()) == 2


def test_detalhe_agente(client, db):
    usuario = _criar_usuario(db)
    resp = client.post("/agentes/", json={"nome": "Detalhe", "usuario_id": usuario.id})
    aid = resp.json()["id"]

    resp = client.get(f"/agentes/{aid}")
    assert resp.status_code == 200
    assert resp.json()["nome"] == "Detalhe"


def test_atualizar_agente(client, db):
    usuario = _criar_usuario(db)
    resp = client.post("/agentes/", json={"nome": "V1", "usuario_id": usuario.id})
    aid = resp.json()["id"]

    resp = client.put(f"/agentes/{aid}", json={
        "nome": "V2",
        "ferramentas_habilitadas": ["buscar_processo", "resumo_financeiro"],
        "instrucoes_sistema": "Foco em financeiro",
    })
    assert resp.status_code == 200
    data = resp.json()
    assert data["nome"] == "V2"
    assert "resumo_financeiro" in data["ferramentas_habilitadas"]


def test_deletar_agente(client, db):
    usuario = _criar_usuario(db)
    resp = client.post("/agentes/", json={"nome": "Del", "usuario_id": usuario.id})
    aid = resp.json()["id"]

    resp = client.delete(f"/agentes/{aid}")
    assert resp.status_code == 204

    resp = client.get(f"/agentes/{aid}")
    assert resp.status_code == 404


def test_agente_inexistente(client):
    resp = client.get("/agentes/9999")
    assert resp.status_code == 404


def test_criar_conversa_com_agente(client, db):
    usuario = _criar_usuario(db)
    resp = client.post("/agentes/", json={"nome": "Agente", "usuario_id": usuario.id})
    aid = resp.json()["id"]

    resp = client.post("/conversas/", json={
        "titulo": "Chat com agente",
        "usuario_id": usuario.id,
        "agente_id": aid,
    })
    assert resp.status_code == 201
    assert resp.json()["agente_id"] == aid
```

**Step 2: Run all tests**

Run: `cd backend && .venv/bin/python -m pytest tests/ -v`
Expected: PASS (todos — ~55+ testes)

**Step 3: Commit**

```bash
git add backend/tests/test_agentes.py
git commit -m "test: CRUD completo agentes + criacao conversa com agente"
```

---

### Task 9: Adicionar metodo `getAgentes` e `criarAgente` ao ApiService Flutter

**Files:**
- Modify: `frontend/lib/services/api_service.dart`

**Step 1: Add agentes API methods**

Append after a secao `// -- Chat / Conversas --`:

```dart
  // ── Agentes ─────────────────────────────────
  Future<List<dynamic>> getAgentes({int? usuarioId}) async {
    final query = usuarioId != null ? '?usuario_id=$usuarioId' : '';
    final resp = await _client.get(Uri.parse('$baseUrl/agentes/$query'));
    return _handleList(resp);
  }

  Future<Map<String, dynamic>> getAgente(int id) async {
    final resp = await _client.get(Uri.parse('$baseUrl/agentes/$id'));
    return _handleMap(resp);
  }

  Future<Map<String, dynamic>> criarAgente(Map<String, dynamic> data) async {
    final resp = await _client.post(
      Uri.parse('$baseUrl/agentes/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return _handleMap(resp);
  }

  Future<Map<String, dynamic>> atualizarAgente(int id, Map<String, dynamic> data) async {
    final resp = await _client.put(
      Uri.parse('$baseUrl/agentes/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(data),
    );
    return _handleMap(resp);
  }

  Future<void> deletarAgente(int id) async {
    await _client.delete(Uri.parse('$baseUrl/agentes/$id'));
  }

  Future<List<dynamic>> getFerramentasDisponiveis() async {
    final resp = await _client.get(Uri.parse('$baseUrl/agentes/ferramentas/disponiveis'));
    return _handleList(resp);
  }
```

**Step 2: Commit**

```bash
git add frontend/lib/services/api_service.dart
git commit -m "feat: metodos API agentes no Flutter ApiService"
```

---

### Task 10: Run full test suite + final commit

**Step 1: Run all backend tests**

Run: `cd backend && .venv/bin/python -m pytest tests/ -v`
Expected: ALL PASS

**Step 2: Verify imports are clean**

Run: `cd backend && .venv/bin/python -c "from app.main import app; print('OK')"`
Expected: OK

**Step 3: Final commit if any unstaged changes**

```bash
git add -A
git status
# Se houver changes: git commit -m "chore: cleanup e ajustes finais agentes juridicos"
```

---

## Verificacao Final

1. `cd backend && .venv/bin/python -m pytest tests/ -v` — todos passam
2. `curl localhost:8000/agentes/ferramentas/disponiveis` — retorna 6 ferramentas
3. Criar agente via POST, criar conversa com `agente_id`, enviar mensagem — tool loop funciona
4. Testes antigos (`test_chat.py`) continuam passando — backward compatible
5. SSE endpoint retorna eventos formatados corretamente

## Arquivos Criados

- `backend/app/services/agente_chat.py` — service com tool loop
- `backend/app/services/ferramentas/__init__.py` — registry
- `backend/app/services/ferramentas/processo.py` — buscar_processo, listar_movimentos
- `backend/app/services/ferramentas/cliente.py` — buscar_cliente
- `backend/app/services/ferramentas/prazo.py` — calcular_prazo, listar_prazos
- `backend/app/services/ferramentas/financeiro.py` — resumo_financeiro
- `backend/app/routers/agentes.py` — CRUD agentes + ferramentas disponiveis
- `backend/tests/test_agentes.py` — testes CRUD
- `backend/tests/test_ferramentas.py` — testes unitarios ferramentas
- `backend/tests/test_agente_chat.py` — testes tool loop + streaming

## Arquivos Modificados

- `backend/app/models.py` — AgenteConfig, ToolExecution, FK agente_id em Conversa
- `backend/app/schemas.py` — schemas agente + agente_id em ConversaCreate/ConversaOut
- `backend/app/routers/chat.py` — dispatch agente vs chat antigo + endpoint SSE
- `backend/app/main.py` — registrar router agentes
- `frontend/lib/services/api_service.dart` — metodos API agentes
