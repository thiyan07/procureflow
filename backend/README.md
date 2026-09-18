# ProcureFlow Backend

FastAPI + PostgreSQL + Firebase Cloud Messaging

## Architecture

Flutter → FastAPI → PostgreSQL
FastAPI → FCM → Farmer App
Rule-based scheduling engine (deterministic, explainable)

## Requirements
- Python 3.11+
- PostgreSQL 16 (via docker-compose)
- Firebase project for FCM (optional in dev - mock mode)

## Setup

```bash
cp .env.example .env
# edit DATABASE_URL, JWT_SECRET, FCM_*
docker compose up -d
pip install -r requirements.txt
alembic upgrade head
python -m scripts.seed
uvicorn app.main:app --reload --port 8000
```

Docs: http://localhost:8000/docs

## Environment

See `.env.example`. Never commit `.env`.

## Migrations

```bash
alembic revision --autogenerate -m "describe"
alembic upgrade head
alembic downgrade -1
```

## Tests

```bash
pytest -v
# concurrent booking test is critical
pytest -k concurrent -v
```

## FCM

- Configure via env: FCM_PROJECT_ID, FCM_CLIENT_EMAIL, FCM_PRIVATE_KEY
- Or set GOOGLE_APPLICATION_CREDENTIALS to serviceAccount.json (gitignored)
- Flutter registers token via POST /api/v1/notifications/device-token

## Scheduling Engine

See `app/services/scheduling_service.py`. Deterministic scoring:
`score = availability * congestion * load * time * buffer` lower = better.
Tie-break by start_time then id. Explainable debug payload included.

## Queue Wait

`estimated_wait = farmers_ahead * avg_processing / active_counters` (counters=0 handled as 1, ceil).

## Minimal Verification

```bash
curl http://localhost:8000/health
curl -X POST http://localhost:8000/api/v1/auth/send-otp -H "Content-Type: application/json" -d '{"mobile":"9876543210"}'
```
