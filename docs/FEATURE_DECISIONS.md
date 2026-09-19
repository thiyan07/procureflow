# Feature Decisions — ProcureFlow Final Expansion

**Date:** 2026-09-18 | **Storage:** 5.8G free | **Principle:** Rules first, AI enhancement, no bloat

## Inventory

**A. Already implemented:** Auth OTP, farmer profile, centre discovery (4 DPCs), commodity/qty, slot availability 8/day, rule scheduler + AI wait/centre-load, booking atomic token P, live queue polling+WS, procurement 6-stage timeline, payment status, notifications 8 types + history, operator dashboard/queue, analytics farmer/operator/management, audit logs, l10n en/ta/hi, offline retry, FCM mock.

**B. Partially:** Booking cancel yes, reschedule no; centre info basic, not detailed; queue turn-approaching not thresholded; payment timeline shows status but not history list; centre capacity/counters read-only; documents in FAQ not checklist.

**C. Missing high-value:** Day Planner single view, reschedule, document checklist, detailed centre info, feedback/grievance light, counter active toggle, slot capacity config, centre open/close emergency, turn-approaching auto notification.

**D. Broken:** None critical; sqlite concurrency overbook (postgres fixes), widget test needed USE_MOCK flag.

**E. Duplicate/redundant:** None; mock vs api dual kept intentionally.

**F. Low-value/bloat to avoid:** Blockchain, crypto, social feed, gamification, paid maps, chat, heavy BI, large LLM.

## Decisions

| Feature | Decision | Reason | User Value | Complexity | Deps |
|---|---|---|---|---|---|
| Day Planner (centre/date/commodity/qty/slot/token/wait/ETA/docs/reminder) | **IMPLEMENT P0** | Farmer primary "what next?" | High | Low | existing booking+queue |
| Booking reschedule | **IMPLEMENT P0** | Cancel+rebook atomic, respects capacity | High | Low | bookings |
| Document checklist | **IMPLEMENT P0** | Need before visit, no sensitive storage | High | Low | static list |
| Centre info detailed (hours, status, queue, wait, contact) | **IMPLEMENT P0** | Reduce trips, already coords | High | Low | centres |
| Feedback/grievance (category, desc, status) | **IMPLEMENT P1** | Lightweight quality loop | Medium | Low | new table |
| Counter management (active/inactive, assign) | **IMPLEMENT P1** | Operate 2-4 counters | High | Low | centres.active_counters |
| Capacity management (slot/daily capacity) | **IMPLEMENT P1** | Affects scheduler safely | High | Low | slots.capacity |
| Centre closure emergency (OPEN/CLOSED) | **IMPLEMENT P1** | Prevent bookings when closed, simple toggle | High | Low | centres.status |
| Turn approaching notification (threshold farmersAhead ≤2) | **IMPLEMENT P1** | Useful intelligence, not spam | High | Low | queue |
| Payment timeline history | **IMPLEMENT P0** | Transparency already partial | High | Low | payments |
| Procurement transparency timeline | **IMPLEMENT P0** | Already 6 steps, keep | High | Low | - |
| Assistant deterministic FAQ | **KEEP** | Already uses DB context, no LLM hallucination | High | Low | - |
| Admin reports CSV export | **DEFER P2** | Small value, can add later | Low | Low | analytics |
| Map paid API | **REJECT P3** | Use coords, not paid | Low | High | - |
| Heavy ML/LLM | **REJECT P3** | Keep classical numpy | - | High | - |
| Blockchain/chat | **REJECT P3** | No procurement value | - | High | - |

**P0/P1 selected:** 10 features, all small, no infra, work with existing architecture, demo-useful.
