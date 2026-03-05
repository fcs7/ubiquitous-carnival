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
    tipo: Mapped[str] = mapped_column(String(50))
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
    tipo: Mapped[str] = mapped_column(String(50))
    descricao: Mapped[str | None] = mapped_column(Text, nullable=True)
    data_limite: Mapped[date] = mapped_column(Date)
    status: Mapped[str] = mapped_column(String(20), default="pendente")
    created_at: Mapped[datetime] = mapped_column(DateTime, default=datetime.utcnow)

    processo: Mapped["Processo"] = relationship(back_populates="prazos")
