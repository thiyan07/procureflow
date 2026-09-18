import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Integer, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
import enum

class QueueStatus(str, enum.Enum):
    WAITING = "WAITING"
    CALLED = "CALLED"
    ARRIVED = "ARRIVED"
    PROCESSING = "PROCESSING"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"
    NO_SHOW = "NO_SHOW"
    ON_HOLD = "ON_HOLD"

class QueueToken(Base):
    __tablename__ = "queue_tokens"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    centre_id: Mapped[str] = mapped_column(String, ForeignKey("procurement_centres.id"), index=True, nullable=False)
    booking_id: Mapped[str] = mapped_column(String, ForeignKey("bookings.id", ondelete="CASCADE"), unique=True, nullable=False)
    token_number: Mapped[str] = mapped_column(String(20), nullable=False)  # P27
    position: Mapped[int] = mapped_column(Integer, nullable=False)
    status: Mapped[str] = mapped_column(String(20), default=QueueStatus.WAITING.value)
    estimated_wait_minutes: Mapped[int] = mapped_column(Integer, default=0)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    booking = relationship("Booking", foreign_keys="[QueueToken.booking_id]")
    events = relationship("QueueEvent", back_populates="token", cascade="all, delete-orphan", foreign_keys="[QueueEvent.token_id]")

class QueueEvent(Base):
    __tablename__ = "queue_events"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    token_id: Mapped[str] = mapped_column(String, ForeignKey("queue_tokens.id", ondelete="CASCADE"), index=True, nullable=False)
    from_status: Mapped[str | None] = mapped_column(String(20), nullable=True)
    to_status: Mapped[str] = mapped_column(String(20), nullable=False)
    actor: Mapped[str | None] = mapped_column(String(50), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)

    token = relationship("QueueToken", back_populates="events")

class CentreQueueState(Base):
    __tablename__ = "centre_queue_states"
    centre_id: Mapped[str] = mapped_column(String, ForeignKey("procurement_centres.id", ondelete="CASCADE"), primary_key=True)
    date: Mapped[str] = mapped_column(String(20), primary_key=True)  # YYYY-MM-DD
    current_ordinal: Mapped[int] = mapped_column(Integer, default=0)
    next_ordinal: Mapped[int] = mapped_column(Integer, default=1)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
