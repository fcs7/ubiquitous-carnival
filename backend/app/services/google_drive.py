"""
Servico de integracao com Google Drive API v3.

SEGURANCA:
- ZERO operacoes de delete — impossivel apagar arquivos do Drive
- Toda escrita valida que o destino esta dentro da pasta raiz configurada
- Audit log de toda operacao que modifica o Drive
- Service Account com escopo restrito a pasta raiz
"""
import functools
import logging

from google.oauth2.service_account import Credentials
from googleapiclient.discovery import build
from googleapiclient.errors import HttpError

from app.config import settings

logger = logging.getLogger(__name__)

SCOPES = ["https://www.googleapis.com/auth/drive"]
FOLDER_MIME = "application/vnd.google-apps.folder"
FIELDS_LISTA = "files(id,name,mimeType,webViewLink,modifiedTime,size,parents)"
FIELDS_ARQUIVO = "id,name,mimeType,webViewLink,modifiedTime,size,parents"


class DriveServiceError(Exception):
    """Erro ao comunicar com Google Drive."""


# ──────────────────────────────────────────────
# Singleton de autenticacao
# ──────────────────────────────────────────────
@functools.cache
def _get_service():
    try:
        creds = Credentials.from_service_account_file(
            settings.google_credentials_path, scopes=SCOPES,
        )
        return build("drive", "v3", credentials=creds, cache_discovery=False)
    except Exception as e:
        raise DriveServiceError(f"Falha ao autenticar no Google Drive: {e}") from e


# ──────────────────────────────────────────────
# Seguranca: validacao de escopo
# ──────────────────────────────────────────────
def _validar_dentro_raiz(file_id: str) -> None:
    """Verifica se o arquivo/pasta esta dentro da pasta raiz configurada.
    Sobe a hierarquia de parents ate encontrar a raiz ou atingir o limite."""
    raiz = settings.google_drive_root_folder_id
    if not raiz:
        raise DriveServiceError("GOOGLE_DRIVE_ROOT_FOLDER_ID nao configurado")
    if file_id == raiz:
        return

    service = _get_service()
    atual = file_id
    for _ in range(20):  # limite de profundidade
        try:
            meta = service.files().get(fileId=atual, fields="id,parents").execute()
        except HttpError as e:
            raise DriveServiceError(f"Erro ao validar escopo: {e}") from e
        parents = meta.get("parents", [])
        if not parents:
            raise DriveServiceError(
                f"SEGURANCA: arquivo {file_id} esta FORA da pasta raiz configurada. Operacao bloqueada."
            )
        if raiz in parents:
            return
        atual = parents[0]
    raise DriveServiceError(
        f"SEGURANCA: hierarquia muito profunda para {file_id}. Operacao bloqueada."
    )


# ──────────────────────────────────────────────
# Leitura (sem restricao de escrita)
# ──────────────────────────────────────────────
def listar_pasta(pasta_id: str, apenas_pastas: bool = False) -> list[dict]:
    """Lista conteudo de uma pasta do Drive."""
    service = _get_service()
    q = f"'{pasta_id}' in parents and trashed=false"
    if apenas_pastas:
        q += f" and mimeType='{FOLDER_MIME}'"
    try:
        resultado = service.files().list(
            q=q, fields=FIELDS_LISTA, orderBy="name", pageSize=1000,
        ).execute()
        return resultado.get("files", [])
    except HttpError as e:
        raise DriveServiceError(f"Erro ao listar pasta: {e}") from e


def buscar_arquivo(nome: str, pasta_id: str | None = None) -> list[dict]:
    """Busca arquivos por nome (parcial)."""
    service = _get_service()
    q = f"name contains '{nome}' and trashed=false"
    if pasta_id:
        q += f" and '{pasta_id}' in parents"
    try:
        resultado = service.files().list(
            q=q, fields=FIELDS_LISTA, orderBy="name", pageSize=100,
        ).execute()
        return resultado.get("files", [])
    except HttpError as e:
        raise DriveServiceError(f"Erro ao buscar arquivo: {e}") from e


def obter_metadados(file_id: str) -> dict:
    """Obtem metadados de um arquivo."""
    service = _get_service()
    try:
        return service.files().get(fileId=file_id, fields=FIELDS_ARQUIVO).execute()
    except HttpError as e:
        raise DriveServiceError(f"Erro ao obter metadados: {e}") from e


