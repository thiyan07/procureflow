import logging
import uuid
from contextvars import ContextVar

request_id_ctx: ContextVar[str] = ContextVar("request_id", default="-")
user_id_ctx: ContextVar[str] = ContextVar("user_id", default="-")

class RequestContextFilter(logging.Filter):
    def filter(self, record):  # type: ignore
        record.request_id = request_id_ctx.get()
        record.user_id = user_id_ctx.get()
        return True

def setup_logging():
    logging.basicConfig(
        level=logging.INFO,
        format="%(asctime)s | %(levelname)s | req=%(request_id)s user=%(user_id)s | %(name)s | %(message)s",
    )
    root = logging.getLogger()
    for h in root.handlers:
        h.addFilter(RequestContextFilter())

def new_request_id() -> str:
    rid = uuid.uuid4().hex[:12]
    request_id_ctx.set(rid)
    return rid
