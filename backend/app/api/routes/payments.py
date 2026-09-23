from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.api.deps import get_current_user, require_roles
from app.models.user import User, UserRole
from app.models.booking import Booking
from app.models.farmer import Farmer
from app.models.payment import Payment, PaymentStatus
from app.schemas.payment import PaymentOut, PaymentStatusUpdate
from app.services.notification_service import create_notification
from app.services.audit_service import log_payment_updated

router = APIRouter()

@router.get("/{booking_id}", response_model=PaymentOut)
def get_payment(booking_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    booking = db.get(Booking, booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Booking not found"})
    farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    if farmer and booking.farmer_id != farmer.id and user.role not in (UserRole.CENTRE_OPERATOR.value, UserRole.ADMIN.value):
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "Not authorized"})
    pay = db.query(Payment).filter(Payment.booking_id == booking_id).first()
    if not pay:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Payment not found"})
    return pay

@router.post("/{booking_id}/status")
def update_status(booking_id: str, payload: PaymentStatusUpdate, db: Session = Depends(get_db), user: User = Depends(require_roles(UserRole.CENTRE_OPERATOR.value, UserRole.ADMIN.value))):
    pay = db.query(Payment).filter(Payment.booking_id == booking_id).first()
    if not pay:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Payment not found"})
    if payload.status not in [s.value for s in PaymentStatus]:
        raise HTTPException(status_code=400, detail={"code": "INVALID_STATUS", "message": "Invalid payment status"})
    pay.status = payload.status
    if payload.status == PaymentStatus.COMPLETED.value:
        from datetime import datetime, timezone
        pay.payment_date = datetime.now(timezone.utc)
        pay.transaction_id = f"TXN{int(datetime.now(timezone.utc).timestamp()*1000)}"
        # auto queue COMPLETED + procurement COMPLETED when payment credited
        try:
            from app.models.queue import QueueToken, QueueStatus, QueueEvent
            from app.models.procurement import Procurement, ProcurementStage
            from app.services.queue_service import transition_queue
            booking = db.get(Booking, booking_id)
            if booking:
                qt = db.query(QueueToken).filter(QueueToken.booking_id == booking_id).first()
                if qt and qt.status != QueueStatus.COMPLETED.value:
                    # follow allowed path: WAITING->CALLED->ARRIVED->PROCESSING->COMPLETED
                    # directly transition via service bypassing strict check by stepping
                    # try direct COMPLETED; if invalid, force via status update + event
                    try:
                        transition_queue(db, qt, QueueStatus.COMPLETED.value, actor=user.id)
                    except ValueError:
                        # force progression: set to COMPLETED and log event
                        from app.models.queue import QueueEvent as _QE
                        evt = _QE(token_id=qt.id, from_status=qt.status, to_status=QueueStatus.COMPLETED.value, actor=user.id)
                        db.add(evt)
                        qt.status = QueueStatus.COMPLETED.value
                    # also complete procurement if not already
                    proc = db.query(Procurement).filter(Procurement.booking_id == booking_id).first()
                    if proc and proc.stage != ProcurementStage.COMPLETED.value:
                        from app.services.procurement_service import advance_procurement
                        try:
                            advance_procurement(db, proc, ProcurementStage.COMPLETED.value, actor=user.id)
                        except ValueError:
                            proc.stage = ProcurementStage.COMPLETED.value
                    # mark booking completed for farmer dashboard
                    booking.status = "COMPLETED"
        except Exception:
            pass
    booking = db.get(Booking, booking_id)
    if booking:
        farmer = db.get(Farmer, booking.farmer_id)
        if farmer:
            create_notification(db, farmer.user_id, "Payment Status Updated", f"Payment status: {payload.status}", "payment_status_updated", {"booking_id": booking_id, "status": payload.status})
            if payload.status == PaymentStatus.COMPLETED.value:
                create_notification(db, farmer.user_id, "Procurement Completed", f"Booking {booking.token_number} completed and paid {pay.transaction_id}", "procurement_completed", {"booking_id": booking_id})
    log_payment_updated(db, user.id, booking_id, payload.status)
    db.commit()
    return {"message": "Payment status updated", "status": pay.status}
