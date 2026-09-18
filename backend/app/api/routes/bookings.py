from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import select
from datetime import date, datetime, timezone
from app.db.session import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.farmer import Farmer
from app.models.slot import Slot
from app.models.booking import Booking, BookingStatus
from app.models.procurement_centre import ProcurementCentre
from app.models.procurement import Procurement, ProcurementStage
from app.models.payment import Payment
from app.models.queue import QueueToken, QueueEvent, QueueStatus, CentreQueueState
from app.schemas.booking import BookingCreate, BookingOut
from app.services.notification_service import send_slot_confirmed
from app.core.config import get_settings

router = APIRouter()
settings = get_settings()

def _farmer_for_user(db: Session, user: User) -> Farmer:
    farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    if not farmer:
        raise HTTPException(status_code=400, detail={"code": "FARMER_NOT_FOUND", "message": "Create farmer profile first"})
    return farmer

@router.post("", response_model=BookingOut, status_code=201)
def create_booking(payload: BookingCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    farmer = _farmer_for_user(db, user)
    # RULE 8: duplicate active booking check
    active = db.query(Booking).filter(Booking.farmer_id == farmer.id, Booking.status == BookingStatus.CONFIRMED.value).first()
    if active:
        raise HTTPException(status_code=400, detail={"code": "DUPLICATE_BOOKING", "message": "Active booking already exists. Cancel first."})

    centre = db.get(ProcurementCentre, payload.centre_id)
    if not centre:
        raise HTTPException(status_code=404, detail={"code": "CENTRE_NOT_FOUND", "message": "Centre not found"})
    if centre.status == "Closed" or not centre.is_active:
        raise HTTPException(status_code=400, detail={"code": "CENTRE_CLOSED", "message": "Centre is closed"})

    # Transaction with select for update to prevent race (atomic: check->reserve->create->token)
    try:
        slot = db.query(Slot).filter(Slot.id == payload.slot_id).with_for_update().first()
        if not slot:
            raise HTTPException(status_code=404, detail={"code": "SLOT_NOT_FOUND", "message": "Slot not found"})
        if slot.centre_id != payload.centre_id:
            raise HTTPException(status_code=400, detail={"code": "SLOT_MISMATCH", "message": "Slot does not belong to centre"})
        # past check
        slot_dt = datetime.combine(slot.date, slot.start_time, tzinfo=timezone.utc)
        if slot_dt < datetime.now(timezone.utc):
            raise HTTPException(status_code=400, detail={"code": "SLOT_PAST", "message": "Cannot book slot in the past"})
        if slot.booked >= slot.capacity:
            raise HTTPException(status_code=409, detail={"code": "SLOT_FULL", "message": "This slot is no longer available."})
        # safety: double check availability
        slot.booked += 1
        if slot.booked >= slot.capacity:
            slot.status = "FULL"
        db.flush()

        # Generate queue token unique per centre/date - lock row to prevent duplicate token numbers
        date_str = slot.date.isoformat()
        qstate = db.query(CentreQueueState).filter(CentreQueueState.centre_id==payload.centre_id, CentreQueueState.date==date_str).with_for_update().first()
        if not qstate:
            qstate = CentreQueueState(centre_id=payload.centre_id, date=date_str, current_ordinal=0, next_ordinal=1)
            db.add(qstate)
            db.flush()
        ordinal = qstate.next_ordinal
        qstate.next_ordinal += 1
        db.flush()
        token_number = f"P{ordinal}"
        # Create booking + queue token
        booking = Booking(
            farmer_id=farmer.id,
            centre_id=payload.centre_id,
            slot_id=slot.id,
            commodity_name=payload.commodity,
            estimated_quantity=payload.estimated_quantity,
            token_number=token_number,
            date=slot.date,
            status=BookingStatus.CONFIRMED.value,
        )
        db.add(booking)
        db.flush()
        # queue token
        # estimate wait
        from app.services.scheduling_service import calculate_wait
        farmers_ahead = db.query(QueueToken).filter(QueueToken.centre_id == payload.centre_id, QueueToken.status.in_([QueueStatus.WAITING.value, QueueStatus.CALLED.value])).count()
        wait = calculate_wait(farmers_ahead, centre.avg_processing_minutes, centre.active_counters)
        qt = QueueToken(centre_id=payload.centre_id, booking_id=booking.id, token_number=token_number, position=ordinal, status=QueueStatus.WAITING.value, estimated_wait_minutes=wait)
        db.add(qt)
        db.flush()
        evt = QueueEvent(token_id=qt.id, from_status=None, to_status=QueueStatus.WAITING.value, actor=user.id)
        db.add(evt)
        # procurement
        proc = Procurement(booking_id=booking.id, stage=ProcurementStage.BOOKING_CONFIRMED.value)
        db.add(proc)
        # payment placeholder
        rate = 2200  # default; could lookup commodity
        from app.models.commodity import Commodity
        comm = db.query(Commodity).filter(Commodity.name == payload.commodity).first()
        if comm:
            rate = comm.rate_per_quintal
        payment = Payment(booking_id=booking.id, commodity=payload.commodity, quantity_quintal=payload.estimated_quantity, rate_per_quintal=rate, total_amount=payload.estimated_quantity * rate, status="PENDING")
        db.add(payment)
        db.flush()
        # notification (before commit to ensure record)
        send_slot_confirmed(db, user.id, token_number, centre.name, f"{slot.start_time}-{slot.end_time}", booking.id)
        db.commit()
    except HTTPException:
        db.rollback()
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail={"code": "BOOKING_FAILED", "message": str(e)})

    # Build response
    db.refresh(booking)
    qt = db.query(QueueToken).filter(QueueToken.booking_id == booking.id).first()
    return BookingOut(
        id=booking.id, farmer_id=booking.farmer_id, centre_id=booking.centre_id, slot_id=booking.slot_id,
        commodity_name=booking.commodity_name, estimated_quantity=booking.estimated_quantity, token_number=booking.token_number,
        queue_token_id=qt.id if qt else None, date=booking.date, status=booking.status, created_at=booking.created_at,
        centre_name=centre.name, slot_start=str(slot.start_time), slot_end=str(slot.end_time),
        queue_position=qt.position if qt else None, estimated_wait=qt.estimated_wait_minutes if qt else None
    )

