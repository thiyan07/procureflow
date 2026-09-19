from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import date, datetime, timezone
from app.db.session import get_db
from app.models.procurement_centre import ProcurementCentre
from app.models.slot import Slot
from app.models.queue import CentreQueueState
from app.schemas.centre import CentreOut, CentreStatusOut
from app.services.scheduling_service import calculate_wait
from pydantic import BaseModel

router = APIRouter()

@router.get("", response_model=list[CentreOut])
def list_centres(db: Session = Depends(get_db)):
    centres = db.query(ProcurementCentre).filter(ProcurementCentre.is_active == True).all()
    return centres

@router.get("/{centre_id}", response_model=CentreOut)
def get_centre(centre_id: str, db: Session = Depends(get_db)):
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    return c

@router.get("/{centre_id}/status", response_model=CentreStatusOut)
def get_centre_status(centre_id: str, db: Session = Depends(get_db)):
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    today = date.today()
    # queue size: count queue tokens waiting/called
    from app.models.queue import QueueToken, QueueStatus
    from app.models.booking import Booking
    qsize = db.query(QueueToken).filter(QueueToken.centre_id == centre_id, QueueToken.status.in_([QueueStatus.WAITING.value, QueueStatus.CALLED.value, QueueStatus.ARRIVED.value])).count()
    # available slots today
    avail = db.query(Slot).filter(Slot.centre_id == centre_id, Slot.date == today, Slot.booked < Slot.capacity).count()
    est = calculate_wait(qsize, c.avg_processing_minutes, c.active_counters)
    is_open = c.status == "Open" and c.is_active and (c.open_time <= datetime.now().time() <= c.close_time)
    return CentreStatusOut(centre=c, is_open=is_open, current_queue_size=qsize, estimated_wait_minutes=est, active_counters=c.active_counters, available_slots=avail)

@router.get("/{centre_id}/dashboard")
def centre_dashboard(centre_id: str, db: Session = Depends(get_db)):
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    from app.models.queue import QueueToken, QueueStatus
    from app.models.procurement import Procurement, ProcurementStage
    from app.models.payment import Payment, PaymentStatus
    total = db.query(QueueToken).filter(QueueToken.centre_id==centre_id).count()
    waiting = db.query(QueueToken).filter(QueueToken.centre_id==centre_id, QueueToken.status==QueueStatus.WAITING.value).count()
    processing = db.query(QueueToken).filter(QueueToken.centre_id==centre_id, QueueToken.status==QueueStatus.PROCESSING.value).count()
    completed = db.query(QueueToken).filter(QueueToken.centre_id==centre_id, QueueToken.status==QueueStatus.COMPLETED.value).count()
    called = db.query(QueueToken).filter(QueueToken.centre_id==centre_id, QueueToken.status==QueueStatus.CALLED.value).count()
    # payments pending
    from app.models.booking import Booking
    bookings = db.query(Booking).filter(Booking.centre_id==centre_id).all()
    bids = [b.id for b in bookings]
    payment_pending = db.query(Payment).filter(Payment.booking_id.in_(bids), Payment.status==PaymentStatus.PENDING.value).count() if bids else 0
    # avg wait / processing - simple
    avg_wait = calculate_wait(waiting, c.avg_processing_minutes, c.active_counters) if waiting else 0
    return {"centre_id": centre_id, "centre_name": c.name, "today_farmers": total, "waiting": waiting, "processing": processing, "completed": completed, "called": called, "payment_pending": payment_pending, "avg_wait_minutes": avg_wait, "active_counters": c.active_counters}

class CentreUpdate(BaseModel):
    active_counters: int | None = None
    slot_capacity: int | None = None
    status: str | None = None
    is_active: bool | None = None
    closure_reason: str | None = None

