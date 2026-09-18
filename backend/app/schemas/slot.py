from pydantic import BaseModel
from datetime import date, time
from typing import Optional

class SlotOut(BaseModel):
    id: str
    centre_id: str
    date: date
    start_time: time
    end_time: time
    capacity: int
    booked: int
    available: int
    status: str
    class Config:
        from_attributes = True

    @classmethod
    def from_orm_slot(cls, s):
        return cls(
            id=s.id, centre_id=s.centre_id, date=s.date, start_time=s.start_time, end_time=s.end_time,
            capacity=s.capacity, booked=s.booked, available=s.capacity - s.booked, status=s.status
        )

class SlotRecommendationOut(BaseModel):
    recommended_slot: Optional[SlotOut] = None
    expected_wait_minutes: int = 0
    reason: str = ""
    alternatives: list[SlotOut] = []
    debug: Optional[dict] = None
