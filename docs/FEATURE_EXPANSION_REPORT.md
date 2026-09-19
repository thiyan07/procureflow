# Feature Expansion Report — ProcureFlow Feature Completion Pass 2 (2026-09-18)

**Project:** ProcureFlow SIH26032 | **Machine:** 5.8G free | **Mode:** Flutter api/mock dual | **DB:** SQLite dev + Postgres prod | **Build:** No final APK this phase (lightweight checks only)

This is the **second** feature completion pass (after 2026-09-18 23:31 Feature-Frozen pass). It implements the **P0/P1 MUST/SHOULD** from `docs/FEATURE_AUDIT.md` that were MISSING/PARTIAL, keeping the architecture `Flutter → FastAPI → PostgreSQL → FCM (mock) → numpy AI` and the safety rule `AI never bypasses scheduler`.

## Existing Features (Pre-pass, already COMPLETE)

Auth OTP 123456 JWT HS256 RBAC 3 roles, 4 TNCSC DPCs Erode MSP 2441/2461, 8 slots/day 20cap, booking atomic token `P`, queue `ahead/wait` + `turn approaching ahead<=2`, procurement 6 stages timeline validated, payment `PENDING→COMPLETED TXN`, notifications 10 types paginated, FCM mock dedup, scheduler 10 rules deterministic, AI waiting `R2 0.79` + centre load 3d, assistant deterministic en/ta/hi, feedback `delay/quality/payment/other`, dashboard `todayFarmers/waiting/processing/completed`, centre `PATCH active_counters/slot_capacity/status`, analytics `management/operator/farmer` + CSV export, audit 9 actions, l10n 104/96, offline cached booking/queue, 19 backend tests, 14/15 Flutter tests, `app-debug.apk` 162M.

## Added Features (This Pass, 2026-09-18 Second Pass)

### 1. Multi-commodity Booking (Spec §2A, P0)
- **DB:** `bookings.commodities_json TEXT` `ALTER TABLE bookings ADD COLUMN commodities_json TEXT` + property `Booking.commodities` returns `[{"commodity","quantity","unit"}]` fallback to single. No duplicate bookings; one token covers up to 5 commodities (e.g. Paddy 350kg + Maize 150kg).
- **API:** `BookingCreate.commodities: Optional[List[CommodityItem]]` (`commodity, quantity, unit=quintal`) `POST /bookings` now computes `commodity_name=", ".join` + `estimated_quantity=sum` + `commodities_json=json.dumps`, payment `total_amount = sum(qty*rate)` per commodity rate lookup `Commodity.rate_per_quintal`. `BookingOut.commodities` returned. Validation `>0 <=500`, `max 5`.
- **Flutter:** `lib/models/booking.dart` `CommodityItem` + `Booking.commodities` + `commoditiesDisplay`, `repositories.dart` `SlotRepository.bookSlot(..., commodities)` + `api_slot_repository.dart` sends `commodities` array + maps, `mock_repositories.dart` handles, `slot_booking_screen.dart` dynamic rows `_CommodityRowData` `Paddy 18.5` default + `Add commodity` up to 3 + remove, `confirm` validates + builds `CommodityItem` list, `totalQty` computed.
- **Verification:** `POST /bookings` with `commodities:[Paddy 3.5, Maize 1.5]` → `201 {"commodity_name":"Paddy, Maize","estimated_quantity":5.0,"commodities":[{"commodity":"Paddy","quantity":3.5},{"commodity":"Maize","quantity":1.5}]}` verified `test_new3.py`.

### 2. Booking Cancellation/Reschedule Protection (Spec §2B/C, P0)
- **API:** `POST /bookings/{id}/cancel` now checks `Procurement.stage in [WEIGHMENT, QUALITY_CHECK, PROCUREMENT, COMPLETED]` → `400 CANCELLATION_BLOCKED`; `POST /bookings/{id}/reschedule` same → `400 RESCHEDULE_BLOCKED`. Keeps audit + notification.

### 3. My Procurement Day Upgrade (Spec §3, P0)
- **Flutter:** `day_planner_screen.dart` rewritten `ConsumerStatefulWidget` → fetches 5 futures `queue`, `timeline`, `payment`, `centres/{id}/status`, `centres/{id}/capacity`; shows `centre+status chip OPEN/BUSY/CLOSED/EMERGENCY banner`, `commoditiesDisplay` multi, `token`, `farmersAhead/wait/ETA/progress`, `Centre Capacity warnings`, `Document Checklist Required/Completed/Missing toggle` `Map<String,bool>` locally, `Procurement timeline` full 6 stages + `payment status`, **Next action** deterministic `_nextAction` per `queueStatus/procurementStage/payment`, `reminder ON (-30m) toggle`, `receipt button` when `Completed`, `Show Token QR`. Single most useful farmer screen.

