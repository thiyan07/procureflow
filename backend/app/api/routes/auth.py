from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.schemas.auth import SendOtpRequest, VerifyOtpRequest, TokenResponse, RefreshRequest, MobileLoginRequest, RegisterRequest
# OTP service deprecated - kept for backward compat import but not used (phone+password only)
# from app.services.otp_service import get_otp_provider
from app.models.user import User, UserRole
from app.models.farmer import Farmer
from app.core.security import create_access_token, create_refresh_token, decode_token, get_password_hash, verify_password
from app.core.config import get_settings
from app.api.deps import get_current_user, security
import uuid
import re

router = APIRouter()

# Simple in-memory rate limiting for login (per mobile, per IP via identifier)
from collections import defaultdict
import time
_login_attempts: dict[str, list[float]] = defaultdict(list)
_LOCKOUT_THRESHOLD = 5
_LOCKOUT_WINDOW_SECONDS = 900  # 15 min
_WEAK_PASSWORD_MIN_LENGTH = 8

def _is_strong_password(pwd: str, mobile: str | None = None) -> tuple[bool, str]:
    if len(pwd) < _WEAK_PASSWORD_MIN_LENGTH:
        return False, f"Password must be at least {_WEAK_PASSWORD_MIN_LENGTH} characters"
    if not re.search(r"[A-Za-z]", pwd):
        return False, "Password must contain at least one letter"
    if not re.search(r"[0-9]", pwd):
        return False, "Password must contain at least one digit"
    if mobile and mobile in pwd:
        return False, "Password must not contain mobile number"
    # optional: common passwords block
    common = {"password", "12345678", "password123", "qwerty123"}
    if pwd.lower() in common and not get_settings().is_dev:
        return False, "Password too common, choose a stronger one"
    return True, ""

def _check_rate_limit(key: str, db: Session | None = None) -> None:
    # Prefer DB persistence so survives restart (PostgreSQL)
    if db is not None:
        try:
            from app.models.auth_security import LoginAttempt
            from datetime import datetime, timezone, timedelta
            now = datetime.now(timezone.utc)
            rec = db.get(LoginAttempt, key)
            if rec:
                # prune if window passed
                age = (now - rec.last_attempt_at).total_seconds() if rec.last_attempt_at else 9999
                if age > _LOCKOUT_WINDOW_SECONDS:
                    rec.attempts = 0
                    rec.first_attempt_at = now
                    db.commit()
                elif rec.attempts >= _LOCKOUT_THRESHOLD:
                    raise HTTPException(status_code=429, detail={"code": "RATE_LIMITED", "message": "Too many failed attempts. Try again in 15 minutes."})
            return
        except HTTPException:
            raise
        except Exception:
            pass
    now = time.time()
    attempts = _login_attempts[key]
    _login_attempts[key] = [t for t in attempts if now - t < _LOCKOUT_WINDOW_SECONDS]
    if len(_login_attempts[key]) >= _LOCKOUT_THRESHOLD:
        raise HTTPException(status_code=429, detail={"code": "RATE_LIMITED", "message": "Too many failed attempts. Try again in 15 minutes."})

def _record_failed_attempt(key: str, db: Session | None = None) -> None:
    if db is not None:
        try:
            from app.models.auth_security import LoginAttempt
            from datetime import datetime, timezone
            now = datetime.now(timezone.utc)
            rec = db.get(LoginAttempt, key)
            if not rec:
                rec = LoginAttempt(key=key, attempts=1, first_attempt_at=now, last_attempt_at=now)
                db.add(rec)
            else:
                # check window
                age = (now - rec.first_attempt_at).total_seconds() if rec.first_attempt_at else 0
                if age > _LOCKOUT_WINDOW_SECONDS:
                    rec.attempts = 1
                    rec.first_attempt_at = now
                else:
                    rec.attempts += 1
                rec.last_attempt_at = now
            db.commit()
            return
        except Exception:
            pass
    _login_attempts[key].append(time.time())

def _clear_attempts(key: str, db: Session | None = None) -> None:
    if db is not None:
        try:
            from app.models.auth_security import LoginAttempt
            rec = db.get(LoginAttempt, key)
            if rec:
                db.delete(rec)
                db.commit()
        except Exception:
            pass
    _login_attempts.pop(key, None)

