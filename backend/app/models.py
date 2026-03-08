from datetime import UTC, datetime, date
from sqlalchemy import (
    String, Integer, Boolean, DateTime, Date,
    ForeignKey, Text, UniqueConstraint, Numeric,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.database import Base


# ──────────────────────────────────────────────
# Usuarios (advogados/socios do escritorio)
# ──────────────────────────────────────────────
class Usuario(Base):
    __tablename__ = "usuarios"

    id: Mapped[int] = mapped_column(primary_key=True)
    nome: Mapped[str] = mapped_column(String(255))
    email: Mapped[str] = mapped_column(String(255), unique=True)
    oab: Mapped[str | None] = mapped_column(String(20), nullable=True)
    ativo: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC))

    conversas: Mapped[list["Conversa"]] = relationship(back_populates="usuario")
    agentes_config: Mapped[list["AgenteConfig"]] = relationship(back_populates="usuario")


# ──────────────────────────────────────────────
# Clientes
# ──────────────────────────────────────────────
class Cliente(Base):
    __tablename__ = "clientes"

    id: Mapped[int] = mapped_column(primary_key=True)
    nome: Mapped[str] = mapped_column(String(255))
    cpf_cnpj: Mapped[str] = mapped_column(String(18), unique=True, index=True)
    rg: Mapped[str | None] = mapped_column(String(20), nullable=True)
    cnh: Mapped[str | None] = mapped_column(String(20), nullable=True)
    data_nascimento: Mapped[date | None] = mapped_column(Date, nullable=True)
    nacionalidade: Mapped[str | None] = mapped_column(String(50), nullable=True)
    estado_civil: Mapped[str | None] = mapped_column(String(30), nullable=True)
    profissao: Mapped[str | None] = mapped_column(String(100), nullable=True)
    telefone: Mapped[str] = mapped_column(String(20))
    telefone2: Mapped[str | None] = mapped_column(String(20), nullable=True)
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    endereco: Mapped[str | None] = mapped_column(Text, nullable=True)
    cidade: Mapped[str | None] = mapped_column(String(100), nullable=True)
    uf: Mapped[str | None] = mapped_column(String(2), nullable=True)
    cep: Mapped[str | None] = mapped_column(String(10), nullable=True)
    observacoes: Mapped[str | None] = mapped_column(Text, nullable=True)
    outros_dados: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC))

    processo_partes: Mapped[list["ProcessoParte"]] = relationship(back_populates="cliente")
    financeiro: Mapped[list["Financeiro"]] = relationship(back_populates="cliente")
    vindi_customers: Mapped[list["VindiCustomer"]] = relationship(back_populates="cliente")


# ──────────────────────────────────────────────
# Processos
# ──────────────────────────────────────────────
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
    data_ajuizamento: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="ativo", index=True)
    ultima_verificacao: Mapped[datetime | None] = mapped_column(DateTime, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC))

    partes: Mapped[list["ProcessoParte"]] = relationship(back_populates="processo", cascade="all, delete-orphan")
    movimentos: Mapped[list["Movimento"]] = relationship(back_populates="processo", cascade="all, delete-orphan")
    prazos: Mapped[list["Prazo"]] = relationship(back_populates="processo", cascade="all, delete-orphan")
    financeiro: Mapped[list["Financeiro"]] = relationship(back_populates="processo", cascade="all, delete-orphan")
    documentos: Mapped[list["Documento"]] = relationship(back_populates="processo")
    conversas: Mapped[list["Conversa"]] = relationship(back_populates="processo")
    vindi_subscriptions: Mapped[list["VindiSubscription"]] = relationship(back_populates="processo")