@router.get("", response_model=list[BookingOut])
def list_bookings(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    farmer = _farmer_for_user(db, user)
    bookings = db.query(Booking).filter(Booking.farmer_id == farmer.id).order_by(Booking.created_at.desc()).all()
    out = []
    for b in bookings:
        qt = db.query(QueueToken).filter(QueueToken.booking_id == b.id).first()
        out.append(BookingOut(id=b.id, farmer_id=b.farmer_id, centre_id=b.centre_id, slot_id=b.slot_id, commodity_name=b.commodity_name, estimated_quantity=b.estimated_quantity, token_number=b.token_number, queue_token_id=qt.id if qt else None, date=b.date, status=b.status, created_at=b.created_at))
    return out

@router.get("/{booking_id}", response_model=BookingOut)
def get_booking(booking_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    booking = db.get(Booking, booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Booking not found"})
    # farmer can only view own unless operator/admin
    if booking.farmer_id:
        farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
        if farmer and booking.farmer_id == farmer.id:
            pass
        elif user.role in ("CENTRE_OPERATOR", "ADMIN"):
            pass
        else:
            raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "Not authorized"})
    qt = db.query(QueueToken).filter(QueueToken.booking_id == booking.id).first()
    return BookingOut(id=booking.id, farmer_id=booking.farmer_id, centre_id=booking.centre_id, slot_id=booking.slot_id, commodity_name=booking.commodity_name, estimated_quantity=booking.estimated_quantity, token_number=booking.token_number, queue_token_id=qt.id if qt else None, date=booking.date, status=booking.status, created_at=booking.created_at)

@router.post("/{booking_id}/cancel")
def cancel_booking(booking_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    booking = db.get(Booking, booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Booking not found"})
    farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    if not farmer or booking.farmer_id != farmer.id:
        if user.role not in ("ADMIN", "CENTRE_OPERATOR"):
            raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "Not authorized"})
    if booking.status == BookingStatus.CANCELLED.value:
        raise HTTPException(status_code=400, detail={"code": "ALREADY_CANCELLED", "message": "Already cancelled"})
    # Transactionally free slot
    slot = db.query(Slot).filter(Slot.id == booking.slot_id).with_for_update().first()
    if slot and slot.booked > 0:
        slot.booked -= 1
        slot.status = "AVAILABLE"
    booking.status = BookingStatus.CANCELLED.value
    # update queue token
    qt = db.query(QueueToken).filter(QueueToken.booking_id == booking.id).first()
    if qt and qt.status != QueueStatus.CANCELLED.value:
        evt = QueueEvent(token_id=qt.id, from_status=qt.status, to_status=QueueStatus.CANCELLED.value, actor=user.id)
        db.add(evt)
        qt.status = QueueStatus.CANCELLED.value
    db.commit()
    return {"message": "Booking cancelled", "booking_id": booking_id}
