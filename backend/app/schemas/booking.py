from pydantic import BaseModel
from datetime import date, datetime
from typing import Optional

class BookingCreate(BaseModel):
    centre_id: str
    slot_id: str
    commodity: str
    estimated_quantity: float
    date: Optional[date] = None

class BookingOut(BaseModel):
    id: str
    farmer_id: str
    centre_id: str
    slot_id: str
    commodity_name: str
    estimated_quantity: float
    token_number: str
    queue_token_id: Optional[str] = None
    date: date
    status: str
    created_at: datetime
    # expanded
    centre_name: Optional[str] = None
    slot_start: Optional[str] = None
    slot_end: Optional[str] = None
    queue_position: Optional[int] = None
    estimated_wait: Optional[int] = None
    class Config:
        from_attributes = True
