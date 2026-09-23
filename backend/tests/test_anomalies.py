import os
os.environ["DATABASE_URL"] = "sqlite:///:memory:"
os.environ["JWT_SECRET"] = "test-secret-for-ci-at-least-32-chars-long-123"

from datetime import date, time
import uuid
import pytest
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.db.base import Base
import app.models  # noqa: F401 ensure models registered
from app.main import app
from app.db.session import get_db as orig_get_db
from fastapi.testclient import TestClient

from app.models.procurement_centre import ProcurementCentre
from app.models.slot import Slot
from app.models.queue import QueueToken, QueueStatus
from app.models.booking import Booking
from app.models.farmer import Farmer
from app.models.user import User


@pytest.fixture(scope="module")
def client_empty():
    # isolated memory DB with StaticPool so TestClient threads share same DB
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
    Base.metadata.create_all(bind=engine)

    def override():
        db = SessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[orig_get_db] = override
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.pop(orig_get_db, None)


def test_thresholds_deterministic_empty(client_empty):
    r = client_empty.get("/api/v1/analytics/anomalies", params={"centre_id": "c1"})
    assert r.status_code == 200
    j = r.json()
    assert j["thresholds"]["capacity"] == 0.85
    assert j["thresholds"]["congestion"] == 20
    assert j["thresholds"]["no_show"] == 0.15
    assert j["is_synthetic"] is True
    # synthetic c1 should trigger all three
    assert any(a["type"] == "CAPACITY_WARNING" for a in j["anomalies"])
    assert any(a["type"] == "CONGESTION" for a in j["anomalies"])
    assert any(a["type"] == "NO_SHOW_ANOMALY" for a in j["anomalies"])
    assert len(j["capacityWarnings"]) > 0
    assert j["congestion"]["level"] == "HIGH"
    assert j["occupancy"] == 0.91  # synthetic map for c1
    assert j["farmers_ahead"] == 24
    assert j["no_show_rate"] == 0.18


def test_anomalies_with_real_data():
    engine = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)
    Base.metadata.create_all(bind=engine)

    def override():
        db = SessionLocal()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[orig_get_db] = override
    client = TestClient(app)

    db = SessionLocal()
    c1 = ProcurementCentre(
        id="c1",
        name="Bhavani RM",
        location="Bhavani",
        district="Erode",
        lat=11.44,
        lng=77.68,
        status="Open",
        is_active=True,
        active_counters=3,
        avg_processing_minutes=3,
        open_time=time(9, 0),
        close_time=time(17, 0),
    )
    db.add(c1)
    db.commit()
    today = date.today()
    s1 = Slot(id=str(uuid.uuid4()), centre_id="c1", date=today, start_time=time(10, 0), end_time=time(10, 30), capacity=20, booked=19, status="AVAILABLE")
    s2 = Slot(id=str(uuid.uuid4()), centre_id="c1", date=today, start_time=time(11, 0), end_time=time(11, 30), capacity=20, booked=18, status="AVAILABLE")
    db.add_all([s1, s2])
    user = User(id="u1", mobile="9999999999", hashed_password="hash", role="FARMER")
    db.add(user)
    db.commit()
    farmer = Farmer(id="f1", farmer_id="FARM001", full_name="Test", mobile="9999999999", village="Bhavani", district="Erode", language_code="en", primary_commodity="Paddy", user_id="u1")
    db.add(farmer)
    db.commit()

    # 25 waiting => congestion >20
    for i in range(25):
        bk = Booking(id=str(uuid.uuid4()), farmer_id="f1", centre_id="c1", slot_id=s1.id, commodity_name="Paddy", estimated_quantity=10, token_number=f"T{i}", date=today, status="CONFIRMED")
        db.add(bk)
        db.commit()
        qt = QueueToken(id=str(uuid.uuid4()), centre_id="c1", booking_id=bk.id, token_number=f"T{i}", position=i, status=QueueStatus.WAITING.value)
        db.add(qt)
        db.commit()
    # 5 no-show => 5/30 ≈16% >15%
    for i in range(5):
        bk = Booking(id=str(uuid.uuid4()), farmer_id="f1", centre_id="c1", slot_id=s1.id, commodity_name="Paddy", estimated_quantity=10, token_number=f"NS{i}", date=today, status="CONFIRMED")
        db.add(bk)
        db.commit()
        qt = QueueToken(id=str(uuid.uuid4()), centre_id="c1", booking_id=bk.id, token_number=f"NS{i}", position=30+i, status=QueueStatus.NO_SHOW.value)
        db.add(qt)
        db.commit()
    # duplicate token
    bk1 = Booking(id=str(uuid.uuid4()), farmer_id="f1", centre_id="c1", slot_id=s1.id, commodity_name="Paddy", estimated_quantity=10, token_number="DUP", date=today, status="CONFIRMED")
    bk2 = Booking(id=str(uuid.uuid4()), farmer_id="f1", centre_id="c1", slot_id=s1.id, commodity_name="Paddy", estimated_quantity=10, token_number="DUP", date=today, status="CONFIRMED")
    db.add_all([bk1, bk2])
    db.commit()
    qt1 = QueueToken(id=str(uuid.uuid4()), centre_id="c1", booking_id=bk1.id, token_number="DUP", position=100, status=QueueStatus.WAITING.value)
    qt2 = QueueToken(id=str(uuid.uuid4()), centre_id="c1", booking_id=bk2.id, token_number="DUP", position=101, status=QueueStatus.WAITING.value)
    db.add_all([qt1, qt2])
    db.commit()

    r = client.get("/api/v1/analytics/anomalies", params={"centre_id": "c1"})
    assert r.status_code == 200
    j = r.json()
    assert j["is_synthetic"] is False
    assert any(a["type"] == "CAPACITY_WARNING" for a in j["anomalies"])
    assert any(a["type"] == "CONGESTION" for a in j["anomalies"])
    assert any(a["type"] == "NO_SHOW_ANOMALY" for a in j["anomalies"])
    assert any(a["type"] == "DUPLICATE_TOKEN" for a in j["anomalies"])
    assert j["occupancy"] > 0.85
    assert j["farmers_ahead"] > 20
    assert j["no_show_rate"] > 0.15
    assert j["congestion"]["level"] == "HIGH"

    app.dependency_overrides.pop(orig_get_db, None)
