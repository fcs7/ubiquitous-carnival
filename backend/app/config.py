from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    database_url: str = "postgresql://muglia:muglia@db:5432/muglia"
    redis_url: str = "redis://redis:6379/0"
    openai_api_key: str = ""
    datajud_api_key: str = "cDZHYzlZa0JadVREZDJCendQbXY6SkJlTzNjLV9TRENyQk1RdnFKZGRQdw=="
    datajud_base_url: str = "https://api-publica.datajud.cnj.jus.br"
    evolution_api_url: str = "http://evolution:8080"
    evolution_api_key: str = ""
    anthropic_api_key: str = ""
    vindi_webhook_secret: str = ""
    vindi_api_key: str = ""
    # Monitoramento
    grafana_url: str = "http://localhost:3001"
    # Alertas
    alert_whatsapp_number: str = ""
    # Google Drive
    google_credentials_path: str = "/run/secrets/google_credentials.json"
    google_drive_root_folder_id: str = ""
    google_drive_pasta_processos: str = "Processos"
    google_drive_pasta_clientes: str = "Clientes"

    class Config:
        env_file = ".env"


settings = Settings()
