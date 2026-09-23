from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class ProcurementOut(BaseModel):
    id: str
    booking_id: str
    stage: str
    approval_status: str = "NONE"
    pending_stage: Optional[str] = None
    created_at: datetime
    class Config:
        from_attributes = True

class ProcurementAdvanceRequest(BaseModel):
    to_stage: str

class ProcurementApproveRequest(BaseModel):
    stage: str
    role: Optional[str] = None

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

class ComplianceCheckRequest(BaseModel):
    question: str
    answer: str

class ComplianceCheckResponse(BaseModel):
    verified: bool
    generated_justification: str
    reason: str
    booking_id: str
    commodity: str
    quantity: float
    grade: Optional[str] = None
    moisture: Optional[float] = None
