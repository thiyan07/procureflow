from sqlalchemy.orm import DeclarativeBase

class Base(DeclarativeBase):
    pass

# Ensure all models are imported so Base.metadata includes them
# Order matters: notification (DeviceToken) before user, etc.
try:
    import app.models.notification  # noqa: F401
    import app.models.user  # noqa: F401
    import app.models.farmer  # noqa: F401
    import app.models.commodity  # noqa: F401
    import app.models.procurement_centre  # noqa: F401
    import app.models.slot  # noqa: F401
    import app.models.booking  # noqa: F401
    import app.models.queue  # noqa: F401
    import app.models.procurement  # noqa: F401
    import app.models.payment  # noqa: F401
    import app.models.feedback  # noqa: F401
    import app.models.auth_security  # noqa: F401 revoked_tokens, login_attempts persistence
except Exception:
    pass