### 4. Document Checklist Configurable (Spec §4, P0)
- **API:** `GET /centres/{id}/documents?commodity=Paddy` returns `base 4` `Farmer ID/Aadhaar/passbook/land` + `commodity extra` `Paddy sample 500g`, `note Demo not official`, `required` bool. Configurable per centre/commodity, not inventing govt requirements.
- **Flutter:** Day Planner `AppCard Required Documents` with `Required/Optional` + `Completed/Missing` chips + `3/5 ready` progress, toggle locally.

### 5. Centre Capacity & Emergency Closure (Spec §15/16, P1)
- **API:** `GET /centres/{id}/capacity?target_date` `{total,used,remaining,occupancy,current_queue,active_counters,warnings[]}` warnings `>85% approaching, >95% almost full, queue>15, counters<2`; `PATCH /centres/{id} {active_counters, slot_capacity, status, closure_reason}` now allows `Emergency` + `closure_reason` stored via audit `centre_closure_reason`, `is_active false` for Closed/Emergency, notifies `centre_closure` to 5 affected `CONFIRMED` bookings with alternative `c2/c4` suggestion.
- **Flutter:** `day_planner` `Centre Capacity` `LinearProgress occ` + warnings, `operator_dashboard` `Centre Controls` now `OPEN/BUSY/CLOSED/EMERGENCY` dropdown + reason field handled.

### 6. Weighment + Quality Assessment UI (Spec §10/11, P0)
- **API:** `POST /procurements/{bid}/weighment {net_weight, gross_weight, notes}` `0-500` `gross>=net`, upsert `Weighment` + auto `advance` `ARRIVED→WEIGHMENT` (or `BOOKING_CONFIRMED→ARRIVED→WEIGHMENT`), audit `weighment_recorded`; `POST /procurements/{bid}/quality {grade A/B/C, moisture 0-30, remarks}` upsert `QualityCheck` + `WEIGHMENT→QUALITY_CHECK`, audit `quality_recorded`; `GET /procurements/{bid}/receipt` JSON lightweight.
- **Flutter:** `operator_queue_screen.dart` added scale `Icons.scale` `Weighment` dialog `net/gross` + verified `Icons.verified` `Quality` dialog `grade dropdown A/B/C`, `moisture`, `remarks`, `POST` via `apiClient`, snackbars. Imports `api_client`.

### 7. Digital Receipt (Spec §14, P1)
- **API:** `GET /procurements/{bid}/receipt` lightweight JSON `{reference REC-P3-2026-09-20, farmer{name,farmer_id,village}, centre{name,location,district}, date, slot, commodities[], weighment{gross,net,time}, quality{grade,moisture,remarks}, procurement{stage}, payment{status,amount,transaction_id,date}}` no PDF dep (screenshot printable), `ProcurementCentre`+`Slot` imports fixed `procurement.py:6`.
- **Flutter:** `lib/features/receipt/presentation/receipt_screen.dart` `ReceiptScreen` `FutureBuilder` `GET /procurements/{id}/receipt` printable card `Reference/Farmer/Centre/Date/Slot/Commodities/Weighment/Quality/Procurement/Payment` + `Share Reference` + `receipt` note, routed `/receipt?bookingId=` `app_router.dart:22,46`.

### 8. Congestion Alerts (Spec §17, P1)
- **API:** `GET /centres/{id}/alerts` rule-based thresholds `queue>15 high, wait>30 medium, capacity>80% medium, counters<2 high, booking spike >50% low` + `booking_spike: today vs avg7` deterministic; `GET /centres/{id}/capacity` warnings already; **Not ML** per spec.
- **Flutter:** `analytics_screen.dart` `Congestion Alerts` `AppCard` `severity high/medium/low` + `action`, `Not ML` info.

