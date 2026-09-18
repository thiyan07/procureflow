from app.db.base import Base
from app.db.session import engine

# Import all models so Alembic sees them
import app.models.user  # noqa: F401
import app.models.farmer  # noqa: F401
import app.models.procurement_centre  # noqa: F401
import app.models.commodity  # noqa: F401
import app.models.slot  # noqa: F401
import app.models.booking  # noqa: F401
import app.models.queue  # noqa: F401
import app.models.procurement  # noqa: F401
import app.models.payment  # noqa: F401
import app.models.notification  # noqa: F401

def init_db():
    Base.metadata.create_all(bind=engine)
