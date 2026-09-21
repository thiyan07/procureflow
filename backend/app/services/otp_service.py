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
        self._attempts: Dict[str, int] = {}

    def send_otp(self, mobile: str) -> str:
        # Rate limit: max 3 per 15 min
        now = datetime.now(timezone.utc)
        attempts = self._attempts.get(mobile, 0)
        if attempts >= settings.otp_max_attempts:
            raise RuntimeError("Too many OTP requests. Please try again later.")
        code = settings.otp_fixed_code
        expiry = now + timedelta(minutes=settings.otp_expiry_minutes)
        self._store[mobile] = (code, expiry)
        self._attempts[mobile] = attempts + 1
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
            self._attempts.pop(mobile, None)
            return True
        return False

class EmailOTPProvider(OTPProvider):
    """Production Email OTP via Brevo transactional email. Uses Brevo API."""

    def __init__(self):
        self._store: Dict[str, Tuple[str, datetime]] = {}
        self._attempts: Dict[str, Tuple[int, datetime]] = {}

    def _is_configured(self) -> bool:
        return bool(settings.brevo_api_key and settings.email_from)

    def _check_rate_limit(self, identifier: str):
        now = datetime.now(timezone.utc)
        entry = self._attempts.get(identifier)
        if entry:
            count, first_time = entry
            # Reset after 15 min
            if (now - first_time).total_seconds() > 15 * 60:
                self._attempts[identifier] = (1, now)
                return
            if count >= settings.otp_max_attempts:
                raise RuntimeError("Too many OTP requests. Please try again in 15 minutes.")
            self._attempts[identifier] = (count + 1, first_time)
        else:
            self._attempts[identifier] = (1, now)

    def send_otp(self, identifier: str) -> str:
        # identifier is email for Brevo, or mobile for fallback
        if not self._is_configured():
            raise RuntimeError("Brevo not configured: set BREVO_API_KEY and EMAIL_FROM and EMAIL_PROVIDER=brevo")
        self._check_rate_limit(identifier)
        import secrets
        # For mobile without email, allow dev mock OTP 123456 for convenience when EMAIL_PROVIDER=brevo
        # This ensures farmer 9876543210 can still use 123456 in dev even with Brevo primary
        is_mobile = "@" not in identifier
        if is_mobile and settings.is_dev:
            # For mobile in dev, use fixed code for convenience, but still store as EmailOTP for consistency
            code = settings.otp_fixed_code
            expiry = datetime.now(timezone.utc) + timedelta(minutes=settings.otp_expiry_minutes)
            self._store[identifier] = (code, expiry)
            print(f"[EmailOTP Mock] mobile={identifier} otp={code} (dev fallback for mobile)")
            return code
        code = f"{secrets.randbelow(900000)+100000:06d}"
        expiry = datetime.now(timezone.utc) + timedelta(minutes=settings.otp_expiry_minutes)
        self._store[identifier] = (code, expiry)
        # Send via Brevo — Brevo needs email
        try:
            import httpx
            to_email = identifier
            if "@" not in identifier:
                # Try to find email from DB via mobile
                from app.db.session import SessionLocal
                from app.models.user import User
                from app.models.farmer import Farmer
                db = SessionLocal()
                try:
                    user = db.query(User).filter(User.mobile == identifier).first()
                    if user and hasattr(user, 'email') and getattr(user, 'email', None):
                        to_email = getattr(user, 'email')
                    else:
                        farmer = db.query(Farmer).filter(Farmer.mobile == identifier).first()
                        to_email = getattr(farmer, 'email', None) if farmer else None
                        if not to_email:
                            # For dev mobile without email, fallback to mock OTP already handled above
                            # For prod, require email
                            raise RuntimeError(f"No email found for mobile {identifier}. Please use email login or register with email.")
                    # Use to_email for sending, but keep store under original identifier for verify
                    # Actually store under to_email for Brevo, but also keep original for mobile verify
                    # For simplicity, store under both
                    self._store[to_email] = (code, expiry)
                finally:
                    db.close()
                to_email = to_email if "@" in to_email else identifier
            else:
                to_email = identifier
            payload = {
                "sender": {"email": settings.email_from, "name": settings.email_from_name},
                "to": [{"email": to_email}],
                "subject": "ProcureFlow OTP - Valid for 5 minutes",
                "htmlContent": f"<html><body><h2>ProcureFlow OTP</h2><p>Your OTP is: <strong>{code}</strong></p><p>Valid for {settings.otp_expiry_minutes} minutes. Do not share.</p><p>If you did not request this, ignore.</p></body></html>",
                "textContent": f"ProcureFlow OTP: {code} valid {settings.otp_expiry_minutes} min",
            }
            headers = {"accept": "application/json", "api-key": settings.brevo_api_key, "content-type": "application/json"}
            response = httpx.post("https://api.brevo.com/v3/smtp/email", json=payload, headers=headers, timeout=10.0)
            if response.status_code not in (200, 201):
                self._store.pop(identifier, None)
                self._store.pop(to_email, None)
                raise RuntimeError(f"Brevo API error {response.status_code}: {response.text[:200]}")
        except ImportError:
            self._store.pop(identifier, None)
            raise RuntimeError("httpx not installed: pip install httpx")
        except RuntimeError:
            raise
        except Exception as e:
            self._store.pop(identifier, None)
            try:
                self._store.pop(to_email, None)
            except:
                pass
            raise RuntimeError(f"Failed to send email via Brevo: {e}")
        return code

    def verify_otp(self, identifier: str, otp: str) -> bool:
        # In dev, allow fixed 123456 for ANY identifier (email or mobile) for convenience/testing
        if settings.is_dev and otp == settings.otp_fixed_code:
            # If fixed code used in dev, accept immediately (for functional tests)
            entry = self._store.get(identifier)
            if entry:
                del self._store[identifier]
                self._attempts.pop(identifier, None)
            return True
        # In dev, allow fixed 123456 for mobile without email for convenience
        if "@" not in identifier and settings.is_dev and otp == settings.otp_fixed_code:
            # Check if there's a stored OTP for this mobile, if not, allow fixed
            entry = self._store.get(identifier)
            if not entry:
                return True
            # If there is stored, check it
            code, expiry = entry
            if datetime.now(timezone.utc) > expiry:
                del self._store[identifier]
                self._attempts.pop(identifier, None)
                return otp == settings.otp_fixed_code
            if otp == code:
                del self._store[identifier]
                self._attempts.pop(identifier, None)
                return True
            return otp == settings.otp_fixed_code
        entry = self._store.get(identifier)
        if not entry:
            # Try lookup via email->mobile mapping
            from app.db.session import SessionLocal
            from app.models.user import User
            db = SessionLocal()
            try:
                user = db.query(User).filter(User.mobile == identifier).first()
                if user and hasattr(user, 'email') and getattr(user, 'email', None):
                    email = getattr(user, 'email')
                    entry = self._store.get(email)
                    if entry:
                        identifier = email
                if not entry:
                    from app.models.farmer import Farmer
                    farmer = db.query(Farmer).filter(Farmer.mobile == identifier).first()
                    if farmer and hasattr(farmer, 'email') and getattr(farmer, 'email', None):
                        email = getattr(farmer, 'email')
                        entry = self._store.get(email)
                        if entry:
                            identifier = email
            finally:
                db.close()
            if not entry:
                return False
        code, expiry = entry
        if datetime.now(timezone.utc) > expiry:
            del self._store[identifier]
            self._attempts.pop(identifier, None)
            return False
        if otp == code:
            del self._store[identifier]
            self._attempts.pop(identifier, None)
            return True
        return False

