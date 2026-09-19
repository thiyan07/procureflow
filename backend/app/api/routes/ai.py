from fastapi import APIRouter, Depends, Query
from datetime import date, time
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.procurement_centre import ProcurementCentre
from app.models.slot import Slot
from app.services.waiting_time_service import predict_waiting_time
from app.services.centre_load_service import predict_centre_load

router = APIRouter()

@router.get("/predict-wait")
def predict_wait(
    farmers_ahead: int = Query(..., ge=0),
    avg_processing: int = Query(3, ge=1),
    active_counters: int = Query(3, ge=0),
    commodity: str | None = None,
    estimated_quantity: float = Query(10, ge=0),
    hour: int | None = Query(None, ge=0, le=23),
    centre_load: float | None = Query(None, ge=0, le=1),
    db: Session = Depends(get_db),
):
    res = predict_waiting_time(farmers_ahead, avg_processing, active_counters, commodity, estimated_quantity, hour, centre_load)
    return res

@router.get("/centre-load/{centre_id}")
def centre_load(centre_id: str, target_date: date = Query(...), db: Session = Depends(get_db)):
    c = db.query(ProcurementCentre).filter(ProcurementCentre.id == centre_id).first()
    if not c:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    # Derive historical counts and occupancy from DB (last 7 days bookings per date)
    from app.models.booking import Booking
    from datetime import timedelta
    hist = []
    for i in range(7, 0, -1):
        d = target_date - timedelta(days=i)
        cnt = db.query(Booking).filter(Booking.centre_id == centre_id, Booking.date == d).count()
        # if no data, use synthetic fallback via service
        hist.append(cnt if cnt > 0 else None)
    # filter Nones for fallback
    hist_clean = [h for h in hist if h is not None]
    if not hist_clean:
        hist_clean = None
    # current queue
    from app.models.queue import QueueToken, QueueStatus
    current_q = db.query(QueueToken).filter(QueueToken.centre_id == centre_id, QueueToken.status.in_([QueueStatus.WAITING.value, QueueStatus.CALLED.value])).count()
    # avg occupancy today
    slots = db.query(Slot).filter(Slot.centre_id == centre_id, Slot.date == target_date).all()
    occ = sum(s.booked / s.capacity if s.capacity else 0 for s in slots) / len(slots) if slots else 0.3
    res = predict_centre_load(centre_id, target_date, hist_clean, current_q, occ)
    return res

@router.get("/slot-recommendation-ai/{centre_id}")
def slot_recommendation_ai(centre_id: str, target_date: date = Query(..., alias="date"), estimated_quantity: float = Query(10), commodity: str = Query("Paddy"), db: Session = Depends(get_db)):
    """
    AI-enhanced slot recommendation pipeline:
    VALID FILTER → RULE SAFETY → AI WAIT PREDICTION → LOAD ANALYSIS → RECOMMENDATION
    AI never recommends invalid/full slot; rule is safety layer.
    """
    c = db.query(ProcurementCentre).filter(ProcurementCentre.id == centre_id).first()
    if not c:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    slots = db.query(Slot).filter(Slot.centre_id == centre_id, Slot.date == target_date).all()
    from app.services.scheduling_service import SlotCandidate, compute_scheduling, get_recommendation
    candidates = [SlotCandidate(s, c) for s in slots]
    eligible = compute_scheduling(candidates, c, target_date, commodity, estimated_quantity)
    best, alts, rule_wait, reason = get_recommendation(eligible)
    if not best:
        return {"recommended_slot": None, "expected_wait_minutes": 0, "reason": reason, "alternatives": [], "ai_used": False}
    # AI-enhanced wait for best slot
    hour = best.slot.start_time.hour if best.slot.start_time else 10
    centre_load = best.slot.booked / best.slot.capacity if best.slot.capacity else 0
    # farmers ahead approx = best slot booked + queue
    from app.models.queue import QueueToken, QueueStatus
    farmers_ahead = db.query(QueueToken).filter(QueueToken.centre_id == centre_id, QueueToken.status.in_([QueueStatus.WAITING.value, QueueStatus.CALLED.value])).count()
    ai_res = predict_waiting_time(farmers_ahead, c.avg_processing_minutes, c.active_counters, commodity, estimated_quantity, hour, centre_load)
    # Use AI wait but keep rule as fallback
    expected_wait = ai_res["predicted_wait"] if ai_res["used_ai"] else rule_wait
    explain = ai_res["reason"] if ai_res["used_ai"] else reason
    # Add centre load prediction
    load_res = predict_centre_load(centre_id, target_date, None, farmers_ahead, centre_load)
    def to_out(slot):
        return {"id": slot.id, "centre_id": slot.centre_id, "date": slot.date, "start_time": slot.start_time, "end_time": slot.end_time, "capacity": slot.capacity, "booked": slot.booked, "available": slot.capacity - slot.booked, "status": slot.status}
    return {
        "recommended_slot": to_out(best.slot),
        "expected_wait_minutes": expected_wait,
        "reason": explain,
        "alternatives": [to_out(a.slot) for a in alts],
        "ai_used": ai_res["used_ai"],
        "ai_model": ai_res["model_info"],
        "rule_wait": rule_wait,
        "centre_load": load_res,
    }

