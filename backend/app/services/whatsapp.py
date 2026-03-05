import requests
from app.config import settings


def enviar_mensagem(telefone: str, mensagem: str) -> bool:
    url = f"{settings.evolution_api_url}/message/sendText/muglia"
    headers = {
        "apikey": settings.evolution_api_key,
        "Content-Type": "application/json",
    }
    body = {
        "number": telefone,
        "text": mensagem,
    }
    try:
        resp = requests.post(url, headers=headers, json=body, timeout=10)
        return resp.status_code in (200, 201)
    except Exception:
        return False


def formatar_notificacao(cnj: str, resumo: str) -> str:
    return f"Atualizacao no processo {cnj}:\n\n{resumo}\n\n- Escritorio Muglia"
