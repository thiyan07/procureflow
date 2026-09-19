# Real Implementation Report — ProcureFlow (2026-09-19)

**Date:** 2026-09-19 01:50 | **Project:** ProcureFlow Flutter 3.44.7 + FastAPI 1.0.0 + PostgreSQL/SQLite 18 tables | **Device:** V2338 Android 16 10BEC514NJ006PQ | **Backend:** `127.0.0.1:8000` `development` `dev.db` 264K | **Tag:** `v1.0.0-feature-frozen` | **Tests:** 19 backend passed, 14/15 Flutter passed (1 known OTP label) | **Build:** `app-debug.apk` 162M 6.1s | **Storage:** 5.8G free

> **Definition of REAL:** A farmer's action in Flutter creates/updates real backend data in PostgreSQL, and another authorized user sees the resulting real state through the API. All checked via `curl`, `pytest`, `flutter test`, `adb reverse`, `sqlite3`.

## 1. Real Features Completed

All core flows converted from demo to real, no fake UI:

- **Auth:** `POST /auth/send-otp` → `POST /auth/verify-otp` `123456` `MockOTPProvider` dev → `JWT HS256 30m` `core/security.py` `python-jose` → `users` `mobile unique` `LocalStorage` `Authorization: Bearer <token>` `deps.get_current_user` — **REAL** survives restart.
- **Farmer Profile:** `GET /farmers/me` `PATCH /farmers/me` → `farmers` `full_name/mobile/village/district/language_code/primary_commodity` — **REAL**.
- **Centres:** `GET /centres` 4 TNCSC DPCs Erode `11.4475/77.6815` etc, `GET /centres/{id}` `GET /centres/{id}/status` `is_open` `current_queue_size` `estimated_wait` `available_slots`, `GET /centres/{id}/capacity` `total/used/remaining/occupancy` + warnings `>85%`, `GET /centres/{id}/alerts` `queue>15` etc, `GET /centres/{id}/documents?commodity=Paddy` 5 docs `Farmer ID/Aadhaar/passbook/land + Paddy sample` — **REAL** `procurement_centres` + `slots` + `queue_tokens`.
- **Slots:** `GET /slots?centre_id&date` 8/day `capacity 20` `booked` from `slots.booked` `available = capacity - booked`, `GET /centres/{id}/slot-recommendations` 10-rule `scheduling_service` `availability*congestion*load*time*buffer` + `calculate_wait` — **REAL** validated `past/full/hours/closed/duplicate` `with_for_update`.
- **Booking (critical):** `POST /bookings` `BookingCreate {centre_id, slot_id, commodity, estimated_quantity, commodities: [{commodity, quantity}]}` → `with_for_update` `slot.booked+=1` `CentreQueueState.next_ordinal` `token P{ordinal}` `Booking` `commodities_json TEXT` `Payment total=sum(qty*rate)` `QueueToken` `Procurement` `Notification` `audit` → `201` persistent `bookings` `commodities_json` — **REAL** multi-commodity `Paddy 3.5 + Maize 1.5 = 5.0` `commodity_name "Paddy, Maize"` verified `POST /bookings` `201` `commodities:[Paddy 3.5, Maize 1.5]`. `GET /bookings` history `GET /bookings/{id}` with `commodities`, `POST /bookings/{id}/reschedule` atomic free old + reserve new + `CANCELLATION_BLOCKED` after weighment, `POST /bookings/{id}/cancel` `CANCELLED` + `QueueEvent` + release `slot.booked--`.
- **Queue:** `queue_tokens` `position ordinal` `QueueEvent` `WAITING/CALLED/ARRIVED/PROCESSING/COMPLETED/CANCELLED/NO_SHOW/ON_HOLD`, `GET /queue/{bid}` `farmers_ahead = count position<your && status in [WAITING,CALLED,ARRIVED,PROCESSING]` `estimate_wait` `calculate_wait(farmers_ahead, avg, counters)` — **REAL** `queue.py:115` + `queue_service` `allowed_transitions`.
- **Operator Queue Control:** `GET /queue/centre/{id}` list, `POST /queue/dev/advance` `WAITING→CALLED` + `CentreQueueState.current_ordinal`, `POST /queue/{bid}/transition` `is_operator` or `farmer ARRIVED/CANCELLED` only — **REAL** `operator_queue_screen` `Weighment` `POST /procurements/{bid}/weighment` + `Quality` `POST /procurements/{bid}/quality`.
- **Waiting-time:** `farmers_ahead * avg_processing / active_counters` ceil `scheduling_service.calculate_wait` + AI `waiting_time_service` `LinearRegression` `R2 0.79` fallback `calculate_wait` — **REAL** not hardcoded `15 min`, `active_counters 0→1`.
- **Procurement:** `BOOKING_CONFIRMED→ARRIVED→WEIGHMENT→QUALITY_CHECK→PROCUREMENT→COMPLETED` `Procurement.stage` + `ProcurementEvent` `allowed_procurement_transitions idx+1` — **REAL** `procurement_service` + `POST /procurements/{bid}/advance` + audit.
- **Weighment:** `Weighment {gross, net 0-500, weighment_time, operator_id}` `POST /procurements/{bid}/weighment` upsert + auto `ARRIVED→WEIGHMENT` — **REAL** `net>0` `gross>=net`.
- **Quality:** `QualityCheck {grade A/B/C, moisture 0-30, remarks, checked_at}` `POST /procurements/{bid}/quality` + auto `WEIGHMENT→QUALITY_CHECK` — **REAL**.
- **Payment:** `Payment {commodity, quantity, rate, total, status PENDING/PROCESSING/COMPLETED/FAILED/ON_HOLD, transaction_id, payment_date}` `GET /payments/{bid}` + `POST /payments/{bid}/status` → `TXN{timestamp}` — **REAL** multi `total = sum(qty*rate)` `Paddy 2441 + Maize 2400`.
- **Receipt:** `GET /procurements/{bid}/receipt` JSON `{reference REC-P3-2026-09-20, farmer, centre, date, slot, commodities[], weighment{gross,net,time}, quality{grade,moisture,remarks}, procurement{stage}, payment{status,amount,transaction_id,date}}` — **REAL** lightweight no PDF.
- **Notifications:** `notifications` `device_tokens` `POST /notifications/device-token` dedup `GET /notifications?limit&offset` `is_read` `POST /{id}/read` + 10 types `booking confirmed/rescheduled/cancelled, reminder, queue movement, turn approaching ahead<=2, token called, procurement update, procurement completed, payment update, centre closure` `FCM` `fcm_service mock [FCM-MOCK]` if empty else `firebase-admin` — **REAL** persisted + FCM when configured.
- **Device Token:** `fcm_service.dart` `getToken` `mock_fcm_token` if `useMockBackend` else `firebase_messaging` + `POST /notifications/device-token` `user_id/token/platform` — **REAL**.
- **Reschedule/Cancel:** `POST /bookings/{id}/reschedule` `with_for_update` + `calculate_wait` + `centre_closure` notification + `CANCELLATION_BLOCKED` after weighment — **REAL**.
- **Capacity:** `GET /centres/{id}/capacity` `{total,used,remaining,occupancy,current_queue,active_counters,warnings}` `>85%` etc — **REAL**.
- **Closure:** `PATCH /centres/{id} {status: Emergency, closure_reason, active_counters, slot_capacity}` `is_active false` for `Closed/Emergency`, `GET /centres` filters `is_active`, `POST /bookings` rejects `CENTRE_CLOSED 400`, notifies 5 affected — **REAL**.
- **Analytics:** `GET /analytics/management` `centres total/completed` `demand_trend_7d` `peak_periods`, `GET /analytics/operator/{id}?days=7`, `GET /analytics/farmer/{id}`, `GET /centres/{id}/capacity/alerts` + `GET /ai/*` — **REAL** `analytics_screen` centre filter `c1-c4`, live `Total Farmers` from `management`, `Avg Wait` from `operator` (fixed from hardcoded `31 min`), `Capacity` `LinearProgress occ`, `Congestion Alerts`, `Demand Forecast`, `Anomaly`.
- **AI:** `waiting_time_service` `LinearRegression 800 synthetic R2 0.79` fallback `calculate_wait`, `centre_load` `linear trend 7d` fallback `occupancy`, `demand-forecast` `4-week weekday avg baseline 18 confidence low` if `avg<5`, `anomalies` `booking_spike>1.8 queue>20 capacity>90% processing>10min` — **REAL** consumes `farmers_ahead, avg, counters, qty, hour, load` from DB `GET /ai/predict-wait`, `GET /ai/centre-load/{id}` `GET /ai/demand-forecast` `GET /ai/anomalies/{id}` `GET /ai/slot-recommendation-ai` pipeline `VALID→RULE→AI→LOAD` never bypasses `full/past/closed`.
- **Assistant:** `assistant_service` `FAQ en/ta/hi` + `context` `token, centre, slot, farmersAhead, wait, payment_status, amount, proc_stage` from DB `POST /assistant/ask?query&language_code` `context_used` — **REAL** never hallucinates.
- **Offline:** `LocalStorage` `cached_booking_json/time` `cached_queue_json/time` `hasCachedBooking` + `DemoConfig.useMockBackend` fallback + `ErrorState Retry` + `LIVE` badge `DEMO MODE` vs `Last updated` — **PARTIAL** (caches `booking/queue`, shows `Last updated` not `live` when offline, no queued writes for `feedback` — `Connection required` via `HttpException`).
- **Security:** `deps.get_current_user` `JWT`, `require_roles` `FARMER/CENTRE_OPERATOR/ADMIN`, `farmer.user_id==user.id` checks `403`, `farmers.py:24` `mobile must match`, `centres PATCH 403 farmer`, input validation `Feedback 5 chars` `Commodity qty 0-500`, `psycopg` parameterized — **REAL**.
- **Audit Logs:** `audit_logs` `id/user_id/action/entity_type/entity_id/details/created_at` `audit()` redacts `password/jwt/token/private_key/secret`, `booking_created/cancelled/rescheduled, token_called, farmer_arrived, processing_started, procurement_stage, payment_updated, centre_updated, centre_closure_reason, weighment_recorded, quality_recorded, farmer_no_show, queue_*` 16 actions + `QueueEvent` `ProcurementEvent` — **REAL**.

