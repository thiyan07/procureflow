from pydantic import BaseModel
from datetime import time
from typing import List

class CentreOut(BaseModel):
    id: str
    name: str
    location: str
    district: str
    lat: float
    lng: float
    status: str
    active_counters: int
    avg_processing_minutes: int
    open_time: time
    close_time: time
    class Config:
        from_attributes = True

class CentreStatusOut(BaseModel):
    centre: CentreOut
    is_open: bool
    current_queue_size: int
    estimated_wait_minutes: int
    active_counters: int
    available_slots: int
