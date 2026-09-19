# API — ProcureFlow Real Contracts (2026-09-19)

**Base:** `http://127.0.0.1:8000/api/v1` `Authorization: Bearer <JWT>` `X-Request-ID` `Content-Type: application/json` | **Errors:** `{"detail":{"code":"CODE","message":"..."}}` `400/401/403/404/409/500` `{"error":{"code":"INTERNAL_ERROR"}}` 500.

## Auth
- `POST /auth/send-otp {mobile}` → `200 {message, mobile}` `[MockOTP] mobile=... otp=123456` dev.
- `POST /auth/verify-otp {mobile, otp}` → `200 {access_token, token_type: bearer, user: {id, mobile, role}}` `JWT HS256 30m`.
- `GET /auth/me` `Bearer` → `200 User` `401` if missing.

## Farmers
- `POST /farmers {full_name, mobile, farmer_id, village, district, language_code, primary_commodity}` → `201 Farmer` `400 ALREADY_EXISTS` `400 MOBILE_MISMATCH`.
- `GET /farmers/me` → `200 Farmer` `404 NOT_FOUND`.
- `PATCH /farmers/me {full_name, village, district, language_code, primary_commodity}` → `200 Farmer`.

## Centres
- `GET /centres` → `200 [Centre]` `is_active true` only.
- `GET /centres/{centre_id}` → `200 Centre` `404`.
- `GET /centres/{centre_id}/status` → `200 {centre, is_open, current_queue_size, estimated_wait_minutes, active_counters, available_slots}`.
- `PATCH /centres/{centre_id} {active_counters 0-10, slot_capacity 5-50, status Open/Closed/Busy/Emergency, closure_reason, is_active}` `CENTRE_OPERATOR/ADMIN` → `200 Centre` `403` farmer `400 INVALID_STATUS` `audit centre_updated` + `centre_closure` notification to 5 affected.
- `GET /centres/{centre_id}/slot-recommendations?date&commodity_id&estimated_quantity=10` → `200 {recommended_slot, expected_wait_minutes, reason, alternatives[3], debug}`.
- `GET /centres/{id}/documents?commodity=Paddy` → `200 {centre_id, commodity, documents: [{id,label,required,description}], note}`.
- `GET /centres/{id}/capacity?target_date` → `200 {centre_id, date, total_capacity, used_capacity, remaining_capacity, occupancy, current_queue, active_counters, warnings[]}`.
- `GET /centres/{id}/alerts` → `200 {centre_id, alerts: [{type,severity,message,action}], queue_size, estimated_wait, occupancy}`.

## Slots
- `GET /slots?centre_id&date` → `200 [{id, centre_id, date, start_time, end_time, capacity, booked, available, status}]`.

## Bookings
- `POST /bookings {centre_id, slot_id, commodity, estimated_quantity, commodities?: [{commodity, quantity, unit}]}` → `201 BookingOut {id, farmer_id, centre_id, slot_id, commodity_name, estimated_quantity, token_number, queue_token_id, date, status, created_at, centre_name, slot_start, slot_end, queue_position, estimated_wait, commodities}` `400 DUPLICATE_BOOKING` `400 CENTRE_CLOSED` `404 SLOT_NOT_FOUND` `400 SLOT_MISMATCH` `400 SLOT_PAST` `409 SLOT_FULL` `400 INVALID_QUANTITY` `400 TOO_MANY_COMMODITIES`.
- `GET /bookings` → `200 [BookingOut]` farmer own sorted desc.
- `GET /bookings/{booking_id}` → `200 BookingOut` `403 FORBIDDEN` if not owner nor `OPERATOR/ADMIN` `404`.
- `POST /bookings/{id}/reschedule {new_slot_id}` → `200 BookingOut` `400 ALREADY_CANCELLED` `400 RESCHEDULE_BLOCKED` after `WEIGHMENT` `404 SLOT_NOT_FOUND` `400 SLOT_MISMATCH` `409 SLOT_FULL` `400 SLOT_PAST` `with_for_update` free old + reserve new.
- `POST /bookings/{id}/cancel` → `200 {message, booking_id}` `400 ALREADY_CANCELLED` `400 CANCELLATION_BLOCKED` after `WEIGHMENT` free `slot.booked--` `QueueEvent CANCELLED`.

