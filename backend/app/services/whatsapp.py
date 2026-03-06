import requests
from app.config import settings

INSTANCIA = "muglia"


def _headers() -> dict:
    return {
        "apikey": settings.evolution_api_key,
        "Content-Type": "application/json",
    }


def enviar_mensagem(telefone: str, mensagem: str) -> bool:
    url = f"{settings.evolution_api_url}/message/sendText/{INSTANCIA}"
    body = {
        "number": telefone,
        "text": mensagem,
    }
    try:
        resp = requests.post(url, headers=_headers(), json=body, timeout=10)
        return resp.status_code in (200, 201)
    except Exception:
        return False


def formatar_notificacao(cnj: str, resumo: str) -> str:
    return f"Atualizacao no processo {cnj}:\n\n{resumo}\n\n- Escritorio Muglia"


def criar_instancia(nome: str = INSTANCIA) -> dict:
    url = f"{settings.evolution_api_url}/instance/create"
    body = {
        "instanceName": nome,
        "integration": "WHATSAPP-BAILEYS",
    }
    resp = requests.post(url, headers=_headers(), json=body, timeout=10)
    return resp.json()


def obter_qrcode(nome: str = INSTANCIA) -> dict:
    url = f"{settings.evolution_api_url}/instance/connect/{nome}"
    resp = requests.get(url, headers=_headers(), timeout=10)
    return resp.json()


def obter_status(nome: str = INSTANCIA) -> dict:
    url = f"{settings.evolution_api_url}/instance/connectionState/{nome}"
    resp = requests.get(url, headers=_headers(), timeout=10)
    return resp.json()


def listar_instancias() -> list:
    url = f"{settings.evolution_api_url}/instance/fetchInstances"
    resp = requests.get(url, headers=_headers(), timeout=10)
    return resp.json()
