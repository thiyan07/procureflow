from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import logging
import time
import uuid

from app.core.config import get_settings
from app.core.logging import setup_logging, request_id_ctx, user_id_ctx
from app.api.routes import auth, farmers, centres, slots, bookings, queue, procurement, payments, notifications, ai, assistant, analytics, feedback, commodities
from app.db.session import engine
from app.db.base import Base

settings = get_settings()
setup_logging()
log = logging.getLogger(__name__)

app = FastAPI(title="ProcureFlow API", version="1.0.0", description="Procurement Centre Management - FastAPI + PostgreSQL + FCM")

app.add_middleware(CORSMiddleware, allow_origins=settings.cors_origins_list or ["*"], allow_credentials=True, allow_methods=["*"], allow_headers=["*"])

@app.middleware("http")
async def add_request_id(request: Request, call_next):
    rid = request.headers.get("X-Request-ID", uuid.uuid4().hex[:12])
    request_id_ctx.set(rid)
    # user_id from token if present - best effort
    start = time.time()
    response = await call_next(request)
    response.headers["X-Request-ID"] = rid
    duration = (time.time() - start) * 1000
    log.info(f"{request.method} {request.url.path} -> {response.status_code} {duration:.1f}ms")
    return response

@app.exception_handler(Exception)
async def generic_handler(request: Request, exc: Exception):
    log.exception(f"Unhandled error: {exc}")
    return JSONResponse(status_code=500, content={"error": {"code": "INTERNAL_ERROR", "message": "Something went wrong"}})

app.include_router(auth.router, prefix=f"{settings.api_v1_prefix}/auth", tags=["auth"])
app.include_router(farmers.router, prefix=f"{settings.api_v1_prefix}/farmers", tags=["farmers"])
app.include_router(centres.router, prefix=f"{settings.api_v1_prefix}/centres", tags=["centres"])
app.include_router(slots.router, prefix=f"{settings.api_v1_prefix}/slots", tags=["slots"])
app.include_router(bookings.router, prefix=f"{settings.api_v1_prefix}/bookings", tags=["bookings"])
app.include_router(queue.router, prefix=f"{settings.api_v1_prefix}/queue", tags=["queue"])
app.include_router(procurement.router, prefix=f"{settings.api_v1_prefix}/procurements", tags=["procurements"])
app.include_router(payments.router, prefix=f"{settings.api_v1_prefix}/payments", tags=["payments"])
app.include_router(notifications.router, prefix=f"{settings.api_v1_prefix}/notifications", tags=["notifications"])
app.include_router(ai.router, prefix=f"{settings.api_v1_prefix}/ai", tags=["ai"])
app.include_router(assistant.router, prefix=f"{settings.api_v1_prefix}/assistant", tags=["assistant"])
app.include_router(analytics.router, prefix=f"{settings.api_v1_prefix}/analytics", tags=["analytics"])
app.include_router(feedback.router, prefix=f"{settings.api_v1_prefix}/feedback", tags=["feedback"])
app.include_router(commodities.router, prefix=f"{settings.api_v1_prefix}/commodities", tags=["commodities"])

@app.get("/health")
def health():
    return {"status": "ok", "env": settings.environment}

@app.get("/")
def root():
    return {"message": "ProcureFlow API", "docs": "/docs"}

@app.on_event("startup")
def on_startup():
    # ensure tables exist even in prod fallback (SQLite) so /health works; alembic is primary for Postgres
    try:
        Base.metadata.create_all(bind=engine)
        log.info(f"DB tables ensured (env={settings.environment}, db={str(engine.url)[:30]}...)")
    except Exception as e:
        log.warning(f"DB create_all failed (maybe no DB): {e}")
