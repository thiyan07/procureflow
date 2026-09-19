# ProcureFlow User Flows

## Farmer (Mobile)
1. **Register/Login:** Splash → Login `9876543210` Send OTP → `123456` Verify → JWT stored `LocalStorage` → `GET /farmers/me` (create if 404 with village/district)
2. **Discovery:** Home `LIVE` badge → Centres `GET /centres` 4 DPCs → Centre detail `GET /centres/c1/status` queue/wait/counters
3. **Booking:** Commodity Paddy/Grade A/Ragi + qty → `GET /slots?centre_id&date` 8 slots → `GET /centres/c1/slot-recommendations` or `GET /ai/slot-recommendation-ai/c1` → select slot → `POST /bookings` → token `P1` QR `PROCUREFLOW|bid|token|c1` (backend generates)
4. **Day Planner:** `/planner` single "what next?" view `GET /queue/{bid}` + `GET /procurements/{bid}/timeline` + `GET /payments/{bid}` + docs checklist + reminder toggle
5. **Booking History:** `/history` `GET /bookings` list sorted desc, detail bottom sheet, **Reschedule** `POST /bookings/{id}/reschedule {new_slot_id}` next-day slots, **Cancel** `POST /bookings/{id}/cancel` frees slot + notification
6. **Token/Queue:** Token screen `GET /queue/{bid}` `farmersAhead, estimatedWait, currentToken` polling 5s `watchQueue` + `WebSocket /queue/ws/{bid}` fallback + `LIVE` vs `Last updated` cache
7. **Procurement Timeline:** `GET /procurements/{bid}/timeline` 6 steps `BOOKING_CONFIRMED→ARRIVED→WEIGHMENT→QUALITY_CHECK→PROCUREMENT→COMPLETED` with timestamps, operator advances
8. **Payment:** `GET /payments/{bid}` `PENDING amount 2461*q` → `COMPLETED` `TXN` after operator `POST /payments/{bid}/status` + timeline stepper `Booking→Procurement→Processing→Completed`
9. **Notifications:** `GET /notifications?limit&offset` history 10 types (slot_confirmed/rescheduled/cancelled, turn_approaching, token_called, procurement, payment) `is_read` dot, tap routing `notification_router` → `POST /notifications/{id}/read` + `device-token` dedup
10. **Assistant:** `AssistantScreen` chips `Where is my token?` → `POST /assistant/ask?query&language_code` deterministic FAQ + context (token/queue/payment from DB) en/ta/hi
11. **Feedback:** `/feedback` category delay/quality/payment/other `POST /feedback`, list `GET /feedback`, operator status update
12. **Offline:** ApiClient throws `HttpException` → `ErrorState Retry`, `OfflineMessage` via cached `LocalStorage` `cached_booking_json/time, cached_queue_json/time`, never fake success

## Operator (Centre Operator `9876543211`)
Login → Dashboard `GET /centres/c1/dashboard` `todayFarmers/waiting/processing/completed/paymentPending/avgWait` → Today's queue `GET /queue/centre/c1` list → Call Next `POST /queue/dev/advance` or `POST /queue/{bid}/transition CALLED` → Mark ARRIVED (farmer) → PROCESSING → Weighment/Quality via `POST /procurements/{bid}/advance` → Payment `POST /payments/{bid}/status COMPLETED` → Next farmer. All updates via PostgreSQL, farmer sees live.

## Admin (ADMIN `9999999999`)
`GET /analytics/management` centres comparison, `GET /analytics/operator/{centre_id}` daily bookings, `GET /analytics/farmer/{id}` history. Lightweight dashboard `OperatorDashboard` + `AnalyticsScreen` `fl_chart`.

## Roles
- `FARMER` can book, view own, ARRIVED/CANCELLED own
- `CENTRE_OPERATOR` can transition any queue/procurement/payment for centre, dashboard
- `ADMIN` all + analytics management

## Error Handling
Full slot 409 `SLOT_FULL`, duplicate 400 `DUPLICATE_BOOKING`, centre closed 400, past slot 400, invalid transition 400, unauth 401, forbidden 403, not found 404. All screens have loading/success/empty/error/offline.
