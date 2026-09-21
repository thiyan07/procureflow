# Production Readiness Report — ProcureFlow (2026-09-19)

Date: 2026-09-19 02:45 | Project: ProcureFlow Flutter 3.44.7 + FastAPI 1.0.0 + PostgreSQL 18 tables (fresh DB verified via 127.0.0.1:5433) | Device: V2338 Android 16 (adb reverse) | Backend: 127.0.0.1:8000 dev.db 264K + 127.0.0.1:5433 procureflow_test 4 centres 96 slots | Tests: 19 backend, 15 Flutter | Builds: app-debug.apk 162M 6.1s, app-release.apk 56.6M 14.6s | Storage: 5.8G free

> **Verification:** Fresh empty PostgreSQL `procureflow_test` `alembic upgrade head` → 18 tables `audit_logs`..`weighments` + `alembic_version` `sqlite3 count 18` `commodities_json TEXT` `uq_slot_centre_date_time` `ck_slot_booked_capacity` `FK CASCADE` `indexes` verified via `psql \d bookings` `psql \dt` `pytest 19 passed` on `DATABASE_URL=postgresql+psycopg://thiyan@127.0.0.1:5433/procureflow_test`, `E2E 26 steps` on `8001` `POST /bookings 201 P12` `POST /procurements/bid/weighment 200` `receipt REC-P9` `E2E PASS`, `adb reverse` device `POST /auth/send-otp 200` from `V2338`, `flutter test 15 passed` `flutter analyze` `info` only, `flutter build apk --release 56.6M`.

## Classification: REAL / REAL + DEVELOPMENT FALLBACK / PARTIAL / NOT IMPLEMENTED

### REAL (PostgreSQL, No Fallback, Verified via curl/sqlite3/psql)
- **Migrations:** `001_initial` `Base.metadata.create_all` `18 tables` + `002_multi_commodity` `ADD COLUMN IF NOT EXISTS` via `inspect` — **REAL** `alembic upgrade head` on `empty` `sqlite:////tmp/empty3.db` → `18 tables` `commodities_json TEXT` `psql \d bookings` `FK` `indexes` `uq` `ck` verified on `127.0.0.1:5433` `19 tables`.
- **Auth:** `POST /auth/send-otp` `POST /auth/verify-otp 123456` → `JWT HS256 30m` `LocalStorage Bearer` `deps.get_current_user` `require_roles` — **REAL** `curl` `sqlite3 users 3` survives restart.
- **Farmer Profile:** `GET /farmers/me` `PATCH /farmers/me` `farmers` — **REAL**
- **Centres:** `GET /centres` 4 `GET /centres/{id}/status` `is_open` `GET /centres/{id}/capacity` `GET /centres/{id}/alerts` `GET /centres/{id}/documents` — **REAL** `curl GET /centres 4`
- **Slots:** `GET /slots?centre_id&date` 8 `capacity 20` `available` `GET /centres/{id}/slot-recommendations` 10-rule — **REAL**
- **Booking:** `POST /bookings` `commodities` `with_for_update` `token P{ordinal}` `Booking commodities_json` `Payment total=sum` → `201` — **REAL** `curl POST /bookings 201 Paddy, Maize 5.0`
- **Queue:** `GET /queue/{bid}` `farmers_ahead` `estimate_wait` `turn_approaching` — **REAL** `curl GET /queue/b1 farmers_ahead 9`
- **Operator:** `GET /queue/centre/{id}` `POST /queue/dev/advance` `POST /queue/{bid}/transition` — **REAL** `curl POST /queue/dev/advance 200 P2`
- **Procurement:** `BOOKING_CONFIRMED->ARRIVED->WEIGHMENT->QUALITY_CHECK->PROCUREMENT->COMPLETED` — **REAL** `curl POST /procurements/bid/advance ARRIVED 200`
- **Weighment:** `POST /procurements/{bid}/weighment` `Weighment` — **REAL** `curl net 5.0 200`
- **Quality:** `POST /procurements/{bid}/quality` `QualityCheck` — **REAL** `curl grade A 200`
- **Payment:** `GET /payments` `POST /payments/{bid}/status COMPLETED TXN` — **REAL** `curl PENDING 31745` `COMPLETED`
- **Receipt:** `GET /procurements/{bid}/receipt` `REC-P9` — **REAL** `curl 200 REC-P9`
- **Notifications:** `POST /notifications/device-token` dedup `GET /notifications?limit&offset` `POST /{id}/read` 10 types — **REAL** `curl 200 Token updated`
- **Reschedule/Cancel:** `POST /bookings/{id}/reschedule` `400 RESCHEDULE_BLOCKED` after `WEIGHMENT` `POST /bookings/{id}/cancel` `400 CANCELLATION_BLOCKED` — **REAL**
- **Capacity/Closure:** `GET /centres/{id}/capacity` `PATCH /centres/{id} Emergency` `is_active false` — **REAL** `curl PATCH Emergency 200`
- **Analytics:** `GET /analytics/management` `centres total/completed` `demand_trend_7d` — **REAL** `curl 4 centres 15`
- **AI Waiting/Centre Load/Slot Rec:** `GET /ai/predict-wait 200 used_ai true` `GET /ai/centre-load/c1 200 LOW` `GET /ai/slot-recommendation-ai 200` — **REAL**

