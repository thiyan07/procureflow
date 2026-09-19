from fastapi import APIRouter, Depends, Query
from datetime import date, timedelta
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.db.session import get_db
from app.models.booking import Booking
from app.models.queue import QueueToken, QueueStatus
from app.models.procurement import Procurement, ProcurementStage
from app.models.payment import Payment
from app.models.procurement_centre import ProcurementCentre

router = APIRouter()

@router.get("/farmer/{farmer_id}")
def farmer_analytics(farmer_id: str, db: Session = Depends(get_db)):
    bookings = db.query(Booking).filter(Booking.farmer_id == farmer_id).all()
    total = len(bookings)
    completed = db.query(Procurement).join(Booking, Procurement.booking_id == Booking.id).filter(Booking.farmer_id == farmer_id, Procurement.stage == ProcurementStage.COMPLETED.value).count()
    payments = db.query(Payment).join(Booking, Payment.booking_id == Booking.id).filter(Booking.farmer_id == farmer_id).all()
    total_amount = sum(p.total_amount for p in payments if p.status == "COMPLETED")
    return {"farmer_id": farmer_id, "total_bookings": total, "completed_procurements": completed, "payments": [{"commodity": p.commodity, "amount": p.total_amount, "status": p.status} for p in payments], "total_amount_received": total_amount}

@router.get("/operator/{centre_id}")
def operator_analytics(centre_id: str, days: int = Query(7, ge=1, le=30), db: Session = Depends(get_db)):
    # daily bookings last N days
    today = date.today()
    daily = []
    for i in range(days):
        d = today - timedelta(days=i)
        cnt = db.query(Booking).filter(Booking.centre_id == centre_id, Booking.date == d).count()
        completed = db.query(QueueToken).filter(QueueToken.centre_id == centre_id, QueueToken.status == QueueStatus.COMPLETED.value).count()  # simplified
        daily.append({"date": d.isoformat(), "bookings": cnt})
    daily.reverse()
    c = db.get(ProcurementCentre, centre_id)
    waiting = db.query(QueueToken).filter(QueueToken.centre_id == centre_id, QueueToken.status == QueueStatus.WAITING.value).count()
    processing = db.query(QueueToken).filter(QueueToken.centre_id == centre_id, QueueToken.status == QueueStatus.PROCESSING.value).count()
    noshow = db.query(QueueToken).filter(QueueToken.centre_id == centre_id, QueueToken.status == QueueStatus.NO_SHOW.value).count()
    # real avg_wait from actual queue: farmers_ahead * avg_processing / active_counters
    if c:
        from app.services.scheduling_service import calculate_wait
        avg_wait = calculate_wait(waiting, c.avg_processing_minutes, c.active_counters)
    else:
        avg_wait = 5
    return {"centre_id": centre_id, "daily_bookings": daily, "waiting": waiting, "processing": processing, "noshow": noshow, "avg_wait": avg_wait, "centre": c.name if c else centre_id}

@router.get("/management")
def management_analytics(db: Session = Depends(get_db)):
    centres = db.query(ProcurementCentre).all()
    out = []
    for c in centres:
        total = db.query(Booking).filter(Booking.centre_id == c.id).count()
        completed = db.query(QueueToken).filter(QueueToken.centre_id == c.id, QueueToken.status == QueueStatus.COMPLETED.value).count()
        out.append({"centre_id": c.id, "centre_name": c.name, "total_bookings": total, "completed": completed, "active_counters": c.active_counters, "avg_processing": c.avg_processing_minutes})
    # demand trends: bookings per day last 7 days all centres
    today = date.today()
    trend = []
    for i in range(7):
        d = today - timedelta(days=i)
        cnt = db.query(Booking).filter(Booking.date == d).count()
        trend.append({"date": d.isoformat(), "bookings": cnt})
    trend.reverse()
    # peak periods: slots with most bookings today
    from app.models.slot import Slot
    peak = db.query(Slot.date, Slot.start_time, func.sum(Slot.booked)).group_by(Slot.date, Slot.start_time).order_by(func.sum(Slot.booked).desc()).limit(5).all()
    peaks = [{"time": str(p[1]), "total_booked": p[2]} for p in peak]
    return {"centres": out, "demand_trend_7d": trend, "peak_periods": peaks}
