import json
import logging
from sqlalchemy.orm import Session
from app.models.notification import Notification, DeviceToken
from app.integrations.firebase.fcm_service import fcm_service

log = logging.getLogger(__name__)

NOTIFICATION_TYPES = [
    "slot_confirmed", "slot_reminder", "queue_position_changed",
    "turn_approaching", "token_called", "procurement_stage_updated",
    "procurement_completed", "payment_status_updated"
]

def create_notification(db: Session, user_id: str, title: str, body: str, ntype: str, data: dict | None = None) -> Notification:
    notif = Notification(user_id=user_id, title=title, body=body, type=ntype, data=json.dumps(data or {}))
    db.add(notif)
    db.flush()
    # send FCM to all device tokens
    tokens = db.query(DeviceToken).filter(DeviceToken.user_id == user_id).all()
    for t in tokens:
        try:
            fcm_service.send_to_token(t.token, title, body, data)
        except Exception as e:
            log.warning(f"FCM send error for user {user_id}: {e}")
    return notif

def send_slot_confirmed(db: Session, user_id: str, token_number: str, centre_name: str, slot_label: str, booking_id: str):
    return create_notification(db, user_id, "Slot Confirmed", f"Token {token_number} at {centre_name} {slot_label} confirmed.", "slot_confirmed", {"booking_id": booking_id})

def send_queue_position_changed(db: Session, user_id: str, token_number: str, ahead: int, wait: int, booking_id: str):
    return create_notification(db, user_id, "Queue Updated", f"Token {token_number}: {ahead} ahead, wait {wait} min.", "queue_position_changed", {"booking_id": booking_id})

def send_turn_approaching(db: Session, user_id: str, token_number: str, booking_id: str):
    return create_notification(db, user_id, "Your turn is approaching", f"Token {token_number} — please proceed to the procurement centre.", "turn_approaching", {"booking_id": booking_id})

def send_token_called(db: Session, user_id: str, token_number: str, booking_id: str):
    return create_notification(db, user_id, "Token Called", f"Token {token_number} is next. Please proceed to counter.", "token_called", {"booking_id": booking_id})

def send_procurement_stage(db: Session, user_id: str, stage: str, booking_id: str):
    return create_notification(db, user_id, "Procurement Updated", f"Procurement stage: {stage}", "procurement_stage_updated", {"booking_id": booking_id})

def send_payment_update(db: Session, user_id: str, status: str, booking_id: str):
    return create_notification(db, user_id, "Payment Status Updated", f"Payment status: {status}", "payment_status_updated", {"booking_id": booking_id})
