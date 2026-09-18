import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Float, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
import enum

class ProcurementStage(str, enum.Enum):
    BOOKING_CONFIRMED = "BOOKING_CONFIRMED"
    ARRIVED = "ARRIVED"
    WEIGHMENT = "WEIGHMENT"
    QUALITY_CHECK = "QUALITY_CHECK"
    PROCUREMENT = "PROCUREMENT"
    COMPLETED = "COMPLETED"

class Procurement(Base):
    __tablename__ = "procurements"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    booking_id: Mapped[str] = mapped_column(String, ForeignKey("bookings.id", ondelete="CASCADE"), unique=True, nullable=False)
    stage: Mapped[str] = mapped_column(String(30), default=ProcurementStage.BOOKING_CONFIRMED.value)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)

    booking = relationship("Booking", back_populates="procurement")
    weighment = relationship("Weighment", back_populates="procurement", uselist=False, cascade="all, delete-orphan")
    quality_check = relationship("QualityCheck", back_populates="procurement", uselist=False, cascade="all, delete-orphan")
    events = relationship("ProcurementEvent", back_populates="procurement", cascade="all, delete-orphan")

class Weighment(Base):
    __tablename__ = "weighments"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    procurement_id: Mapped[str] = mapped_column(String, ForeignKey("procurements.id", ondelete="CASCADE"), unique=True, nullable=False)
    gross_weight: Mapped[float | None] = mapped_column(Float, nullable=True)
    net_weight: Mapped[float | None] = mapped_column(Float, nullable=True)
    weighment_time: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    operator_id: Mapped[str | None] = mapped_column(String, nullable=True)
    procurement = relationship("Procurement", back_populates="weighment")

class QualityCheck(Base):
    __tablename__ = "quality_checks"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    procurement_id: Mapped[str] = mapped_column(String, ForeignKey("procurements.id", ondelete="CASCADE"), unique=True, nullable=False)
    grade: Mapped[str | None] = mapped_column(String(20), nullable=True)  # A, B, C
    moisture_percent: Mapped[float | None] = mapped_column(Float, nullable=True)
    remarks: Mapped[str | None] = mapped_column(String(255), nullable=True)
    checked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    procurement = relationship("Procurement", back_populates="quality_check")

class ProcurementEvent(Base):
    __tablename__ = "procurement_events"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    procurement_id: Mapped[str] = mapped_column(String, ForeignKey("procurements.id", ondelete="CASCADE"), index=True, nullable=False)
    from_stage: Mapped[str | None] = mapped_column(String(30), nullable=True)
    to_stage: Mapped[str] = mapped_column(String(30), nullable=False)
    actor: Mapped[str | None] = mapped_column(String(50), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    procurement = relationship("Procurement", back_populates="events")

class AuditLog(Base):
    __tablename__ = "audit_logs"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    user_id: Mapped[str | None] = mapped_column(String, nullable=True)
    action: Mapped[str] = mapped_column(String(100), nullable=False)
    entity_type: Mapped[str | None] = mapped_column(String(50), nullable=True)
    entity_id: Mapped[str | None] = mapped_column(String, nullable=True)
    details: Mapped[str | None] = mapped_column(String(1000), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