# ──────────────────────────────────────────────
# Escrita (com validacao de seguranca + audit log)
# ──────────────────────────────────────────────
def criar_pasta(nome: str, pasta_pai_id: str) -> dict:
    """Cria uma pasta dentro de outra. Valida escopo antes."""
    _validar_dentro_raiz(pasta_pai_id)
    service = _get_service()
    metadata = {
        "name": nome,
        "mimeType": FOLDER_MIME,
        "parents": [pasta_pai_id],
    }
    try:
        pasta = service.files().create(body=metadata, fields=FIELDS_ARQUIVO).execute()
        logger.info("DRIVE AUDIT: Pasta criada — nome=%s, id=%s, pai=%s", nome, pasta["id"], pasta_pai_id)
        return pasta
    except HttpError as e:
        raise DriveServiceError(f"Erro ao criar pasta: {e}") from e


def obter_ou_criar_pasta(nome: str, pasta_pai_id: str) -> dict:
    """Busca pasta por nome dentro do pai. Cria se nao existir. Idempotente."""
    service = _get_service()
    q = f"name='{nome}' and '{pasta_pai_id}' in parents and mimeType='{FOLDER_MIME}' and trashed=false"
    try:
        resultado = service.files().list(q=q, fields=FIELDS_LISTA, pageSize=1).execute()
    except HttpError as e:
        raise DriveServiceError(f"Erro ao buscar pasta existente: {e}") from e

    existentes = resultado.get("files", [])
    if existentes:
        return existentes[0]
    return criar_pasta(nome, pasta_pai_id)


def mover_arquivo(file_id: str, nova_pasta_id: str) -> dict:
    """Move arquivo para outra pasta. Valida escopo de ambos."""
    _validar_dentro_raiz(file_id)
    _validar_dentro_raiz(nova_pasta_id)
    service = _get_service()
    try:
        arquivo = service.files().get(fileId=file_id, fields="parents").execute()
        parents_atuais = ",".join(arquivo.get("parents", []))
        resultado = service.files().update(
            fileId=file_id,
            addParents=nova_pasta_id,
            removeParents=parents_atuais,
            fields=FIELDS_ARQUIVO,
        ).execute()
        logger.info(
            "DRIVE AUDIT: Arquivo movido — id=%s, de=%s, para=%s",
            file_id, parents_atuais, nova_pasta_id,
        )
        return resultado
    except HttpError as e:
        raise DriveServiceError(f"Erro ao mover arquivo: {e}") from e


# ──────────────────────────────────────────────
# Organizacao de pastas por processo
# ──────────────────────────────────────────────
def montar_pasta_processo(cnj: str, cliente_nome: str | None = None) -> dict:
    """Cria hierarquia raiz/ → Processos/ → {cnj}/ no Drive.
    Retorna metadados da pasta do processo."""
    raiz = settings.google_drive_root_folder_id
    if not raiz:
        raise DriveServiceError("GOOGLE_DRIVE_ROOT_FOLDER_ID nao configurado")

    pasta_processos = obter_ou_criar_pasta(settings.google_drive_pasta_processos, raiz)
    nome_pasta = cnj
    if cliente_nome:
        nome_pasta = f"{cnj} — {cliente_nome}"
    pasta_processo = obter_ou_criar_pasta(nome_pasta, pasta_processos["id"])

    logger.info("DRIVE AUDIT: Pasta de processo montada — cnj=%s, pasta_id=%s", cnj, pasta_processo["id"])
    return pasta_processo


def simular_organizacao(cnj: str, cliente_nome: str | None = None) -> dict:
    """Modo dry-run: retorna a estrutura que SERIA criada, sem modificar o Drive."""
    raiz = settings.google_drive_root_folder_id
    nome_pasta = cnj
    if cliente_nome:
        nome_pasta = f"{cnj} — {cliente_nome}"
    return {
        "acao": "simulacao",
        "estrutura": f"{settings.google_drive_pasta_processos}/{nome_pasta}/",
        "pasta_raiz_id": raiz,
        "mensagem": "Nenhuma alteracao foi feita no Drive. Use simular=false para executar.",
    }
