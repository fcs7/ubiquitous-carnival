import json

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import AgenteConfig, Cliente, Processo, ProcessoParte, Usuario
from app.schemas import (
    AgenteConfigCreate,
    AgenteConfigOut,
    AgenteConfigUpdate,
    FerramentaDisponivel,
)


# ── Schemas para geracao automatica ──────────────────

class GerarInstrucaoRequest(BaseModel):
    nome: str
    descricao: str | None = None
    provider: str = "anthropic"
    modelo: str = "claude-sonnet-4-6"
    ferramentas_habilitadas: list[str] = []


class GerarInstrucaoResponse(BaseModel):
    instrucoes_sistema: str


class GerarContextoRequest(BaseModel):
    cliente_ids: list[int]


class GerarContextoResponse(BaseModel):
    contexto_referencia: str


class GerarMemoriaRequest(BaseModel):
    pasta_drive_id: str


class GerarMemoriaResponse(BaseModel):
    arquivos_gerados: list[str]
    arquivos_fonte: int
    tokens_usados: int
    pasta_local: str


# ── Meta-prompt para gerar instrucoes de sistema ─────

META_PROMPT = """Voce e um especialista em engenharia de prompts para modelos de IA, baseado nas melhores praticas da Anthropic.

Sua tarefa e gerar instrucoes de sistema (system prompt) para um agente de IA juridico de um escritorio de advocacia brasileiro.

O prompt gerado deve seguir esta estrutura:
1. PAPEL: Defina claramente quem o agente e e sua especialidade
2. CONTEXTO: Escritorio Muglia, direito brasileiro
3. INSTRUCOES: Regras claras e especificas (use listas numeradas)
4. FORMATO DE SAIDA: Como as respostas devem ser estruturadas
5. RESTRICOES: O que o agente NAO deve fazer

Diretrizes:
- Seja especifico e direto (nao use linguagem vaga)
- Use XML tags para separar secoes quando util (ex: <instrucoes>, <formato>)
- Inclua instrucoes sobre citar artigos de lei quando aplicavel
- O prompt deve ser em portugues brasileiro
- Adapte o tom (formal/tecnico para advogados, acessivel para clientes)
- Considere as ferramentas disponiveis para orientar o agente sobre quando usa-las
- NAO inclua exemplos no prompt gerado (serao adicionados separadamente)
- Mantenha o prompt conciso mas completo (maximo ~500 palavras)"""

router = APIRouter(prefix="/agentes", tags=["agentes"])


@router.get("/ferramentas/disponiveis", response_model=list[FerramentaDisponivel])
def listar_ferramentas_disponiveis():
    from app.services.ferramentas import FERRAMENTAS_DISPONIVEIS
    return [
        FerramentaDisponivel(nome=k, descricao_ui=v["descricao_ui"], categoria=v["categoria"])
        for k, v in FERRAMENTAS_DISPONIVEIS.items()
    ]


@router.post("/gerar-instrucao", response_model=GerarInstrucaoResponse)
def gerar_instrucao(payload: GerarInstrucaoRequest):
    from app.services.providers.anthropic_provider import _get_client

    user_msg = f"""Gere instrucoes de sistema para o seguinte agente:

Nome: {payload.nome}
Descricao: {payload.descricao or 'Nao informada'}
Provider: {payload.provider}
Modelo: {payload.modelo}
Ferramentas disponiveis: {', '.join(payload.ferramentas_habilitadas) if payload.ferramentas_habilitadas else 'Nenhuma'}

Gere APENAS o system prompt, sem explicacoes adicionais."""

    client = _get_client()
    response = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=1024,
        system=META_PROMPT,
        messages=[{"role": "user", "content": user_msg}],
    )

    instrucoes = ""
    for block in response.content:
        if hasattr(block, "text") and block.type == "text":
            instrucoes += block.text

    return GerarInstrucaoResponse(instrucoes_sistema=instrucoes.strip())