## Queue
- `GET /queue/{booking_id}` → `200 QueueStatusOut {booking_id, token_number, queue_position, farmers_ahead, estimated_wait_minutes, status, debug}` `turn_approaching` notification if `0<ahead<=2`.
- `POST /queue/{booking_id}/transition {to_status: WAITING/CALLED/ARRIVED/PROCESSING/COMPLETED/CANCELLED/NO_SHOW/ON_HOLD}` → `200 {message, status}` `403 Only operator` except `ARRIVED/CANCELLED` farmer allowed `400 INVALID_TRANSITION` `audit` + notification.
- `GET /queue/centre/{centre_id}` → `200 [{token_number, position, status, booking_id, farmer_name, commodity, quantity, created_at}]`.
- `POST /queue/dev/advance?centre_id` `is_dev` → `200 {token_number, position, status}` `WAITING→CALLED` + `CentreQueueState.current_ordinal`.
- `GET /queue/dev/status?centre_id` → `200 [{token_number, position, status, booking_id}]` dev.
- `GET /queue/{booking_id}/events` → `200 [{id, from_status, to_status, created_at}]`.
- `WebSocket /queue/ws/{booking_id}` → `ws_manager` broadcast `{"status", "token"}`.

## Procurement
- `GET /procurements/{booking_id}` → `200 Procurement {id, booking_id, stage}` `403` `404`.
- `POST /procurements/{booking_id}/advance {to_stage}` `CENTRE_OPERATOR/ADMIN` → `200 {message, stage}` `400 INVALID_TRANSITION` `audit procurement_stage` + notification.
- `GET /procurements/{booking_id}/timeline` → `200 [TimelineStepOut {title, subtitle, timestamp, is_completed, is_current}]` 6 stages.
- `POST /procurements/{booking_id}/weighment {net_weight, gross_weight?, notes?}` `0-500` `gross>=net` → `200 {message, stage, net_weight}` `WEIGHMENT` + audit.
- `POST /procurements/{booking_id}/quality {grade A/B/C, moisture_percent 0-30, remarks?}` → `200 {message, stage, grade}` + audit.
- `GET /procurements/{booking_id}/receipt` → `200 {reference, farmer, centre, date, slot, commodities[], weighment{gross,net,time}, quality{grade,moisture,remarks}, procurement{stage}, payment{status,amount,transaction_id,date}}`.

## Payments
- `GET /payments/{booking_id}` → `200 Payment {id, booking_id, commodity, quantity_quintal, rate_per_quintal, total_amount, status, transaction_id, payment_date}` `403`.
- `POST /payments/{booking_id}/status {status: PENDING/PROCESSING/COMPLETED/FAILED/ON_HOLD}` `CENTRE_OPERATOR/ADMIN` → `200 {message, status}` `TXN{timestamp}` if `COMPLETED` + notification + audit.

## Notifications
- `POST /notifications/device-token {token, platform}` → `200 {message, token}` dedup `Token updated` else `Token registered`.
- `GET /notifications?limit=50&offset=0` `limit 1-100` → `200 [Notification {id, user_id, title, body, type, is_read, created_at, data}]` sorted `desc created_at`.
- `POST /notifications/{notification_id}/read` → `200 {message}` `404` if not owner.