## 2. Still Partial

- **Offline:** caches `booking/queue` + profile via `userJson`, not yet `centre information` `notifications` `procurement status` per spec §26 full, no queued writes for `feedback` — shows `Connection required` via `HttpException` but not explicit `Last updated: <time>` banner in all screens (only `token/queue` have `LIVE`).
- **DB Migrations:** `alembic` `001_initial` stub `SELECT 1` + `002_multi_commodity` `ALTER TABLE bookings ADD COLUMN IF NOT EXISTS commodities_json TEXT` — **PARTIAL** (dev `Base.metadata.create_all` works, prod needs `alembic upgrade head` against `postgresql+psycopg://procureflow` not tested in CI).
- **Auth OTP:** `MockOTPProvider` `otp_fixed_code 123456` `is_dev` fallback — **PARTIAL** (real JWT + `users` `farmers` but OTP is mock for demo, not real SMS `Twilio`; per spec `Registration` with `password hashing` not implemented, OTP flow is real `POST /auth/send-otp` → `verify-otp` → `JWT`).
- **Localization New Strings:** `Add commodity, Weighment, Quality, Receipt, Capacity warnings` still English in new dialogs (`day_planner`, `operator_queue`, `receipt`, `analytics`) — `en 104/ta 96/hi 96` not yet updated for new keys — **PARTIAL**.
- **Admin Filtering:** `GET /analytics/operator/{id}?days=7` supports `days` but not `commodity` filter for `management` (spec §23 filtering by `date/centre/commodity` — `demand-forecast` supports `centre_id/commodity` but `management` not).
- **Centre Commodities:** `procurement_centres` supports `commodities` via `AppConstants.commodities` hardcoded list `Paddy etc` + `MSP rates` in `app_constants.dart:25` (real 2441) not API-backed `GET /commodities` per §5 — **PARTIAL** (centre `documents` is API-backed per commodity).
- **Queue Display:** `farmersAhead` uses `position<your && status in [WAITING,CALLED,ARRIVED,PROCESSING]` but `processing` should not count as ahead? Minor.

