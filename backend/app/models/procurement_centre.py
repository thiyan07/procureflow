import uuid
from datetime import datetime, time
from sqlalchemy import String, DateTime, Float, Integer, Time, Boolean
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base

class ProcurementCentre(Base):
    __tablename__ = "procurement_centres"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    location: Mapped[str] = mapped_column(String(255), nullable=False)
    district: Mapped[str] = mapped_column(String(100), nullable=False)
    lat: Mapped[float] = mapped_column(Float, nullable=False, default=0)
    lng: Mapped[float] = mapped_column(Float, nullable=False, default=0)
    status: Mapped[str] = mapped_column(String(20), default="Open")  # Open, Closed, Busy
    active_counters: Mapped[int] = mapped_column(Integer, default=3)
    avg_processing_minutes: Mapped[int] = mapped_column(Integer, default=3)
    open_time: Mapped[time] = mapped_column(Time, default=time(9, 0))
    close_time: Mapped[time] = mapped_column(Time, default=time(17, 0))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    slots = relationship("Slot", back_populates="centre", cascade="all, delete-orphan")
    bookings = relationship("Booking", back_populates="centre")
