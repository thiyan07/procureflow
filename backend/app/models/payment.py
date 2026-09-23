import uuid
from datetime import datetime
from sqlalchemy import String, DateTime, Float, ForeignKey
from sqlalchemy.orm import Mapped, mapped_column, relationship
from app.db.base import Base
import enum

class PaymentStatus(str, enum.Enum):
    PENDING = "PENDING"
    CALCULATED = "CALCULATED"
    APPROVED = "APPROVED"
    PROCESSING = "PROCESSING"
    PAID = "PAID"
    COMPLETED = "COMPLETED"  # alias for PAID for backward compat
    FAILED = "FAILED"
    REVERSED = "REVERSED"
    ON_HOLD = "ON_HOLD"

class Payment(Base):
    __tablename__ = "payments"
    id: Mapped[str] = mapped_column(String, primary_key=True, default=lambda: str(uuid.uuid4()))
    booking_id: Mapped[str] = mapped_column(String, ForeignKey("bookings.id", ondelete="CASCADE"), unique=True, nullable=False)
    commodity: Mapped[str] = mapped_column(String(50), nullable=False)
    quantity_quintal: Mapped[float] = mapped_column(Float, nullable=False)
    rate_per_quintal: Mapped[float] = mapped_column(Float, nullable=False)
    total_amount: Mapped[float] = mapped_column(Float, nullable=False)
    gross_amount: Mapped[float | None] = mapped_column(Float, nullable=True)
    deductions: Mapped[float | None] = mapped_column(Float, nullable=True, default=0)
    net_payable: Mapped[float | None] = mapped_column(Float, nullable=True)
    payment_method: Mapped[str | None] = mapped_column(String(30), nullable=True, default="BANK_TRANSFER")
    reference_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    status: Mapped[str] = mapped_column(String(20), default=PaymentStatus.PENDING.value)
    transaction_id: Mapped[str | None] = mapped_column(String(100), nullable=True)
    payment_date: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=datetime.utcnow, onupdate=datetime.utcnow)
