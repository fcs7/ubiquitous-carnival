from openai import OpenAI
from app.config import settings

client = None


def get_client():
    global client
    if client is None:
        client = OpenAI(api_key=settings.openai_api_key)
    return client


def traduzir_movimento(nome: str, complementos: str = "") -> str:
    prompt = f"""Traduza este andamento processual para linguagem simples que um leigo entenda.
Seja direto, maximo 2 frases. Nao use termos juridicos.

Andamento: {nome}
{f'Detalhes: {complementos}' if complementos else ''}

Traducao:"""

    try:
        resp = get_client().chat.completions.create(
            model="gpt-4o-mini",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=150,
            temperature=0.3,
        )
        return resp.choices[0].message.content.strip()
    except Exception as e:
        return f"{nome} (traducao indisponivel)"
