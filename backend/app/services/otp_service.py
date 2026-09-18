from abc import ABC, abstractmethod
from datetime import datetime, timedelta, timezone
from typing import Dict, Tuple
from app.core.config import get_settings

settings = get_settings()

class OTPProvider(ABC):
    @abstractmethod
    def send_otp(self, mobile: str) -> str:
        pass

    @abstractmethod
    def verify_otp(self, mobile: str, otp: str) -> bool:
        pass

class MockOTPProvider(OTPProvider):
    """Development OTP provider - stores in memory, uses fixed code."""

    def __init__(self):
        self._store: Dict[str, Tuple[str, datetime]] = {}

    def send_otp(self, mobile: str) -> str:
        code = settings.otp_fixed_code
        expiry = datetime.now(timezone.utc) + timedelta(minutes=settings.otp_expiry_minutes)
        self._store[mobile] = (code, expiry)
        # Do not log OTP in production; dev logging only with marker
        if settings.is_dev:
            print(f"[MockOTP] mobile={mobile} otp={code} (dev only)")
        return code

    def verify_otp(self, mobile: str, otp: str) -> bool:
        entry = self._store.get(mobile)
        if not entry:
            # allow fixed code even if not sent (for dev convenience)
            return otp == settings.otp_fixed_code
        code, expiry = entry
        if datetime.now(timezone.utc) > expiry:
            del self._store[mobile]
            return False
        if otp == code:
            del self._store[mobile]
            return True
        return False

# Singleton
_otp_provider: OTPProvider = MockOTPProvider()

def get_otp_provider() -> OTPProvider:
    return _otp_provider
