# Security — ProcureFlow Real (2026-09-19)

**JWT:** `core/security.py` `JWT HS256 30m access 7d refresh` `python-jose` `passlib bcrypt` (for OTP mock), `create_access_token` `sub=user.id` `exp` `iat`, `deps.get_current_user` `Authorization: Bearer <token>` `401` if missing `403` if role insufficient `require_roles` `FARMER/CENTRE_OPERATOR/ADMIN`.

**Password Hashing:** `MockOTPProvider` `otp_fixed_code 123456` dev, `passlib bcrypt` for `otp_fixed_code` not password (spec §2 password hashing not needed for OTP flow, but `passlib` available for future `password`).

**RBAC:** `UserRole FARMER/CENTRE_OPERATOR/ADMIN` (mapped `CENTRE_MANAGER/DISTRICT_ADMIN/SYSTEM_ADMIN` → `ADMIN`), `bookings.py:152` `farmer.user_id==user.id` or `OPERATOR/ADMIN` else `403`, `queue.py:99` `is_owner||is_operator`, `procurement.py:31` same, `farmers.py:24` `mobile must match` unless `ADMIN`, `centres PATCH 403 farmer` `centres.py:75`, `feedback status` `OPERATOR/ADMIN` only, `payments` `OPERATOR/ADMIN` only.

**API Authorization Tests:** `curl POST /auth/verify-otp` `200` `GET /bookings/{other_bid}` `farmer A` → `403` `unauth 401` `operator 200` verified `final_verify.py`.

**CORS:** `core/config.py` `cors_origins http://localhost:3000,5173` `app.main.py` `CORSMiddleware allow_origins cors_origins_list or ["*"]` `allow_credentials True`.

**SQL Injection:** `psycopg` `sqlalchemy` `Session query` `filter(Booking.centre_id==centre_id)` parameterized, no `text` with f-string, `CheckConstraint` `booked<=capacity` prevents injection.

**Input Validation:** `pydantic` `BookingCreate` `centre_id str` `slot_id str` `commodity str` `estimated_quantity float >0` `CommodityItem quantity 0-500` `grade A/B/C` `moisture 0-30` `FeedbackCreate category delay/quality/payment/other` `len(description)>=5`, `FormValidators` `mobile 10 digits` `otp 6 digits` Flutter `TextFormField validator`.

**Rate Limiting:** Not explicit `slowapi` but `safety_buffer 2` `CheckConstraint` + `with_for_update` prevents overbooking, `otp_max_attempts 3` `otp_expiry 5m` in `otp_service`.

**Secret Management:** `.env` `database_url` `jwt_secret` `fcm_project_id/client_email/private_key` `otp_fixed_code` — **never committed** `.env.example` empty `FCM_PROJECT_ID=` `JWT_SECRET=change-me`, `.gitignore` `*.env` `__pycache__` `*.pyc`, `audit_service` redacts `password/jwt/token/private_key/secret` `details[:1000]` `[REDACTED]`.

**Error Leakage:** `generic_handler` `500 INTERNAL_ERROR` `log.exception` server logs technical, client gets `{"error":{"code":"INTERNAL_ERROR","message":"Something went wrong"}}` not stack trace, `ApiClient _errorMessage` parses `detail.message` else `Request failed (400)`.

**Sensitive Logging:** `audit_logs` `details` truncated `1000` redacted, `FCM` `token[:10]...` not full, `uvicorn` `X-Request-ID` `user_id` not `JWT`.

**Multi-user Isolation:** `Farmer A` `bookings` `farmer_id` `FARM-A-001` vs `Farmer B` `FARM-B-001` `operator` sees `GET /queue/centre/c1` `14` but `farmer A` `GET /bookings/{bidB}` `403`, verified `final_verify.py` `farmer A access B 403` `farmer B access own 200`.

**Device Integration:** `adb reverse tcp:8000` `V2338` `POST /auth/send-otp 200` from device verified `uvicorn.log`.

