import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Float
from sqlalchemy.orm import Mapped, mapped_column
from app.db.base import Base

class Commodity(Base):
    __tablename__ = "commodities"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    code: Mapped[str] = mapped_column(String(20), unique=True, nullable=False)
    rate_per_quintal: Mapped[float] = mapped_column(Float, default=2200)
    is_active: Mapped[bool] = mapped_column(default=True)  # type: ignore
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
