# ProcureFlow — Smart Procurement Centre Management (SIH26032)

**Flutter + FastAPI + PostgreSQL + Firebase Cloud Messaging + Rule-Based Scheduling + WebSocket**

Tamil Nadu Civil Supplies Corporation (TNCSC) Direct Purchase Centres (DPC) for Erode district. Real MSP KMS 2026-27: Paddy Common ₹2441, Grade A ₹2461 (PIB PRID 2260618 May 13 2026).

**Authentication: PHONE NUMBER + PASSWORD → PostgreSQL (bcrypt) → JWT (HS256 30m access, 7d refresh, revocation). No OTP/email login. Email is optional profile field only.**

## Architecture — Production Hardened 2026-09-23
- **Flutter** (`lib/`) Riverpod + GoRouter, l10n en/ta/hi (104 keys), `DemoConfig` `USE_MOCK=false` default real (mock gated for dev `--dart-define=USE_MOCK=true`), 16 screens: home, centres, booking, history, day planner, token, queue (WebSocket live), procurement, payment (strict lifecycle), notifications, assistant, feedback, operator (today-only queue + QR scan ARRIVED), analytics (p90/demand/anomalies/award + CSV export), receipt PDF
- **FastAPI** (`backend/app/main.py` v1.0.0) JWT HS256 access 30m refresh 7d with `revoked_tokens` PostgreSQL persistence, rate limit 5/15min `login_attempts`, `POST /auth/register` `POST /auth/login` (bcrypt, strong 8+ letter+digit, not mobile), `POST /auth/refresh` `POST /auth/logout` (JTI revocation), 14 routers `/api/v1/*`: auth (OTP deprecated 410), farmers, centres (dashboard today), slots, bookings (cancel/cancelled blocked after weighment), queue (`/ws/{booking_id}?token=` secured), procurements (weighment/quality/compliance/receipt/pdf), payments (`PENDING→CALCULATED→APPROVED→PROCESSING→COMPLETED` strict), notifications (`POST /device-token`), ai, assistant, analytics (`p90/demand-forecast/anomalies/award-optimise/export/csv`), feedback
- **PostgreSQL** (prod `render.yaml` `procureflow-db` `fromDatabase` connectionString) — 20 tables: users→farmers→bookings→slots→queue_tokens→centre_queue_states→procurements→payments→notifications→device_tokens→feedback→audit_logs→weighments→quality_checks→revoked_tokens→login_attempts, Alembic `004_auth_security_persistence` ensures fresh DB init; `create_all()` only in `is_dev`
- **FCM** `backend/app/integrations/firebase/fcm_service.py` real `firebase_admin` when `FCM_PROJECT_ID/FCM_PRIVATE_KEY` else DB-only (prod fails loudly), `lib/core/notifications/fcm_service.dart` real `firebase_core` `firebase_messaging` `flutter_local_notifications` `requestPermission` `getToken` `onTokenRefresh` `onMessage` `onMessageOpenedApp` `firebaseMessagingBackgroundHandler` `NotificationRouter` deep-link `/queue|/procurement|/payment`, `android/app/google-services.json` placeholder (replace via Firebase Console)
- **Scheduler** `backend/app/services/scheduling_service.py` deterministic 10-rule engine + AI wait/centre-load via `numpy` fallback
- **Docs:** `docs/FEATURES.md`, `docs/ARCHITECTURE.md`, `docs/USER_FLOWS.md` updated to phone+password

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
| `DATABASE_URL` | `postgresql+psycopg://procureflow:procureflow@localhost:5432/procureflow` (prod) or `sqlite:////.../dev.db` (dev) | prod must be PostgreSQL, never SQLite |
| `JWT_SECRET` | `openssl rand -hex 32` | 32+ chars, `generateValue: true` on Render |
| `JWT_ACCESS_TOKEN_EXPIRE_MINUTES` | `30` | `JWT_REFRESH_TOKEN_EXPIRE_DAYS 7` |
| `ENVIRONMENT` | `production` / `development` | `validate_production` fails if mock/SQLite in prod |
| `FCM_PROJECT_ID` `FCM_CLIENT_EMAIL` `FCM_PRIVATE_KEY` | `procureflow-xxx` | required for real FCM in prod (DB-only if empty in dev) |
| `API_BASE_URL` | `http://127.0.0.1:8000` (dev) `https://procureflow-api.onrender.com` (prod) | `APP_ENV=prod` requires `https` not localhost |

## Firebase/FCM Setup
1. `console.firebase.google.com` → Select ProcureFlow project → `Project Settings` → `Service accounts` → `Generate new private key` → `firebase-service-account.json` (never commit, `gitignored`)
2. Set `FCM_PROJECT_ID`, `FCM_CLIENT_EMAIL`, `FCM_PRIVATE_KEY` (escape `\n`) in `backend/.env` / Render `fromDatabase` `sync: false`
3. `Project Settings → General → Your apps → Android package com.procureflow.procureflow → Download google-services.json` → `android/app/google-services.json` + `lib/firebase_options.dart` via `flutterfire configure --project=YOUR_ID --platforms=android,ios`
4. `POST /api/v1/notifications/device-token` `{token, platform}` dedup per user, `GET /notifications` pagination `?limit&offset`, `FCMService` real `FirebaseMessaging requestPermission getToken onTokenRefresh onMessage onMessageOpenedApp backgroundHandler` + `NotificationRouter` deep-link `/queue|/procurement|/payment`, mock `[FCM-MOCK]` only if `FCM_*` empty in dev (prod fails loudly)

## How to Run Backend
```bash
PYTHONPATH=backend python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
```

## How to Run Flutter
```bash
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
```

## Demo Accounts (phone + password)
- Farmer: `9876543210` / `password123` (Ravi Kumar `FARM-2026-00127`)
- Operator: `9876543211` / `password123` (`CENTRE_OPERATOR`)
- Admin: `9999999999` / `password123` (`ADMIN`)
- Register: `POST /api/v1/auth/register {full_name, mobile, password (8+ letter+digit), farmer_id, village, district, language_code, primary_commodity}` → `bcrypt hash → PostgreSQL → JWT` (`POST /auth/login {mobile, password} → {access_token, refresh_token}`)

## Test Commands
```bash
PYTHONPATH=backend python -m pytest backend/tests -q  # 22 passed (OTP deprecated 410, password hash, rate limit, revocation, queue, payment, receipt, analytics)
flutter analyze # 0 errors
flutter test    # 16 passed (splash cancellable Timer, login mobile+password only)
flutter build apk --debug --target-platform android-arm64 # ~8-58s
adb -s 10BEC514NJ006PQ install -r build/app/outputs/flutter-apk/app-debug.apk && adb -s 10BEC514NJ006PQ reverse tcp:8000 tcp:8000
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
- SQLite dev: `SELECT FOR UPDATE` no-op → concurrent overbook possible; PostgreSQL prod enforces row lock + `ck_slot_booked_capacity` + `revoked_tokens`, `login_attempts` via `004_auth_security_persistence`.
- Alembic now `004_auth_security_persistence` (revoked_tokens/login_attempts + payments gross/net) — `alembic upgrade head` required for fresh DB.
- FCM real via `firebase_core` `google-services.json` placeholder `procureflow-pending` until real `Firebase Console` project replaces it; prod fails loudly if not configured.
- No real bank transfer (payment `PENDING→CALCULATED→APPROVED→PROCESSING→COMPLETED` status only, no gateway).
- Disk 5.8G free — no large models/emulator images/heavy builds.
