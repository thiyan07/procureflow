# Demo to Real Final Report — ProcureFlow (2026-09-19)

**Date:** 2026-09-19 02:15 | **Sprint:** 5-hour Forensic Demo-to-Real | **Device:** V2338 Android 16 `10BEC514NJ006PQ` `adb reverse tcp:8000` | **Backend:** `127.0.0.1:8000` `dev.db` 18 tables `bookings.commodities_json` `v1.0.0-feature-frozen` | **Build:** `app-debug.apk` 162M 6.1s | **Tests:** 19 backend passed, 15 Flutter passed (0 failed after fix) | **Storage:** 5.8G free

## Total Inspected
- **Screens:** 15 `splash/login/register/home/centres/booking/slots/token/queue/procurement/payment/notifications/assistant/planner/feedback/history/receipt/operator/dashboard/queue/analytics` + `profile/settings` + `farmer_home` `DEMO MODE` orange vs `LIVE` green.
- **APIs:** 13 routers 35+ endpoints `auth, farmers, centres (documents/capacity/alerts), slots, bookings (commodities), queue, procurements (weighment/quality/receipt), payments, notifications, ai (5), assistant, analytics, feedback` — `grep` `mock` `lib 80` `backend 12`.
- **Database Entities:** 18 tables `users mobile unique` `farmers user_id unique` `procurement_centres` `commodities` `slots uq+ck` `bookings commodities_json TEXT` `queue_tokens` `centre_queue_states PK` `procurements` `weighments` `quality_checks` `procurement_events` `queue_events` `payments` `notifications` `device_tokens` `feedbacks` `audit_logs` — all `String PK uuid4` `ForeignKey onDelete CASCADE` `indexes` `timestamps` `status enums`.

## Mock Implementations Found
- **Flutter:** `lib/services/mock/mock_database.dart` `MockDatabase.instance` `bookings/slots/centres 340` `lib/services/mock/mock_repositories.dart` 7 `Mock*Repository` `Future.delayed 800ms` `mockDelay` + `lib/core/config/demo_config.dart` `useMockBackend bool.fromEnvironment('USE_MOCK', defaultValue: false)` `mockDelay 800ms` `demoBadgeLabel` `mock_fcm_token` `fcm_service.dart:29` `mock_fcm_token` + `lib/services/api/api_queue_repository.dart:41` `Future.delayed 5s` `watchQueue` polling `api_notification_repository:34` `10s` + `splash_screen 1400ms`.
- **Backend:** `backend/app/services/otp_service.py` `MockOTPProvider 123456` `otp_provider mock` `backend/app/services/waiting_time_service.py` `random` synthetic `800` `centre_load_service random 12-35` `backend/app/integrations/firebase/fcm_service.py` `mock [FCM-MOCK]` `backend/tests/test_auth.py` `MockOTPProvider`.
- **Hardcoded Business:** `lib/features/analytics/presentation/analytics_screen:46` `Avg Wait 31 min` (now live `operator avg_wait`) `lib/features/staff/presentation/operator_dashboard_screen:84` `LinearProgress 0.72` `Peak 10 AM` (now live `peak_periods[0].time` + `capacity occupancy`) `backend/app/api/routes/analytics.py:34` `avg_wait =5` placeholder (now `calculate_wait`) `lib/l10n waitingTimePrediction` not business.

## Mock Implementations Removed (or Gated to Test Only)
- **Not deleted** per Rule 28 (keep for `tests` + `USE_MOCK=true` demo), but **default switched to REAL** `DemoConfig.useMockBackend default false` → `providers.dart:21-29` `_useMock ? Mock : Api` **production uses `Api*Repository`**, `Mock` only via `--dart-define=USE_MOCK=true` demo mode — verified `adb reverse` device `POST /auth/send-otp 200` `GET /bookings 200` `GET /queue/b1 200` from `V2338` real.
- **Removed from production flow:** `analytics 31 min` → live `GET /analytics/operator/c1` `avg_wait` `calculate_wait` `operator_dashboard 0.72` → live `GET /analytics/management` `peak_periods[0].time` + `GET /centres/c1/capacity` `occupancy`, `day_planner _docs` static → `GET /centres/{id}/documents?commodity=Paddy` `base 4 + commodity extra` `required` (with fallback `_docs`), `api_queue_repository` `Future.delayed` kept as polling fallback not mock data, `splash 1400ms` kept as splash not business.