# ──────────────────────────────────────────────
# Processo <-> Cliente (N:N com papel)
# Um processo tem autor, reu, advogado, etc.
# ──────────────────────────────────────────────
class ProcessoParte(Base):
    __tablename__ = "processo_partes"
    __table_args__ = (
        UniqueConstraint("processo_id", "cliente_id", "papel", name="uq_processo_cliente_papel"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    processo_id: Mapped[int] = mapped_column(ForeignKey("processos.id", ondelete="CASCADE"))
    cliente_id: Mapped[int] = mapped_column(ForeignKey("clientes.id"), index=True)
    papel: Mapped[str] = mapped_column(String(30))  # autor, reu, advogado, terceiro

    processo: Mapped["Processo"] = relationship(back_populates="partes")
    cliente: Mapped["Cliente"] = relationship(back_populates="processo_partes")


# ──────────────────────────────────────────────
# Movimentos processuais
# ──────────────────────────────────────────────
class Movimento(Base):
    __tablename__ = "movimentos"
    __table_args__ = (
        UniqueConstraint("processo_id", "codigo", "data_hora", name="uq_movimento"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    processo_id: Mapped[int] = mapped_column(ForeignKey("processos.id", ondelete="CASCADE"), index=True)
    codigo: Mapped[int] = mapped_column(Integer)
    nome: Mapped[str] = mapped_column(String(255))
    data_hora: Mapped[datetime] = mapped_column(DateTime, index=True)
    complementos: Mapped[str | None] = mapped_column(Text, nullable=True)
    resumo_ia: Mapped[str | None] = mapped_column(Text, nullable=True)
    notificado: Mapped[bool] = mapped_column(Boolean, default=False, index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))

    processo: Mapped["Processo"] = relationship(back_populates="movimentos")


# ──────────────────────────────────────────────
# Prazos
# ──────────────────────────────────────────────
class Prazo(Base):
    __tablename__ = "prazos"

    id: Mapped[int] = mapped_column(primary_key=True)
    processo_id: Mapped[int] = mapped_column(ForeignKey("processos.id", ondelete="CASCADE"), index=True)
    tipo: Mapped[str] = mapped_column(String(50))  # intimacao, audiencia, pericia
    descricao: Mapped[str | None] = mapped_column(Text, nullable=True)
    data_limite: Mapped[date] = mapped_column(Date, index=True)
    status: Mapped[str] = mapped_column(String(20), default="pendente", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC))

    processo: Mapped["Processo"] = relationship(back_populates="prazos")


# ──────────────────────────────────────────────
# Financeiro (vinculado a processo E cliente)
# ──────────────────────────────────────────────
class Financeiro(Base):
    __tablename__ = "financeiro"

    id: Mapped[int] = mapped_column(primary_key=True)
    processo_id: Mapped[int] = mapped_column(ForeignKey("processos.id", ondelete="CASCADE"), index=True)
    cliente_id: Mapped[int] = mapped_column(ForeignKey("clientes.id"), index=True)
    tipo: Mapped[str] = mapped_column(String(50))  # honorario, custas, pericia, acordo
    descricao: Mapped[str | None] = mapped_column(String(255), nullable=True)
    valor: Mapped[float] = mapped_column(Numeric(12, 2))
    status: Mapped[str] = mapped_column(String(20), default="pendente", index=True)
    data_vencimento: Mapped[date | None] = mapped_column(Date, nullable=True, index=True)
    data_pagamento: Mapped[date | None] = mapped_column(Date, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC))

    processo: Mapped["Processo"] = relationship(back_populates="financeiro")
    cliente: Mapped["Cliente"] = relationship(back_populates="financeiro")
    vindi_bill: Mapped["VindiBill | None"] = relationship(back_populates="financeiro", uselist=False)


# ──────────────────────────────────────────────
# Documentos e modelos
# ──────────────────────────────────────────────
class Documento(Base):
    __tablename__ = "documentos"

    id: Mapped[int] = mapped_column(primary_key=True)
    nome: Mapped[str] = mapped_column(String(255))
    tipo: Mapped[str] = mapped_column(String(30), index=True)  # modelo, gerado, upload, drive
    categoria: Mapped[str | None] = mapped_column(String(50), nullable=True)  # peticao, contestacao, recurso
    arquivo_path: Mapped[str | None] = mapped_column(String(500), nullable=True)
    mime_type: Mapped[str] = mapped_column(String(100))
    tamanho_bytes: Mapped[int | None] = mapped_column(Integer, nullable=True)
    # Google Drive
    drive_file_id: Mapped[str | None] = mapped_column(String(200), nullable=True, index=True)
    drive_url: Mapped[str | None] = mapped_column(String(500), nullable=True)
    drive_pasta_id: Mapped[str | None] = mapped_column(String(200), nullable=True)
    origem: Mapped[str] = mapped_column(String(20), default="local")  # local | drive
    processo_id: Mapped[int | None] = mapped_column(ForeignKey("processos.id"), nullable=True, index=True)
    cliente_id: Mapped[int | None] = mapped_column(ForeignKey("clientes.id"), nullable=True, index=True)
    usuario_id: Mapped[int | None] = mapped_column(ForeignKey("usuarios.id"), nullable=True)
    conversa_id: Mapped[int | None] = mapped_column(ForeignKey("conversas.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))

    processo: Mapped["Processo | None"] = relationship(back_populates="documentos")


# ──────────────────────────────────────────────
# Conversas do chat juridico
# ──────────────────────────────────────────────
class Conversa(Base):
    __tablename__ = "conversas"

    id: Mapped[int] = mapped_column(primary_key=True)
    titulo: Mapped[str | None] = mapped_column(String(255), nullable=True)
    usuario_id: Mapped[int] = mapped_column(ForeignKey("usuarios.id"), index=True)
    processo_id: Mapped[int | None] = mapped_column(ForeignKey("processos.id"), nullable=True, index=True)
    modelo_claude: Mapped[str] = mapped_column(String(50), default="claude-haiku-4-5-20251001")
    agente_id: Mapped[int | None] = mapped_column(ForeignKey("agentes_config.id"), nullable=True, index=True)
    config_extra: Mapped[str | None] = mapped_column(Text, nullable=True)  # JSON com configs especificas
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC))

    usuario: Mapped["Usuario"] = relationship(back_populates="conversas")
    processo: Mapped["Processo | None"] = relationship(back_populates="conversas")
    agente_config: Mapped["AgenteConfig | None"] = relationship(back_populates="conversas")
    mensagens: Mapped[list["Mensagem"]] = relationship(back_populates="conversa", cascade="all, delete-orphan")


class Mensagem(Base):
    __tablename__ = "mensagens"

    id: Mapped[int] = mapped_column(primary_key=True)
    conversa_id: Mapped[int] = mapped_column(ForeignKey("conversas.id", ondelete="CASCADE"), index=True)
    role: Mapped[str] = mapped_column(String(20))  # user, assistant
    conteudo: Mapped[str] = mapped_column(Text)
    tokens_input: Mapped[int | None] = mapped_column(Integer, nullable=True)
    tokens_output: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))

    conversa: Mapped["Conversa"] = relationship(back_populates="mensagens")


