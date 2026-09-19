from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.booking import Booking
from app.models.queue import QueueToken
from app.models.payment import Payment
from app.models.procurement import Procurement
from app.services.assistant_service import answer

router = APIRouter()

@router.post("/ask")
def ask_assistant(query: str, language_code: str = "en", db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    # Gather context for deterministic answers
    from app.models.farmer import Farmer
    farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    ctx = {}
    if farmer:
        booking = db.query(Booking).filter(Booking.farmer_id == farmer.id, Booking.status == "CONFIRMED").order_by(Booking.created_at.desc()).first()
        if booking:
            ctx["token"] = booking.token_number
            ctx["centre"] = booking.centre_id
            ctx["slot"] = str(booking.date) + " " + (str(db.get(QueueToken, booking.id)) if False else "")
            # queue
            qt = db.query(QueueToken).filter(QueueToken.booking_id == booking.id).first()
            if qt:
                # farmers ahead
                from app.models.queue import QueueStatus
                ahead = db.query(QueueToken).filter(QueueToken.centre_id == qt.centre_id, QueueToken.position < qt.position, QueueToken.status.in_([QueueStatus.WAITING.value, QueueStatus.CALLED.value])).count()
                ctx["farmers_ahead"] = ahead
                ctx["wait"] = qt.estimated_wait_minutes
            # payment
            pay = db.query(Payment).filter(Payment.booking_id == booking.id).first()
            if pay:
                ctx["payment_status"] = pay.status
                ctx["amount"] = pay.total_amount
            # procurement
            proc = db.query(Procurement).filter(Procurement.booking_id == booking.id).first()
            if proc:
                ctx["proc_stage"] = proc.stage
            # slot time
            from app.models.slot import Slot
            slot = db.get(Slot, booking.slot_id)
            if slot:
                ctx["slot"] = f"{slot.start_time}-{slot.end_time} on {slot.date}"
                ctx["centre"] = db.get(db.query(booking).first().centre_id) if False else booking.centre_id
    ans = answer(query, language_code, ctx)
    return {"answer": ans, "language": language_code, "context_used": bool(ctx)}

@router.get("/faq")
def faq(language_code: str = "en"):
    from app.services.assistant_service import FAQ
    return FAQ.get(language_code, FAQ["en"])
