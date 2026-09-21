from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.schemas.auth import SendOtpRequest, VerifyOtpRequest, TokenResponse, RefreshRequest, MobileLoginRequest, RegisterRequest
from app.services.otp_service import get_otp_provider
from app.models.user import User, UserRole
from app.models.farmer import Farmer
from app.core.security import create_access_token, create_refresh_token, decode_token, get_password_hash, verify_password
from app.core.config import get_settings
from app.api.deps import get_current_user
import uuid
import re

router = APIRouter()

@router.post("/send-otp")
def send_otp(payload: SendOtpRequest):
    identifier = payload.get_identifier()
    provider = get_otp_provider()
    try:
        provider.send_otp(identifier)
    except RuntimeError as e:
        msg = str(e)
        # Rate limit -> 429, others -> 400
        if "Too many" in msg:
            raise HTTPException(status_code=429, detail={"code": "RATE_LIMITED", "message": msg})
        # No email found for mobile etc -> 400 not 500
        raise HTTPException(status_code=400, detail={"code": "OTP_SEND_FAILED", "message": msg})
    except Exception as e:
        raise HTTPException(status_code=400, detail={"code": "OTP_SEND_FAILED", "message": str(e)})
    # Return which identifier was used (don't expose OTP)
    if payload.email:
        return {"message": "OTP sent", "email": payload.email}
    return {"message": "OTP sent", "mobile": payload.mobile}

@router.post("/register", response_model=TokenResponse)
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    # Validate mobile 10 digits already done by schema, but double-check
    mobile = payload.mobile.strip()
    if not re.fullmatch(r"\d{10}", mobile):
        raise HTTPException(status_code=400, detail={"code": "INVALID_MOBILE", "message": "Mobile must be 10 digits"})
    if len(payload.password) < 6:
        raise HTTPException(status_code=400, detail={"code": "WEAK_PASSWORD", "message": "Password must be at least 6 characters"})
    # Checks duplicate mobile/email/farmer_id
    if db.query(User).filter(User.mobile == mobile).first():
        raise HTTPException(status_code=400, detail={"code": "MOBILE_EXISTS", "message": "Mobile already registered"})
    email = payload.email.strip().lower() if payload.email else None
    if email and db.query(User).filter(User.email == email).first():
        raise HTTPException(status_code=400, detail={"code": "EMAIL_EXISTS", "message": "Email already registered"})
    if db.query(Farmer).filter(Farmer.farmer_id == payload.farmer_id).first():
        raise HTTPException(status_code=400, detail={"code": "FARMER_ID_EXISTS", "message": "Farmer ID already exists"})
    # Also check farmer email duplicate if provided
    if email and db.query(Farmer).filter(Farmer.email == email).first():
        raise HTTPException(status_code=400, detail={"code": "EMAIL_EXISTS", "message": "Email already registered"})

    hashed = get_password_hash(payload.password)
    user_id = str(uuid.uuid4())
    user = User(id=user_id, mobile=mobile, email=email, hashed_password=hashed, role=UserRole.FARMER.value)
    db.add(user)
    db.flush()
    farmer = Farmer(
        id=str(uuid.uuid4()),
        user_id=user.id,
        full_name=payload.full_name,
        mobile=mobile,
        email=email,
        farmer_id=payload.farmer_id,
        village=payload.village,
        district=payload.district,
        language_code=payload.language_code,
        primary_commodity=payload.primary_commodity,
    )
    db.add(farmer)
    db.commit()
    db.refresh(user)
    access = create_access_token(user.id, user.role)
    refresh = create_refresh_token(user.id, user.role)
    return TokenResponse(access_token=access, refresh_token=refresh, role=user.role, user_id=user.id)

@router.post("/login", response_model=TokenResponse)
def login(payload: MobileLoginRequest, db: Session = Depends(get_db)):
    mobile = payload.mobile.strip()
    user = db.query(User).filter(User.mobile == mobile).first()
    if not user or not user.hashed_password:
        raise HTTPException(status_code=401, detail={"code": "INVALID_CREDENTIALS", "message": "Invalid mobile or password"})
    # Primary check
    password_ok = False
    try:
        password_ok = verify_password(payload.password, user.hashed_password)
    except Exception:
        password_ok = False
    # Dev fallback: allow 123456 / password123 for demo accounts regardless of stored hash (for seed/migration convenience)
    if not password_ok:
        settings = get_settings()
        if settings.is_dev and payload.password in ("123456", "password123"):
            # Allow dev fixed passwords for demo users or if stored hash was for the other dev password
            # Try alternative hash verification if primary failed due to hash mismatch
            # Also allow if user is a demo account with is_dev override
            demo_mobiles = {"9876543210", "9876543211", "9999999999", "9876500001"}
            if mobile in demo_mobiles:
                password_ok = True
            else:
                # For other users, still allow 123456 in dev to mimic OTP fallback? No, require proper hash
                # But we can try to accept if the stored hash corresponds to either password
                # Compute hashes not possible; instead we treat dev OTP as valid password fallback for any user with hashed_password
                # Only allow if password is one of dev passwords and user exists — for broader dev convenience
                # To avoid security regression, we require that the user was created via OTP and has placeholder logic? 
                # Simplify: do not allow generic fallback for non-demo users
                pass
        if not password_ok:
            raise HTTPException(status_code=401, detail={"code": "INVALID_CREDENTIALS", "message": "Invalid mobile or password"})
    access = create_access_token(user.id, user.role)
    refresh = create_refresh_token(user.id, user.role)
    return TokenResponse(access_token=access, refresh_token=refresh, role=user.role, user_id=user.id)

@router.post("/verify-otp", response_model=TokenResponse)
def verify_otp(payload: VerifyOtpRequest, db: Session = Depends(get_db)):
    identifier = payload.get_identifier()
    provider = get_otp_provider()
    if not provider.verify_otp(identifier, payload.otp):
        raise HTTPException(status_code=400, detail={"code": "INVALID_OTP", "message": "Invalid or expired OTP"})
    # Lookup by email or mobile
    user = None
    if payload.email:
        user = db.query(User).filter(User.email == payload.email.strip().lower()).first()
        if not user and payload.mobile:
            user = db.query(User).filter(User.mobile == payload.mobile).first()
    else:
        user = db.query(User).filter(User.mobile == payload.mobile).first()
        # Also try email if User has email matching mobile's email (for Brevo flow where mobile was used to lookup email)
        if not user and "@" in identifier:
            user = db.query(User).filter(User.email == identifier.lower()).first()
    if not user:
        # Create new user — prefer email if provided, else mobile
        email = payload.email.strip().lower() if payload.email else None
        mobile = payload.mobile.strip() if payload.mobile else (f"email_{identifier}" if email else identifier)
        # Ensure mobile is unique — generate placeholder if email only
        if not mobile or "@" in mobile:
            mobile = f"999{str(uuid.uuid4().int)[:7]}"
        user = User(id=str(uuid.uuid4()), mobile=mobile, email=email, role=UserRole.FARMER.value)
        db.add(user)
        db.commit()
        db.refresh(user)
    else:
        # If user exists but email provided and not set, update
        if payload.email and not user.email:
            user.email = payload.email.strip().lower()
            db.commit()
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
    return {"user": {"id": user.id, "mobile": user.mobile, "email": user.email, "role": user.role}, "farmer": farmer}
