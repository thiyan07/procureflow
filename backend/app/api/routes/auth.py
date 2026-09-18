from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.schemas.auth import SendOtpRequest, VerifyOtpRequest, TokenResponse, RefreshRequest
from app.services.otp_service import get_otp_provider
from app.models.user import User, UserRole
from app.models.farmer import Farmer
from app.core.security import create_access_token, create_refresh_token, decode_token
from app.api.deps import get_current_user
import uuid

router = APIRouter()

@router.post("/send-otp")
def send_otp(payload: SendOtpRequest):
    provider = get_otp_provider()
    provider.send_otp(payload.mobile)
    return {"message": "OTP sent", "mobile": payload.mobile}

@router.post("/verify-otp", response_model=TokenResponse)
def verify_otp(payload: VerifyOtpRequest, db: Session = Depends(get_db)):
    provider = get_otp_provider()
    if not provider.verify_otp(payload.mobile, payload.otp):
        raise HTTPException(status_code=400, detail={"code": "INVALID_OTP", "message": "Invalid or expired OTP"})
    user = db.query(User).filter(User.mobile == payload.mobile).first()
    if not user:
        user = User(id=str(uuid.uuid4()), mobile=payload.mobile, role=UserRole.FARMER.value)
        db.add(user)
        db.commit()
        db.refresh(user)
    access = create_access_token(user.id, user.role)
    refresh = create_refresh_token(user.id, user.role)
    return TokenResponse(access_token=access, refresh_token=refresh, role=user.role, user_id=user.id)

@router.post("/refresh", response_model=TokenResponse)
def refresh(payload: RefreshRequest, db: Session = Depends(get_db)):
    try:
        data = decode_token(payload.refresh_token)
    except ValueError:
        raise HTTPException(status_code=401, detail={"code": "INVALID_TOKEN", "message": "Invalid refresh token"})
    if data.get("type") != "refresh":
        raise HTTPException(status_code=401, detail={"code": "INVALID_TOKEN", "message": "Invalid token type"})
    user_id = data.get("sub")
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=401, detail={"code": "USER_NOT_FOUND", "message": "User not found"})
    access = create_access_token(user.id, user.role)
    refresh_tok = create_refresh_token(user.id, user.role)
    return TokenResponse(access_token=access, refresh_token=refresh_tok, role=user.role, user_id=user.id)

@router.get("/me")
def me(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    return {"user": {"id": user.id, "mobile": user.mobile, "role": user.role}, "farmer": farmer}