@router.patch("/{centre_id}", response_model=CentreOut)
def update_centre(centre_id: str, payload: CentreUpdate, db: Session = Depends(get_db), user=Depends(__import__('app.api.deps', fromlist=['get_current_user']).get_current_user)):
    from app.models.user import User as U
    # require operator/admin
    if user.role not in ("CENTRE_OPERATOR", "ADMIN"):
        from fastapi import HTTPException as HE
        raise HE(status_code=403, detail={"code": "FORBIDDEN", "message": "Only operator/admin"})
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    if payload.active_counters is not None:
        if payload.active_counters < 0 or payload.active_counters > 10:
            raise HTTPException(status_code=400, detail={"code": "INVALID_COUNTERS", "message": "0-10"})
        c.active_counters = payload.active_counters
    if payload.slot_capacity is not None:
        if payload.slot_capacity < 5 or payload.slot_capacity > 50:
            raise HTTPException(status_code=400, detail={"code": "INVALID_CAPACITY", "message": "5-50"})
        # update today's slots capacity for centre
        today = date.today()
        for s in db.query(Slot).filter(Slot.centre_id == centre_id, Slot.date >= today).all():
            s.capacity = payload.slot_capacity
            if s.booked >= s.capacity:
                s.status = "FULL"
            else:
                s.status = "AVAILABLE"
    if payload.status is not None:
        if payload.status not in ("Open", "Closed", "Busy", "Emergency"):
            raise HTTPException(status_code=400, detail={"code": "INVALID_STATUS", "message": "Open/Closed/Busy/Emergency"})
        c.status = payload.status
        c.is_active = payload.status not in ("Closed","Emergency")
        # store closure reason if provided (lightweight: audit details + notification)
        if payload.closure_reason:
            from app.services.audit_service import audit as _audit
            _audit(db, user.id if hasattr(user,'id') else None, "centre_closure_reason", "procurement_centre", centre_id, payload.closure_reason[:200])
    if payload.is_active is not None:
        c.is_active = payload.is_active
    from app.services.audit_service import audit
    audit(db, user.id if hasattr(user,'id') else None, "centre_updated", "procurement_centre", centre_id, f"counters={payload.active_counters} cap={payload.slot_capacity} status={payload.status} reason={payload.closure_reason or ''}")
    # notify affected farmers if closed/emergency
    if payload.status in ("Closed","Emergency"):
        try:
            from app.models.booking import Booking as _B
            from app.models.queue import QueueToken as _QT, QueueStatus as _QS
            from app.services.notification_service import create_notification as _cn
            # find today's bookings for centre that are still CONFIRMED/WAITING
            today_bk = db.query(_B).filter(_B.centre_id==centre_id, _B.status=="CONFIRMED").all()
            for bk in today_bk[:5]:  # notify first 5 to avoid spam
                from app.models.farmer import Farmer as _F
                farmer = db.get(_F, bk.farmer_id)
                if farmer:
                    _cn(db, farmer.user_id, f"Centre {c.status}", f"{c.name} is {c.status.lower()}. {payload.closure_reason or ''} Alternative: consider nearby centre c2/c4.", "centre_closure", {"centre_id": centre_id, "booking_id": bk.id})
        except:
            pass
    db.commit()
    db.refresh(c)
    return c

@router.get("/{centre_id}/slot-recommendations")
def slot_recommendations(centre_id: str, date: date = Query(...), commodity_id: str | None = None, estimated_quantity: float = Query(10), db: Session = Depends(get_db)):
    from app.models.commodity import Commodity
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    commodity_name = "Paddy"
    if commodity_id:
        comm = db.get(Commodity, commodity_id)
        if comm:
            commodity_name = comm.name
        else:
            # try by name
            commodity_name = commodity_id
    slots = db.query(Slot).filter(Slot.centre_id == centre_id, Slot.date == date).all()
    from app.services.scheduling_service import SlotCandidate, compute_scheduling, get_recommendation
    candidates = [SlotCandidate(s, c) for s in slots]
    eligible = compute_scheduling(candidates, c, date, commodity_name, estimated_quantity)
    best, alts, wait, reason = get_recommendation(eligible)
    def to_out(slot):
        return {"id": slot.id, "centre_id": slot.centre_id, "date": slot.date, "start_time": slot.start_time, "end_time": slot.end_time, "capacity": slot.capacity, "booked": slot.booked, "available": slot.capacity - slot.booked, "status": slot.status}
    if not best:
        return {"recommended_slot": None, "expected_wait_minutes": 0, "reason": reason, "alternatives": [], "debug": {"eligible_count": 0}}
    return {
        "recommended_slot": to_out(best.slot),
        "expected_wait_minutes": wait,
        "reason": reason,
        "alternatives": [to_out(a.slot) for a in alts],
        "debug": best.debug,
    }

@router.get("/{centre_id}/documents")
def centre_documents(centre_id: str, commodity: str = Query("Paddy"), db: Session = Depends(get_db)):
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    # Configurable checklist — demo-oriented, clearly marked
    base = [
        {"id":"farmer_id","label":"Farmer ID (FARM-*)","required":True,"description":"TNCSC Farmer ID"},
        {"id":"aadhaar","label":"Aadhaar","required":True,"description":"Identity proof"},
        {"id":"bank_passbook","label":"Bank passbook (for payment)","required":True,"description":"Payment credit"},
        {"id":"land_doc","label":"Land document (Patta/Chitta)","required":False,"description":"If required for verification"},
    ]
    # commodity-specific
    commodity_map = {
        "Paddy": [{"id":"paddy_sample","label":"Paddy sample (500g)","required":True,"description":"For moisture/quality check"}],
        "Ragi": [{"id":"ragi_sample","label":"Ragi sample","required":True,"description":"Sample"}],
        "Maize": [{"id":"maize_sample","label":"Maize sample","required":True}],
    }
    extra = commodity_map.get(commodity, [{"id":"sample","label":f"{commodity} sample","required":True}])
    docs = base + extra
    return {"centre_id": centre_id, "commodity": commodity, "documents": docs, "note": "Demo requirements — not official government list. Bring originals + photocopy."}

