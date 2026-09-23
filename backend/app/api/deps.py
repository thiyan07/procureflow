from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.core.security import decode_token
from app.models.user import User

security = HTTPBearer()

# In-memory revoked jti set for logout (single-instance; for multi-instance use Redis/DB)
_revoked_jti: set[str] = set()

def revoke_token(jti: str) -> None:
    _revoked_jti.add(jti)

def is_revoked(jti: str) -> bool:
    return jti in _revoked_jti

def get_current_user(credentials: HTTPAuthorizationCredentials = Depends(security), db: Session = Depends(get_db)) -> User:
    token = credentials.credentials
    try:
        payload = decode_token(token)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail={"code": "INVALID_TOKEN", "message": "Invalid token"})
    if payload.get("type") != "access":
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail={"code": "INVALID_TOKEN", "message": "Invalid token type"})
    jti = payload.get("jti")
    if jti and is_revoked(jti):
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
