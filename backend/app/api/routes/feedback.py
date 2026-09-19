from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import desc
from app.db.session import get_db
from app.api.deps import get_current_user
from app.models.user import User
from app.models.feedback import Feedback, FeedbackStatus
from pydantic import BaseModel

router = APIRouter()

class FeedbackCreate(BaseModel):
    category: str
    description: str

class FeedbackOut(BaseModel):
    id: str
    category: str
    description: str
    status: str
    created_at: str
    class Config:
        from_attributes = True

@router.post("", response_model=FeedbackOut, status_code=201)
def create_feedback(payload: FeedbackCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    if payload.category not in ["delay", "quality", "payment", "other"]:
        raise HTTPException(status_code=400, detail={"code": "INVALID_CATEGORY", "message": "Category must be delay/quality/payment/other"})
    if len(payload.description.strip()) < 5:
        raise HTTPException(status_code=400, detail={"code": "INVALID_DESC", "message": "Description too short"})
    fb = Feedback(user_id=user.id, category=payload.category, description=payload.description.strip())
    db.add(fb)
    db.commit()
    db.refresh(fb)
    return FeedbackOut(id=fb.id, category=fb.category, description=fb.description, status=fb.status, created_at=fb.created_at.isoformat())

@router.get("", response_model=list[FeedbackOut])
def list_feedback(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    # Farmer sees own, operator/admin sees all
    if user.role in ("CENTRE_OPERATOR", "ADMIN"):
        fbs = db.query(Feedback).order_by(desc(Feedback.created_at)).limit(50).all()
    else:
        fbs = db.query(Feedback).filter(Feedback.user_id == user.id).order_by(desc(Feedback.created_at)).limit(50).all()
    return [FeedbackOut(id=f.id, category=f.category, description=f.description, status=f.status, created_at=f.created_at.isoformat()) for f in fbs]

@router.get("/{feedback_id}", response_model=FeedbackOut)
def get_feedback(feedback_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    fb = db.get(Feedback, feedback_id)
    if not fb:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Feedback not found"})
    if fb.user_id != user.id and user.role not in ("ADMIN", "CENTRE_OPERATOR"):
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "Not authorized"})
    return FeedbackOut(id=fb.id, category=fb.category, description=fb.description, status=fb.status, created_at=fb.created_at.isoformat())

@router.post("/{feedback_id}/status")
def update_status(feedback_id: str, status: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    if user.role not in ("ADMIN", "CENTRE_OPERATOR"):
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "Only operator/admin"})
    fb = db.get(Feedback, feedback_id)
    if not fb:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Feedback not found"})
    if status not in [s.value for s in FeedbackStatus]:
        raise HTTPException(status_code=400, detail={"code": "INVALID_STATUS", "message": "Invalid status"})
    fb.status = status
    db.commit()
    return {"message": "Updated", "status": fb.status}
