# Real Architecture — ProcureFlow (2026-09-19)

**Stack:** Flutter `ProviderScope` `LocalStorage` `GoRouter` → FastAPI `app/main.py` `X-Request-ID` → `Business Services` `scheduling_service` `waiting_time_service` `centre_load_service` `notification_service` `audit_service` → PostgreSQL `psycopg` `SQLAlchemy DeclarativeBase` `session pool_pre_ping` + `CentreQueueState with_for_update` → FCM `firebase-admin` mock fallback.

## Backend
- `app/main.py` `FastAPI 1.0.0` `CORS *` dev `X-Request-ID` `uuid4` `request_id_ctx` `setup_logging`, `startup` `Base.metadata.create_all` if `is_dev`, `exception_handler` `500 INTERNAL_ERROR`.
- Routers `13` `/api/v1`: `auth` `farmers` `centres` (`documents/capacity/alerts`) `slots` `bookings` (`commodities` multi) `queue` `procurements` (`weighment/quality/receipt`) `payments` `notifications` `ai` (`demand-forecast/anomalies`) `assistant` `analytics` `feedback`.
- `core/config.py` `pydantic-settings` `database_url` `jwt_secret` `jwt_algorithm HS256` `otp_fixed_code 123456` `fcm_*` `scheduler_safety_buffer 2` `default_active_counters 3`.
- `core/security.py` `JWT HS256 30m access 7d refresh` `python-jose` `passlib bcrypt` (for OTP mock).
- `db/base.py` `DeclarativeBase` eager imports `notification, user, farmer, commodity, procurement_centre, slot, booking, queue, procurement, payment, feedback` + `alembic` `001_initial` `002_multi_commodity`.
- `db/session.py` `create_engine pool_pre_ping` `SessionLocal` `get_db`.

## Models 18 Tables
`users mobile unique` `farmers user_id unique` `procurement_centres` `commodities` `slots uq_slot_centre_date_time ck_booked_capacity` `bookings commodities_json TEXT` `queue_tokens booking_id unique` `centre_queue_states PK(centre_id,date)` `procurements` `weighments` `quality_checks` `procurement_events` `queue_events` `payments` `notifications` `device_tokens` `feedbacks` `audit_logs` — all `uuid4 PK` `ForeignKey onDelete CASCADE` `indexes centre_id/date` `timestamps`.

## Services
- `scheduling_service` 10 rules deterministic `SlotCandidate` `compute_scheduling` `get_recommendation` `calculate_wait`.
- `waiting_time_service` `LinearRegression` `800 synthetic` `R2 0.79` fallback `calculate_wait`.
- `centre_load_service` `linear trend 7d` fallback `random 12-35` if no history.
- `assistant_service` deterministic `FAQ en/ta/hi` + DB `token/queue/payment`.
- `notification_service` `create_notification` + `fcm_service` `send_slot_confirmed`.
- `audit_service` `audit` redacts `password/jwt`.

## Flutter
- `lib/main.dart` `ProviderScope` `LocalStorage init` `FCMService init` `GoRouter` `AppTheme`.
- `core/routing/app_router.dart` `GoRouter` 15 routes `/splash/login/register/home/centres/booking/slots/token/queue/procurement/payment/notifications/assistant/planner/feedback/history/receipt/operator/analytics` `errorBuilder`.
- `core/config/demo_config.dart` `useMockBackend bool.fromEnvironment('USE_MOCK', defaultValue: false)` `mockDelay 800ms` `demoBadgeLabel`.
- `services/api/*` 9 repos `api_client.dart` `http` `Authorization Bearer` `X-Request-ID` `get/post/patch/getList` `HttpException`, `services/mock/*` 7 mocks gated.
- `features/*` 15 screens `planner` `receipt` `history` `slot_booking` multi `operator_queue` weighment `analytics` capacity/alerts/demand/anomaly.
- `l10n` `en 104/ta 96/hi 96` + new strings English.

## DB Relations
`User→Farmer→Booking→Slot→QueueToken→Procurement→Weighment/QualityCheck→Payment→Notification` FK cascade `with_for_update` booking atomic.

## FCM
`integrations/firebase/fcm_service.py` `mock [FCM-MOCK]` if `FCM_*` empty else `firebase-admin` `device_tokens` dedup, `notification_service` 10 types, `fcm_service.dart` `mock_fcm_token` if `useMockBackend` else `firebase_messaging` + `notification_router`.

## Audit
`audit_logs` `actor/action/entity/details redacted` logged `booking_created/cancelled/rescheduled, token_called, farmer_arrived, processing_started, procurement_stage, payment_updated, centre_updated, centre_closure_reason, weighment_recorded, quality_recorded, farmer_no_show`.

## Real Flow
`Flutter ApiClient -> FastAPI -> Service -> PostgreSQL -> Response -> Flutter Provider -> Screen` `PostgreSQL` source of truth, `FCM` only push.