@router.post("/send-otp", deprecated=True)
def send_otp(payload: SendOtpRequest):
    # DEPRECATED: OTP authentication removed - phone+password + JWT is the only auth (see CRITICAL AUTH REQUIREMENT)
    # Kept as 410 to avoid breaking old clients silently; email remains optional profile field only.
    raise HTTPException(status_code=410, detail={"code": "DEPRECATED", "message": "OTP authentication deprecated. Use POST /auth/login with phone number and password. Email remains optional profile field."})

@router.post("/register", response_model=TokenResponse)
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    # Validate mobile 10 digits already done by schema, but double-check
    mobile = payload.mobile.strip()
    if not re.fullmatch(r"\d{10}", mobile):
        raise HTTPException(status_code=400, detail={"code": "INVALID_MOBILE", "message": "Mobile must be 10 digits"})
    ok, msg = _is_strong_password(payload.password, mobile)
    if not ok:
        raise HTTPException(status_code=400, detail={"code": "WEAK_PASSWORD", "message": msg})
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
    _check_rate_limit(mobile, db)
    user = db.query(User).filter(User.mobile == mobile).first()
    if not user or not user.hashed_password:
        _record_failed_attempt(mobile, db)
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
            demo_mobiles = {"9876543210", "9876543211", "9999999999", "9876500001"}
            if mobile in demo_mobiles:
                password_ok = True
    if not password_ok:
        _record_failed_attempt(mobile, db)
        # audit log failed login
        try:
            from app.services.audit_service import audit
            audit(db, user.id if user else None, "login_failed", "user", mobile, "invalid password")
            db.commit()
        except Exception:
            pass
        raise HTTPException(status_code=401, detail={"code": "INVALID_CREDENTIALS", "message": "Invalid mobile or password"})
    _clear_attempts(mobile, db)
    access = create_access_token(user.id, user.role)
    refresh = create_refresh_token(user.id, user.role)
    try:
        from app.services.audit_service import audit
        audit(db, user.id, "login_success", "user", user.id, f"role {user.role}")
        db.commit()
    except Exception:
        pass
    return TokenResponse(access_token=access, refresh_token=refresh, role=user.role, user_id=user.id)

@router.post("/verify-otp", deprecated=True)
def verify_otp(payload: VerifyOtpRequest, db: Session = Depends(get_db)):
    # DEPRECATED: OTP authentication removed - phone+password + JWT is the only auth
    raise HTTPException(status_code=410, detail={"code": "DEPRECATED", "message": "OTP authentication deprecated. Use POST /auth/login with phone number and password."})

@router.post("/refresh", response_model=TokenResponse)
def refresh(payload: RefreshRequest, db: Session = Depends(get_db)):
    try:
        data = decode_token(payload.refresh_token)
    except ValueError:
        raise HTTPException(status_code=401, detail={"code": "INVALID_TOKEN", "message": "Invalid refresh token"})
    if data.get("type") != "refresh":
        raise HTTPException(status_code=401, detail={"code": "INVALID_TOKEN", "message": "Invalid token type"})
    # check refresh token revocation
    from app.api.deps import is_revoked
    jti = data.get("jti")
    if jti and is_revoked(jti):
        raise HTTPException(status_code=401, detail={"code": "TOKEN_REVOKED", "message": "Refresh token revoked"})
    user_id = data.get("sub")
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=401, detail={"code": "USER_NOT_FOUND", "message": "User not found"})
    access = create_access_token(user.id, user.role)
    refresh_tok = create_refresh_token(user.id, user.role)
    return TokenResponse(access_token=access, refresh_token=refresh_tok, role=user.role, user_id=user.id)

@router.post("/logout")
def logout(user: User = Depends(get_current_user), credentials: HTTPAuthorizationCredentials = Depends(security), db: Session = Depends(get_db)):
    from app.api.deps import revoke_token
    token = credentials.credentials
    try:
        payload = decode_token(token)
        jti = payload.get("jti")
        exp = payload.get("exp")
        expires_at = None
        if exp:
            try:
                from datetime import datetime, timezone
                expires_at = datetime.fromtimestamp(exp, tz=timezone.utc)
            except Exception:
                expires_at = None
        if jti:
            revoke_token(jti, db, expires_at)
    except Exception:
        pass
    try:
        from app.services.audit_service import audit
        audit(db, user.id, "logout", "user", user.id, "revoked token")
        db.commit()
    except Exception:
        pass
    return {"message": "Logged out"}

@router.get("/me")
def me(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    return {"user": {"id": user.id, "mobile": user.mobile, "email": user.email, "role": user.role}, "farmer": farmer}
