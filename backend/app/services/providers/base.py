from dataclasses import dataclass, field


@dataclass
class ToolCall:
    """Representacao unificada de uma chamada de ferramenta."""
    id: str
    name: str
    input: dict


@dataclass
class ProviderResponse:
    """Resposta normalizada de qualquer provider."""
    text: str
    tool_calls: list[ToolCall] = field(default_factory=list)
    stop_reason: str = "end_turn"  # "end_turn" ou "tool_use"
    input_tokens: int = 0
    output_tokens: int = 0
