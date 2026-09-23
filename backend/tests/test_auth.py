from app.core.security import create_access_token, decode_token, create_refresh_token, get_password_hash, verify_password
from fastapi.testclient import TestClient
from app.main import app

def test_jwt():
    tok = create_access_token("u1", "FARMER")
    data = decode_token(tok)
    assert data["sub"] == "u1"
    assert data["role"] == "FARMER"

def test_refresh():
    tok = create_refresh_token("u1", "FARMER")
    data = decode_token(tok)
    assert data["type"] == "refresh"

def test_password_hash():
    pwd = "SecurePass123"
    hashed = get_password_hash(pwd)
    assert verify_password(pwd, hashed) is True
    assert verify_password("wrong", hashed) is False

def test_otp_deprecated():
    # OTP authentication deprecated - phone+password + JWT is the only auth
    # /send-otp and /verify-otp must return 410 Gone
    client = TestClient(app)
    r1 = client.post("/api/v1/auth/send-otp", json={"mobile": "9876543210"})
    assert r1.status_code == 410
    assert r1.json()["detail"]["code"] == "DEPRECATED"
    r2 = client.post("/api/v1/auth/verify-otp", json={"mobile": "9876543210", "otp": "123456"})
    assert r2.status_code == 410