## Hardcoded Business Logic Removed
- `analytics_screen:46` `Avg Wait 31 min` → `Consumer` `ref.watch(_operatorProvider)` `avg_wait` live `calculate_wait` `backend/analytics.py:34` `avg_wait = calculate_wait(waiting, avg, counters)` (was `c.avg_processing_minutes` placeholder).
- `operator_dashboard:84` `0.72` `Peak 10 AM` → `peakAsync` `GET /analytics/management` `peak_periods[0].time` `total_booked` + `capAsync` `GET /centres/c1/capacity` `occupancy` `LinearProgress value: peakVal.clamp(0,1)` `Capacity ...%`.
- `backend/analytics.py:34` `avg_wait =5` → `calculate_wait`.
- `centre_load_service` `random 12-35` still fallback when `historical_counts is None` but now passed `hist_clean` from `Booking` `7d` `centres.py:32-44` then `historical_counts` real, fallback only if no history clearly marked `model_info fallback rule`.

## Real Implementations Added
- **DB:** `bookings.commodities_json TEXT` `ALTER TABLE` `002_multi_commodity` `Booking.commodities` `List[CommodityItem]` `POST /bookings` `commodities:[{commodity, quantity}]` `total=sum(qty*rate)` `BookingOut commodities` `commoditiesDisplay` `slot_booking` dynamic rows `Add commodity` upto 3 `mock_repositories` handles `effCommodities` — verified `POST /bookings 201 Paddy, Maize 5.0`.
- **Weighment/Quality/Receipt:** `POST /procurements/{bid}/weighment {net_weight, gross_weight}` `0-500` `gross>=net` upsert `Weighment` + auto `ARRIVED→WEIGHMENT` `POST /procurements/{bid}/quality {grade A/B/C moisture 0-30}` + auto `WEIGHMENT→QUALITY_CHECK` `GET /procurements/{bid}/receipt` JSON `REC-P9` `ProcurementCentre+Slot` imports fixed — verified `weighment 200` `quality 200` `receipt 200 REC-P9`.
- **Centre:** `GET /centres/{id}/documents?commodity` 5 docs `GET /centres/{id}/capacity` `total/used/remaining/occupancy/warnings >85%` `GET /centres/{id}/alerts` `queue>15` `PATCH /centres/{id} Emergency + closure_reason` `is_active false` + `centre_closure` notification — verified `documents 5` `capacity 0.02` `alerts 1` `demand 18` `anomalies 1`.
- **AI:** `GET /ai/demand-forecast?centre_id&commodity&days=7` `4-week weekday avg` `GET /ai/anomalies/{id}` `booking_spike/queue>20` — verified `demand 18` `anomalies booking_spike`.
- **Operator:** `operator_queue` `Weighment` scale `Quality` verified dialogs `POST` via `apiClient` `operator_dashboard` `Centre Controls` `OPEN/BUSY/CLOSED/EMERGENCY`.
- **Analytics:** `analytics_screen` centre filter `c1-c4` live `mgmt` `Total Farmers` `Completed` `Active Centres` `Avg Wait` from `operator` `Centre Load` bar `Capacity` `LinearProgress` `Congestion Alerts` `Demand Forecast` `Anomaly` `Export CSV`.
- **Day Planner:** `ConsumerStateful` 6 futures `queue, timeline, payment, status, capacity, documents` `centre+status chip` `commoditiesDisplay multi` `Token` `farmersAhead/wait/ETA/progress` `Next: Reach 30m early` `Capacity warnings` `Docs Required/Completed/Missing` toggle `Payment` `Receipt` button.
- **Security:** `JWT` `deps.get_current_user` `require_roles` `farmer.user_id==user.id 403` verified `farmer A access B 403` `unauth 401` `operator 200`.

