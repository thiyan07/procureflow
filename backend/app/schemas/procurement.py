from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class ProcurementOut(BaseModel):
    id: str
    booking_id: str
    stage: str
    created_at: datetime
    class Config:
        from_attributes = True

class ProcurementAdvanceRequest(BaseModel):
    to_stage: str

class TimelineStepOut(BaseModel):
    title: str
    subtitle: str
    timestamp: Optional[datetime] = None
    is_completed: bool
    is_current: bool

class WeighmentOut(BaseModel):
    gross_weight: Optional[float] = None
    net_weight: Optional[float] = None
    weighment_time: Optional[datetime] = None

class QualityCheckOut(BaseModel):
    grade: Optional[str] = None
    moisture_percent: Optional[float] = None
    remarks: Optional[str] = None
    checked_at: Optional[datetime] = None