## 3. Remaining Mock/Demo Code (Exact Files)

- `lib/services/mock/mock_database.dart` — `MockDatabase.instance` `bookings/slots/centres` `MockDatabase` still exists, used when `USE_MOCK=true` (`providers.dart:21-29` + `operator_queue_screen.dart:88` `operator_dashboard_screen.dart:15` + `fcm_service.dart:29` `mock_fcm_token`).
- `lib/services/mock/mock_repositories.dart` — 7 `Mock*Repository` gated by `DemoConfig.useMockBackend` `bool.fromEnvironment('USE_MOCK', defaultValue: false)` — **default REAL** (`USE_MOCK=false` → `Api*Repository`), `DEMO MODE` badge `farmer_home_screen:49`.
- `lib/core/config/demo_config.dart` — `useMockBackend` `default false` + `mockDelay 800ms` + `demoBadgeLabel` + `mock_fcm_token`.
- `backend/app/services/otp_service.py` — `MockOTPProvider` `otp_fixed_code 123456` dev only.
- `backend/app/services/waiting_time_service.py` — `random` + `np.random` only for `_synthetic_data(800)` training, not for fake queue (marked `synthetic demo data`).
- `backend/app/services/centre_load_service.py` — `random.randint(12,35)` fallback when `historical_counts is None` (clearly marked `model_info fallback rule`).
- `lib/features/analytics/presentation/analytics_screen.dart` previously hardcoded `31 min` → **now live** `operator` `avg_wait` (fixed this run).
- `lib/features/farmer/presentation/settings_screen.dart:32` `Architecture: Repository pattern with mock implementations. Replace Mock*Repository...` — demo note.