# ──────────────────────────────────────────────
# Configuracoes do escritorio
# ──────────────────────────────────────────────
class ConfigEscritorio(Base):
    __tablename__ = "config_escritorio"

    id: Mapped[int] = mapped_column(primary_key=True)
    chave: Mapped[str] = mapped_column(String(100), unique=True, index=True)
    valor: Mapped[str] = mapped_column(Text)
    descricao: Mapped[str | None] = mapped_column(String(255), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC))


# ──────────────────────────────────────────────
# Vindi — Tabelas espelho
# ──────────────────────────────────────────────
class VindiCustomer(Base):
    __tablename__ = "vindi_customers"

    id: Mapped[int] = mapped_column(primary_key=True)
    vindi_id: Mapped[int] = mapped_column(Integer, unique=True, index=True)
    nome: Mapped[str] = mapped_column(String(255))
    email: Mapped[str | None] = mapped_column(String(255), nullable=True)
    cpf_cnpj: Mapped[str | None] = mapped_column(String(18), nullable=True)
    telefone: Mapped[str | None] = mapped_column(String(20), nullable=True)
    dados_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    cliente_id: Mapped[int | None] = mapped_column(ForeignKey("clientes.id"), nullable=True, index=True)
    status_sync: Mapped[str] = mapped_column(String(20), default="pendente", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC))

    cliente: Mapped["Cliente | None"] = relationship(back_populates="vindi_customers")
    subscriptions: Mapped[list["VindiSubscription"]] = relationship(back_populates="vindi_customer")
    bills: Mapped[list["VindiBill"]] = relationship(back_populates="vindi_customer")


