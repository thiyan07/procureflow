from pydantic import BaseModel
from datetime import datetime
from typing import Optional

class DeviceTokenRequest(BaseModel):
    token: str
    platform: str = "android"

class NotificationOut(BaseModel):
    id: str
    title: str
    body: str
    type: str
    is_read: bool
    created_at: datetime
    class Config:
        from_attributes = True
