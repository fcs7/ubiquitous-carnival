from datetime import date, datetime
from pydantic import BaseModel


# -- Clientes --
class ClienteCreate(BaseModel):
    nome: str
    cpf_cnpj: str
    rg: str | None = None
    cnh: str | None = None
    data_nascimento: date | None = None
    nacionalidade: str | None = None
    estado_civil: str | None = None
    profissao: str | None = None
    telefone: str
    telefone2: str | None = None
    email: str | None = None
    endereco: str | None = None
    cidade: str | None = None
    uf: str | None = None
    cep: str | None = None
    observacoes: str | None = None
    outros_dados: str | None = None


class ClienteUpdate(BaseModel):
    nome: str | None = None
    cpf_cnpj: str | None = None
    rg: str | None = None
    cnh: str | None = None
    data_nascimento: date | None = None
    nacionalidade: str | None = None
    estado_civil: str | None = None
    profissao: str | None = None
    telefone: str | None = None
    telefone2: str | None = None
    email: str | None = None
    endereco: str | None = None
    cidade: str | None = None
    uf: str | None = None
    cep: str | None = None
    observacoes: str | None = None
    outros_dados: str | None = None


class ClienteOut(BaseModel):
    id: int
    nome: str
    cpf_cnpj: str
    rg: str | None
    cnh: str | None
    data_nascimento: date | None
    nacionalidade: str | None
    estado_civil: str | None
    profissao: str | None
    telefone: str
    telefone2: str | None
    email: str | None
    endereco: str | None
    cidade: str | None
    uf: str | None
    cep: str | None
    observacoes: str | None
    outros_dados: str | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# -- Processos --
class ProcessoCreate(BaseModel):
    cnj: str


class ProcessoOut(BaseModel):
    id: int
    cnj: str
    numero_limpo: str
    tribunal: str
    alias_tribunal: str
    classe_codigo: int | None
    classe_nome: str | None
    orgao_julgador: str | None
    grau: str | None
    data_ajuizamento: datetime | None
    status: str
    ultima_verificacao: datetime | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class MovimentoOut(BaseModel):
    id: int
    processo_id: int
    codigo: int
    nome: str
    data_hora: datetime
    complementos: str | None
    resumo_ia: str | None
    notificado: bool
    created_at: datetime

    model_config = {"from_attributes": True}


class ProcessoParteCreate(BaseModel):
    cliente_id: int
    papel: str


class ProcessoParteOut(BaseModel):
    id: int
    processo_id: int
    cliente_id: int
    papel: str

    model_config = {"from_attributes": True}


class ProcessoDetailOut(ProcessoOut):
    partes: list[ProcessoParteOut] = []
    movimentos: list[MovimentoOut] = []


# -- Financeiro --
class FinanceiroCreate(BaseModel):
    processo_id: int
    cliente_id: int
    tipo: str
    descricao: str | None = None
    valor: float
    status: str = "pendente"
    data_vencimento: date | None = None


class FinanceiroOut(BaseModel):
    id: int
    processo_id: int
    cliente_id: int
    tipo: str
    descricao: str | None
    valor: float
    status: str
    data_vencimento: date | None
    data_pagamento: date | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class FinanceiroResumo(BaseModel):
    pendente: float
    pago: float
    total: float


# -- Prazos --
class PrazoCreate(BaseModel):
    processo_id: int
    tipo: str
    descricao: str | None = None
    data_limite: date
    status: str = "pendente"


class PrazoOut(BaseModel):
    id: int
    processo_id: int
    tipo: str
    descricao: str | None
    data_limite: date
    status: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


# -- Conversas / Chat --
class ConversaCreate(BaseModel):
    titulo: str | None = None
    processo_id: int | None = None
    usuario_id: int
    modelo_claude: str = "claude-haiku-4-5-20251001"
    agente_id: int | None = None


class MensagemOut(BaseModel):
    id: int
    conversa_id: int
    role: str
    conteudo: str
    tokens_input: int | None
    tokens_output: int | None
    created_at: datetime

    model_config = {"from_attributes": True}


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


class ConversaDetailOut(ConversaOut):
    mensagens: list[MensagemOut] = []


class MensagemCreate(BaseModel):
    mensagem: str
    modelo: str | None = None


class ChatResponse(BaseModel):
    resposta: str
    modelo: str
    tokens_input: int
    tokens_output: int


# -- Vindi --
class VindiCustomerOut(BaseModel):
    id: int
    vindi_id: int
    nome: str
    email: str | None
    cpf_cnpj: str | None
    telefone: str | None
    cliente_id: int | None
    status_sync: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class VindiProductOut(BaseModel):
    id: int
    vindi_id: int
    nome: str
    descricao: str | None
    valor: float | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class VindiSubscriptionOut(BaseModel):
    id: int
    vindi_id: int
    vindi_customer_id: int | None
    vindi_product_id: int | None
    processo_id: int | None
    status: str
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class VindiBillOut(BaseModel):
    id: int
    vindi_id: int
    vindi_customer_id: int | None
    vindi_subscription_id: int | None
    valor: float
    status: str
    data_vencimento: date | None
    data_pagamento: date | None
    financeiro_id: int | None
    created_at: datetime
    updated_at: datetime

    model_config = {"from_attributes": True}


class VindiVincularCustomerRequest(BaseModel):
    cliente_id: int | None = None


class VindiVincularSubscriptionRequest(BaseModel):
    processo_id: int


class VindiCustomerDetailOut(VindiCustomerOut):
    subscriptions: list[VindiSubscriptionOut] = []
    bills: list[VindiBillOut] = []


# -- Tags --
class TagCreate(BaseModel):
    nome: str
    cor: str | None = None


class TagOut(BaseModel):
    id: int
    nome: str
    cor: str | None
    created_at: datetime

    model_config = {"from_attributes": True}


class TagEntidadeCreate(BaseModel):
    tag_id: int
    entidade_tipo: str
    entidade_id: int


class TagEntidadeOut(BaseModel):
    id: int
    tag_id: int
    entidade_tipo: str
    entidade_id: int

    model_config = {"from_attributes": True}


# -- Agentes --
class AgenteConfigCreate(BaseModel):
    nome: str
    usuario_id: int
    descricao: str | None = None
    instrucoes_sistema: str | None = None
    provider: str = "anthropic"
    modelo: str = "claude-sonnet-4-5-20250514"
    ferramentas_habilitadas: list[str] = []
    contexto_referencia: str | None = None
    max_tokens: int = 4096
    max_iteracoes_tool: int = 10


class AgenteConfigUpdate(BaseModel):
    nome: str | None = None
    descricao: str | None = None
    instrucoes_sistema: str | None = None
    provider: str | None = None
    modelo: str | None = None
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
    provider: str
    modelo: str
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
        import json as _json
        data = {c.key: getattr(obj, c.key) for c in obj.__table__.columns}
        data["ferramentas_habilitadas"] = _json.loads(data.get("ferramentas_habilitadas", "[]"))
        return cls(**data)


class FerramentaDisponivel(BaseModel):
    nome: str
    descricao_ui: str
    categoria: str