@router.get("/{centre_id}/capacity")
def centre_capacity(centre_id: str, target_date: date = Query(None), db: Session = Depends(get_db)):
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    d = target_date or date.today()
    slots = db.query(Slot).filter(Slot.centre_id==centre_id, Slot.date==d).all()
    total = sum(s.capacity for s in slots)
    used = sum(s.booked for s in slots)
    remaining = total - used if total else 0
    qsize = db.query(Slot).filter(Slot.centre_id==centre_id).count()  # dummy to use func?
    from app.models.queue import QueueToken, QueueStatus
    qsize = db.query(QueueToken).filter(QueueToken.centre_id==centre_id, QueueToken.status.in_([QueueStatus.WAITING.value, QueueStatus.CALLED.value])).count()
    occupancy = used/total if total else 0
    # warnings
    warnings=[]
    if occupancy > 0.85:
        warnings.append("Centre approaching capacity (>85%)")
    if occupancy > 0.95:
        warnings.append("Centre almost full (>95%) — consider alternative centre/slot")
    if qsize > 15:
        warnings.append(f"High queue ({qsize} farmers) — expect delay")
    if c.active_counters < 2:
        warnings.append("Too few active counters — waiting time high")
    return {"centre_id":centre_id,"date":str(d),"total_capacity":total,"used_capacity":used,"remaining_capacity":remaining,"occupancy":round(occupancy,2),"current_queue":qsize,"active_counters":c.active_counters,"warnings":warnings,"status":c.status}

@router.get("/{centre_id}/alerts")
def centre_alerts(centre_id: str, db: Session = Depends(get_db)):
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    from app.models.queue import QueueToken, QueueStatus
    from app.models.booking import Booking
    from datetime import timedelta
    today = date.today()
    alerts=[]
    # queue exceeds threshold
    qsize = db.query(QueueToken).filter(QueueToken.centre_id==centre_id, QueueToken.status.in_([QueueStatus.WAITING.value, QueueStatus.CALLED.value, QueueStatus.ARRIVED.value])).count()
    if qsize > 15:
        alerts.append({"type":"queue_high","severity":"high","message":f"Queue high: {qsize} farmers waiting","action":"Add counter or extend slots"})
    # waiting time exceeds 30
    est = calculate_wait(qsize, c.avg_processing_minutes, c.active_counters)
    if est > 30:
        alerts.append({"type":"wait_high","severity":"medium","message":f"Estimated wait {est} min exceeds 30 min","action":"Activate additional counter"})
    # centre near capacity
    slots_today = db.query(Slot).filter(Slot.centre_id==centre_id, Slot.date==today).all()
    total = sum(s.capacity for s in slots_today)
    used = sum(s.booked for s in slots_today)
    occ = used/total if total else 0
    if occ > 0.8:
        alerts.append({"type":"capacity_warning","severity":"medium","message":f"Centre {int(occ*100)}% booked today","action":"Suggest alternative centre/date"})
    # too few counters
    if c.active_counters < 2:
        alerts.append({"type":"counters_low","severity":"high","message":f"Only {c.active_counters} active counters","action":"Activate maintenance counters"})
    # booking spike last 2 days vs avg 7d
    daily=[]
    for i in range(7):
        d = today - timedelta(days=i)
        cnt = db.query(Booking).filter(Booking.centre_id==centre_id, Booking.date==d).count()
        daily.append(cnt)
    avg7 = sum(daily)/7 if daily else 0
    today_cnt = daily[0] if daily else 0
    if avg7 > 0 and today_cnt > avg7*1.5:
        alerts.append({"type":"booking_spike","severity":"low","message":f"Today {today_cnt} bookings vs avg {avg7:.1f} (+50%)","action":"Monitor queue"})
    if not alerts:
        alerts.append({"type":"normal","severity":"info","message":"Centre operating normally","action":"No action"})
    return {"centre_id":centre_id,"alerts":alerts,"queue_size":qsize,"estimated_wait":est,"occupancy":round(occ,2)}