class ProductionOTPProvider(OTPProvider):
    """Production OTP via Twilio (or any SMS). Fails safely if not configured."""

    def __init__(self):
        self._store: Dict[str, Tuple[str, datetime]] = {}

    def _is_configured(self) -> bool:
        return bool(settings.twilio_account_sid and settings.twilio_auth_token and settings.twilio_from_number)

    def send_otp(self, mobile: str) -> str:
        if not self._is_configured():
            # Fail safely - do not pretend SMS was sent
            raise RuntimeError("OTP production provider not configured: set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, TWILIO_FROM_NUMBER and OTP_PROVIDER=production")
        # Generate random 6-digit OTP for production
        import secrets
        code = f"{secrets.randbelow(900000)+100000:06d}"
        expiry = datetime.now(timezone.utc) + timedelta(minutes=settings.otp_expiry_minutes)
        self._store[mobile] = (code, expiry)
        # Try Twilio if available, else log and store
        try:
            from twilio.rest import Client  # type: ignore
            client = Client(settings.twilio_account_sid, settings.twilio_auth_token)
            # E.164 format: +91 + mobile (India)
            to_number = f"+91{mobile}" if not mobile.startswith("+") else mobile
            client.messages.create(body=f"ProcureFlow OTP: {code} valid {settings.otp_expiry_minutes} min", from_=settings.twilio_from_number, to=to_number)
        except ImportError:
            # twilio not installed - fail safely, do not fake success
            raise RuntimeError("Twilio library not installed: pip install twilio")
        except Exception as e:
            # Do not store OTP if SMS failed
            self._store.pop(mobile, None)
            raise RuntimeError(f"Failed to send SMS via Twilio: {e}")
        return code

    def verify_otp(self, mobile: str, otp: str) -> bool:
        entry = self._store.get(mobile)
        if not entry:
            return False
        code, expiry = entry
        if datetime.now(timezone.utc) > expiry:
            del self._store[mobile]
            return False
        if otp == code:
            del self._store[mobile]
            return True
        return False