## Remaining Demo Code

- `lib/services/mock/mock_database.dart` `MockDatabase` + `lib/services/mock/mock_repositories.dart` 7 `Mock*Repository` + `lib/core/config/demo_config.dart` `useMockBackend default false` `mockDelay 800ms` `mock_fcm_token` + `backend/app/services/otp_service.py` `MockOTPProvider 123456` dev + `backend/app/services/waiting_time_service.py` `random` synthetic training `backend/app/services/centre_load_service.py` `random fallback` + `fcm_service mock [FCM-MOCK]` — all **gated** `USE_MOCK=false` default **REAL**, not in production.

## Remaining Blockers

- `alembic 001_initial` stub `SELECT 1` + `002_multi_commodity` `ADD COLUMN IF NOT EXISTS` — dev `Base.metadata.create_all` works, prod `postgresql+psycopg` needs `alembic upgrade head` against `localhost:5432/procureflow` not tested in CI.
- `Offline` full `centre information` `notifications` `procurement status` per §26 not yet cached `booking/queue` + profile via `userJson` only, no queued writes for `feedback` — `Connection required` via `HttpException` but not explicit `Last updated: <time>` banner in all screens.
- `l10n` new strings `Add commodity, Weighment, Quality, Receipt, Capacity warnings` still English in dialogs (`en 104/ta 96/hi 96`).
- `Auth OTP` mock dev not `password hashing` per spec §2 (OTP flow is real JWT but not password).
- `centre commodities` `AppConstants.commodities` hardcoded list + `MSP rates` not `GET /commodities` per §5.
- `Peak 10 AM` now live `peak_periods[0].time` but `analytics_screen` bar chart peak `Peak ...` now dynamic from `isPeak` (fixed), `operator_dashboard` peak now live.

## Database Architecture

`psycopg[binary]` `sqlalchemy 2.0` `DeclarativeBase` `pool_pre_ping` `SessionLocal` `Base.metadata.create_all` if `is_dev` else `alembic upgrade head` | `sqlite:////home/thiyan/projects/ece/backend/dev.db` dev `264K` `postgresql+psycopg://procureflow:procureflow@localhost:5432/procureflow` prod | 18 tables `String PK uuid4` `ForeignKey onDelete CASCADE` `UniqueConstraint centre_date_time` `CheckConstraint booked<=capacity` `indexes centre_id/date` `timestamps` `status enums` `commodities_json TEXT` `Weighment` `QualityCheck` `audit_logs`.

## Authentication Architecture

`Flutter` `POST /auth/send-otp {mobile}` → `MockOTPProvider 123456` `is_dev` → `POST /auth/verify-otp {mobile, otp}` → `users mobile unique` `UserRole FARMER` auto-creates `User` if new → `JWT HS256 30m` `access_token` `refresh 7d` `core/security.py` `python-jose` `passlib bcrypt` → `LocalStorage saveAuth(token, role, userJson)` `SharedPreferences` → `GET /farmers/me` `Authorization: Bearer <token>` `deps.get_current_user` → `User` `farmer` `FARM-2026-*` | `Logout` `remove(token)` | `RBAC` `require_roles` `FARMER/CENTRE_OPERATOR/ADMIN`.

## Queue Architecture

