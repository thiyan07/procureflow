import uuid
import json
from datetime import datetime, date
from sqlalchemy import String, DateTime, Date, Float, ForeignKey, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
import enum

class BookingStatus(str, enum.Enum):
    CONFIRMED = "CONFIRMED"
    CANCELLED = "CANCELLED"

class Booking(Base):
    __tablename__ = "bookings"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    farmer_id: Mapped[str] = mapped_column(String, ForeignKey("farmers.id", ondelete="CASCADE"), index=True, nullable=False)
    centre_id: Mapped[str] = mapped_column(String, ForeignKey("procurement_centres.id"), nullable=False)
    slot_id: Mapped[str] = mapped_column(String, ForeignKey("slots.id"), nullable=False)
    commodity_id: Mapped[str | None] = mapped_column(String, ForeignKey("commodities.id"), nullable=True)
    commodity_name: Mapped[str] = mapped_column(String(50), nullable=False)
    estimated_quantity: Mapped[float] = mapped_column(Float, nullable=False)
    # Multi-commodity JSON: [{"commodity":"Paddy","quantity":350,"unit":"kg"},...] — lightweight, avoids duplicate bookings
    commodities_json: Mapped[str | None] = mapped_column(Text, nullable=True)
    token_number: Mapped[str] = mapped_column(String(20), nullable=False)
    date: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[str] = mapped_column(String(20), default=BookingStatus.CONFIRMED.value)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    @property
    def commodities(self) -> list[dict]:
        if self.commodities_json:
            try:
                return json.loads(self.commodities_json)
            except:
                return []
        return [{"commodity": self.commodity_name, "quantity": self.estimated_quantity, "unit": "quintal"}]

    farmer = relationship("Farmer", back_populates="bookings")
    centre = relationship("ProcurementCentre", back_populates="bookings")
    slot = relationship("Slot", back_populates="bookings")
    # QueueToken is linked via QueueToken.booking_id -> Booking.id (one-to-one). Keep as viewonly to avoid FK cycle issues.
    queue_token = relationship("QueueToken", foreign_keys="QueueToken.booking_id", primaryjoin="Booking.id==QueueToken.booking_id", uselist=False, viewonly=True)
    procurement = relationship("Procurement", back_populates="booking", uselist=False)
