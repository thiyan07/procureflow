from pydantic import BaseModel
from typing import Optional

class FarmerCreate(BaseModel):
    full_name: str
    mobile: str
    farmer_id: str
    village: str
    district: str
    language_code: str = "en"
    primary_commodity: str = "Paddy"

class FarmerUpdate(BaseModel):
    full_name: Optional[str] = None
    village: Optional[str] = None
    district: Optional[str] = None
    language_code: Optional[str] = None
    primary_commodity: Optional[str] = None

class FarmerOut(BaseModel):
    id: str
    user_id: str
    full_name: str
    mobile: str
    farmer_id: str
    village: str
    district: str
    language_code: str
    primary_commodity: str

    class Config:
        from_attributes = True
