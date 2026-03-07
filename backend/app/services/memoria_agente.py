"""
Servico de geracao de memoria de agentes a partir de arquivos do Google Drive.

Fluxo: pasta Drive → baixar conteudo textual → Claude gera .md estruturados
       → salva em data/agentes/{agente_id}/*.md
"""
import json
import logging
from dataclasses import dataclass, field
from pathlib import Path

from app.services.google_drive import (
    FOLDER_MIME,
    DriveServiceError,
    _validar_dentro_raiz,
    baixar_conteudo_arquivo,
    listar_pasta,
)

logger = logging.getLogger(__name__)

PASTA_BASE = Path("data/agentes")

META_PROMPT_MEMORIA = """Voce e um especialista em organizar conhecimento juridico.

Sua tarefa e analisar documentos de um escritorio de advocacia e gerar arquivos de memoria estruturados em Markdown.

Regras:
1. Identifique temas e topicos distintos nos documentos fornecidos
2. Gere um JSON com chaves sendo nomes de arquivo snake_case terminando em .md e valores sendo conteudo Markdown
3. Cada arquivo deve ter um titulo (# Titulo), secoes claras, e ser focado em um tema
4. Sempre inclua uma chave "index.md" com um indice listando todos os arquivos gerados com resumos de uma frase
5. Mantenha cada arquivo com no maximo 600 palavras
6. O conteudo deve ser em portugues brasileiro
7. Extraia informacoes uteis: procedimentos, jurisprudencia, modelos, regras do escritorio, dados de clientes
8. NAO inclua dados sensíveis como senhas ou tokens
9. Retorne APENAS o JSON, sem explicacoes adicionais

Formato de saida (JSON puro):
{
  "index.md": "# Indice\\n\\n- **tema.md** — Descricao breve\\n",
  "tema.md": "# Titulo do Tema\\n\\nConteudo organizado...\\n"
}"""

MAX_CARACTERES_POR_ARQUIVO = 8000


@dataclass
class GeracaoMemoriaResult:
    arquivos_gerados: list[str] = field(default_factory=list)
    arquivos_fonte: int = 0
    tokens_usados: int = 0
    pasta_local: str = ""


def pasta_agente(agente_id: int) -> Path:
    """Retorna o caminho da pasta de memoria do agente, criando se necessario."""
    pasta = PASTA_BASE / str(agente_id)
    pasta.mkdir(parents=True, exist_ok=True)
    return pasta


def listar_arquivos_memoria(agente_id: int) -> list[str]:
    """Lista nomes dos arquivos .md na pasta de memoria do agente."""
    pasta = PASTA_BASE / str(agente_id)
    if not pasta.exists():
        return []
    return sorted(f.name for f in pasta.glob("*.md"))


def carregar_memoria(agente_id: int) -> str:
    """Le todos os .md da pasta do agente e monta bloco XML para o system prompt.
    Retorna string vazia se nao houver arquivos."""
    pasta = PASTA_BASE / str(agente_id)
    if not pasta.exists():
        return ""

    arquivos = sorted(pasta.glob("*.md"))
    if not arquivos:
        return ""

    partes = ["<memoria_agente>"]
    for arq in arquivos:
        if arq.name == "index.md":
            continue
        conteudo = arq.read_text(encoding="utf-8")
        # Trunca arquivos muito grandes para nao estourar o contexto
        if len(conteudo) > MAX_CARACTERES_POR_ARQUIVO:
            conteudo = conteudo[:MAX_CARACTERES_POR_ARQUIVO] + "\n\n[...truncado]"
        partes.append(f"<arquivo nome='{arq.name}'>\n{conteudo}\n</arquivo>")
    partes.append("</memoria_agente>")

    return "\n".join(partes)