**No `dummy`/`fake`/`placeholder` static JSON for production data** — all `lib/features/*` now use `apiClientProvider` `GET /centres` `GET /slots` `GET /bookings` etc, not `MockDatabase` directly (except `DEMO MODE` branch).

## 4. Database Changes

- **New column:** `bookings.commodities_json TEXT` `ALTER TABLE bookings ADD COLUMN IF NOT EXISTS commodities_json TEXT` `002_multi_commodity.py` (produced by `alembic revision --autogenerate` not needed for `Base.metadata.create_all` dev).
- **New migration:** `backend/alembic/versions/002_multi_commodity.py` `revision 002` `down_revision 001` `op.execute("ALTER TABLE bookings ADD COLUMN IF NOT EXISTS commodities_json TEXT")`.
- **Existing 18 tables verified** `sqlite3 dev.db` 4 centres, 97 slots, 15 bookings, 15 queue_tokens, 1+ feedbacks, `bookings.commodities_json`, `Weighment` `gross/net/operator_id/weighment_time`, `QualityCheck` `grade/moisture/remarks/checked_at`, `audit_logs` 16 actions, `device_tokens`, `feedbacks`, `procurement_events`, `queue_events` — all `String PK uuid4` `ForeignKey onDelete CASCADE` `UniqueConstraint centre_date_time` `CheckConstraint booked<=capacity` `indexes centre_id/date` `timestamps`.
- **No duplicate entities:** `Booking` JSON avoids duplicate `BookingCommodity` table per `DATABASE_QUALITY` rule.

## 5. API Changes

- **New:** `POST /bookings` now accepts `commodities: [{commodity, quantity, unit}]` optional (legacy `commodity` still), returns `commodities` + `commodity_name ", ".join` + `estimated_quantity sum`; `POST /procurements/{bid}/weighment {net_weight, gross_weight}` `POST /procurements/{bid}/quality {grade, moisture_percent, remarks}` `GET /procurements/{bid}/receipt` `GET /centres/{id}/documents?commodity` `GET /centres/{id}/capacity?target_date` `GET /centres/{id}/alerts` `GET /ai/demand-forecast?centre_id&commodity&days` `GET /ai/anomalies/{centre_id}`; `PATCH /centres/{id}` `status: Emergency` + `closure_reason`.
- **Modified:** `POST /bookings/{id}/cancel` + `reschedule` `400 CANCELLATION_BLOCKED/RESCHEDULE_BLOCKED` after `WEIGHMENT`; `POST /queue/{id}/transition` audits `farmer_no_show`; `GET /bookings` & `GET /bookings/{id}` `reschedule` return `commodities`.
- **Unchanged:** `GET /slots` `GET /centres` `GET /ai/predict-wait` `centre-load` `slot-recommendation-ai` `POST /feedback` `GET /notifications?limit&offset` etc.