@router.post("/gerar-contexto", response_model=GerarContextoResponse)
def gerar_contexto(payload: GerarContextoRequest, db: Session = Depends(get_db)):
    clientes_com_processos = []
    for cid in payload.cliente_ids:
        cliente = db.query(Cliente).filter(Cliente.id == cid).first()
        if not cliente:
            raise HTTPException(status_code=404, detail=f"Cliente id={cid} nao encontrado")
        partes = (
            db.query(ProcessoParte, Processo)
            .join(Processo, ProcessoParte.processo_id == Processo.id)
            .filter(ProcessoParte.cliente_id == cliente.id)
            .all()
        )
        processos = [(proc, pp.papel) for pp, proc in partes]
        clientes_com_processos.append((cliente, processos))

    contexto = _formatar_contexto_clientes(clientes_com_processos)
    return GerarContextoResponse(contexto_referencia=contexto)


@router.post("/{agente_id}/gerar-memoria", response_model=GerarMemoriaResponse)
def gerar_memoria(agente_id: int, payload: GerarMemoriaRequest, db: Session = Depends(get_db)):
    """Gera arquivos de memoria (.md) a partir de uma pasta do Google Drive."""
    from app.services.google_drive import DriveServiceError
    from app.services.memoria_agente import gerar_e_salvar_memoria

    agente = db.query(AgenteConfig).filter(AgenteConfig.id == agente_id).first()
    if not agente:
        raise HTTPException(status_code=404, detail="Agente nao encontrado")

    try:
        resultado = gerar_e_salvar_memoria(agente_id, payload.pasta_drive_id)
    except DriveServiceError as e:
        msg = str(e)
        if "SEGURANCA" in msg:
            raise HTTPException(status_code=403, detail=msg)
        raise HTTPException(status_code=502, detail=f"Erro no Google Drive: {msg}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erro ao gerar memoria com IA: {e}")

    return GerarMemoriaResponse(
        arquivos_gerados=resultado.arquivos_gerados,
        arquivos_fonte=resultado.arquivos_fonte,
        tokens_usados=resultado.tokens_usados,
        pasta_local=resultado.pasta_local,
    )


@router.get("/{agente_id}/memoria", response_model=list[str])
def listar_memoria(agente_id: int):
    """Lista arquivos de memoria (.md) do agente."""
    from app.services.memoria_agente import listar_arquivos_memoria

    return listar_arquivos_memoria(agente_id)


def _formatar_contexto_clientes(clientes_com_processos: list) -> str:
    partes = ["<clientes_escritorio>"]
    for cliente, processos in clientes_com_processos:
        partes.append(f"  <cliente id='{cliente.id}'>")
        partes.append(f"    <nome>{cliente.nome}</nome>")
        partes.append(f"    <cpf_cnpj>{cliente.cpf_cnpj}</cpf_cnpj>")
        if cliente.telefone:
            partes.append(f"    <telefone>{cliente.telefone}</telefone>")
        if cliente.email:
            partes.append(f"    <email>{cliente.email}</email>")
        if processos:
            partes.append("    <processos>")
            for proc, papel in processos:
                partes.append(f"      <processo cnj='{proc.cnj}' papel='{papel}'>")
                partes.append(f"        <tribunal>{proc.tribunal}</tribunal>")
                partes.append(f"        <status>{proc.status}</status>")
                if proc.classe_nome:
                    partes.append(f"        <classe>{proc.classe_nome}</classe>")
                partes.append("      </processo>")
            partes.append("    </processos>")
        partes.append("  </cliente>")
    partes.append("</clientes_escritorio>")
    return "\n".join(partes)


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
        provider=payload.provider,
        modelo=payload.modelo,
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
def atualizar_agente(agente_id: int, payload: AgenteConfigUpdate, usuario_id: int, db: Session = Depends(get_db)):
    agente = db.query(AgenteConfig).filter(
        AgenteConfig.id == agente_id,
        AgenteConfig.usuario_id == usuario_id,
    ).first()
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
def deletar_agente(agente_id: int, usuario_id: int, db: Session = Depends(get_db)):
    agente = db.query(AgenteConfig).filter(
        AgenteConfig.id == agente_id,
        AgenteConfig.usuario_id == usuario_id,
    ).first()
    if not agente:
        raise HTTPException(status_code=404, detail="Agente nao encontrado")
    db.delete(agente)
    db.commit()
