import uuid
from datetime import datetime, date, time
from sqlalchemy import String, Date, Time, Integer, DateTime, ForeignKey, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
import enum

class SlotStatus(str, enum.Enum):
    AVAILABLE = "AVAILABLE"
    FULL = "FULL"
    CLOSED = "CLOSED"

class Slot(Base):
    __tablename__ = "slots"
    __table_args__ = (UniqueConstraint("centre_id", "date", "start_time", name="uq_slot_centre_date_time"),)
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    centre_id: Mapped[str] = mapped_column(String, ForeignKey("procurement_centres.id", ondelete="CASCADE"), index=True, nullable=False)
    date: Mapped[date] = mapped_column(Date, nullable=False, index=True)
    start_time: Mapped[time] = mapped_column(Time, nullable=False)
    end_time: Mapped[time] = mapped_column(Time, nullable=False)
    capacity: Mapped[int] = mapped_column(Integer, default=20, nullable=False)
    booked: Mapped[int] = mapped_column(Integer, default=0, nullable=False)
    status: Mapped[str] = mapped_column(String(20), default=SlotStatus.AVAILABLE.value)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    centre = relationship("ProcurementCentre", back_populates="slots")
    bookings = relationship("Booking", back_populates="slot")

    @property
    def available(self) -> int:
        return self.capacity - self.booked