def gerar_e_salvar_memoria(agente_id: int, pasta_drive_id: str) -> GeracaoMemoriaResult:
    """Orquestra o fluxo completo: Drive → Claude → .md files."""
    # 1. Seguranca: validar que a pasta esta dentro da raiz
    _validar_dentro_raiz(pasta_drive_id)

    # 2. Listar arquivos da pasta (nao-recursivo)
    itens = listar_pasta(pasta_drive_id)
    arquivos_drive = [item for item in itens if item.get("mimeType") != FOLDER_MIME]

    if not arquivos_drive:
        return GeracaoMemoriaResult(pasta_local=str(pasta_agente(agente_id)))

    # 3. Baixar conteudo textual de cada arquivo
    conteudos = []
    for item in arquivos_drive:
        nome, texto = baixar_conteudo_arquivo(item["id"])
        if nome and texto.strip():
            conteudos.append((nome, texto))

    if not conteudos:
        return GeracaoMemoriaResult(
            arquivos_fonte=len(arquivos_drive),
            pasta_local=str(pasta_agente(agente_id)),
        )

    # 4. Chamar Claude para gerar memoria estruturada
    arquivos_md, tokens = _chamar_claude_para_memoria(conteudos)

    # 5. Salvar .md files no filesystem
    pasta = pasta_agente(agente_id)
    # Limpa arquivos anteriores
    for antigo in pasta.glob("*.md"):
        antigo.unlink()

    nomes_gerados = []
    for nome_arquivo, conteudo_md in arquivos_md.items():
        caminho = pasta / nome_arquivo
        caminho.write_text(conteudo_md, encoding="utf-8")
        nomes_gerados.append(nome_arquivo)

    logger.info(
        "MEMORIA AGENTE: agente_id=%d, fontes=%d, gerados=%d, tokens=%d",
        agente_id, len(conteudos), len(nomes_gerados), tokens,
    )

    return GeracaoMemoriaResult(
        arquivos_gerados=sorted(nomes_gerados),
        arquivos_fonte=len(conteudos),
        tokens_usados=tokens,
        pasta_local=str(pasta),
    )


def _chamar_claude_para_memoria(conteudos: list[tuple[str, str]]) -> tuple[dict[str, str], int]:
    """Envia conteudos dos arquivos para Claude e retorna dict de .md files gerados.
    Retorna (arquivos_md, tokens_usados)."""
    from app.services.providers.anthropic_provider import _get_client

    # Monta o bloco de arquivos fonte
    partes_fonte = ["<arquivos_fonte>"]
    for nome, texto in conteudos:
        # Trunca arquivos fonte muito grandes
        if len(texto) > 10000:
            texto = texto[:10000] + "\n\n[...truncado]"
        partes_fonte.append(f"<arquivo nome='{nome}'>\n{texto}\n</arquivo>")
    partes_fonte.append("</arquivos_fonte>")

    user_msg = (
        "Analise os seguintes documentos e gere arquivos de memoria "
        "estruturados em Markdown.\n\n"
        + "\n".join(partes_fonte)
        + "\n\nGere APENAS o JSON conforme as instrucoes."
    )

    client = _get_client()
    response = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=4096,
        system=META_PROMPT_MEMORIA,
        messages=[{"role": "user", "content": user_msg}],
    )

    texto_resposta = ""
    for block in response.content:
        if hasattr(block, "text") and block.type == "text":
            texto_resposta += block.text

    tokens = (response.usage.input_tokens or 0) + (response.usage.output_tokens or 0)

    # Parsear JSON da resposta
    try:
        arquivos_md = json.loads(texto_resposta.strip())
    except json.JSONDecodeError:
        # Tenta extrair JSON de dentro de code fences
        import re
        match = re.search(r"```(?:json)?\s*\n(.*?)\n```", texto_resposta, re.DOTALL)
        if match:
            arquivos_md = json.loads(match.group(1).strip())
        else:
            raise DriveServiceError(
                "Erro ao interpretar resposta da IA. Tente novamente."
            )

    if not isinstance(arquivos_md, dict):
        raise DriveServiceError("Resposta da IA nao e um dicionario de arquivos.")

    return arquivos_md, tokens
