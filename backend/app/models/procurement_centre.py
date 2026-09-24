import uuid
from datetime import datetime, time
from sqlalchemy import String, DateTime, Float, Integer, Time, Boolean, Text, Table, Column, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base

# Association table for centre <-> commodity many-to-many
centre_commodities = Table(
    "centre_commodities",
    Base.metadata,
    Column("centre_id", String, ForeignKey("procurement_centres.id", ondelete="CASCADE"), primary_key=True),
    Column("commodity_id", String, ForeignKey("commodities.id", ondelete="CASCADE"), primary_key=True),
)

class ProcurementCentre(Base):
    __tablename__ = "procurement_centres"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    centre_code: Mapped[str | None] = mapped_column(String(20), nullable=True, unique=True, index=True)
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    location: Mapped[str] = mapped_column(String(255), nullable=False)
    address: Mapped[str | None] = mapped_column(Text, nullable=True)
    district: Mapped[str] = mapped_column(String(100), nullable=False)
    lat: Mapped[float] = mapped_column(Float, nullable=False, default=0, index=True)
    lng: Mapped[float] = mapped_column(Float, nullable=False, default=0, index=True)
    phone: Mapped[str | None] = mapped_column(String(15), nullable=True)
    contact_person: Mapped[str | None] = mapped_column(String(100), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default="Open")  # Open, Closed, Busy, Emergency
    active_counters: Mapped[int] = mapped_column(Integer, default=3)
    avg_processing_minutes: Mapped[int] = mapped_column(Integer, default=3)
    daily_capacity: Mapped[int | None] = mapped_column(Integer, nullable=True, default=120)
    open_time: Mapped[time] = mapped_column(Time, default=time(9, 0))
    close_time: Mapped[time] = mapped_column(Time, default=time(17, 0))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    slots = relationship("Slot", back_populates="centre", cascade="all, delete-orphan")
    bookings = relationship("Booking", back_populates="centre")
    commodities = relationship("Commodity", secondary=centre_commodities, backref="centres", lazy="selectin")