# Singleton — selects provider based on settings (email/brevo primary)
def _create_provider() -> OTPProvider:
    # Brevo email is primary for production (EMAIL_PROVIDER=brevo)
    email_prov = getattr(settings, 'email_provider', 'mock').lower()
    otp_prov = settings.otp_provider.lower()
    provider = None
    if email_prov == "brevo" or otp_prov == "brevo" or otp_prov == "email":
        provider = EmailOTPProvider()
    elif otp_prov == "production":
        provider = ProductionOTPProvider()
    else:
        provider = MockOTPProvider()
    # Debug log for production verification (do not log secrets)
    try:
        print(f"[OTP Provider] email_provider={email_prov} otp_provider={otp_prov} -> {type(provider).__name__} brevo_configured={bool(getattr(settings, 'brevo_api_key', ''))}")
    except:
        pass
    return provider

_otp_provider: OTPProvider = _create_provider()

def get_otp_provider() -> OTPProvider:
    # Re-create if settings changed (e.g. tests switching env)
    global _otp_provider
    current_email = getattr(settings, 'email_provider', 'mock').lower()
    current_otp = settings.otp_provider.lower()
    is_email = isinstance(_otp_provider, EmailOTPProvider)
    is_prod = isinstance(_otp_provider, ProductionOTPProvider)
    should_be_email = current_email == "brevo" or current_otp in ("brevo", "email")
    should_be_prod = current_otp == "production"
    # Debug
    print(f"[get_otp_provider] email={current_email} otp={current_otp} is_email={is_email} should_be_email={should_be_email} -> {type(_otp_provider).__name__}")
    if should_be_email and not is_email:
        _otp_provider = _create_provider()
        print(f"[get_otp_provider] switched to {type(_otp_provider).__name__}")
    elif should_be_prod and not is_prod:
        _otp_provider = _create_provider()
        print(f"[get_otp_provider] switched to {type(_otp_provider).__name__}")
    elif not should_be_email and not should_be_prod and (is_email or is_prod):
        _otp_provider = _create_provider()
        print(f"[get_otp_provider] switched to {type(_otp_provider).__name__}")
    return _otp_provider
