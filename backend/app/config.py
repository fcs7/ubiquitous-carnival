from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://muglia:muglia@db:5432/muglia"
    openai_api_key: str = ""
    anthropic_api_key: str = ""
    vindi_webhook_secret: str = ""
    vindi_api_key: str = ""
    # Google Drive
    google_credentials_path: str = "/run/secrets/google_credentials.json"
    google_drive_root_folder_id: str = ""
    google_drive_pasta_processos: str = "Processos"
    google_drive_pasta_clientes: str = "Clientes"

    class Config:
        env_file = ".env"
        extra = "ignore"


settings = Settings()
