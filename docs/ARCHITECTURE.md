# ProcureFlow Architecture

## Overview
Flutter (Riverpod, GoRouter) → FastAPI → PostgreSQL/SQLite → FCM. Deterministic scheduler is safety layer; AI enhances wait prediction.

## Backend — Updated 2026-09-18 Pass 2
- `app/main.py` FastAPI 1.0.0, CORS `*` dev, `X-Request-ID` middleware
- Routers `/api/v1`: auth, farmers, centres (+`documents/capacity/alerts`), slots, bookings (`commodities` multi + `reschedule/cancel` blocked after weighment), queue (+`NO_SHOW` audit), procurements (+`weighment/quality/receipt`), payments, notifications (+`centre_closure`), ai (+`demand-forecast/anomalies`), assistant, analytics, feedback — 13 routers
- `core/config.py` `pydantic-settings` env `database_url`, `jwt_secret`, `fcm_*`, `scheduler_safety_buffer`
- `core/security.py` JWT HS256 access 30m refresh 7d, `passlib bcrypt`
- `db/base.py` `DeclarativeBase` eager imports, `session.py` `create_engine pool_pre_ping`
- Models 18 tables: users (mobile unique), farmers (user_id unique), procurement_centres, commodities, slots `uq_slot_centre_date_time + ck_booked_capacity`, bookings (`commodities_json TEXT` multi-commodity), queue_tokens `booking_id unique`, centre_queue_states PK (centre_id,date), procurements, payments, notifications, device_tokens, feedbacks, audit_logs, weighments, quality_checks, procurement_events, queue_events

## Scheduling
`services/scheduling_service.py` 10 rules scoring `availability*congestion*load*time*buffer`, `calculate_wait(farmers_ahead, avg, counters)` ceil.

## AI
- `waiting_time_service.py` LinearRegression numpy synthetic 800 rows R2~0.85 fallback rule
- `centre_load_service.py` linear trend 7-day `LOW/NORMAL/HIGH`
- `ai/demand-forecast` 4-week weekday avg fallback baseline 18 + `anomalies` rule-based queue/spike/capacity/delay (no heavy ML)
- Pipeline: VALID FILTER → RULE SAFETY → AI WAIT → LOAD → RECOMMENDATION → EXPLANATION
- `api/routes/ai.py` `/predict-wait`, `/centre-load/{id}`, `/slot-recommendation-ai/{id}`, `/demand-forecast`, `/anomalies/{id}`

## DB Relations
User→Farmer→Booking→Slot→QueueToken→Procurement→Payment→Notification; FK cascade, `with_for_update` for booking atomic.

## Flutter
`lib/main.dart` `ProviderScope` `LocalStorage` `FCMService`, `core/routing/app_router.dart` GoRouter + `/receipt`, `core/config/demo_config.dart` `USE_MOCK` `API_BASE_URL`, `services/api/*` 9 repos + `api_ai_repository.dart`, `features/*` 15 screens `planner` full, `bookings/history`, `receipt`, `slots` multi-commodity, `analytics` capacity/alerts/demand/anomaly + centre filter, `operator/queue` weighment/quality, `l10n` en 104/ta 96/hi 96 + new strings, `models` `Booking.commodities`.

## FCM
`integrations/firebase/fcm_service.py` mock if no creds, `device_tokens` dedup, `notification_service.py` 8 types, Flutter `fcm_service.dart` handles foreground/background tap via `notification_router`.

## Audit
`services/audit_service.py` `audit_logs` (actor, action, entity, details redacted), logged on booking, queue, procurement, payment.
