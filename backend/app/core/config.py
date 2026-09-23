import os
from pydantic import field_validator
from pydantic_settings import BaseSettings
from functools import lru_cache


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://procureflow:procureflow@localhost:5432/procureflow"

    @field_validator("database_url", mode="before")
    @classmethod
    def _fix_database_url(cls, v: str) -> str:
        # Render free DB gives postgres:// or postgresql:// without driver.
        # SQLAlchemy + psycopg3 needs postgresql+psycopg://
        if isinstance(v, str):
            if v.startswith("postgres://"):
                v = v.replace("postgres://", "postgresql+psycopg://", 1)
            elif v.startswith("postgresql://") and "+psycopg" not in v:
                v = v.replace("postgresql://", "postgresql+psycopg://", 1)
            # Render internal URL may be postgres://... with query ?sslmode=require
        return v
    jwt_secret: str = "change-me-dev-secret-at-least-32-chars-long"
    jwt_algorithm: str = "HS256"
    jwt_access_token_expire_minutes: int = 30
    jwt_refresh_token_expire_days: int = 7

    # DEPRECATED OTP - kept for backward compat only, not used for auth (phone+password+JWT is the only auth)
    # Will be removed in future; production no longer requires OTP config
    otp_provider: str = "deprecated"  # deprecated - OTP removed, kept for compat
    otp_fixed_code: str = "123456"
    otp_expiry_minutes: int = 5
    otp_max_attempts: int = 3
    twilio_account_sid: str = ""  # deprecated
    twilio_auth_token: str = ""  # deprecated
    twilio_from_number: str = ""  # deprecated
    brevo_api_key: str = ""  # email remains optional profile field, not auth
    email_from: str = "noreply@procureflow.in"
    email_from_name: str = "ProcureFlow"
    email_provider: str = "mock"  # deprecated for auth

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
            # OTP deprecated - no longer required for production (phone+password only)
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
