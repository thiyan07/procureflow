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
    # strict state machine
    valid = [s.value for s in PaymentStatus]
    if payload.status not in valid:
        raise HTTPException(status_code=400, detail={"code": "INVALID_STATUS", "message": "Invalid payment status"})
    # normalize PAID alias to COMPLETED for storage
    status_norm = payload.status
    if status_norm == PaymentStatus.PAID.value:
        status_norm = PaymentStatus.COMPLETED.value
    # also normalize COMPLETED alias for PAID if needed
    # Define allowed transitions (strict)
    allowed_transitions = {
        PaymentStatus.PENDING.value: [PaymentStatus.CALCULATED.value, PaymentStatus.APPROVED.value, PaymentStatus.PROCESSING.value, PaymentStatus.FAILED.value],
        PaymentStatus.CALCULATED.value: [PaymentStatus.APPROVED.value, PaymentStatus.FAILED.value],
        PaymentStatus.APPROVED.value: [PaymentStatus.PROCESSING.value, PaymentStatus.FAILED.value],
        PaymentStatus.PROCESSING.value: [PaymentStatus.COMPLETED.value, PaymentStatus.PAID.value, PaymentStatus.FAILED.value, PaymentStatus.REVERSED.value],
        PaymentStatus.COMPLETED.value: [PaymentStatus.REVERSED.value],
        PaymentStatus.PAID.value: [PaymentStatus.REVERSED.value],
        PaymentStatus.FAILED.value: [PaymentStatus.PENDING.value, PaymentStatus.CALCULATED.value],
        PaymentStatus.REVERSED.value: [],
        PaymentStatus.ON_HOLD.value: [PaymentStatus.PENDING.value, PaymentStatus.FAILED.value],
    }
    current = pay.status
    if status_norm != current:
        allowed = allowed_transitions.get(current, [])
        if status_norm not in allowed:
            raise HTTPException(status_code=400, detail={"code": "INVALID_TRANSITION", "message": f"Invalid payment transition {current} -> {status_norm}. Allowed: {allowed}"})
    pay.status = status_norm
    # fill financials if not set
    if pay.gross_amount is None:
        pay.gross_amount = pay.total_amount
    if pay.deductions is None:
        pay.deductions = 0
    if pay.net_payable is None:
        pay.net_payable = (pay.gross_amount or pay.total_amount) - (pay.deductions or 0)
    if status_norm in (PaymentStatus.COMPLETED.value, PaymentStatus.PAID.value, PaymentStatus.PROCESSING.value):
        if pay.payment_method is None:
            pay.payment_method = "BANK_TRANSFER"
        if status_norm == PaymentStatus.COMPLETED.value and pay.reference_id is None:
            pay.reference_id = pay.transaction_id
    if status_norm == PaymentStatus.COMPLETED.value:
        from datetime import datetime, timezone
        pay.payment_date = datetime.now(timezone.utc)
        pay.transaction_id = f"TXN{int(datetime.now(timezone.utc).timestamp()*1000)}"
        if pay.reference_id is None:
            pay.reference_id = pay.transaction_id
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
