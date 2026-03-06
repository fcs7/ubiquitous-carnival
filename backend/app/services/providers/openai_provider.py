import json
from openai import OpenAI
from app.config import settings
from app.services.providers.base import ProviderResponse, ToolCall

_client = None


def _get_client():
    global _client
    if _client is None:
        _client = OpenAI(api_key=settings.openai_api_key)
    return _client


class OpenAIProvider:
    """Provider OpenAI (GPT) com tool use (function calling)."""

    def chat(
        self,
        model: str,
        system: str,
        messages: list[dict],
        tools: list[dict] | None = None,
        max_tokens: int = 4096,
    ) -> ProviderResponse:
        client = _get_client()

        # OpenAI usa system como primeira mensagem
        oai_messages = [{"role": "system", "content": system}]
        oai_messages.extend(self._converter_mensagens(messages))

        kwargs = {
            "model": model,
            "max_tokens": max_tokens,
            "messages": oai_messages,
        }
        if tools:
            kwargs["tools"] = self.format_tool_schemas(tools)

        response = client.chat.completions.create(**kwargs)

        choice = response.choices[0]
        message = choice.message

        text = message.content or ""
        tool_calls = []

        if message.tool_calls:
            for tc in message.tool_calls:
                tool_calls.append(ToolCall(
                    id=tc.id,
                    name=tc.function.name,
                    input=json.loads(tc.function.arguments),
                ))

        stop_reason = "tool_use" if tool_calls else "end_turn"

        return ProviderResponse(
            text=text,
            tool_calls=tool_calls,
            stop_reason=stop_reason,
            input_tokens=response.usage.prompt_tokens if response.usage else 0,
            output_tokens=response.usage.completion_tokens if response.usage else 0,
        )

    def format_tool_schemas(self, anthropic_tools: list[dict]) -> list[dict]:
        """Converte tool schemas do formato Anthropic para OpenAI."""
        oai_tools = []
        for tool in anthropic_tools:
            oai_tools.append({
                "type": "function",
                "function": {
                    "name": tool["name"],
                    "description": tool.get("description", ""),
                    "parameters": tool.get("input_schema", {"type": "object", "properties": {}}),
                },
            })
        return oai_tools

    def _converter_mensagens(self, messages: list[dict]) -> list[dict]:
        """Converte historico do formato Anthropic para OpenAI."""
        oai_msgs = []
        for msg in messages:
            role = msg["role"]
            content = msg["content"]

            # Mensagem simples (string)
            if isinstance(content, str):
                oai_msgs.append({"role": role, "content": content})
                continue

            # Mensagem com blocos (tool_use / tool_result)
            if isinstance(content, list):
                # Assistente com tool_use
                if role == "assistant":
                    text_parts = []
                    tool_calls = []
                    for block in content:
                        if block.get("type") == "text":
                            text_parts.append(block["text"])
                        elif block.get("type") == "tool_use":
                            tool_calls.append({
                                "id": block["id"],
                                "type": "function",
                                "function": {
                                    "name": block["name"],
                                    "arguments": json.dumps(block["input"]),
                                },
                            })
                    oai_msg = {"role": "assistant", "content": "\n".join(text_parts) or None}
                    if tool_calls:
                        oai_msg["tool_calls"] = tool_calls
                    oai_msgs.append(oai_msg)

                # User com tool_result
                elif role == "user":
                    for block in content:
                        if block.get("type") == "tool_result":
                            oai_msgs.append({
                                "role": "tool",
                                "tool_call_id": block["tool_use_id"],
                                "content": block["content"],
                            })

        return oai_msgs

    def format_assistant_with_tools(self, text: str, tool_calls: list[ToolCall]) -> list[dict]:
        """Formata mensagem do assistente com tool_use para o historico (formato Anthropic interno)."""
        content = []
        if text:
            content.append({"type": "text", "text": text})
        for tc in tool_calls:
            content.append({
                "type": "tool_use",
                "id": tc.id,
                "name": tc.name,
                "input": tc.input,
            })
        return content

    def format_tool_result_message(self, tool_call_id: str, result: str) -> dict:
        """Formata resultado de uma tool para incluir no historico (formato Anthropic interno)."""
        return {
            "type": "tool_result",
            "tool_use_id": tool_call_id,
            "content": result,
        }