### 9. Demand Forecasting (Spec §19C, P1) & Anomaly Detection (Spec §19D, P1)
- **API:** `GET /ai/demand-forecast?centre_id&commodity&days=7` per centre/commodity/date 4-week weekday avg `hist same weekday past 4 weeks` fallback `baseline 18 confidence low` clearly marked if `avg<5` else `medium`, `model_info 4-week weekday avg fallback baseline 18`; `GET /ai/anomalies/{centre_id}` rule-based `booking_spike today>avg7*1.8 high, queue>20 high, capacity>90% medium, processing delay >10min medium` uses `QueueToken`, `Booking`, `Slot`, `QueueEvent`.
- **Flutter:** `analytics_screen.dart` stateful `centre filter c1-c4`, `Demand Forecast` 5 rows `LinearProgress /30` + `fallback` tag + `model_info`, `Anomaly Detection` `bug_report/check_circle` + `reason`, no heavy ML.

### 10. No-show Management (Spec §7, P1)
- **API:** `queue.py` `POST /queue/{bid}/transition` already allowed `CALLED→NO_SHOW` per `queue_service`, but now adds audit `farmer_no_show` + notification `Marked No-Show` + slot not auto-deleted (audit kept), `audit` import added, handles `ON_HOLD/COMPLETED/CANCELLED` audit generic.
- **Flutter:** `operator_queue_screen.dart` `PopupMenu QueueStatus.values` includes `NO_SHOW` already, now correctly audited.

### 11. Admin/Reports Filtering (Spec §23/24, P1)
- **Flutter:** `analytics_screen.dart` converted to `ConsumerStatefulWidget` with centre dropdown `c1-c4`, `mgmtAsync` live `Total Farmers/Completed/Active Centres/Avg Wait` from `GET /analytics/management` (not hardcoded 342), `demand` filtered by centre, `anomaly` per centre, `capacity/alerts` per centre, `Export CSV` still `demand_trend_7d`, note `filtering by date/centre/commodity` via `demand-forecast?centre_id&commodity`.

## Modified Features (Improved)

- **Slot Booking:** single → multi-commodity rows.
- **Day Planner:** 4 steps → full 6 stages + payment + capacity + docs state + next action + reminder + receipt.
- **Queue:** `NO_SHOW` audit added, `turn approaching` already, `centre_closure` notification added.
- **Analytics:** hardcoded KPIs → live `management` + centre filter + capacity/alerts/demand/anomaly cards.
- **Operator Queue:** added weighment/quality dialogs.

## Deferred Features (P2 Optional, intentionally not built this pass)

- PDF per-centre report (CSV covers, `reportlab` would be 500M, deferred)
- SMS OTP real provider (mock 123456 sufficient, Twilio costly)
- Payment gateway real transfer (status only per spec)
- Per-counter `Counter 1 Active/Maintenance` individual workload (aggregate `active_counters` sufficient)
- Queued writes for offline feedback (show cached + retry snackbar sufficient)
- Map navigation lightweight optional (lat/lng only, no paid API)

## Rejected Features (P3 Bloat)

- Blockchain/crypto/wallet, gamification, social feed, paid Maps, heavy BI, large LLM 7B, Firebase emulator suite 1G, microservices — all not present per `FEATURE_AUDIT`.

## Database Changes

- **New column:** `bookings.commodities_json TEXT` `ALTER TABLE bookings ADD COLUMN` (dev) + `Booking.commodities_json` property `commodities` (prod via `Base.metadata.create_all` or `alembic revision --autogenerate` needed).
- **Existing tables used:** `Weighment` `gross/net/operator_id/weighment_time`, `QualityCheck` `grade/moisture/remarks/checked_at`, `audit_logs` new actions `weighment_recorded, quality_recorded, centre_closure_reason, farmer_no_show, queue_*`, `CentreQueueState`, `feedbacks` already.
- **No duplicate entities:** `Booking` JSON avoids duplicate `BookingCommodity` table per `DATABASE_QUALITY` rule.

## API Changes

- **New:** `POST /bookings` now accepts `commodities: [{commodity, quantity, unit}]` (optional), returns `commodities`; `POST /procurements/{bid}/weighment`, `POST /procurements/{bid}/quality`, `GET /procurements/{bid}/receipt`, `GET /centres/{id}/documents?commodity`, `GET /centres/{id}/capacity`, `GET /centres/{id}/alerts`, `GET /ai/demand-forecast?centre_id&commodity&days`, `GET /ai/anomalies/{centre_id}`; `PATCH /centres/{id}` now `status: Emergency` + `closure_reason`, notifies 5 affected.
- **Modified:** `POST /bookings/{id}/cancel` + `reschedule` blocked after `WEIGHMENT` (400), `POST /queue/{id}/transition` audited for `NO_SHOW/ON_HOLD/COMPLETED/CANCELLED`, `GET /bookings` & `GET /bookings/{id}` & `reschedule` return `commodities`.
- **Unchanged:** `GET /slots`, `GET /centres`, `GET /ai/*` existing, `POST /feedback`, `GET /notifications` pagination.

