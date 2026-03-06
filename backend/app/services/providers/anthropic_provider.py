import anthropic
from app.config import settings
from app.services.providers.base import ProviderResponse, ToolCall

_client = None


def _get_client():
    global _client
    if _client is None:
        _client = anthropic.Anthropic(api_key=settings.anthropic_api_key)
    return _client


class AnthropicProvider:
    """Provider Anthropic (Claude) com tool use."""

    def chat(
        self,
        model: str,
        system: str,
        messages: list[dict],
        tools: list[dict] | None = None,
        max_tokens: int = 4096,
    ) -> ProviderResponse:
        client = _get_client()

        kwargs = {
            "model": model,
            "max_tokens": max_tokens,
            "system": system,
            "messages": messages,
        }
        if tools:
            kwargs["tools"] = tools

        response = client.messages.create(**kwargs)

        text = ""
        tool_calls = []
        for block in response.content:
            if hasattr(block, "text") and block.type == "text":
                text += block.text
            elif block.type == "tool_use":
                tool_calls.append(ToolCall(
                    id=block.id,
                    name=block.name,
                    input=block.input,
                ))

        return ProviderResponse(
            text=text,
            tool_calls=tool_calls,
            stop_reason=response.stop_reason,
            input_tokens=response.usage.input_tokens,
            output_tokens=response.usage.output_tokens,
        )

    def format_tool_schemas(self, tools: list[dict]) -> list[dict]:
        """Anthropic usa o formato nativo — retorna como esta."""
        return tools

    def format_tool_results(self, results: list[dict]) -> list[dict]:
        """Formata resultados de tool para o formato Anthropic."""
        return results

    def format_assistant_with_tools(self, text: str, tool_calls: list[ToolCall]) -> list[dict]:
        """Formata mensagem do assistente com tool_use para o historico."""
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
        """Formata resultado de uma tool para incluir no historico."""
        return {
            "type": "tool_result",
            "tool_use_id": tool_call_id,
            "content": result,
        }
