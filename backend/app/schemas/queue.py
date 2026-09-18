from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class QueueStatusOut(BaseModel):
    booking_id: str
    token_number: str
    queue_position: int
    farmers_ahead: int
    estimated_wait_minutes: int
    status: str
    debug: Optional[dict] = None

class QueueEventOut(BaseModel):
    id: str
    token_id: str
    from_status: Optional[str]
    to_status: str
    created_at: datetime
    class Config:
        from_attributes = True

class QueueTransitionRequest(BaseModel):
    to_status: str
