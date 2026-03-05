from datetime import datetime, date
from sqlalchemy import (
    String, Integer, Float, Boolean, DateTime, Date,
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
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    conversas: Mapped[list["Conversa"]] = relationship(back_populates="usuario")


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
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    processo_partes: Mapped[list["ProcessoParte"]] = relationship(back_populates="cliente")
    financeiro: Mapped[list["Financeiro"]] = relationship(back_populates="cliente")


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
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    partes: Mapped[list["ProcessoParte"]] = relationship(back_populates="processo", cascade="all, delete-orphan")
    movimentos: Mapped[list["Movimento"]] = relationship(back_populates="processo", cascade="all, delete-orphan")
    prazos: Mapped[list["Prazo"]] = relationship(back_populates="processo", cascade="all, delete-orphan")
    financeiro: Mapped[list["Financeiro"]] = relationship(back_populates="processo", cascade="all, delete-orphan")
    documentos: Mapped[list["Documento"]] = relationship(back_populates="processo")
    conversas: Mapped[list["Conversa"]] = relationship(back_populates="processo")


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
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

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
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

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
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    processo: Mapped["Processo"] = relationship(back_populates="financeiro")
    cliente: Mapped["Cliente"] = relationship(back_populates="financeiro")


# ──────────────────────────────────────────────
# Documentos e modelos
# ──────────────────────────────────────────────
class Documento(Base):
    __tablename__ = "documentos"

    id: Mapped[int] = mapped_column(primary_key=True)
    nome: Mapped[str] = mapped_column(String(255))
    tipo: Mapped[str] = mapped_column(String(30), index=True)  # modelo, gerado, upload
    categoria: Mapped[str | None] = mapped_column(String(50), nullable=True)  # peticao, contestacao, recurso
    arquivo_path: Mapped[str] = mapped_column(String(500))
    mime_type: Mapped[str] = mapped_column(String(100))
    tamanho_bytes: Mapped[int] = mapped_column(Integer)
    processo_id: Mapped[int | None] = mapped_column(ForeignKey("processos.id"), nullable=True, index=True)
    cliente_id: Mapped[int | None] = mapped_column(ForeignKey("clientes.id"), nullable=True, index=True)
    usuario_id: Mapped[int | None] = mapped_column(ForeignKey("usuarios.id"), nullable=True)
    conversa_id: Mapped[int | None] = mapped_column(ForeignKey("conversas.id"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

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
    config_extra: Mapped[str | None] = mapped_column(Text, nullable=True)  # JSON com configs especificas
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

    usuario: Mapped["Usuario"] = relationship(back_populates="conversas")
    processo: Mapped["Processo | None"] = relationship(back_populates="conversas")
    mensagens: Mapped[list["Mensagem"]] = relationship(back_populates="conversa", cascade="all, delete-orphan")


class Mensagem(Base):
    __tablename__ = "mensagens"

    id: Mapped[int] = mapped_column(primary_key=True)
    conversa_id: Mapped[int] = mapped_column(ForeignKey("conversas.id", ondelete="CASCADE"), index=True)
    role: Mapped[str] = mapped_column(String(20))  # user, assistant
    conteudo: Mapped[str] = mapped_column(Text)
    tokens_input: Mapped[int | None] = mapped_column(Integer, nullable=True)
    tokens_output: Mapped[int | None] = mapped_column(Integer, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

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
    updated_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