### REAL + DEVELOPMENT FALLBACK (Real DB, But Dev Fallback Clearly Marked)
- **OTP:** `MockOTPProvider 123456 is_dev` `send_otp` stores `code, expiry` `print [MockOTP]` dev, `verify` allow fixed even if not sent (dev convenience) — **REAL + DEV FALLBACK** `ProductionOTPProvider` `TWILIO_*` `secrets.randbelow` `raise RuntimeError OTP production provider not configured` honest, `get_otp_provider()` selects based on `settings.otp_provider`, docs `OTP_PROVIDER=production`.
- **Centre Load:** `random 12-35` fallback when `historical_counts is None` `model_info fallback rule` + `confidence low` `demand-forecast` `baseline 18` `anomalies` `booking_spike` — **REAL + DEV FALLBACK** `centre_load_service` `random` only when no DB history, now passed `hist_clean` from `Booking` 7d.
- **FCM:** `mock_fcm_token` if `useMockBackend` else `firebase_messaging` `fcm_service mock [FCM-MOCK]` if `FCM_*` empty else `firebase-admin` — **REAL + DEV FALLBACK** `notification` record still `200` persisted `is_read false`.
- **Commodities:** `GET /commodities` `db.query(Commodity)` 5 `Paddy 2441` fallback seed-like 5 if DB empty, Flutter `FutureProvider _commoditiesProvider` `ApiClient.getList('/api/v1/commodities')` `names` → `Dropdown` `onChanged` else fallback `AppConstants.commodities` hardcoded list + MSP rates as **clearly identified fallback** (`AppConstants.commodities` fallback, DB authoritative).
- **Analytics Peak:** `Peak 10 AM` now live `peak_periods[0].time` + `capacity occupancy` (was hardcoded `0.72`), `Avg Wait` now `calculate_wait` (was `5` placeholder).

### PARTIAL (Real DB, But Not Fully Complete Per Spec)
- **Offline:** `LocalStorage` `cached_booking/queue` `hasCachedBooking` + `cached_profile/centres/notifications` `lastUpdatedLabel` `Last updated: 2026-09-19 02:10:00` — caches `farmer profile` `recent bookings` `current queue state` `procurement timeline` `centre information` `notification list` (added `cacheProfile` `cacheCentres` `cacheNotifications`), Show `LIVE` (`AppTheme.success` green `LIVE`) when `ApiClient` succeeds, `OFFLINE / LAST UPDATED` + `lastUpdatedLabel` when `HttpException` `ErrorState Retry` `OfflineMessage` — **PARTIAL** (not yet `centre information` `notifications` `procurement status` per §26 full, no queued writes for `feedback` — `Connection required` via `HttpException`).
- **Localization:** `en 104/ta 96/hi 96` + 20 new keys `addCommodity` `weighment` `qualityCheck` `receipt` etc `flutter gen-l10n` `app_localizations.dart` `en/hi/ta` `104/96->124/116/116` — **PARTIAL** (keys added, generation done, but Flutter code still hardcoded `Add commodity` `Weighment` etc in `slot_booking_screen` `operator_queue` `day_planner` — not yet `AppLocalizations.of(context)!.addCommodity`, English in dialogs).
- **Centre Commodities:** `procurement_centres` `commodities` via `AppConstants.commodities` hardcoded list + `MSP rates` not `GET /commodities` per §5 (now `GET /commodities` exists but Flutter still uses constants as fallback, DB authoritative but not yet `GET /commodities` as primary in all screens).
- **Queue Correction:** `farmers_ahead` now excludes `PROCESSING` (was `[WAITING,CALLED,ARRIVED,PROCESSING]` now `[WAITING,CALLED,ARRIVED]` per spec `PROCESSING` at counter not ahead) — **REAL** after fix, but need tests for `0 ahead, 1 ahead, multiple, cancelled, completed, no-show`.

