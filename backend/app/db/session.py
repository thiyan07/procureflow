from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app.core.config import get_settings

settings = get_settings()
try:
    engine = create_engine(settings.database_url, pool_pre_ping=True, future=True)
except Exception as e:
    # Fallback to SQLite so /health still responds even if Postgres URL is invalid/provisioning
    import logging
    logging.getLogger(__name__).warning(f"DB engine failed for {settings.database_url[:30]}... fall back to SQLite: {e}")
    engine = create_engine("sqlite:////tmp/procureflow.db", pool_pre_ping=True, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
