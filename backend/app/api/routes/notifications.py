from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import desc
from app.db.session import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.notification import Notification, DeviceToken
from app.schemas.notification import DeviceTokenRequest, NotificationOut

router = APIRouter()

@router.post("/device-token")
def register_device_token(payload: DeviceTokenRequest, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    existing = db.query(DeviceToken).filter(DeviceToken.token == payload.token).first()
    if existing:
        existing.user_id = user.id
        existing.platform = payload.platform
        db.commit()
        return {"message": "Token updated", "token": existing.token}
    dt = DeviceToken(user_id=user.id, token=payload.token, platform=payload.platform)
    db.add(dt)
    db.commit()
    return {"message": "Token registered", "token": dt.token}

@router.get("", response_model=list[NotificationOut])
def list_notifications(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    notifs = db.query(Notification).filter(Notification.user_id == user.id).order_by(desc(Notification.created_at)).limit(50).all()
    return notifs

@router.post("/{notification_id}/read")
def mark_read(notification_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    n = db.get(Notification, notification_id)
    if not n or n.user_id != user.id:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Notification not found"})
    n.is_read = True
    db.commit()
    return {"message": "Marked read"}

# SSE-style polling fallback endpoint already via GET ""
