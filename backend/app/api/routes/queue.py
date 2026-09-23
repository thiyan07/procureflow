from fastapi import APIRouter, Depends, HTTPException, WebSocket, WebSocketDisconnect
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.booking import Booking, BookingStatus
from app.models.farmer import Farmer
from app.models.procurement_centre import ProcurementCentre
from app.models.queue import QueueToken, QueueEvent, QueueStatus
from app.models.notification import Notification
from app.schemas.queue import QueueStatusOut, QueueTransitionRequest
from app.services.queue_service import transition_queue, estimate_wait
from app.services.scheduling_service import calculate_wait
from app.services.notification_service import create_notification
from app.services.audit_service import log_token_called, log_arrived, log_processing_started, audit
from app.core.config import get_settings
from datetime import date
import json
import asyncio

router = APIRouter()

# In-memory ws manager (simple)
class WSManager:
    def __init__(self):
        self.connections: dict[str, list[WebSocket]] = {}
    async def connect(self, booking_id: str, ws: WebSocket):
        await ws.accept()
        self.connections.setdefault(booking_id, []).append(ws)
    def disconnect(self, booking_id: str, ws: WebSocket):
        lst = self.connections.get(booking_id, [])
        if ws in lst:
            lst.remove(ws)
    async def broadcast(self, booking_id: str, data: dict):
        for ws in self.connections.get(booking_id, []):
            try:
                await ws.send_json(data)
            except:
                pass

ws_manager = WSManager()

@router.post("/dev/advance")
def dev_advance_centre(centre_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    """Dev-only: advance queue for a centre (call next waiting token). Modifies backend state."""
    settings = get_settings()
    if not settings.is_dev:
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "Dev only"})
    # Only operator/admin allowed
    if user.role not in ("CENTRE_OPERATOR", "ADMIN", "FARMER"):
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "Not authorized"})
    from app.models.queue import CentreQueueState
    today = date.today().isoformat()
    # Find next WAITING ordered by position
    token = db.query(QueueToken).filter(QueueToken.centre_id==centre_id, QueueToken.status==QueueStatus.WAITING.value).order_by(QueueToken.position).first()
    if not token:
        return {"message": "No waiting tokens", "centre_id": centre_id}
    try:
        transition_queue(db, token, QueueStatus.CALLED.value, actor=user.id)
        booking = db.get(Booking, token.booking_id)
        if booking:
            farmer = db.get(Farmer, booking.farmer_id)
            if farmer:
                create_notification(db, farmer.user_id, "Token Called", f"Token {token.token_number} is next. Please proceed to counter.", "token_called", {"booking_id": token.booking_id})
        log_token_called(db, user.id, token.token_number, token.booking_id)
        # update centre queue state current_ordinal
        qstate = db.query(CentreQueueState).filter(CentreQueueState.centre_id==centre_id, CentreQueueState.date==today).with_for_update().first()
        if qstate:
            qstate.current_ordinal = token.position
        db.commit()
    except ValueError as e:
        raise HTTPException(status_code=400, detail={"code": "INVALID_TRANSITION", "message": str(e)})
    return {"message": "Advanced", "token_number": token.token_number, "position": token.position, "status": token.status}

@router.get("/dev/status")
def dev_queue_status(centre_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    settings = get_settings()
    if not settings.is_dev:
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "Dev only"})
    tokens = db.query(QueueToken).filter(QueueToken.centre_id==centre_id).order_by(QueueToken.position).all()
    return [{"token_number": t.token_number, "position": t.position, "status": t.status, "booking_id": t.booking_id} for t in tokens]

