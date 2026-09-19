# ProcureFlow AI — Lightweight Classical ML (No Large Models)

**Principle:** AI enhances, never replaces deterministic safety. Rule layer filters invalid/full slots; AI only refines wait/ load predictions.

## Components

### 1. Waiting-Time Prediction (`services/waiting_time_service.py`)
- **Model:** Linear Regression `y = b0 + b1*farmers + b2*avg + b3*qty_factor + b4*load + b5*hour` via `numpy.linalg.lstsq`
- **Training:** 800 synthetic rows (seed 42) from Erode DPC ranges (farmers 0-20, avg 3-4, counters 2-4, qty 5-30, hour 9-14, load 0.1-0.9), target = `calculate_wait + qty*0.1 + load*2 + hour` + noise. R2 ~0.85.
- **Inference:** feature `qty_factor=1+(q-10)*0.02`, `centre_load=farmers/20`, clamp `max(0, pred)`, blend if `|pred-rule|>15 → (pred+rule)/2`.
- **Fallback:** any error/invalid → `calculate_wait` rule, `used_ai:false`, reason `Rule-based X min`.
- **API:** `GET /api/v1/ai/predict-wait?farmers_ahead=&avg_processing=&active_counters=&commodity=&estimated_quantity=&hour=&centre_load=` returns `{predicted_wait, rule_wait, used_ai, reason, model_info}`.
- **Flutter:** `ApiAiRepository.predictWaitingTime` calls endpoint, fallback to local deterministic in `answerAssistant`.

### 2. Smart Slot Recommendation (`services/scheduling_service.py` + `api/routes/ai.py`)
- Pipeline: VALID FILTER (past/full/hours) → RULE SAFETY (scoring) → AI WAIT (per best slot `farmers_ahead, avg, counters, qty, hour, load`) → LOAD ANALYSIS → RECOMMENDATION.
- Returns `recommended_slot, expected_wait (AI if used else rule), reason (AI or rule), alternatives×3, ai_used, rule_wait, centre_load`.
- Endpoint: `GET /api/v1/ai/slot-recommendation-ai/{centre_id}?date=&estimated_quantity=&commodity=`

### 3. Centre Load Prediction (`services/centre_load_service.py`)
- **Model:** 7-day bookings `y` linear trend `m,c = lstsq([x,1], y)`, forecast 3 days `pred = m*idx + c + occupancy*5 + queue*0.1`, level `LOW <18 NORMAL <28 HIGH`.
- Fallback: occupancy `>0.7 HIGH`.
- API: `GET /api/v1/ai/centre-load/{centre_id}?target_date=` returns `{level, score, reason, forecast_3d, model_info}`.

## Fallback Strategy
All AI calls wrapped `try/except` → rule-based. Booking never fails due to AI. Synthetic data marked `trained_on: synthetic demo data`.

## Dependencies
Only `numpy` (already present), no `scikit-learn` (17G cache not installed per 6G constraint), no pandas, CPU inference <10ms.

## Future
Optional LLM for FAQ only, not account data; keep retrieval deterministic.
