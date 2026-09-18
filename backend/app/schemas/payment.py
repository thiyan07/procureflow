from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class PaymentOut(BaseModel):
    id: str
    booking_id: str
    commodity: str
    quantity_quintal: float
    rate_per_quintal: float
    total_amount: float
    status: str
    transaction_id: Optional[str] = None
    payment_date: Optional[datetime] = None
    class Config:
        from_attributes = True

class PaymentStatusUpdate(BaseModel):
    status: str
