from pydantic import BaseModel

class SendOtpRequest(BaseModel):
    mobile: str

class VerifyOtpRequest(BaseModel):
    mobile: str
    otp: str

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
