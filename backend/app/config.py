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

    class Config:
        env_file = ".env"


settings = Settings()
