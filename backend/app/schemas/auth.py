from pydantic import BaseModel, Field, field_validator
from typing import Optional
import re

class SendOtpRequest(BaseModel):
    mobile: Optional[str] = None
    email: Optional[str] = None

    def get_identifier(self) -> str:
        # Prefer email for Brevo, fallback to mobile
        if self.email and self.email.strip():
            return self.email.strip().lower()
        if self.mobile and self.mobile.strip():
            return self.mobile.strip()
        raise ValueError("Either mobile or email is required")

class VerifyOtpRequest(BaseModel):
    mobile: Optional[str] = None
    email: Optional[str] = None
    otp: str

    def get_identifier(self) -> str:
        if self.email and self.email.strip():
            return self.email.strip().lower()
        if self.mobile and self.mobile.strip():
            return self.mobile.strip()
        raise ValueError("Either mobile or email is required")

class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    role: str
    user_id: str

class RefreshRequest(BaseModel):
    refresh_token: str

class UserOut(BaseModel):
    id: str
    mobile: str
    role: str

class MobileLoginRequest(BaseModel):
    mobile: str = Field(..., description="10 digit mobile number")
    password: str = Field(..., min_length=6, description="Password min 6 chars")

    @field_validator("mobile")
    @classmethod
    def validate_mobile(cls, v: str) -> str:
        v = v.strip()
        if not re.fullmatch(r"\d{10}", v):
            raise ValueError("Mobile must be 10 digits")
        return v

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("Password must be at least 6 characters")
        return v

class RegisterRequest(BaseModel):
    full_name: str = Field(..., min_length=2, max_length=100)
    mobile: str = Field(..., description="10 digit mobile number")
    password: str = Field(..., min_length=6, description="Password min 6 chars")
    farmer_id: str = Field(..., min_length=3, max_length=50)
    village: str = Field(..., min_length=2, max_length=100)
    district: str = Field(..., min_length=2, max_length=100)
    language_code: str = Field(default="en")
    primary_commodity: str = Field(default="Paddy")
    email: Optional[str] = Field(default=None)

    @field_validator("mobile")
    @classmethod
    def validate_mobile(cls, v: str) -> str:
        v = v.strip()
        if not re.fullmatch(r"\d{10}", v):
            raise ValueError("Mobile must be 10 digits")
        return v

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 6:
            raise ValueError("Password must be at least 6 characters")
        return v

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: Optional[str]) -> Optional[str]:
        if v is None or v.strip() == "":
            return None
        v = v.strip().lower()
        if "@" not in v or "." not in v:
            raise ValueError("Invalid email format")
        return v