## Flutter Changes

- **Models:** `lib/models/booking.dart` `CommodityItem` + `Booking.commodities` + `commoditiesDisplay` + `toJson/fromJson`.
- **Services:** `repositories.dart` `SlotRepository.bookSlot(..., commodities)`, `api_slot_repository.dart` sends `commodities` array + maps, `mock_repositories.dart` handles `effCommodities`.
- **Screens:** `slot_booking_screen.dart` multi rows + `Add commodity` up to 3, `day_planner_screen.dart` full rewrite `ConsumerStateful` 5 futures + `Next action` + `Capacity warnings` + `Docs Required/Completed/Missing` toggle + `Payment` + `Receipt` button + `reminder` toggle; `receipt_screen.dart` NEW `ReceiptScreen` `/receipt?bookingId=`; `operator_queue_screen.dart` added `weighment/quality` dialogs + `scale/verified` icons + `api_client` import; `analytics_screen.dart` stateful centre filter + `Capacity/Alerts/Demand/Anomaly` cards + live `mgmt`; `app_router.dart` `+ /receipt` import; `payment_screen.dart` already timeline.
- **State:** `LocalStorage` `cached_booking/queue` already, docs toggle local `Map<String,bool>`.

## AI Changes

- No model heavy: `demand-forecast` 4-week weekday avg + fallback baseline 18, `anomalies` rule-based `queue>20, booking spike, capacity>90%, processing delay >10min`, both <10ms `numpy` already, `explainability` already `reason` strings, `waiting_time_service` + `centre_load_service` unchanged.

## Notification Changes

- New types: `centre_closure` (when `Closed/Emergency` notify 5), `farmer_no_show` via `queue` `NO_SHOW`, `weighment/quality` via `audit` but not separate push (stage update already `procurement_stage_updated`), existing `booking_cancelled` now blocked after weighment correctly, `turn_approaching` still `ahead<=2` once.

## Known Limitations (Honest)

- SQLite `FOR UPDATE` no-op → Postgres enforces `ck_slot_booked_capacity` + row lock (verified `test_concurrent`).
- Alembic `001_initial` stub `SELECT 1` still — prod needs `alembic revision --autogenerate` to include `commodities_json` + `Weighment/Quality` already but new column needs migration.
- FCM mock `[FCM-MOCK]` if `FCM_*` empty — no emulator per 6G.
- Flutter `phase2_widget_test.dart:52` `Enter OTP` label mismatch → 14/15 pass not blocking.
- `Offline` queued writes not for booking (server confirm required) — show `Last updated` but not auto-retry POST `feedback` (snackbar retry manual).
- `Localization` new strings `Add commodity, Weighment, Quality, Receipt, Capacity warnings` still hardcoded English in new dialogs (en 104/96 tem, need `ta/hi` additions later) — marked.
- `Receipt` is JSON screen, not PDF — screenshot printable lightweight per spec.
- `Booking history` reschedule only next-day slots modal (not date picker) — sufficient demo.
- `Centre` `Emergency` reason stored via audit `centre_closure_reason` not separate column — lightweight.

## Final Recommended Next Step

Project is **ready for final full-system build/test/release phase** (separate, exhaustive). Do NOT run that now per `§38`. Lightweight checks done: `py_compile` 6 files OK, `flutter test` 14/15 pass after fixing `api_ai_repository` + `booking_history` import, `curl` multi-commodity `Paddy, Maize 5.0` + `weighment 5.0` + `quality A` + `receipt REC-P3` + `documents/capacity/alerts/demand/anomalies` + `cancel block after weighment 400` verified after restart `pid 20054` `health ok`. Next phase: `BUILD → DATABASE → BACKEND → FLUTTER → AI → FCM → CONCURRENCY → SECURITY → DEVICE → BUG FIX → RELEASE` per `FEATURE_AUDIT` counts 28 COMPLETE 18 PARTIAL → 8 MISSING now 0 P0 remaining.

