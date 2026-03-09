import json
from datetime import UTC, date, datetime, timedelta

from sqlalchemy.orm import Session

from app.models import AgenteConfig, Conversa, Mensagem, Prazo, Usuario
from app.services.agente_chat import (
    _executar_tool_loop,
    _obter_tool_schemas,
    montar_system_prompt_agente,
)
from app.services.ferramentas import FERRAMENTAS_DISPONIVEIS
from app.services.providers import get_provider

NOME_AGENTE_PADRAO = "Assistente Muglia"
TITULO_CONVERSA_ASSISTENTE = "__assistente__"


def get_or_create_agente_padrao(db: Session, usuario_id: int) -> AgenteConfig:
    agente = (
        db.query(AgenteConfig)
        .filter(AgenteConfig.nome == NOME_AGENTE_PADRAO, AgenteConfig.usuario_id == usuario_id)
        .first()
    )
    if agente:
        return agente

    todas_ferramentas = list(FERRAMENTAS_DISPONIVEIS.keys())
    agente = AgenteConfig(
        usuario_id=usuario_id,
        nome=NOME_AGENTE_PADRAO,
        descricao="Assistente juridico unificado do escritorio Muglia",
        instrucoes_sistema=(
            "Voce eh o assistente principal do escritorio Muglia. "
            "Responda perguntas juridicas, busque processos, calcule prazos "
            "e gere documentos. Seja proativo ao alertar sobre prazos urgentes."
        ),
        provider="anthropic",
        modelo="claude-sonnet-4-6",
        ferramentas_habilitadas=json.dumps(todas_ferramentas),
        max_tokens=4096,
        max_iteracoes_tool=10,
    )
    db.add(agente)
    db.flush()
    return agente


def get_or_create_conversa_assistente(db: Session, usuario_id: int) -> Conversa:
    conversa = (
        db.query(Conversa)
        .filter(Conversa.titulo == TITULO_CONVERSA_ASSISTENTE, Conversa.usuario_id == usuario_id)
        .first()
    )
    if conversa:
        return conversa

    agente = get_or_create_agente_padrao(db, usuario_id)
    conversa = Conversa(
        titulo=TITULO_CONVERSA_ASSISTENTE,
        usuario_id=usuario_id,
        agente_id=agente.id,
        modelo_claude=agente.modelo,
    )
    db.add(conversa)
    db.flush()
    return conversa


def criar_conversa_assistente(
    db: Session, usuario_id: int, agente_id: int, titulo: str | None = None
) -> Conversa:
    agente = db.query(AgenteConfig).filter(AgenteConfig.id == agente_id).first()
    if not agente:
        raise ValueError("Agente nao encontrado")

    conversa = Conversa(
        titulo=titulo,
        usuario_id=usuario_id,
        agente_id=agente.id,
        modelo_claude=agente.modelo,
    )
    db.add(conversa)
    db.commit()
    db.refresh(conversa)
    return conversa


def listar_conversas_assistente(db: Session, usuario_id: int) -> list[Conversa]:
    return (
        db.query(Conversa)
        .filter(
            Conversa.usuario_id == usuario_id,
            Conversa.titulo != TITULO_CONVERSA_ASSISTENTE,
        )
        .order_by(Conversa.updated_at.desc())
        .all()
    )


def deletar_conversa_assistente(db: Session, usuario_id: int, conversa_id: int) -> None:
    conversa = (
        db.query(Conversa)
        .filter(Conversa.id == conversa_id, Conversa.usuario_id == usuario_id)
        .first()
    )
    if not conversa:
        raise ValueError("Conversa nao encontrada")
    db.delete(conversa)
    db.commit()


def gerar_titulo_automatico(mensagem: str) -> str:
    texto = mensagem.strip()
    if len(texto) <= 60:
        return texto
    return texto[:57] + "..."


