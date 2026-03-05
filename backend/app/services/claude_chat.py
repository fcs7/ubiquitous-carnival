import json
import anthropic
from sqlalchemy.orm import Session
from app.config import settings
from app.models import Conversa, Mensagem, Processo, ProcessoParte, Movimento, ConfigEscritorio

SYSTEM_PROMPT_JURIDICO = """Voce eh um assistente juridico especializado em direito brasileiro.

Regras:
- Sempre use linguagem formal juridica quando gerando documentos
- Cite artigos de lei quando relevante (CPC, CC, CF, CLT, CDC, CP, CPP)
- Formate documentos segundo padroes forenses brasileiros
- Use os dados do processo e cliente fornecidos no contexto
- Quando gerar pecas juridicas, inclua: cabecalho, qualificacao das partes, dos fatos, do direito, dos pedidos
- Respeite formatacao de tribunais especificos quando mencionado
- Valores monetarios em reais (R$)
- Datas no formato brasileiro (dd/mm/aaaa)

Voce tem acesso aos dados do processo e cliente no contexto abaixo."""

_client = None


def get_anthropic_client():
    global _client
    if _client is None:
        _client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
    return _client


def montar_contexto_processo(db: Session, processo_id: int) -> str:
    processo = db.query(Processo).filter(Processo.id == processo_id).first()
    if not processo:
        return ""

    partes = db.query(ProcessoParte).filter(ProcessoParte.processo_id == processo_id).all()
    movimentos = (
        db.query(Movimento)
        .filter(Movimento.processo_id == processo_id)
        .order_by(Movimento.data_hora.desc())
        .limit(20)
        .all()
    )

    ctx = f"""
DADOS DO PROCESSO:
- CNJ: {processo.cnj}
- Tribunal: {processo.tribunal}
- Classe: {processo.classe_nome or 'N/A'}
- Orgao Julgador: {processo.orgao_julgador or 'N/A'}
- Grau: {processo.grau or 'N/A'}
- Status: {processo.status}
"""

    if partes:
        ctx += "\nPARTES:\n"
        for p in partes:
            cliente = p.cliente
            ctx += f"- {p.papel.upper()}: {cliente.nome} (CPF/CNPJ: {cliente.cpf_cnpj})\n"

    if movimentos:
        ctx += f"\nULTIMOS MOVIMENTOS ({len(movimentos)}):\n"
        for m in movimentos:
            ctx += f"- {m.data_hora}: {m.nome}\n"

    return ctx


def montar_config_escritorio(db: Session) -> str:
    configs = db.query(ConfigEscritorio).all()
    if not configs:
        return ""
    ctx = "\nCONFIG DO ESCRITORIO:\n"
    for c in configs:
        ctx += f"- {c.chave}: {c.valor}\n"
    return ctx


def carregar_historico(db: Session, conversa_id: int) -> list[dict]:
    mensagens = (
        db.query(Mensagem)
        .filter(Mensagem.conversa_id == conversa_id)
        .order_by(Mensagem.created_at)
        .all()
    )
    return [{"role": m.role, "content": m.conteudo} for m in mensagens]


def chat(
    db: Session,
    conversa_id: int,
    mensagem_usuario: str,
    modelo: str | None = None,
) -> dict:
    conversa = db.query(Conversa).filter(Conversa.id == conversa_id).first()
    if not conversa:
        raise ValueError("Conversa nao encontrada")

    modelo_usar = modelo or conversa.modelo_claude

    # Monta system prompt
    system_parts = [SYSTEM_PROMPT_JURIDICO]
    system_parts.append(montar_config_escritorio(db))
    if conversa.processo_id:
        system_parts.append(montar_contexto_processo(db, conversa.processo_id))
    system_prompt = "\n".join(system_parts)

    # Carrega historico
    historico = carregar_historico(db, conversa_id)
    historico.append({"role": "user", "content": mensagem_usuario})

    # Chama Claude API
    client = get_anthropic_client()
    response = client.messages.create(
        model=modelo_usar,
        max_tokens=4096,
        system=system_prompt,
        messages=historico,
    )

    resposta_texto = response.content[0].text

    # Salva mensagens no banco
    msg_user = Mensagem(
        conversa_id=conversa_id,
        role="user",
        conteudo=mensagem_usuario,
        tokens_input=response.usage.input_tokens,
    )
    msg_assistant = Mensagem(
        conversa_id=conversa_id,
        role="assistant",
        conteudo=resposta_texto,
        tokens_output=response.usage.output_tokens,
    )
    db.add_all([msg_user, msg_assistant])
    db.commit()

    return {
        "resposta": resposta_texto,
        "modelo": modelo_usar,
        "tokens_input": response.usage.input_tokens,
        "tokens_output": response.usage.output_tokens,
    }