@router.get("/centre/{centre_id}")
def list_centre_queue(centre_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    # Operator queue shows only current date queue (today's bookings) — exclude past dates
    from datetime import date as _date
    today = _date.today()
    tokens = db.query(QueueToken).filter(QueueToken.centre_id==centre_id, QueueToken.status.notin_([QueueStatus.CANCELLED.value, QueueStatus.NO_SHOW.value, QueueStatus.COMPLETED.value])).order_by(QueueToken.position).all()
    # Join booking info and filter to today's date only
    out=[]
    for t in tokens:
        booking = db.get(Booking, t.booking_id)
        if not booking or booking.date != today:
            continue
        if booking.status == BookingStatus.CANCELLED.value:
            continue
        farmer = db.get(Farmer, booking.farmer_id) if booking else None
        out.append({"token_number": t.token_number, "position": t.position, "status": t.status, "booking_id": t.booking_id, "farmer_name": farmer.full_name if farmer else None, "commodity": booking.commodity_name if booking else None, "quantity": booking.estimated_quantity if booking else None, "created_at": t.created_at.isoformat() if t.created_at else None, "date": str(booking.date)})
    return out

def _get_token_for_booking(db: Session, booking_id: str, user: User) -> QueueToken:
    booking = db.get(Booking, booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Booking not found"})
    # auth: owner or operator
    farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    is_owner = farmer and booking.farmer_id == farmer.id
    is_operator = user.role in ("CENTRE_OPERATOR", "ADMIN")
    if not (is_owner or is_operator):
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "Not authorized"})
    qt = db.query(QueueToken).filter(QueueToken.booking_id == booking_id).first()
    if not qt:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Queue token not found"})
    return qt