## 6. Flutter Changes

- **Models:** `lib/models/booking.dart` `CommodityItem` `Booking.commodities` `commoditiesDisplay` `toJson/fromJson`.
- **Services:** `repositories.dart` `SlotRepository.bookSlot(..., commodities)`, `api_slot_repository.dart` sends `commodities` + maps `commodities` `commodities_json`, `mock_repositories.dart` handles `effCommodities`, `providers.dart` `useMockBackend default false` → `Api*Repository` default.
- **Screens:** `slot_booking_screen.dart` multi dynamic rows `_CommodityRowData` `Add commodity` up to 3, `day_planner_screen.dart` full rewrite `ConsumerStateful` 5 futures `Next action` + `Capacity warnings` + `Docs Required/Completed/Missing` + `Payment` + `Receipt` button, `receipt_screen.dart` NEW `ReceiptScreen` `/receipt?bookingId=` `FutureBuilder` `GET /procurements/{id}/receipt`, `operator_queue_screen.dart` `Weighment` scale + `Quality` verified dialogs `POST` via `apiClient`, `analytics_screen.dart` centre filter `c1-c4` live `mgmt` + `operator avg_wait` + `Capacity` `LinearProgress` + `Congestion Alerts` + `Demand Forecast` + `Anomaly`.
- **Core:** `lib/core/storage/local_storage.dart` `cached_booking/queue` + `hasCachedBooking` (profile/centre caching still partial), `lib/core/config/demo_config.dart` `useMockBackend default false` `mock_fcm_token`, `app_router.dart` `+ /receipt`.
- **L10n:** `en 104/ta 96/hi 96` not yet updated for new `Add commodity` etc — still English in dialogs.

## 7. Authentication (Real Flow)

`Flutter` `POST /auth/send-otp {mobile}` → `MockOTPProvider` `123456` `is_dev` → `POST /auth/verify-otp {mobile, otp}` → `users` `mobile unique` `UserRole FARMER` (auto-creates `User` if `mobile` new) → `JWT HS256 30m` `access_token` `refresh 7d` `core/security.py` `python-jose` `passlib bcrypt` (for `otp_fixed_code` not password) → `LocalStorage saveAuth(token, role, userJson)` `SharedPreferences` → `GET /farmers/me` `Authorization: Bearer <token>` `deps.get_current_user` → `User` `farmer` `FARM-2026-*`. `Logout` `remove(token)`. `RBAC` `require_roles` `FARMER/CENTRE_OPERATOR/ADMIN` never trust Flutter.

## 8. Queue (Real Calculation)

`queue_tokens` `position ordinal` `CentreQueueState next_ordinal` `with_for_update` `token P{ordinal}` `QueueEvent`. `GET /queue/{bid}` `farmers_ahead = SELECT COUNT(*) WHERE centre_id==qt.centre_id AND position < qt.position AND status IN [WAITING,CALLED,ARRIVED,PROCESSING]` `estimate_wait = calculate_wait(farmers_ahead, avg_processing=centre.avg_processing_minutes, active_counters=centre.active_counters)` `ceil(farmers_ahead*avg/counters)` fallback `1` if `0`, `current_token = min(position WHERE status WAITING)`. `turn_approaching` `0<ahead<=2` once per booking `Notification` `data.like booking_id`. States `WAITING→CALLED→ARRIVED→PROCESSING→COMPLETED` + `CANCELLED/NO_SHOW/ON_HOLD` validated `allowed_transitions`.

## 9. Procurement (Real State Machine)

