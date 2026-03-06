import json
import time
from sqlalchemy.orm import Session

from app.models import Conversa, Mensagem, AgenteConfig, ToolExecution
from app.services.claude_chat import (
    SYSTEM_PROMPT_JURIDICO,
    montar_config_escritorio,
    montar_contexto_processo,
    carregar_historico,
)
from app.services.ferramentas import FERRAMENTAS_DISPONIVEIS
from app.services.providers import get_provider


def montar_system_prompt_agente(agente: AgenteConfig, db: Session, processo_id: int | None) -> str:
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
    schemas = []
    for nome in ferramentas_habilitadas:
        if nome in FERRAMENTAS_DISPONIVEIS:
            schemas.append(FERRAMENTAS_DISPONIVEIS[nome]["schema"])
    return schemas


def _executar_ferramenta(tool_name: str, tool_input: dict, tool_use_id: str, db: Session, conversa_id: int) -> str:
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
        output_json=json.dumps({"resultado": resultado}, ensure_ascii=False) if not erro else None,
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
    conversa = db.query(Conversa).filter(Conversa.id == conversa_id).first()
    if not conversa:
        raise ValueError("Conversa nao encontrada")

    agente = conversa.agente_config
    if not agente:
        raise ValueError("Conversa nao tem agente configurado")

    provider = get_provider(agente.provider)
    try:
        ferramentas = json.loads(agente.ferramentas_habilitadas or "[]")
    except json.JSONDecodeError:
        ferramentas = []
    tool_schemas = _obter_tool_schemas(ferramentas)

    system_prompt = montar_system_prompt_agente(agente, db, conversa.processo_id)
    historico = carregar_historico(db, conversa_id)
    historico.append({"role": "user", "content": mensagem_usuario})

    iteracao = 0
    texto_acumulado = ""
    total_input = 0
    total_output = 0

    msg_user = Mensagem(
        conversa_id=conversa_id,
        role="user",
        conteudo=mensagem_usuario,
    )

    try:
        while iteracao < agente.max_iteracoes_tool:
            response = provider.chat(
                model=agente.modelo,
                system=system_prompt,
                messages=historico,
                tools=tool_schemas if tool_schemas else None,
                max_tokens=agente.max_tokens,
            )

            total_input += response.input_tokens
            total_output += response.output_tokens

            if response.stop_reason == "end_turn":
                texto_acumulado += response.text or ""
                break
            elif response.stop_reason == "tool_use":
                texto_acumulado += response.text

                # Monta conteudo do assistente com tool calls para o historico
                assistant_content = provider.format_assistant_with_tools(response.text, response.tool_calls)
                historico.append({"role": "assistant", "content": assistant_content})

                # Executa ferramentas
                tool_results = []
                for tc in response.tool_calls:
                    resultado = _executar_ferramenta(tc.name, tc.input, tc.id, db, conversa_id)
                    tool_results.append(provider.format_tool_result_message(tc.id, resultado))

                historico.append({"role": "user", "content": tool_results})
            else:
                # stop_reason desconhecido (ex: "max_tokens")
                texto_acumulado += response.text or ""
                break

            iteracao += 1

        msg_user.tokens_input = total_input
        msg_assistant = Mensagem(
            conversa_id=conversa_id,
            role="assistant",
            conteudo=texto_acumulado,
            tokens_output=total_output,
        )
        db.add_all([msg_user, msg_assistant])
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
    }


def chat_com_agente_stream(
    db: Session,
    conversa_id: int,
    mensagem_usuario: str,
):
    conversa = db.query(Conversa).filter(Conversa.id == conversa_id).first()
    if not conversa:
        yield f"data: {json.dumps({'tipo': 'erro', 'mensagem': 'Conversa nao encontrada'})}\n\n"
        return

    agente = conversa.agente_config
    if not agente:
        yield f"data: {json.dumps({'tipo': 'erro', 'mensagem': 'Agente nao configurado'})}\n\n"
        return

    provider = get_provider(agente.provider)
    try:
        ferramentas = json.loads(agente.ferramentas_habilitadas or "[]")
    except json.JSONDecodeError:
        ferramentas = []
    tool_schemas = _obter_tool_schemas(ferramentas)

    system_prompt = montar_system_prompt_agente(agente, db, conversa.processo_id)
    historico = carregar_historico(db, conversa_id)
    historico.append({"role": "user", "content": mensagem_usuario})

    iteracao = 0
    texto_acumulado = ""
    total_input = 0
    total_output = 0

    msg_user = Mensagem(
        conversa_id=conversa_id,
        role="user",
        conteudo=mensagem_usuario,
    )

    try:
        while iteracao < agente.max_iteracoes_tool:
            response = provider.chat(
                model=agente.modelo,
                system=system_prompt,
                messages=historico,
                tools=tool_schemas if tool_schemas else None,
                max_tokens=agente.max_tokens,
            )

            total_input += response.input_tokens
            total_output += response.output_tokens

            if response.stop_reason == "end_turn":
                texto_acumulado += response.text or ""
                if response.text:
                    yield f"data: {json.dumps({'tipo': 'texto', 'conteudo': response.text}, ensure_ascii=False)}\n\n"
                break
            elif response.stop_reason == "tool_use":
                if response.text:
                    texto_acumulado += response.text
                    yield f"data: {json.dumps({'tipo': 'texto', 'conteudo': response.text}, ensure_ascii=False)}\n\n"

                for tc in response.tool_calls:
                    yield f"data: {json.dumps({'tipo': 'tool_inicio', 'tool': tc.name})}\n\n"

                assistant_content = provider.format_assistant_with_tools(response.text, response.tool_calls)
                historico.append({"role": "assistant", "content": assistant_content})

                tool_results = []
                for tc in response.tool_calls:
                    resultado = _executar_ferramenta(tc.name, tc.input, tc.id, db, conversa_id)
                    tool_results.append(provider.format_tool_result_message(tc.id, resultado))
                    yield f"data: {json.dumps({'tipo': 'tool_resultado', 'tool': tc.name})}\n\n"

                historico.append({"role": "user", "content": tool_results})
            else:
                # stop_reason desconhecido (ex: "max_tokens")
                texto_acumulado += response.text or ""
                if response.text:
                    yield f"data: {json.dumps({'tipo': 'texto', 'conteudo': response.text}, ensure_ascii=False)}\n\n"
                break

            iteracao += 1

        msg_user.tokens_input = total_input
        msg_assistant = Mensagem(
            conversa_id=conversa_id,
            role="assistant",
            conteudo=texto_acumulado,
            tokens_output=total_output,
        )
        db.add_all([msg_user, msg_assistant])
        db.commit()
    except Exception:
        db.add(msg_user)
        db.commit()
        raise

    yield f"data: {json.dumps({'tipo': 'fim', 'tokens_input': total_input, 'tokens_output': total_output})}\n\n"
