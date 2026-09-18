# ProcureFlow QA Checklist (Senior QA + Integration Engineer)

Generated: 2026-09-18 | Storage: 5.8G free (limit 3G floor)

## 0. State Snapshot
- Branch: main | Commit: 7d42184 | Backend: sqlite fallback (postgres role procureflow not exists)
- Real TNCSC DPCs 4 centres, MSP 2441/2461 KMS 2026-27, FCM mock mode

## 1. Backend Health (FastAPI)
- [ ] /health 200
- [ ] /docs 200
- [ ] config loads env sqlite:////.../dev.db
- [ ] auth send-otp/verify-otp/refresh/me
- [ ] farmers me/create/patch
- [ ] centres list/get/status/dashboard/slot-recommendations
- [ ] slots list (centre_id+date)
- [ ] bookings POST/GET/list/cancel
- [ ] queue get/transition/events/dev/advance/centre
- [ ] procurements get/advance/timeline
- [ ] payments get/status
- [ ] notifications device-token/list/pagination/read
- [ ] invalid ID 404, duplicate 400, auth 401, role 403, slot full 409

## 2. PostgreSQL Integrity (sqlite dev)
- [ ] tables 17, FKs, unique, indexes idx_*, timestamps, enums, cascade
- [ ] alembic stub (no destructive migration)

## 3. Concurrency
- [ ] slot capacity 1 → 2 threads → 1 success 1 FULL, no overbook, no duplicate token

## 4. Scheduler
- [ ] 12 cases deterministic, zero counters safe, past/full filtered, reason/alternatives

## 5-7. Farmer/Operator/Queue Journey
- [ ] Register→Login→Centre→Commodity→Qty→Reco→Booking→Token→Queue→Arrived→Processing→Completed→Payment

## 8. FCM
- [ ] mock provider logs, notification rows created, device token dedup, no secrets committed

## 9-10. Flutter API/Offline
- [ ] repositories map http 200/4xx, loading/empty/error/offline, no fake success

## 11. Demo Data
- [ ] 4 DPC Bhavani/Perundurai/Sathyamangalam/Gobichettipalayam, 5 commodities MSP 2441/2461 etc, slots 8/day, queue states

## 12. UI
- [ ] M3, spacing, badges, LIVE vs DEMO, l10n en/ta/hi

## 13. Security
- [ ] .gitignore .env, JWT HS256, CORS, no secrets, role checks

## 14-15. Tests/Build
- [ ] backend 19 pass, flutter analyze 0 errors, test 14/15, apk debug builds

## 16. Final E2E
- [ ] Bhavani Paddy → token → operator call → processing → payment COMPLETED → notifications