def montar_contexto_urgente(db: Session) -> str:
    limite = date.today() + timedelta(days=7)
    prazos = (
        db.query(Prazo)
        .filter(Prazo.status == "pendente", Prazo.data_limite <= limite)
        .order_by(Prazo.data_limite)
        .all()
    )
    if not prazos:
        return ""

    linhas = [f"\nPRAZOS URGENTES ({len(prazos)}):"]
    for p in prazos:
        desc = p.descricao or p.tipo
        linhas.append(f"- {p.data_limite.strftime('%d/%m/%Y')}: {desc} (processo_id={p.processo_id})")
    return "\n".join(linhas)


def carregar_historico_limitado(db: Session, conversa_id: int, limite: int = 20) -> list[dict]:
    mensagens = (
        db.query(Mensagem)
        .filter(Mensagem.conversa_id == conversa_id)
        .order_by(Mensagem.created_at.desc())
        .limit(limite)
        .all()
    )
    mensagens.reverse()
    return [{"role": m.role, "content": m.conteudo} for m in mensagens]


def assistente_chat(
    db: Session,
    usuario_id: int,
    mensagem: str,
    conversa_id: int | None = None,
    agente_id: int | None = None,
) -> dict:
    usuario = db.query(Usuario).filter(Usuario.id == usuario_id).first()
    if not usuario:
        raise ValueError("Usuario nao encontrado")

    # Resolver conversa: existente, nova com agente, ou sentinel legado
    if conversa_id:
        conversa = (
            db.query(Conversa)
            .filter(Conversa.id == conversa_id, Conversa.usuario_id == usuario_id)
            .first()
        )
        if not conversa:
            raise ValueError("Conversa nao encontrada")
    elif agente_id:
        conversa = criar_conversa_assistente(db, usuario_id, agente_id)
    else:
        conversa = get_or_create_conversa_assistente(db, usuario_id)

    agente = conversa.agente_config
    if not agente:
        agente = get_or_create_agente_padrao(db, usuario_id)
        conversa.agente_id = agente.id
        db.flush()

    provider = get_provider(agente.provider)
    try:
        ferramentas = json.loads(agente.ferramentas_habilitadas or "[]")
    except json.JSONDecodeError:
        ferramentas = []
    tool_schemas = _obter_tool_schemas(ferramentas)

    system_prompt = montar_system_prompt_agente(agente, db, conversa.processo_id)
    system_prompt += f"\n\nDATA ATUAL: {date.today().strftime('%d/%m/%Y')}"
    system_prompt += montar_contexto_urgente(db)

    historico = carregar_historico_limitado(db, conversa.id)
    historico.append({"role": "user", "content": mensagem})

    msg_user = Mensagem(
        conversa_id=conversa.id,
        role="user",
        conteudo=mensagem,
    )

    try:
        texto_acumulado, total_input, total_output = _executar_tool_loop(
            provider=provider,
            historico=historico,
            system_prompt=system_prompt,
            tool_schemas=tool_schemas,
            max_tokens=agente.max_tokens,
            max_iteracoes=agente.max_iteracoes_tool,
            db=db,
            conversa_id=conversa.id,
            modelo=agente.modelo,
        )

        msg_user.tokens_input = total_input
        msg_assistant = Mensagem(
            conversa_id=conversa.id,
            role="assistant",
            conteudo=texto_acumulado,
            tokens_output=total_output,
        )
        db.add_all([msg_user, msg_assistant])

        # Auto-gerar titulo na primeira mensagem (sentinel __assistente__ nao muda)
        if conversa.titulo is None:
            conversa.titulo = gerar_titulo_automatico(mensagem)

        # Atualizar updated_at da conversa
        conversa.updated_at = datetime.now(UTC)
        db.commit()
    except Exception:
        db.add(msg_user)
        db.commit()
        raise

    return {
        "resposta": texto_acumulado,
        "modelo": agente.modelo,
        "tokens_input": total_input,
        "tokens_output": total_output,
        "conversa_id": conversa.id,
    }