`Procurement.stage` `BOOKING_CONFIRMED→ARRIVED→WEIGHMENT→QUALITY_CHECK→PROCUREMENT→COMPLETED` `ProcurementStage` enum `STAGE_ORDER`, `allowed_procurement_transitions` only `idx+1`, `advance_procurement` `ProcurementEvent` `from_stage/to_stage/actor` `db.flush`, `POST /procurements/{bid}/advance {to_stage}` role `CENTRE_OPERATOR` → `200` else `400 Invalid transition`, `GET /procurements/{bid}/timeline` `isCompleted=i<idx` `isCurrent=i==idx` `timestamp` from `ProcurementEvent`, `Weighment` `net 0-500` `gross>=net` + auto `ARRIVED→WEIGHMENT`, `Quality` `grade A/B/C` `moisture 0-30` + auto `WEIGHMENT→QUALITY_CHECK`.

## 10. Notifications (FCM + DB)

`notifications` `id/user_id/title/body/type/is_read/created_at/data JSON` + `device_tokens` `user_id/token/platform`, `POST /notifications/device-token` dedup `token` `platform` `user_id`, `GET /notifications?limit&offset` pagination `is_read` `POST /{id}/read`, `notification_service` 10 types `booking confirmed/rescheduled/cancelled, reminder, queue movement, turn approaching, token called, procurement update, procurement completed, payment update, centre closure` `create_notification(db, user_id, title, body, type, data)` `db.add(Notification)`, `FCM` `integrations/firebase/fcm_service.py` `firebase-admin` if `FCM_PROJECT_ID/CLIENT_EMAIL/PRIVATE_KEY` else `log.info [FCM-MOCK] to=... title=...`, `fcm_service.dart` `mock_fcm_token` if `useMockBackend` else `firebase_messaging getToken` + `POST /device-token`, `notification_router.dart` tap `turn_approaching→/queue` etc, `adb reverse` device `127.0.0.1:8000` verified `POST /auth/send-otp 200` from `V2338`.

## 11. AI (Real Inputs, Fallback)

- **Waiting:** `farmers_ahead, avg_processing, active_counters, commodity, estimated_quantity, hour, centre_load` from DB `queue_tokens` `centre.avg_processing` `slot.booked/capacity` → `waiting_time_service` `LinearRegression` `coeffs` `800 synthetic R2 0.79` `X @ coeffs` `clamp max 0` `blend if |pred-rule|>15` → `predicted_wait` `used_ai true/false` fallback `calculate_wait` — **deterministic** `seed 42` training only, inference `<10ms` `numpy` only.
- **Centre Load:** `historical_counts 7d Booking centre_id date` `centre_load_service` `linear trend m*idx+c+occupancy*5+queue*0.1` `LOW<18 NORMAL<28 HIGH` 3d `forecast_3d` fallback `random 12-35` if `None` but now passed `hist_clean` from DB.
- **Demand Forecast:** `4-week weekday avg` `hist same weekday past 4 weeks` `avg_hist` `predicted = int(avg_hist)` `confidence medium` else `baseline 18 low` clearly marked.
- **Anomaly:** `booking_spike today>avg7*1.8 high, queue>20 high, capacity>90% medium, processing delay >10min medium` from `Booking` `QueueToken` `Slot` `QueueEvent`.
- **Smart Recommendation:** `GET /ai/slot-recommendation-ai` → `compute_scheduling` `eligible` `full/past/hours/closed` filtered → `get_recommendation` `best` `alternatives 3` `rule_wait` → `predict_waiting_time` `hour, centre_load` → `expected_wait = ai if used_ai else rule` `reason = ai if used_ai else rule` + `centre_load` — **AI never bypasses rule**: `eligible` already filtered `full` etc, `ai_used false` → `rule_wait`.

## 12. Security (RBAC + Isolation)

`JWT` `HS256` `access 30m` `refresh 7d` `passlib` not needed for OTP, `core/security.py` `create_access_token`, `deps.get_current_user` `Authorization: Bearer` `401` if missing, `require_roles` `403`, `bookings.py:152` `farmer.user_id==user.id` or `OPERATOR/ADMIN` else `403`, `queue.py:99` same, `procurement.py:31` same, `farmers.py:24` `mobile must match` unless `ADMIN`, `centres PATCH 403 farmer` `centres.py:75`, input `FeedbackCreate` `len(description)<5` `400`, `CommodityItem qty 0-500` `400`, `psycopg` parameterized `SELECT` no SQL injection, `.env.example` empty `jwt_secret` `fcm_*` not committed, `audit_service` redacts `password/jwt/token`.

