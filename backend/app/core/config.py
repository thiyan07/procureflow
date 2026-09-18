from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://procureflow:procureflow@localhost:5432/procureflow"
    jwt_secret: str = "change-me-dev-secret-at-least-32-chars-long"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 30
    jwt_refresh_token_expire_days: int = 7

    otp_provider: str = "mock"
    otp_fixed_code: str = "123456"
    otp_expiry_minutes: int = 5
    otp_max_attempts: int = 3

    fcm_project_id: str = ""
    fcm_client_email: str = ""
    fcm_private_key: str = ""

    environment: str = "development"
    api_v1_prefix: str = "/api/v1"
    cors_origins: str = "http://localhost:3000,http://localhost:5173"

    scheduler_safety_buffer: int = 2
    default_active_counters: int = 3
    default_avg_processing_minutes: int = 3

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"
        case_sensitive = False

    @property
    def is_dev(self) -> bool:
        return self.environment in ("development", "dev")

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]


@lru_cache
def get_settings() -> Settings:
    return Settings()  # type: ignore