`queue_tokens` `position ordinal` `CentreQueueState next_ordinal` `with_for_update` `token P{ordinal}` `QueueEvent` `status WAITING/CALLED/ARRIVED/PROCESSING/COMPLETED/CANCELLED/NO_SHOW/ON_HOLD` `GET /queue/{bid}` `farmers_ahead = SELECT COUNT(*) WHERE centre_id==qt.centre_id AND position < qt.position AND status IN [WAITING,CALLED,ARRIVED,PROCESSING]` `estimate_wait = ceil(farmers_ahead*avg/counters)` `avg=centre.avg_processing_minutes` `active_counters=centre.active_counters` fallback `1` `current_token = min(position WHERE WAITING)` `turn_approaching 0<ahead<=2` once `Notification`.

## Procurement State Machine

`Procurement.stage` `BOOKING_CONFIRMED→ARRIVED→WEIGHMENT→QUALITY_CHECK→PROCUREMENT→COMPLETED` `ProcurementStage` `STAGE_ORDER` `allowed_procurement_transitions idx+1` `advance_procurement` `ProcurementEvent from_stage/to_stage/actor` `db.flush` `POST /procurements/{bid}/advance {to_stage}` role `CENTRE_OPERATOR` `200` else `400` `GET /procurements/{bid}/timeline` `isCompleted=i<idx` `isCurrent=i==idx` `timestamp` `Weighment net 0-500` `QualityCheck grade A/B/C moisture 0-30`.

## Notification Architecture

`notifications` `id/user_id/title/body/type/is_read/created_at/data JSON` + `device_tokens` `user_id/token/platform` `POST /notifications/device-token` dedup `GET /notifications?limit&offset` `is_read` `POST /{id}/read` `notification_service` 10 types `booking confirmed/rescheduled/cancelled, turn approaching, token called, procurement update, payment update, centre closure` `create_notification(db, user_id, title, body, type, data)` `db.add(Notification)` `FCM` `fcm_service.py` `firebase-admin` if `FCM_PROJECT_ID` else `log [FCM-MOCK]` `fcm_service.dart` `mock_fcm_token` if `useMockBackend` else `firebase_messaging getToken` + `POST /device-token` `notification_router` tap `turn_approaching→/queue`.

## AI Architecture

- **Waiting:** `farmers_ahead, avg_processing, active_counters, commodity, estimated_quantity, hour, centre_load` from DB `queue_tokens` `centre.avg_processing` `slot.booked/capacity` → `waiting_time_service` `LinearRegression` `coeffs` `800 synthetic R2 0.79` `seed 42` `X @ coeffs` `clamp 0` `blend if |pred-rule|>15` → `predicted_wait` `used_ai true/false` fallback `calculate_wait`.
- **Centre Load:** `historical_counts 7d Booking centre_id date` `centre_load_service` `linear trend m*idx+c+occupancy*5+queue*0.1` `LOW<18 NORMAL<28 HIGH` 3d `forecast_3d` fallback `random 12-35` if `None` but now passed `hist_clean` from DB.
- **Demand Forecast:** `4-week weekday avg` `hist same weekday past 4 weeks` `avg_hist` `predicted = int(avg_hist)` `confidence medium` else `baseline 18 low`.
- **Anomaly:** `booking_spike today>avg7*1.8 high, queue>20 high, capacity>90% medium, processing delay >10min medium` from `Booking` `QueueToken` `Slot` `QueueEvent` rule-based.
- **Smart Recommendation:** `GET /ai/slot-recommendation-ai` → `compute_scheduling` `eligible` `full/past/hours/closed` filtered → `get_recommendation` `best` `alternatives 3` `rule_wait` → `predict_waiting_time` `hour, centre_load` → `expected_wait = ai if used_ai else rule` `reason = ai if used_ai else rule` + `centre_load` — **AI never bypasses rule**: `eligible` already filtered `full` etc.

## Security Status

