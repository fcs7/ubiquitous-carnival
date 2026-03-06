from app.services.providers.base import ProviderResponse, ToolCall
from app.services.providers.anthropic_provider import AnthropicProvider
from app.services.providers.openai_provider import OpenAIProvider


PROVIDERS = {
    "anthropic": AnthropicProvider,
    "openai": OpenAIProvider,
}


def get_provider(provider_name: str):
    """Factory: retorna instancia do provider pelo nome."""
    cls = PROVIDERS.get(provider_name)
    if not cls:
        raise ValueError(f"Provider '{provider_name}' nao suportado. Disponiveis: {list(PROVIDERS.keys())}")
    return cls()