@router.get("/demand-forecast")
def demand_forecast(centre_id: str = Query(None), commodity: str = Query(None), days: int = Query(7, ge=1, le=14), db: Session = Depends(get_db)):
    """Lightweight demand forecast per centre/commodity/date using historical bookings + fallback baseline 20 bookings/day."""
    from app.models.booking import Booking
    from datetime import timedelta, date as _date
    today = _date.today()
    out=[]
    for i in range(days):
        d = today + timedelta(days=i)
        q = db.query(Booking)
        if centre_id:
            q = q.filter(Booking.centre_id==centre_id)
        if commodity:
            # handle multi-commodity JSON: check commodity_name like or commodities_json like
            q = q.filter((Booking.commodity_name.contains(commodity)) | (Booking.commodities_json.contains(commodity) if hasattr(Booking, 'commodities_json') else False))
        # historical avg for same weekday past 4 weeks
        hist=[]
        for w in range(1,5):
            hd = d - timedelta(days=w*7)
            cnt = db.query(Booking).filter(Booking.date==hd)
            if centre_id:
                cnt = cnt.filter(Booking.centre_id==centre_id)
            if commodity:
                cnt = cnt.filter(Booking.commodity_name.contains(commodity))
            hist.append(cnt.count())
        avg_hist = sum(hist)/len(hist) if hist else 0
        # fallback baseline 15-25
        if avg_hist < 5:
            baseline = 18
            predicted = baseline
            reason = "Baseline 18 (insufficient history, clearly marked fallback)"
            confidence = "low"
        else:
            predicted = int(avg_hist)
            reason = f"Avg {avg_hist:.1f} same weekday past 4 weeks"
            confidence = "medium"
        out.append({"date": d.isoformat(), "predicted_bookings": predicted, "reason": reason, "confidence": confidence, "historical_avg": avg_hist})
    return {"centre_id": centre_id, "commodity": commodity, "forecast": out, "model_info": "4-week weekday avg fallback baseline 18"}

@router.get("/anomalies/{centre_id}")
def anomalies(centre_id: str, db: Session = Depends(get_db)):
    """Lightweight anomaly detection: queue growth, processing delay, booking spike, capacity."""
    from app.models.queue import QueueToken, QueueStatus
    from app.models.booking import Booking
    from datetime import timedelta, date as _date, datetime, timezone
    c = db.query(ProcurementCentre).filter(ProcurementCentre.id==centre_id).first()
    if not c:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    alerts=[]
    # queue growth: compare waiting now vs 1 hour ago via audit? use current vs avg 7d
    qsize = db.query(QueueToken).filter(QueueToken.centre_id==centre_id, QueueToken.status.in_([QueueStatus.WAITING.value, QueueStatus.CALLED.value])).count()
    # booking spike today vs avg 7d
    today = _date.today()
    today_cnt = db.query(Booking).filter(Booking.centre_id==centre_id, Booking.date==today).count()
    hist7 = [db.query(Booking).filter(Booking.centre_id==centre_id, Booking.date==today - timedelta(days=i)).count() for i in range(1,8)]
    avg7 = sum(hist7)/7 if hist7 else 5
    if avg7>0 and today_cnt > avg7*1.8:
        alerts.append({"type":"booking_spike","severity":"high","message":f"Today {today_cnt} vs avg {avg7:.1f} 7d (+80%)","reason":"Unusual booking spike, check capacity"})
    # queue >15
    if qsize > 20:
        alerts.append({"type":"queue_high","severity":"high","message":f"Queue {qsize} unusually high","reason":"Queue growth anomaly"})
    # capacity
    from app.models.slot import Slot
    slots = db.query(Slot).filter(Slot.centre_id==centre_id, Slot.date==today).all()
    total = sum(s.capacity for s in slots)
    used = sum(s.booked for s in slots)
    occ = used/total if total else 0
    if occ > 0.9:
        alerts.append({"type":"capacity_high","severity":"medium","message":f"Capacity {occ:.0%} today","reason":"Near full, risk of overload"})
    # processing delay: any token in PROCESSING >10 min?
    from app.models.queue import QueueEvent
    proc_tokens = db.query(QueueToken).filter(QueueToken.centre_id==centre_id, QueueToken.status==QueueStatus.PROCESSING.value).all()
    for qt in proc_tokens:
        # check last event time
        evt = db.query(QueueEvent).filter(QueueEvent.token_id==qt.id, QueueEvent.to_status==QueueStatus.PROCESSING.value).order_by(QueueEvent.created_at.desc()).first()
        if evt and (datetime.now(timezone.utc) - evt.created_at).total_seconds() > 600:
            alerts.append({"type":"processing_delay","severity":"medium","message":f"Token {qt.token_number} processing >10 min","reason":"Processing delay anomaly"})
            break
    if not alerts:
        alerts.append({"type":"normal","severity":"info","message":"No anomalies detected","reason":"Centre operating within normal ranges"})
    return {"centre_id":centre_id,"anomalies":alerts,"queue_size":qsize,"occupancy":round(occ,2),"today_bookings":today_cnt}
