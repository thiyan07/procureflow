import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional

from jose import jwt, JWTError

from app.core.config import get_settings

settings = get_settings()

# Use bcrypt directly to avoid passlib+bcrypt 5.x incompatibility (passlib 1.7.4)
# Fallback to passlib if bcrypt not available
try:
    import bcrypt as _bcrypt

    # Patch for passlib compatibility if still used elsewhere: ensure __about__ exists
    if not hasattr(_bcrypt, "__about__"):
        _bcrypt.__about__ = type("obj", (), {"__version__": _bcrypt.__version__})  # type: ignore

    _use_bcrypt_direct = True
except ImportError:
    _use_bcrypt_direct = False
    from passlib.context import CryptContext

    pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def create_access_token(subject: str, role: str, expires_delta: Optional[timedelta] = None) -> str:
    expire = datetime.now(timezone.utc) + (expires_delta or timedelta(minutes=settings.jwt_access_token_expire_minutes))
    payload = {"sub": subject, "role": role, "exp": expire, "jti": str(uuid.uuid4()), "type": "access"}
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def create_refresh_token(subject: str, role: str) -> str:
    expire = datetime.now(timezone.utc) + timedelta(days=settings.jwt_refresh_token_expire_days)
    payload = {"sub": subject, "role": role, "exp": expire, "jti": str(uuid.uuid4()), "type": "refresh"}
    return jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)


def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.jwt_secret, algorithms=[settings.jwt_algorithm])
    except JWTError as e:
        raise ValueError(str(e))


def verify_password(plain: str, hashed: str) -> bool:
    if _use_bcrypt_direct:
        try:
            import bcrypt as _bc

            return _bc.checkpw(plain.encode("utf-8")[:72], hashed.encode("utf-8"))
        except Exception:
            return False
    return pwd_context.verify(plain, hashed)  # type: ignore


def get_password_hash(password: str) -> str:
    if _use_bcrypt_direct:
        import bcrypt as _bc

        # bcrypt only uses first 72 bytes; truncate to avoid ValueError
        salt = _bc.gensalt()
        return _bc.hashpw(password.encode("utf-8")[:72], salt).decode("utf-8")
    return pwd_context.hash(password)  # type: ignore