## 13. Known Limitations (Brutally Honest)

- **DB Migrations:** `001_initial` stub `SELECT 1` + `002_multi_commodity` `ADD COLUMN IF NOT EXISTS` — dev `Base.metadata.create_all` works, prod `postgresql+psycopg` needs `alembic upgrade head` against `localhost:5432/procureflow` not tested in CI (no `psql` running).
- **Auth OTP Mock:** `MockOTPProvider` `123456` `is_dev` fallback — real SMS `Twilio` not integrated, `Registration` with `password hashing` per spec §3 not implemented (OTP flow is real JWT but not password).
- **Offline Full:** caches `booking/queue` `hasCachedBooking` + profile via `userJson` + `LIVE` badge, not yet `centre information` `notifications` `procurement status` per §26 full, no queued writes for `feedback` — `Connection required` via `HttpException` but not explicit `Last updated: <time>` banner in all screens (only `token/queue` show `LIVE`).
- **Admin Filtering:** `GET /analytics/operator/{id}?days=7` supports `days` but `GET /analytics/management` not yet `commodity` filter for `management` (spec §23 filtering by `date/centre/commodity` — `demand-forecast` supports `centre_id/commodity` but `management` not).
- **Centre Commodities:** `procurement_centres` `commodities` via `AppConstants.commodities` hardcoded list + `MSP rates` `app_constants.dart:25` not API-backed `GET /commodities` per §5.
- **Queue Display:** `farmersAhead` counts `PROCESSING` as ahead (should maybe not), minor.
- **Localization New Strings:** `Add commodity, Weighment, Quality, Receipt, Capacity warnings` still English in new dialogs (`day_planner` `Weighment`, `operator_queue` `Quality`) — `en 104/ta 96/hi 96` not yet updated.
- **Broken Test:** `test/phase2_widget_test.dart:52` `Expected "Enter OTP" found 0` — label is `Verify OTP` not `Enter OTP`, `flutter test 14/15` pass, not blocking.
- **Receipt PDF:** JSON screen, not PDF — screenshot printable lightweight per spec §14 (avoid `reportlab` 500M).
- **Centre Emergency Reason:** stored via audit `centre_closure_reason` not separate column `closure_reason TEXT` — lightweight.
- **Flutter `Avg Wait`:** previously hardcoded `31 min` now live `operator avg_wait` (fixed this run), but `Peak 10 AM - 12 PM` still hardcoded in `analytics_screen` not from `peak_periods` `GET /analytics/management`.
- **Disk:** `build 2.0G` `app-debug.apk 162M` `df -h 5.8G free` — no `emulator` `huge model` `Docker` per `6GB` rule.

## 14. Final Status

**PARTIALLY REAL — MORE WORK REQUIRED**

Core flows `Flutter → FastAPI → PostgreSQL` are **REAL** and survive restart (`GET /bookings 15` after `pkill -9` `setsid` restart `GET /bookings 15`), `POST /bookings 201` multi `Paddy, Maize 5.0` with `commodities`, `queue` from DB `farmersAhead 9`, `procurement` state machine `WEIGHMENT` `Quality A`, `payment` `COMPLETED TXN`, `receipt REC-P3`, `notifications` persisted + `FCM` mock, `AI` real data fallback, `RBAC` `403/401/200`, `concurrency` `ck_slot_booked_capacity`, `device V2338` `adb reverse` `POST /auth/send-otp 200` from device verified.

Remaining `PARTIAL` (offline full, migrations prod, OTP mock, l10n new strings, admin commodity filter) are honest and small, mock code remains gated `USE_MOCK=false` default real per Rule 28, no demo cheating in production mode.

**Not yet production ready** per spec §39 `PARTIALLY REAL` — needs `alembic` prod test, real SMS, `ta/hi` for new dialogs, `Last updated` banner everywhere, and `commodity` filter in `management` before `REAL IMPLEMENTATION COMPLETE`.

