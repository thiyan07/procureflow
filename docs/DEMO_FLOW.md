# ProcureFlow Demo Flow (Real TNCSC DPC Data)

**Centres (Erode, MSP KMS 2026-27):** TNCSC DPC Bhavani RM (c1, Gobichettipalayam Div), Perundurai RM (c2, Erode Div), Sathyamangalam RM (c3), Gobichettipalayam RM (c4). Commodities: Paddy Common 2441 / Grade A 2461 / Ragi 4886 / Maize 2400 / Tur 8000. Slots 8/day 09:00-11:30 + 13:30-15:00 capacity 20, 2026-09-19 etc.

## Farmer Journey (Farmer `9876543210` / OTP `123456`)

1. **Login:** `POST /api/v1/auth/send-otp` `{"mobile":"9876543210"}` → `POST /auth/verify-otp` `{"mobile":"...","otp":"123456"}` → `access_token` → `GET /auth/me` → farmer `Ravi Kumar Kavindapadi`
2. **Home:** `FarmerHomeScreen` shows `LIVE • TNCSC DPC • MSP 2026-27` (not DEMO), village, `GET /bookings` active or `No active booking`
3. **Centre:** `GET /api/v1/centres` list 4 → open `c1` → `GET /centres/c1/status` `is_open, current_queue_size, estimated_wait, active_counters`
4. **Commodity/Qty:** Select `Paddy Grade A` / `12` quintal (maps to `2441/2461`)
5. **Recommendation:** `GET /centres/c1/slot-recommendations?date=2026-09-19&estimated_quantity=12` → `{recommended_slot: 09:00, wait 2, reason "Lower expected centre load.", alternatives×3}`
6. **Slot:** `GET /slots?centre_id=c1&date=2026-09-19` 8 slots with `available/booked` → tap first available
7. **Confirm Booking:** `POST /api/v1/bookings` `{"centre_id":"c1","slot_id":"...","commodity":"Paddy Grade A","estimated_quantity":12}` → `201 {id, token_number:"P2", centre_name, slot_start, queue_position}` atomic `SELECT FOR UPDATE` → token generated backend only
8. **Token:** `TokenScreen` QR `PROCUREFLOW|bid|P2|c1` + `GET /queue/{bid}` `farmersAhead 1 wait 2 status WAITING`
9. **Queue:** `QueueScreen` polling 5s `watchQueue` → `GET /queue/{bid}` `farmersAhead, estimatedWait, debug` + `WebSocket /queue/ws/{bid}` fallback
10. **Arrive:** Farmer `POST /queue/{bid}/transition` `{"to_status":"ARRIVED"}` (allowed farmer) → status `ARRIVED`
11. **Procurement:** Operator `9876543211` login → `GET /centres/c1/dashboard` `today_farmers, waiting, processing` → `GET /queue/centre/c1` list → `POST /procurements/{bid}/advance` `ARRIVED→WEIGHMENT→QUALITY_CHECK→PROCUREMENT→COMPLETED` each creates `procurement_events` + notification `procurement_stage_updated` → `GET /procurements/{bid}/timeline` shows `Booking Confirmed✓ Arrived✓ Weighment●`
12. **Payment:** `GET /payments/{bid}` `PENDING 29332 (12*2441)` → Operator `POST /payments/{bid}/status` `PROCESSING→COMPLETED` `transaction_id TXN...` `payment_date` → Farmer `GET /payments/{bid}` `COMPLETED`
13. **Notifications:** `GET /notifications?limit=50` history `Slot Confirmed, Token Called, Procurement Updated×2, Payment Status Updated` + `POST /notifications/{id}/read` + `POST /notifications/device-token` dedup. Dev simulate: `POST /queue/dev/advance?centre_id=c1` advances `P1→CALLED` increments `CentreQueueState.current_ordinal`.

## Operator Journey (`9876543211`)

`Login → Dashboard GET /centres/c1/dashboard → Today's queue GET /queue/centre/c1 → Call Next POST /queue/dev/advance → Mark ARRIVED/PROCESSING via POST /queue/{bid}/transition → Procurement Advance → Payment Completed → Farmer sees update`.

## Verification

`backend 19 tests`, `flutter analyze 0 errors`, `flutter build apk --debug` ✓, `df -h 5.8G free`, `GET /health ok`, `sqlite 17 tables`, `FCM mock` logs `[FCM-MOCK]`.