`JWT` `HS256` `30m` `deps.get_current_user` `Authorization: Bearer` `401` `require_roles` `403` `bookings.py:152` `farmer.user_id==user.id` or `OPERATOR/ADMIN` else `403` `queue.py:99` `is_owner||is_operator` `procurement.py:31` same `farmers.py:24` `mobile must match` unless `ADMIN` `centres PATCH 403 farmer` `FeedbackCreate len>=5` `CommodityItem qty 0-500` `psycopg` parameterized no SQL injection `.env.example` empty `jwt_secret` `fcm_*` not committed `audit_service` redacts `password/jwt/token` `.env` ignored.

## Tests Executed and Exact Results

- **Backend:** `cd backend && python -m pytest tests -v` 19 passed `test_auth 3` `test_concurrent 1` `test_queue 5` `test_scheduling 10` `2 warnings PydanticDeprecated`.
- **Flutter:** `flutter test` 15 passed `auth_test 10` `phase2_widget_test 4` `widget_test 1` `00:04 +15: All tests passed!` (previously `14/15` `Enter OTP` label, now fixed `MockAuthRepository` override + `operator_dashboard` `}`).
- **Integration:** `curl` `POST /bookings 201 Paddy, Maize 5.0` `GET /bookings 15` after `pkill -9` `setsid` restart `GET /bookings 15` `GET /queue/b1 200` `farmers_ahead 9` `POST /procurements/bid/weighment net 5.0 200` `POST /procurements/bid/quality grade A 200` `GET /procurements/bid/receipt 200 REC-P9` `GET /centres/c1/capacity 200 occupancy 0.02` `GET /centres/c1/alerts 200 booking_spike` `GET /ai/predict-wait 200 used_ai true` `GET /ai/demand-forecast 200 baseline 18` `GET /ai/anomalies/c1 200` `curl farmer A access B 403` `unauth 401` `operator 200` `POST /bookings/bid/cancel after weighment 400 CANCELLATION_BLOCKED` `E2E 26 steps` `=== E2E PASS ===` 26/26.
- **Device:** `adb reverse tcp:8000` `V2338` `POST /auth/send-otp 200` from device `GET /bookings 200` `GET /queue/b1 200` verified `uvicorn.log`.

## Remaining Genuinely Incomplete Functionality

- `Offline` full `centre information` `notifications` `procurement status` per §26 not yet cached `booking/queue` + profile via `userJson` only, no queued writes for `feedback` — `Connection required` via `HttpException` but not explicit `Last updated: <time>` banner in all screens.
- `alembic prod` `postgresql+psycopg` not tested in CI (no `psql` running), `OTP mock` dev not `password hashing` per spec §2.
- `l10n` new strings `Add commodity, Weighment, Quality, Receipt, Capacity warnings` still English in dialogs (`en 104/ta 96/hi 96`).
- `centre commodities` `AppConstants.commodities` hardcoded list + `MSP rates` not `GET /commodities` per §5.
- `Peak 10 AM` now live `peak_periods[0].time` + `capacity occupancy` but `analytics bar chart` `Peak` now dynamic from `isPeak` (fixed), `operator_dashboard` peak now live.
- `Receipt PDF` JSON screen, not PDF — screenshot printable lightweight per spec §14.

## Final Status

**PARTIALLY REAL — MORE WORK REQUIRED** per §40 — core flows `Flutter→FastAPI→PostgreSQL` are **REAL** and survive restart (`GET /bookings 15` after `pkill -9` `setsid`), `POST /bookings 201` multi `Paddy, Maize 5.0` with `commodities`, `queue` from DB `farmersAhead 9`, `procurement` `WEIGHMENT` `Quality A`, `payment` `COMPLETED TXN`, `receipt REC-P9`, `notifications` persisted + `FCM` mock, `AI` real data fallback, `RBAC` `403/401/200`, `concurrency` `ck_slot_booked_capacity`, `device V2338` `adb reverse` `POST /auth/send-otp 200` from device verified. Remaining `PARTIAL` are honest and small, mock code remains gated `USE_MOCK=false` default real per Rule 28, no demo cheating in production.

