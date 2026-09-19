from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.api.deps import get_current_user, require_roles
from app.models.user import User, UserRole
from app.models.booking import Booking
from app.models.farmer import Farmer
from app.models.procurement import Procurement, ProcurementStage, Weighment, QualityCheck, ProcurementEvent
from app.models.procurement_centre import ProcurementCentre
from app.models.slot import Slot
from app.schemas.procurement import ProcurementOut, ProcurementAdvanceRequest, TimelineStepOut
from app.services.procurement_service import advance_procurement
from app.services.notification_service import create_notification
from app.services.audit_service import log_procurement_completed

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
        log_procurement_completed(db, user.id, booking_id, payload.to_stage)
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

# Weighment — record actual quantity
from pydantic import BaseModel as _BM
class WeighmentCreate(_BM):
    gross_weight: float | None = None
    net_weight: float
    notes: str | None = None

@router.post("/{booking_id}/weighment")
def record_weighment(booking_id: str, payload: WeighmentCreate, db: Session = Depends(get_db), user: User = Depends(require_roles(UserRole.CENTRE_OPERATOR.value, UserRole.ADMIN.value))):
    proc = db.query(Procurement).filter(Procurement.booking_id == booking_id).first()
    if not proc:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Procurement not found"})
    # validate
    if payload.net_weight <= 0 or payload.net_weight > 500:
        raise HTTPException(status_code=400, detail={"code": "INVALID_WEIGHT", "message": "Net weight must be 0-500 quintal"})
    if payload.gross_weight is not None and payload.gross_weight < payload.net_weight:
        raise HTTPException(status_code=400, detail={"code": "INVALID_WEIGHT", "message": "Gross must be >= net"})
    # ensure stage is ARRIVED or WEIGHMENT
    if proc.stage not in [ProcurementStage.ARRIVED.value, ProcurementStage.WEIGHMENT.value, ProcurementStage.BOOKING_CONFIRMED.value]:
        # allow but log
        pass
    # upsert weighment
    w = db.query(Weighment).filter(Weighment.procurement_id == proc.id).first()
    if not w:
        w = Weighment(procurement_id=proc.id, gross_weight=payload.gross_weight, net_weight=payload.net_weight, operator_id=user.id)
        db.add(w)
    else:
        w.gross_weight = payload.gross_weight
        w.net_weight = payload.net_weight
        w.operator_id = user.id
    from datetime import datetime, timezone
    w.weighment_time = datetime.now(timezone.utc)
    # advance to WEIGHMENT if not already
    try:
        if proc.stage == ProcurementStage.ARRIVED.value:
            advance_procurement(db, proc, ProcurementStage.WEIGHMENT.value, actor=user.id)
        elif proc.stage == ProcurementStage.BOOKING_CONFIRMED.value:
            advance_procurement(db, proc, ProcurementStage.ARRIVED.value, actor=user.id)
            advance_procurement(db, proc, ProcurementStage.WEIGHMENT.value, actor=user.id)
    except ValueError:
        pass
    from app.services.audit_service import audit
    audit(db, user.id, "weighment_recorded", "procurement", booking_id, f"net {payload.net_weight} gross {payload.gross_weight}")
    db.commit()
    return {"message": "Weighment recorded", "stage": proc.stage, "net_weight": w.net_weight}

class QualityCreate(_BM):
    grade: str | None = None  # A/B/C
    moisture_percent: float | None = None
    remarks: str | None = None

@router.post("/{booking_id}/quality")
def record_quality(booking_id: str, payload: QualityCreate, db: Session = Depends(get_db), user: User = Depends(require_roles(UserRole.CENTRE_OPERATOR.value, UserRole.ADMIN.value))):
    proc = db.query(Procurement).filter(Procurement.booking_id == booking_id).first()
    if not proc:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Procurement not found"})
    if payload.moisture_percent is not None and (payload.moisture_percent < 0 or payload.moisture_percent > 30):
        raise HTTPException(status_code=400, detail={"code": "INVALID_MOISTURE", "message": "Moisture 0-30% only"})
    if payload.grade and payload.grade not in ["A","B","C"]:
        raise HTTPException(status_code=400, detail={"code": "INVALID_GRADE", "message": "Grade must be A/B/C"})
    qc = db.query(QualityCheck).filter(QualityCheck.procurement_id == proc.id).first()
    if not qc:
        qc = QualityCheck(procurement_id=proc.id, grade=payload.grade, moisture_percent=payload.moisture_percent, remarks=payload.remarks)
        db.add(qc)
    else:
        qc.grade = payload.grade or qc.grade
        qc.moisture_percent = payload.moisture_percent if payload.moisture_percent is not None else qc.moisture_percent
        qc.remarks = payload.remarks or qc.remarks
    from datetime import datetime, timezone
    qc.checked_at = datetime.now(timezone.utc)
    try:
        if proc.stage == ProcurementStage.WEIGHMENT.value:
            advance_procurement(db, proc, ProcurementStage.QUALITY_CHECK.value, actor=user.id)
    except ValueError:
        pass
    from app.services.audit_service import audit
    audit(db, user.id, "quality_recorded", "procurement", booking_id, f"grade {payload.grade} moisture {payload.moisture_percent}")
    db.commit()
    return {"message": "Quality recorded", "stage": proc.stage, "grade": qc.grade}

@router.get("/{booking_id}/receipt")
def get_receipt(booking_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    booking = db.get(Booking, booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Booking not found"})
    farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    if farmer and booking.farmer_id != farmer.id and user.role not in (UserRole.CENTRE_OPERATOR.value, UserRole.ADMIN.value):
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "Not authorized"})
    proc = db.query(Procurement).filter(Procurement.booking_id == booking_id).first()
    from app.models.payment import Payment
    payment = db.query(Payment).filter(Payment.booking_id == booking_id).first()
    weighment = db.query(Weighment).filter(Weighment.procurement_id == proc.id).first() if proc else None
    quality = db.query(QualityCheck).filter(QualityCheck.procurement_id == proc.id).first() if proc else None
    centre = db.get(ProcurementCentre, booking.centre_id) if booking else None
    farmer_obj = db.get(Farmer, booking.farmer_id) if booking else None
    # reference number lightweight: booking token + date
    ref = f"REC-{booking.token_number}-{booking.date.isoformat()}"
    return {
        "reference": ref,
        "farmer": {"name": farmer_obj.full_name if farmer_obj else None, "farmer_id": farmer_obj.farmer_id if farmer_obj else None, "village": farmer_obj.village if farmer_obj else None},
        "centre": {"name": centre.name if centre else None, "location": centre.location if centre else None, "district": centre.district if centre else None},
        "date": str(booking.date),
        "slot": str(db.get(Slot, booking.slot_id).start_time) if booking.slot_id else None,
        "commodities": booking.commodities if hasattr(booking, 'commodities') else [{"commodity": booking.commodity_name, "quantity": booking.estimated_quantity}],
        "weighment": {"gross": weighment.gross_weight if weighment else None, "net": weighment.net_weight if weighment else None, "time": weighment.weighment_time.isoformat() if weighment and weighment.weighment_time else None} if proc else None,
        "quality": {"grade": quality.grade if quality else None, "moisture": quality.moisture_percent if quality else None, "remarks": quality.remarks if quality else None} if proc else None,
        "procurement": {"stage": proc.stage if proc else None, "booking_id": booking_id},
        "payment": {"status": payment.status if payment else None, "amount": payment.total_amount if payment else None, "transaction_id": payment.transaction_id if payment else None, "date": payment.payment_date.isoformat() if payment and payment.payment_date else None} if payment else None,
    }
