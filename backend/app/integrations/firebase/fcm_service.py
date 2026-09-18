import logging
from typing import Optional
from app.core.config import get_settings

settings = get_settings()
log = logging.getLogger(__name__)

class FCMService:
    """Thin wrapper. In dev without credentials, logs and returns mock success."""

    def __init__(self):
        self._initialized = False
        self._app = None

    def _ensure_init(self):
        if self._initialized:
            return self._app is not None
        if not settings.fcm_project_id or not settings.fcm_private_key:
            log.info("FCM not configured - running in mock mode")
            self._initialized = True
            return False
        try:
            import firebase_admin
            from firebase_admin import credentials
            cred_dict = {
                "type": "service_account",
                "project_id": settings.fcm_project_id,
                "client_email": settings.fcm_client_email,
                "private_key": settings.fcm_private_key.replace("\\n", "\n"),
                "token_uri": "https://oauth2.googleapis.com/token",
            }
            cred = credentials.Certificate(cred_dict)
            self._app = firebase_admin.initialize_app(cred)
            self._initialized = True
            return True
        except Exception as e:
            log.warning(f"FCM init failed, mock mode: {e}")
            self._initialized = True
            return False

    def send_to_token(self, token: str, title: str, body: str, data: Optional[dict] = None) -> bool:
        if not self._ensure_init():
            log.info(f"[FCM-MOCK] to={token[:10]}... title={title} body={body} data={data}")
            return True
        try:
            from firebase_admin import messaging
            msg = messaging.Message(
                notification=messaging.Notification(title=title, body=body),
                token=token,
                data={k: str(v) for k, v in (data or {}).items()},
            )
            resp = messaging.send(msg, app=self._app)
            log.info(f"FCM sent {resp} to {token[:10]}")
            return True
        except Exception as e:
            log.error(f"FCM send failed: {e}")
            return False

fcm_service = FCMService()
