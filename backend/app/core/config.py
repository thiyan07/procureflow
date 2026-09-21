import os
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://procureflow:procureflow@localhost:5432/procureflow"
    jwt_secret: str = "change-me-dev-secret-at-least-32-chars-long"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 30
    jwt_refresh_token_expire_days: int = 7

    otp_provider: str = "mock"  # mock | production (twilio) | brevo
    otp_fixed_code: str = "123456"
    otp_expiry_minutes: int = 5
    otp_max_attempts: int = 3
    # Production OTP (Twilio) — set via env, fail safe if missing
    twilio_account_sid: str = ""
    twilio_auth_token: str = ""
    twilio_from_number: str = ""
    # Brevo Email OTP — primary for production
    brevo_api_key: str = ""
    email_from: str = "noreply@procureflow.in"
    email_from_name: str = "ProcureFlow"
    email_provider: str = "mock"  # mock | brevo | brevo_mock (dev fallback)

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
        env_file = os.path.join(os.path.dirname(__file__), "../../.env") if os.path.exists(os.path.join(os.path.dirname(__file__), "../../.env")) else "backend/.env"
        env_file_encoding = "utf-8"
        case_sensitive = False

    @property
    def is_dev(self) -> bool:
        return self.environment in ("development", "dev")

    @property
    def cors_origins_list(self) -> list[str]:
        return [o.strip() for o in self.cors_origins.split(",") if o.strip()]

    def validate_production(self):
        """Fail fast if production is misconfigured — never silently use dev fallbacks."""
        if self.environment.lower() in ("production", "prod"):
            errors = []
            if "sqlite" in self.database_url.lower():
                errors.append("DATABASE_URL must be PostgreSQL in production, not SQLite")
            if self.jwt_secret == "change-me-dev-secret-at-least-32-chars-long":
                errors.append("JWT_SECRET must be set to a strong random value in production")
            if self.otp_provider.lower() == "mock":
                errors.append("OTP_PROVIDER must be 'production' in production, not 'mock'")
            if self.otp_provider.lower() == "production" and not (self.twilio_account_sid and self.twilio_auth_token and self.twilio_from_number):
                errors.append("TWILIO_* credentials must be set when OTP_PROVIDER=production")
            if not self.fcm_project_id or not self.fcm_client_email or not self.fcm_private_key:
                # FCM is optional but should not silently mock in prod — warn
                import logging
                logging.getLogger(__name__).warning("FCM not configured in production — notifications will be DB-only, not pushed")
            if errors:
                raise ValueError("Production configuration error: " + "; ".join(errors))


@lru_cache
def get_settings() -> Settings:
    s = Settings()  # type: ignore
    # Validate production immediately (fail fast)
    try:
        s.validate_production()
    except ValueError as e:
        # In production, raise; in dev, just log warning
        import logging, os
        if s.environment.lower() in ("production", "prod"):
            raise
        else:
            logging.getLogger(__name__).warning(str(e))
    return s
