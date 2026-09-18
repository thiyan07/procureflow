from fastapi import APIRouter, Depends, Query
from datetime import date
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.slot import Slot

router = APIRouter()

@router.get("", response_model=list[dict])
def list_slots(centre_id: str = Query(...), date: date = Query(...), db: Session = Depends(get_db)):
    slots = db.query(Slot).filter(Slot.centre_id == centre_id, Slot.date == date).order_by(Slot.start_time).all()
    out = []
    for s in slots:
        out.append({"id": s.id, "centre_id": s.centre_id, "date": s.date, "start_time": s.start_time, "end_time": s.end_time, "capacity": s.capacity, "booked": s.booked, "available": s.capacity - s.booked, "status": s.status})
    return out