class VindiProduct(Base):
    __tablename__ = "vindi_products"

    id: Mapped[int] = mapped_column(primary_key=True)
    vindi_id: Mapped[int] = mapped_column(Integer, unique=True, index=True)
    nome: Mapped[str] = mapped_column(String(255))
    descricao: Mapped[str | None] = mapped_column(String(255), nullable=True)
    valor: Mapped[float | None] = mapped_column(Numeric(12, 2), nullable=True)
    dados_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC))

    subscriptions: Mapped[list["VindiSubscription"]] = relationship(back_populates="vindi_product")


class VindiSubscription(Base):
    __tablename__ = "vindi_subscriptions"

    id: Mapped[int] = mapped_column(primary_key=True)
    vindi_id: Mapped[int] = mapped_column(Integer, unique=True, index=True)
    vindi_customer_id: Mapped[int | None] = mapped_column(ForeignKey("vindi_customers.id"), nullable=True, index=True)
    vindi_product_id: Mapped[int | None] = mapped_column(ForeignKey("vindi_products.id"), nullable=True, index=True)
    processo_id: Mapped[int | None] = mapped_column(ForeignKey("processos.id"), nullable=True, index=True)
    status: Mapped[str] = mapped_column(String(30), default="active")
    dados_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC))

    vindi_customer: Mapped["VindiCustomer | None"] = relationship(back_populates="subscriptions")
    vindi_product: Mapped["VindiProduct | None"] = relationship(back_populates="subscriptions")
    processo: Mapped["Processo | None"] = relationship(back_populates="vindi_subscriptions")
    bills: Mapped[list["VindiBill"]] = relationship(back_populates="vindi_subscription")


class VindiBill(Base):
    __tablename__ = "vindi_bills"

    id: Mapped[int] = mapped_column(primary_key=True)
    vindi_id: Mapped[int] = mapped_column(Integer, unique=True, index=True)
    vindi_customer_id: Mapped[int | None] = mapped_column(ForeignKey("vindi_customers.id"), nullable=True, index=True)
    vindi_subscription_id: Mapped[int | None] = mapped_column(ForeignKey("vindi_subscriptions.id"), nullable=True, index=True)
    valor: Mapped[float] = mapped_column(Numeric(12, 2))
    status: Mapped[str] = mapped_column(String(30), default="pending")
    data_vencimento: Mapped[date | None] = mapped_column(Date, nullable=True)
    data_pagamento: Mapped[date | None] = mapped_column(Date, nullable=True)
    financeiro_id: Mapped[int | None] = mapped_column(ForeignKey("financeiro.id"), nullable=True, index=True)
    dados_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC))
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=lambda: datetime.now(UTC), onupdate=lambda: datetime.now(UTC))

    vindi_customer: Mapped["VindiCustomer | None"] = relationship(back_populates="bills")
    vindi_subscription: Mapped["VindiSubscription | None"] = relationship(back_populates="bills")
    financeiro: Mapped["Financeiro | None"] = relationship(back_populates="vindi_bill")


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
    provider: Mapped[str] = mapped_column(String(20), default="anthropic")  # anthropic, openai
    modelo: Mapped[str] = mapped_column(String(50), default="claude-sonnet-4-6")
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
