# ProcureFlow — Smart Procurement Centre Management (SIH26032)

**Flutter + FastAPI + PostgreSQL/SQLite + Firebase Cloud Messaging + Rule-Based Scheduling**

Tamil Nadu Civil Supplies Corporation (TNCSC) Direct Purchase Centres (DPC) for Erode district. Real MSP KMS 2026-27: Paddy Common ₹2441, Grade A ₹2461 (PIB PRID 2260618 May 13 2026).

## Architecture — Feature Frozen 2026-09-18
- **Flutter** (`lib/`) Riverpod + GoRouter, l10n en/ta/hi (104 keys), `DemoConfig` mock/api dual mode (`USE_MOCK` dart-define), 14 screens: home, centres, booking, history, day planner, token, queue, procurement, payment, notifications, assistant, feedback, operator, analytics
- **FastAPI** (`backend/app/main.py` v1.0.0) JWT HS256, 13 routers `/api/v1/*`: auth, farmers, centres, slots, bookings (reschedule/cancel), queue, procurements, payments, notifications (pagination), ai (predict-wait, centre-load, slot-recommendation-ai), assistant (ask/faq), analytics, feedback
- **PostgreSQL** (prod) / **SQLite** fallback (`backend/dev.db`) — 18 tables: users→farmers→bookings→slots→queue_tokens→centre_queue_states→procurements→payments→notifications→device_tokens→feedback→audit_logs (+ weighments, quality_checks)
- **FCM** `backend/app/integrations/firebase/fcm_service.py` mock `[FCM-MOCK]` when `FCM_*` empty, 10 notification types, tap routing
- **Scheduler** `backend/app/services/scheduling_service.py` deterministic 10-rule engine + AI wait/centre-load via `numpy` fallback
- **Docs:** `docs/FEATURES.md` (core/smart/ai/operator/admin), `docs/ARCHITECTURE.md`, `docs/USER_FLOWS.md`, `docs/AI.md`, `docs/DEMO_FLOW.md`, `docs/FEATURE_DECISIONS.md`

## Flutter Setup
```bash
flutter --version # 3.44.7 Dart 3.12.2
flutter pub get
# API mode (default): backend at 127.0.0.1:8000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
# Android emulator:
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
# Mock mode:
flutter run --dart-define=USE_MOCK=true
```

## Backend Setup
```bash
cd backend
python -m venv venv && source venv/bin/activate
pip install -r requirements.txt
# .env (see .env.example) — sqlite for dev, postgres for prod:
# database_url=sqlite:////home/thiyan/projects/ece/backend/dev.db
# database_url=postgresql+psycopg://procureflow:procureflow@localhost:5432/procureflow
# jwt_secret=change-me-dev-secret-at-least-32-chars-long
# fcm_project_id= / fcm_client_email= / fcm_private_key= (mock if empty)
python -m scripts.seed
PYTHONPATH=backend python -m uvicorn app.main:app --host 127.0.0.1 --port 8000
# docs: http://127.0.0.1:8000/docs  health: /health
```

## PostgreSQL Setup
- Dev: sqlite auto (`Base.metadata.create_all` if `environment=development`)
- Prod: `psql`, `alembic upgrade head` (stub `001_initial` → `SELECT 1`, generate via `alembic revision --autogenerate`)
- Erode: 2 divisions (Erode/Gobichettipalayam) 10 taluks 375 villages — 4 DPCs seeded.

## Environment Variables
| key | example | notes |
|---|---|---|
| `database_url` | `sqlite:////.../dev.db` or `postgresql+psycopg://...` | .env |
| `jwt_secret` | `change-me...` | 32+ chars |
| `jwt_algorithm` | `HS256` | |
| `otp_fixed_code` | `123456` | mock OTP |
| `fcm_project_id` etc | `` | empty → mock |
| `API_BASE_URL` | `http://127.0.0.1:8000` | dart-define |

## Firebase/FCM Setup
1. Firebase console → project → service account JSON
2. Set `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY` (escaped `\n`) in `backend/.env`
3. Flutter `pubspec.yaml` uncomment `firebase_core/messaging` when credentials ready
4. `POST /api/v1/notifications/device-token` dedup, `GET /notifications` pagination `?limit&offset`, mock logs `[FCM-MOCK]` if no creds — never commit JSON.

## How to Run Backend
```bash
PYTHONPATH=backend python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

## How to Run Flutter
```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Demo Accounts
- Farmer: `9876543210` / OTP `123456` (TNCSC DPC)
- Operator: `9876543211` / `123456`
- Any new mobile via `POST /auth/verify-otp` auto-creates `FARMER` (admin `9999999999`)

## Test Commands
```bash
cd backend && python -m pytest tests -v # 19 tests
flutter analyze # 30 infos, 0 errors
flutter test    # 14/15 pass (1 widget OTP label)
flutter build apk --debug # 37.8s, needs ~1G free
```

## Rule-Based Scheduling
`backend/app/services/scheduling_service.py` 10 rules: 1 full reject, 2 hours, 3 occupancy `booked/capacity`, 4 quantity factor `1+(q-10)*0.02`, 5 capacity `load/counters`, 6 active counters, 7 safety buffer penalty, 8 duplicate (booking API), 9 past, 10 DB `FOR UPDATE`. Score `availability*congestion*load*time*buffer`, tie `start_time,id`, returns `recommended_slot, wait, reason "Lower expected centre load.", alternatives×3`. Deterministic, handles `counters=0` via fallback 1.

## Feature Expansion — Completed (Frozen)
- **Day Planner** `/planner` — single view centre/date/commodity/qty/slot/token/ahead/wait/ETA/docs/reminder (see `docs/FEATURES.md` CORE)
- **Booking History + Reschedule/Cancel** `/history` — list, detail, reschedule atomic to next-day slots, cancel with slot free + notification
- **Operator Centre Controls** `/operator` — active counters 0-5, slot capacity 10-30, OPEN/BUSY/CLOSED emergency (blocks new bookings)
- **Payment Timeline** — `Payment Timeline` stepper BOOKING_CONFIRMED→PROCUREMENT→PROCESSING→COMPLETED in `/payment`
- **Feedback/Grievance** `/feedback` — category delay/quality/payment/other, status OPEN/RESOLVED, operator view all
- **Offline Cache** — `LocalStorage` cached booking/queue JSON + time, `LIVE` badge vs `Last updated`, never fake success
- **Notifications Wired:** `feedback` router + cancel/reschedule notifications + `turn_approaching` threshold `ahead<=2`
- **Analytics CSV** — Export button uses `GET /analytics/management` demand_trend_7d → `date,bookings` CSV
- See `docs/FEATURE_DECISIONS.md` for P0/P1 selected (10 features) and P3 rejected (blockchain/maps/heavy ML)

## Known Limitations
- SQLite dev: `SELECT FOR UPDATE` no-op → concurrent overbook possible (7/7 vs 5/5 expected); postgres enforces row lock + `ck_slot_booked_capacity`.
- Alembic `001_initial` stub; prod needs `alembic revision --autogenerate`.
- FCM mock unless credentials set (no emulator per 6G constraint).
- Widget test `phase2_widget_test.dart:51` expects "Enter OTP" label mismatch (not blocking).
- No real bank transfer (payment status only).
- 5.8G free — no large models, no emulator images, no heavy builds in this phase.
