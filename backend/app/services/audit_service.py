"""
Audit logging service (Phase 14).

Logs: booking created/cancelled, token generated/called, arrived, processing, procurement completed, payment updated.
Never logs passwords, JWTs, FCM keys.
"""
import logging
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.models.procurement import AuditLog

log = logging.getLogger(__name__)

def audit(db: Session, actor: str | None, action: str, entity_type: str | None = None, entity_id: str | None = None, details: str | None = None):
    try:
        # Truncate details to 1000 chars, strip secrets
        if details:
            # never log tokens/secrets
            for secret in ["password", "jwt", "token", "private_key", "secret"]:
                if secret in details.lower():
                    details = "[REDACTED]"
                    break
            details = details[:1000]
        entry = AuditLog(user_id=actor, action=action, entity_type=entity_type, entity_id=entity_id, details=details)
        db.add(entry)
        db.flush()
    except Exception as e:
        log.warning(f"audit failed {action}: {e}")

# Convenience wrappers
def log_booking_created(db, actor, booking_id, token):
    audit(db, actor, "booking_created", "booking", booking_id, f"token {token}")

def log_booking_cancelled(db, actor, booking_id):
    audit(db, actor, "booking_cancelled", "booking", booking_id, None)

def log_token_called(db, actor, token_number, booking_id):
    audit(db, actor, "token_called", "queue_token", booking_id, f"token {token_number} called")

def log_arrived(db, actor, booking_id):
    audit(db, actor, "farmer_arrived", "booking", booking_id, None)

def log_processing_started(db, actor, booking_id):
    audit(db, actor, "processing_started", "booking", booking_id, None)

def log_procurement_completed(db, actor, booking_id, stage):
    audit(db, actor, "procurement_stage", "procurement", booking_id, f"stage {stage}")

def log_payment_updated(db, actor, booking_id, status):
    audit(db, actor, "payment_updated", "payment", booking_id, f"status {status}")