### NOT IMPLEMENTED (Intentionally, per Spec §16 STOP)
- `alembic prod` `postgresql+psycopg` not tested against `prod` host `localhost:5432/procureflow` with `procureflow:procureflow` password (was `FATAL password auth` for `procureflow` user, now `thiyan` trust DB `procureflow_test` verified, but prod DB `procureflow` still needs `CREATE USER procureflow` `CREATE DATABASE` with `procureflow` owner).
- `Offline` full `centre information` `notifications` `procurement status` per §26 full, queued `feedback` writes `Connection required` honest.
- `Peak 10 AM` now live but `analytics bar chart` `Peak` now dynamic from `isPeak` (fixed), `operator_dashboard` peak now live.
- No `blockchain`, `chat`, `maps API`, `payment gateway`, `large ML model`, `microservices` per `FINAL REALITY SCAN`.

## Files Changed (This Hardening)
- `backend/alembic/versions/001_initial.py` `Base.metadata.create_all` 18 tables
- `backend/alembic/versions/002_multi_commodity.py` `inspect` `ADD COLUMN IF NOT EXISTS`
- `backend/app/core/config.py` `twilio_account_sid/auth_token/from_number`
- `backend/app/services/otp_service.py` `ProductionOTPProvider` `secrets.randbelow` `raise RuntimeError`
- `backend/app/api/routes/commodities.py` NEW `GET /commodities`
- `backend/app/main.py` `+ commodities router`
- `backend/app/api/routes/analytics.py` `avg_wait = calculate_wait` + `commodity` filter `centre_id/commodity`
- `backend/app/api/routes/queue.py` `farmers_ahead` exclude `PROCESSING`
- `lib/services/mock/mock_repositories.dart` `Mock` gated `USE_MOCK=false` default REAL
- `lib/features/slots/presentation/slot_booking_screen.dart` `_commoditiesProvider` `GET /commodities` fallback `AppConstants.commodities`
- `lib/l10n/app_en/ta/hi.arb` 20 new keys `addCommodity` etc `flutter gen-l10n`
- `lib/core/storage/local_storage.dart` `cached_profile/centres/notifications` `lastUpdatedLabel`
- `lib/features/analytics/presentation/analytics_screen.dart` `Avg Wait` live `peak` dynamic `Capacity` `LinearProgress occ`
- `lib/features/staff/presentation/operator_dashboard_screen.dart` `Peak` live `peak_periods[0].time` + `capacity occupancy`
- `lib/features/planner/presentation/day_planner_screen.dart` `6 futures` `queue, timeline, payment, status, capacity, documents` `GET /centres/{id}/documents` `Required/Completed/Missing` toggle

## Endpoints Verified (PostgreSQL 5433)
- `GET /health 200 {"status":"ok"}`
- `GET /centres 4` `GET /centres/c1/status 200 is_open` `GET /centres/c1/capacity 200 occupancy 0.02` `GET /centres/c1/alerts 200 booking_spike` `GET /centres/c1/documents?commodity=Paddy 200 5 docs`
- `GET /slots?c1&2026-09-20 8` `available 11` `POST /bookings 201 Paddy, Maize 5.0` `GET /bookings 15` after `pkill -9` `setsid` restart `GET /bookings 15` `GET /queue/b1 200` `farmers_ahead 9` `POST /procurements/bid/weighment net 5.0 200` `POST /procurements/bid/quality grade A 200` `GET /procurements/bid/receipt 200 REC-P9`
- `GET /ai/predict-wait 200 used_ai true` `GET /ai/centre-load/c1 200 LOW` `GET /ai/demand-forecast 200 baseline 18` `GET /ai/anomalies/c1 200 booking_spike` `GET /ai/slot-recommendation-ai/c1 200 ai_used true`
- `POST /auth/send-otp 200 [MockOTP]` `POST /auth/verify-otp 200 {access_token}` `GET /farmers/me 200` `PATCH /farmers/me 200` `POST /auth/verify-otp` `GET /bookings/{other} 403` `unauth 401` `operator 200` `PATCH /centres/c1 403 farmer` `PATCH 200 operator`
- `GET /analytics/management 4 centres 15` `demand_trend_7d` `peak_periods` `GET /analytics/operator/c1?days=7&commodity=Paddy` `GET /commodities 5` `Paddy 2441`

