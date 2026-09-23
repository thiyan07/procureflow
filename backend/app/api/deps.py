from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.core.security import decode_token
from app.models.user import User

security = HTTPBearer()

# In-memory fallback for dev (when DB not available) - kept for low-cost deploy
_revoked_jti: set[str] = set()

def revoke_token(jti: str, db: Session | None = None, expires_at=None) -> None:
    _revoked_jti.add(jti)
    if db is not None:
        try:
            from app.models.auth_security import RevokedToken
            from datetime import datetime, timezone
            # Persist to PostgreSQL so survives restart
            existing = db.get(RevokedToken, jti)
            if not existing:
                rt = RevokedToken(jti=jti, expires_at=expires_at)
                db.add(rt)
                db.commit()
        except Exception:
            pass  # fallback to memory

def is_revoked(jti: str, db: Session | None = None) -> bool:
    if jti in _revoked_jti:
        return True
    if db is not None:
        try:
            from app.models.auth_security import RevokedToken
            existing = db.get(RevokedToken, jti)
            if existing:
                _revoked_jti.add(jti)
                return True
        except Exception:
            pass
    return False

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security), db: Session = Depends(get_db)) -> User:
    token = credentials.credentials
    try:
        payload = decode_token(token)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail={"code": "INVALID_TOKEN", "message": "Invalid token"})
    if payload.get("type") != "access":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail={"code": "INVALID_TOKEN", "message": "Invalid token type"})
    jti = payload.get("jti")
    if jti and is_revoked(jti, db):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail={"code": "TOKEN_REVOKED", "message": "Token has been revoked. Please login again."})
    user_id = payload.get("sub")
    user = db.get(User, user_id)
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail={"code": "USER_NOT_FOUND", "message": "User not found"})
    return user

def require_roles(*roles: str):
    def _check(user: User = Depends(get_current_user)):
        if user.role not in roles:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail={"code": "FORBIDDEN", "message": "Insufficient permissions"})
        return user
    return _check