## AI
- `GET /ai/predict-wait?farmers_ahead&avg_processing&active_counters&commodity&estimated_quantity&hour&centre_load` → `200 {predicted_wait, rule_wait, used_ai, reason, model_info}` `fallback rule` if invalid.
- `GET /ai/centre-load/{centre_id}?target_date` → `200 {level LOW/NORMAL/HIGH, score, reason, forecast_3d: [{date, expected_bookings, level}], model_info}`.
- `GET /ai/slot-recommendation-ai/{centre_id}?date&estimated_quantity&commodity` → `200 {recommended_slot, expected_wait_minutes, reason, alternatives[3], ai_used, ai_model, rule_wait, centre_load}` pipeline `VALID→RULE→AI→LOAD`.
- `GET /ai/demand-forecast?centre_id&commodity&days=7` → `200 {centre_id, commodity, forecast: [{date, predicted_bookings, reason, confidence low/medium, historical_avg}], model_info}` baseline `18` if `avg<5`.
- `GET /ai/anomalies/{centre_id}` → `200 {centre_id, anomalies: [{type,severity,message,reason}], queue_size, occupancy, today_bookings}`.

## Assistant
- `POST /assistant/ask?query&language_code=en/ta/hi` `Bearer` → `200 {answer, language, context_used}` `FAQ en/ta/hi` + DB `token, centre, slot, farmersAhead, wait, payment_status, amount, proc_stage`.
- `GET /assistant/faq?language_code=en` → `200 {how to book, documents, where centre, what token, payment, procurement}`.

## Analytics
- `GET /analytics/farmer/{farmer_id}` → `200 {farmer_id, total_bookings, completed_procurements, payments[], total_amount_received}`.
- `GET /analytics/operator/{centre_id}?days=7` `1-30` → `200 {centre_id, daily_bookings: [{date, bookings}], waiting, processing, noshow, avg_wait, centre}`.
- `GET /analytics/management` → `200 {centres: [{centre_id, centre_name, total_bookings, completed, active_counters, avg_processing}], demand_trend_7d: [{date, bookings}], peak_periods: [{time, total_booked}]}`.

## Feedback
- `POST /feedback {category: delay/quality/payment/other, description}` `len>=5` → `201 {id, category, description, status, created_at}`.
- `GET /feedback` → `200 [FeedbackOut]` farmer own else `OPERATOR/ADMIN` all 50 `desc`.
- `GET /feedback/{feedback_id}` → `200 FeedbackOut` `403` `404`.
- `POST /feedback/{feedback_id}/status?status=OPEN/REVIEWED/RESOLVED/CLOSED` `OPERATOR/ADMIN` → `200 {message, status}`.

## Health
- `GET /health` → `200 {status: ok, env: development}`.
- `GET /` → `200 {message: ProcureFlow API, docs: /docs}`.
- `GET /docs` → Swagger.

## Enums
- `QueueStatus WAITING/CALLED/ARRIVED/PROCESSING/COMPLETED/CANCELLED/NO_SHOW/ON_HOLD`
- `ProcurementStage BOOKING_CONFIRMED/ARRIVED/WEIGHMENT/QUALITY_CHECK/PROCUREMENT/COMPLETED`
- `PaymentStatus PENDING/PROCESSING/COMPLETED/FAILED/ON_HOLD`
- `UserRole FARMER/CENTRE_OPERATOR/ADMIN` + `CENTRE_MANAGER/DISTRICT_ADMIN/SYSTEM_ADMIN` mapped to `ADMIN` for now.
- `FeedbackStatus OPEN/REVIEWED/RESOLVED/CLOSED` + `OPEN/REVIEWED/RESOLVED` in model.

## Pagination
- `GET /notifications?limit&offset` `limit 1-100` `offset 0` `order desc created_at`.

## Nullability
- `commodities` `Optional` `null` → legacy single, `commodities_json` `Text nullable`, `rate_per_quintal` `Float`, `transaction_id` `String nullable`, `payment_date` `DateTime nullable`.

## IDs
- Stable `uuid4` `String PK` `id` `token_number P{ordinal}` `reference REC-P{ordinal}-{date}`.

