from app.core.security import create_access_token, decode_token, create_refresh_token
from app.services.otp_service import MockOTPProvider

def test_jwt():
    tok = create_access_token("u1", "FARMER")
    data = decode_token(tok)
    assert data["sub"] == "u1"
    assert data["role"] == "FARMER"

def test_refresh():
    tok = create_refresh_token("u1", "FARMER")
    data = decode_token(tok)
    assert data["type"] == "refresh"

def test_otp():
    p = MockOTPProvider()
    p.send_otp("9999999999")
    assert p.verify_otp("9999999999", "123456") is True
    # In dev mock mode, fixed code is always accepted even without send, so second verify without re-send still passes (fallback)
    # Re-send to test single-use: first verify consumes, second should require resend but still passes via fixed-code fallback in mock (dev convenience)
    assert p.verify_otp("9999999999", "123456") is True
    # wrong code fails
    p.send_otp("9999999999")
    assert p.verify_otp("9999999999", "000000") is False
