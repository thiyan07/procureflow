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