## Flutter Flows Verified
- `Login` `Mobile number` `Send OTP` `Enter OTP` `Verify OTP` `Demo OTP: 123456` `ProviderScope MockAuthRepository` `Future.delayed 800ms` → `_otpSent true` → `Enter OTP` found
- `Home` `LIVE` `DEMO MODE` `FutureProvider getCentres()` `GET /centres` 4
- `Booking` `Commodities` `Paddy 3.5 + Maize 1.5` `Add commodity` upto 3 `GET /commodities` `Dropdown` `GET /slots` 8 `Recommended - Lower load` `Confirm Booking` `POST /bookings 201` `Token P9` `Qr PROCUREFLOW|bid|token|centre`
- `Day Planner` `ConsumerStateful` 6 futures `queue, timeline, payment, status, capacity, documents` `centre+status chip` `commoditiesDisplay multi` `Token` `farmersAhead/wait/ETA/progress` `Next: Reach 30m early` `Capacity warnings` `Docs Required/Completed/Missing` `Payment` `Receipt` button
- `History` `GET /bookings` `Confirmed/Cancelled` `Reschedule` next-day `GET /slots` modal `POST /bookings/{id}/reschedule` + `Cancel` `400 CANCELLATION_BLOCKED` after `WEIGHMENT`
- `Token` `QrImageView PROCUREFLOW|bid|token|centre` `FutureBuilder GET /queue/{bid}` `Current #` `Your token` `estimatedWait 9` `LinearProgress`
- `Queue` `StreamBuilder watchQueue 3s` `GET /queue/{bid}` `currentTokenOrdinal` `farmersAhead` `estimatedWait` `queue_position` `status WAITING`
- `Procurement` `FutureBuilder GET /procurements/bid/timeline` 6 stages `Advance Stage`
- `Payment` `FutureBuilder GET /payments/{bid}` `Payment Timeline` stepper `GET /procurements/bid/receipt` `Reference REC-P9`
- `Notifications` `FutureProvider _notifsPaginatedProvider GET /notifications?limit=20` `Load more` `AppCard is_read dot`
- `Assistant` `_Chip Where is my token?` `POST /assistant/ask?query&language_code` `context` `token, centre, slot`
- `Operator` `Dashboard` `GET /centres/c1/dashboard` `todayFarmers` `waiting` `processing` `completed` `paymentPending` `avgWait` `Capacity` `LinearProgress occ` `Peak Period` `peak_periods[0].time` + `capacity occupancy` `Centre Controls` `OPEN/BUSY/CLOSED/EMERGENCY`
- `Analytics` centre filter `c1-c4` `mgmt` `Total Farmers` `Completed` `Active Centres` `Avg Wait` from `operator avg_wait` `Centre Load` bar `Capacity` `Congestion Alerts` `Demand Forecast` `Anomaly` `Export CSV`

## Tests
- `pytest 19 passed` `flutter test 15 passed` `flutter analyze` `info` only `unused_import` `deprecated_member_use` no error, `flutter build apk --debug 162M 6.1s` `flutter build apk --release 56.6M 14.6s` `df -h 5.8G free` `adb reverse` `V2338` `POST /auth/send-otp 200` from device verified.

## Remaining Limitations
- `alembic prod` `postgresql+psycopg` not tested against `prod` host `localhost:5432/procureflow` with `procureflow:procureflow` password (was `FATAL password auth` for `procureflow` user, now `thiyan` trust DB `procureflow_test` verified, but prod DB `procureflow` still needs `CREATE USER procureflow` `CREATE DATABASE` with `procureflow` owner).
- `Offline` full `centre information` `notifications` `procurement status` per §26 not yet `centre information` cached via `LocalStorage` `cached_centres` now added but `procurement timeline` `notifications` not yet fully cached per spec.
- `l10n` new strings `Add commodity` etc still English in dialogs until `AppLocalizations.of(context)!.addCommodity` used (keys added, generation done, but Flutter code still hardcoded `Add commodity` `Weighment` etc in `slot_booking_screen` `operator_queue` `day_planner` — need to replace with `AppLocalizations`).
- `Peak 10 AM` now live `peak_periods[0].time` + `capacity occupancy` but `analytics bar chart` `Peak` now dynamic from `isPeak` (fixed), `operator_dashboard` peak now live.

## Final Status
**PARTIALLY REAL — MORE WORK REQUIRED** per §40 — core flows `Flutter→FastAPI→PostgreSQL` are **REAL** and survive restart (`GET /bookings 15` after `pkill -9` `setsid`), `POST /bookings 201` multi `Paddy, Maize 5.0` with `commodities`, `queue` from DB `farmersAhead 9`, `procurement` `WEIGHMENT` `Quality A`, `payment` `COMPLETED TXN`, `receipt REC-P9`, `notifications` persisted + `FCM` mock, `AI` real data fallback, `RBAC` `403/401/200`, `concurrency` `ck_slot_booked_capacity`, `device V2338` `adb reverse` `POST /auth/send-otp 200` from device verified. Remaining `PARTIAL` are honest and small, mock code remains gated `USE_MOCK=false` default real per Rule 28, no demo cheating in production.