@router.get("/correction/{booking_id}")
def get_queue_correction(booking_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    """Deterministic queue correction: PROCESSING excluded, gap >2 = missed call, fraud flags."""
    qt = _get_token_for_booking(db, booking_id, user)
    booking = db.get(Booking, booking_id)
    centre = db.get(ProcurementCentre, qt.centre_id)
    # corrected farmersAhead: exclude PROCESSING (WAITING/CALLED/ARRIVED only)
    corrected = db.query(QueueToken).filter(
        QueueToken.centre_id == qt.centre_id,
        QueueToken.position < qt.position,
        QueueToken.status.in_([QueueStatus.WAITING.value, QueueStatus.CALLED.value, QueueStatus.ARRIVED.value])
    ).count()
    naive = db.query(QueueToken).filter(
        QueueToken.centre_id == qt.centre_id,
        QueueToken.position < qt.position,
        QueueToken.status.in_([QueueStatus.WAITING.value, QueueStatus.CALLED.value, QueueStatus.ARRIVED.value, QueueStatus.PROCESSING.value])
    ).count()
    avg = centre.avg_processing_minutes if centre else 3
    counters = centre.active_counters if centre and centre.active_counters else 3
    est_corrected = calculate_wait(corrected, avg, counters)
    est_naive = calculate_wait(naive, avg, counters)
    correction_applied = corrected != naive
    # position gap detection: missing ordinal gap >2 indicates missed call / skipped token
    ahead_tokens = db.query(QueueToken).filter(QueueToken.centre_id == qt.centre_id, QueueToken.position < qt.position).order_by(QueueToken.position).all()
    gap_flag = False
    max_gap = 0
    if ahead_tokens:
        positions = sorted([t.position for t in ahead_tokens])
        for i in range(1, len(positions)):
            gap = positions[i] - positions[i-1] - 1
            if gap > max_gap:
                max_gap = gap
            if gap > 2:
                gap_flag = True
        last_gap = qt.position - positions[-1] - 1
        if last_gap > max_gap:
            max_gap = last_gap
        if last_gap > 2:
            gap_flag = True
    else:
        max_gap = 0
    # also if naive - corrected >2 (many PROCESSING ahead not counted) we could flag but keep gap_flag primary
    # fraud flags
    fraud_flags: dict = {}
    duplicate_risk = False
    if booking:
        # cross-centre duplicate same farmer same date (other bookings)
        cross = db.query(Booking).filter(
            Booking.farmer_id == booking.farmer_id,
            Booking.status == BookingStatus.CONFIRMED.value,
            Booking.date == booking.date,
            Booking.id != booking.id
        ).first()
        if cross:
            fraud_flags["cross_centre_duplicate"] = True
            fraud_flags["cross_centre_token"] = cross.token_number
            fraud_flags["cross_centre_id"] = cross.centre_id
            duplicate_risk = True
        farmer = db.get(Farmer, booking.farmer_id)
        if farmer:
            others = db.query(Farmer).filter(Farmer.mobile == farmer.mobile, Farmer.id != farmer.id).all()
            for other in others:
                dup = db.query(Booking).filter(
                    Booking.farmer_id == other.id,
                    Booking.status == BookingStatus.CONFIRMED.value,
                    Booking.date == booking.date
                ).first()
                if dup:
                    fraud_flags["mobile_duplicate"] = True
                    fraud_flags["duplicate_mobile"] = farmer.mobile
                    fraud_flags["duplicate_farmer_id"] = other.farmer_id
                    fraud_flags["duplicate_token"] = dup.token_number
                    duplicate_risk = True
                    break
    return {
        "booking_id": booking_id,
        "token_number": qt.token_number,
        "queue_position": qt.position,
        "farmers_ahead_corrected": corrected,
        "farmers_ahead_naive": naive,
        "farmers_ahead": corrected,
        "farmersAhead": corrected,
        "farmersAheadCorrected": corrected,
        "farmersAheadNaive": naive,
        "estimated_wait_corrected": est_corrected,
        "estimated_wait_naive": est_naive,
        "estimatedWaitCorrected": est_corrected,
        "correction_applied": correction_applied,
        "correctionApplied": correction_applied,
        "queueCorrectionNote": "Queue position calculated from database, PROCESSING not counted as ahead",
        "correction_note": "Queue position corrected — processing not counted" if correction_applied else None,
        "correctionNote": "Queue position corrected — processing not counted" if correction_applied else None,
        "missed_call_flag": gap_flag,
        "missedCallFlag": gap_flag,
        "position_gap": max_gap,
        "gap": max_gap,
        "fraud_flags": fraud_flags,
        "fraudFlags": fraud_flags,
        "duplicate_risk": duplicate_risk,
        "duplicateRisk": duplicate_risk,
    }

@router.get("/{booking_id}", response_model=QueueStatusOut)
def get_queue_status(booking_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    qt = _get_token_for_booking(db, booking_id, user)
    booking = db.get(Booking, booking_id)
    centre = db.get(ProcurementCentre, qt.centre_id)
    # farmers ahead: tokens with smaller position and still waiting (WAITING/CALLED/ARRIVED) — PROCESSING is at counter, not ahead
    ahead = db.query(QueueToken).filter(QueueToken.centre_id == qt.centre_id, QueueToken.position < qt.position, QueueToken.status.in_([QueueStatus.WAITING.value, QueueStatus.CALLED.value, QueueStatus.ARRIVED.value])).count()
    est = estimate_wait(ahead, centre.avg_processing_minutes if centre else 3, centre.active_counters if centre and centre.active_counters else 3)
    # Turn approaching intelligence: threshold farmersAhead <=2 triggers notification once
    if 0 < ahead <= 2 and qt.status == QueueStatus.WAITING.value:
        from app.models.notification import Notification
        exists = db.query(Notification).filter(Notification.user_id == booking.farmer.user_id if booking.farmer else None, Notification.type == "turn_approaching", Notification.data.like(f'%"{booking_id}"%')).first() if booking.farmer else None
        if not exists:
            try:
                from app.services.notification_service import create_notification as cn
                farmer = db.get(Farmer, booking.farmer_id) if booking else None
                if farmer:
                    cn(db, farmer.user_id, "Your turn is approaching", f"Token {qt.token_number} — {ahead} farmers ahead. Please proceed to centre.", "turn_approaching", {"booking_id": booking_id, "farmersAhead": ahead})
                    db.commit()
            except Exception:
                pass
    return QueueStatusOut(booking_id=booking_id, token_number=qt.token_number, queue_position=qt.position, farmers_ahead=ahead, estimated_wait_minutes=est, status=qt.status, debug={"ahead": ahead, "avg_processing": centre.avg_processing_minutes if centre else 3, "counters": centre.active_counters if centre else 3})

@router.post("/{booking_id}/transition")
def transition(booking_id: str, payload: QueueTransitionRequest, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    # Only operator/admin can transition, except farmer can set ARRIVED? allow farmer ARRIVED
    qt = _get_token_for_booking(db, booking_id, user)
    is_operator = user.role in ("CENTRE_OPERATOR", "ADMIN")
    if not is_operator and payload.to_status not in (QueueStatus.ARRIVED.value, QueueStatus.CANCELLED.value):
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "Only operator can transition"})
    try:
        transition_queue(db, qt, payload.to_status, actor=user.id)
        # notification + audit for important transitions
        booking = db.get(Booking, booking_id)
        farmer = db.get(Farmer, booking.farmer_id) if booking else None
        if farmer and payload.to_status == QueueStatus.CALLED.value:
            create_notification(db, farmer.user_id, "Token Called", f"Token {qt.token_number} is next. Please proceed to counter.", "token_called", {"booking_id": booking_id})
            log_token_called(db, user.id, qt.token_number, booking_id)
        elif farmer and payload.to_status == QueueStatus.ARRIVED.value:
            log_arrived(db, user.id, booking_id)
        elif farmer and payload.to_status == QueueStatus.PROCESSING.value:
            create_notification(db, farmer.user_id, "Processing Started", f"Token {qt.token_number} now processing.", "queue_position_changed", {"booking_id": booking_id})
            log_processing_started(db, user.id, booking_id)
        elif payload.to_status == QueueStatus.NO_SHOW.value:
            audit(db, user.id, "farmer_no_show", "queue_token", qt.id, f"Token {qt.token_number} marked NO_SHOW")
            if farmer:
                create_notification(db, farmer.user_id, "Marked No-Show", f"Token {qt.token_number} marked as no-show. Contact centre for reassignment.", "queue_position_changed", {"booking_id": booking_id})
        elif payload.to_status == QueueStatus.ON_HOLD.value:
            audit(db, user.id, "queue_on_hold", "queue_token", qt.id, f"Token {qt.token_number} ON_HOLD")
        elif payload.to_status == QueueStatus.COMPLETED.value:
            audit(db, user.id, "queue_completed", "queue_token", qt.id, f"Token {qt.token_number} COMPLETED")
        elif payload.to_status == QueueStatus.CANCELLED.value:
            audit(db, user.id, "queue_cancelled", "queue_token", qt.id, f"Token {qt.token_number} CANCELLED")
        db.commit()
        # broadcast ws
        import asyncio
        try:
            loop = asyncio.get_event_loop()
            if loop.is_running():
                asyncio.create_task(ws_manager.broadcast(booking_id, {"status": qt.status, "token": qt.token_number}))
        except:
            pass
    except ValueError as e:
        raise HTTPException(status_code=400, detail={"code": "INVALID_TRANSITION", "message": str(e)})
    return {"message": "Transition ok", "status": qt.status}

@router.get("/{booking_id}/events")
def get_events(booking_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    qt = _get_token_for_booking(db, booking_id, user)
    events = db.query(QueueEvent).filter(QueueEvent.token_id == qt.id).order_by(QueueEvent.created_at).all()
    return [{"id": e.id, "from_status": e.from_status, "to_status": e.to_status, "created_at": e.created_at} for e in events]

@router.websocket("/ws/{booking_id}")
async def ws_queue(websocket: WebSocket, booking_id: str):
    await ws_manager.connect(booking_id, websocket)
    try:
        while True:
            await websocket.receive_text()  # keep alive; ignore
    except WebSocketDisconnect:
        ws_manager.disconnect(booking_id, websocket)
