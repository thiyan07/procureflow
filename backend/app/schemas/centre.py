from pydantic import BaseModel
from datetime import time
from typing import List, Optional

class CentreOut(BaseModel):
    id: str
    centre_code: Optional[str] = None
    name: str
    location: str
    address: Optional[str] = None
    district: str
    lat: float
    lng: float
    phone: Optional[str] = None
    contact_person: Optional[str] = None
    status: str
    active_counters: int
    avg_processing_minutes: int
    daily_capacity: Optional[int] = None
    open_time: time
    close_time: time
    distance_km: Optional[float] = None
    supported_commodities: Optional[List[str]] = None
    remaining_capacity_today: Optional[int] = None
    class Config:
        from_attributes = True

class CentreStatusOut(BaseModel):
    centre: CentreOut
    is_open: bool
    current_queue_size: int
    estimated_wait_minutes: int
    active_counters: int
    available_slots: int
