from sqlalchemy.orm import Session
from app.models.queue import QueueToken, QueueEvent, CentreQueueState, QueueStatus
from app.models.booking import Booking
from app.services.scheduling_service import calculate_wait
import math

def get_or_create_centre_queue_state(db: Session, centre_id: str, date_str: str) -> CentreQueueState:
    state = db.get(CentreQueueState, (centre_id, date_str))
    if not state:
        state = CentreQueueState(centre_id=centre_id, date=date_str, current_ordinal=0, next_ordinal=1)
        db.add(state)
        db.flush()
    return state

def estimate_wait(farmers_ahead: int, avg_processing: int, active_counters: int) -> int:
    return calculate_wait(farmers_ahead, avg_processing, active_counters)

def allowed_transitions(current: str) -> list[str]:
    mapping = {
        QueueStatus.WAITING.value: [QueueStatus.CALLED.value, QueueStatus.CANCELLED.value, QueueStatus.ON_HOLD.value],
        QueueStatus.CALLED.value: [QueueStatus.ARRIVED.value, QueueStatus.NO_SHOW.value, QueueStatus.CANCELLED.value],
        QueueStatus.ARRIVED.value: [QueueStatus.PROCESSING.value, QueueStatus.CANCELLED.value],
        QueueStatus.PROCESSING.value: [QueueStatus.COMPLETED.value, QueueStatus.ON_HOLD.value],
        QueueStatus.ON_HOLD.value: [QueueStatus.WAITING.value, QueueStatus.CANCELLED.value],
    }
    return mapping.get(current, [])

def transition_queue(db: Session, token: QueueToken, to_status: str, actor: str | None = None) -> QueueToken:
    allowed = allowed_transitions(token.status)
    if to_status not in allowed and token.status != to_status:
        raise ValueError(f"Invalid transition {token.status} -> {to_status}. Allowed: {allowed}")
    evt = QueueEvent(token_id=token.id, from_status=token.status, to_status=to_status, actor=actor)
    db.add(evt)
    token.status = to_status
    db.flush()
    return token
