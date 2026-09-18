from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.api.deps import get_current_user, require_roles
from app.models.user import User, UserRole
from app.models.booking import Booking
from app.models.farmer import Farmer
from app.models.procurement import Procurement, ProcurementStage, Weighment, QualityCheck, ProcurementEvent
from app.schemas.procurement import ProcurementOut, ProcurementAdvanceRequest, TimelineStepOut
from app.services.procurement_service import advance_procurement
from app.services.notification_service import create_notification

router = APIRouter()

STAGE_TITLES = {
    ProcurementStage.BOOKING_CONFIRMED.value: ("Booking Confirmed", "Slot confirmed"),
    ProcurementStage.ARRIVED.value: ("Arrived at Centre", "Checked-in at gate"),
    ProcurementStage.WEIGHMENT.value: ("Weighment", "Weighment in progress"),
    ProcurementStage.QUALITY_CHECK.value: ("Quality Check", "Grading and quality check"),
    ProcurementStage.PROCUREMENT.value: ("Procurement", "Procurement approval"),
    ProcurementStage.COMPLETED.value: ("Completed", "Procurement completed"),
}

@router.get("/{booking_id}", response_model=ProcurementOut)
def get_procurement(booking_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    booking = db.get(Booking, booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Booking not found"})
    farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    if farmer and booking.farmer_id != farmer.id and user.role not in (UserRole.CENTRE_OPERATOR.value, UserRole.ADMIN.value):
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "Not authorized"})
    proc = db.query(Procurement).filter(Procurement.booking_id == booking_id).first()
    if not proc:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Procurement not found"})
    return proc

@router.post("/{booking_id}/advance")
def advance(booking_id: str, payload: ProcurementAdvanceRequest, db: Session = Depends(get_db), user: User = Depends(require_roles(UserRole.CENTRE_OPERATOR.value, UserRole.ADMIN.value))):
    proc = db.query(Procurement).filter(Procurement.booking_id == booking_id).first()
    if not proc:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Procurement not found"})
    try:
        advance_procurement(db, proc, payload.to_stage, actor=user.id)
        booking = db.get(Booking, booking_id)
        if booking:
            farmer = db.get(Farmer, booking.farmer_id)
            if farmer:
                create_notification(db, farmer.user_id, "Procurement Updated", f"Stage changed to {payload.to_stage}", "procurement_stage_updated", {"booking_id": booking_id, "stage": payload.to_stage})
        db.commit()
    except ValueError as e:
        raise HTTPException(status_code=400, detail={"code": "INVALID_TRANSITION", "message": str(e)})
    return {"message": "Advanced", "stage": proc.stage}

@router.get("/{booking_id}/timeline", response_model=list[TimelineStepOut])
def timeline(booking_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    proc = db.query(Procurement).filter(Procurement.booking_id == booking_id).first()
    if not proc:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Procurement not found"})
    # order
    order = [s.value for s in ProcurementStage]
    try:
        idx = order.index(proc.stage)
    except ValueError:
        idx = 0
    steps = []
    events = db.query(ProcurementEvent).filter(ProcurementEvent.procurement_id == proc.id).order_by(ProcurementEvent.created_at).all()
    # map stage to event time
    stage_time = {e.to_stage: e.created_at for e in events}
    stage_time[order[0]] = proc.created_at
    for i, stage in enumerate(order):
        is_completed = i < idx
        is_current = i == idx
        title, subtitle = STAGE_TITLES.get(stage, (stage, ""))
        ts = stage_time.get(stage)
        if is_completed and not ts:
            ts = proc.created_at
        steps.append(TimelineStepOut(title=title, subtitle=subtitle, timestamp=ts if (is_completed or is_current) else None, is_completed=is_completed, is_current=is_current))
    # add payment steps as extra (not in ProcurementStage) if needed - we keep procurement only
    return steps
