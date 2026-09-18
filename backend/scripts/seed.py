"""Seed development data - run with python -m scripts.seed or python scripts/seed.py"""
import uuid
from datetime import date, time, timedelta, datetime, timezone

from app.db.session import SessionLocal, engine
from app.db.base import Base
import app.models.user, app.models.farmer, app.models.procurement_centre, app.models.commodity, app.models.slot, app.models.booking, app.models.queue, app.models.procurement, app.models.payment, app.models.notification
from app.models.user import User, UserRole
from app.models.farmer import Farmer
from app.models.procurement_centre import ProcurementCentre
from app.models.commodity import Commodity
from app.models.slot import Slot
from app.models.booking import Booking, BookingStatus
from app.models.queue import QueueToken, QueueEvent, QueueStatus, CentreQueueState
from app.models.procurement import Procurement, ProcurementStage
from app.models.payment import Payment, PaymentStatus

def run():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    try:
        # Clear? Only if empty
        if db.query(ProcurementCentre).count() > 0:
            print("Already seeded, skipping")
            return
        # Real MSP as per Cabinet / PIB 2026-27 KMS (latest as of 2026-09-18)
        # Sources: PIB PRID 2260618 (2026-27, May 13 2026) + desagri.gov.in MSP Notifications Kharif 2026-27
        # Paddy Common Rs 2441 (+72), Grade A Rs 2461 (+72), Ragi Rs 4886, Maize Rs 2400 approx; Tur Rs 8000
        # Previous 2025-26 was 2369/2389 - now superseded
        comms = [
            Commodity(name="Paddy", code="PADDY", rate_per_quintal=2441),  # Common - most procured in Tamil Nadu DPCs - KMS 2026-27
            Commodity(name="Paddy Grade A", code="PADDY-A", rate_per_quintal=2461),  # KMS 2026-27
            Commodity(name="Ragi", code="RAGI", rate_per_quintal=4886),  # MSP 2025-26 KMS (unchanged ref)
            Commodity(name="Maize", code="MAIZE", rate_per_quintal=2400),
            Commodity(name="Pulses (Tur)", code="PULSES-TUR", rate_per_quintal=8000),
        ]
        for c in comms:
            db.add(c)
        db.flush()
        # Real TNCSC Direct Purchase Centres (DPC) - Erode district
        # Erode has 2 Revenue Divisions (Erode, Gobichettipalayam) & 10 Taluks per erode.nic.in
        # DPCs opened with Collector approval each season (Kuruvai Oct1-Dec15, Samba Dec16-Jul31)
        # Using live Regulatory Markets: Bhavani RM (Bhavani taluk, Gobichettipalayam division)
        # Perundurai RM (Perundurai taluk, Erode division), Sathyamangalam RM, Gobichettipalayam RM
        centres = [
            ProcurementCentre(id="c1", name="TNCSC DPC - Bhavani Regulatory Market", location="Bhavani Regulatory Market, Bhavani Taluk, Gobichettipalayam Division", district="Erode", lat=11.4475, lng=77.6815, status="Open", active_counters=3, avg_processing_minutes=3, open_time=time(9,0), close_time=time(17,0)),
            ProcurementCentre(id="c2", name="TNCSC DPC - Perundurai Regulatory Market", location="Perundurai Regulatory Market, Perundurai Taluk, Erode Division", district="Erode", lat=11.2760, lng=77.5860, status="Open", active_counters=2, avg_processing_minutes=4, open_time=time(9,0), close_time=time(17,0)),
            ProcurementCentre(id="c3", name="TNCSC DPC - Sathyamangalam Regulatory Market", location="Sathyamangalam Regulatory Market, Sathyamangalam Taluk, Gobichettipalayam Division", district="Erode", lat=11.5054, lng=77.2380, status="Busy", active_counters=4, avg_processing_minutes=3, open_time=time(9,0), close_time=time(17,0)),
            ProcurementCentre(id="c4", name="TNCSC DPC - Gobichettipalayam Regulatory Market", location="Gobichettipalayam Regulatory Market, Gobichettipalayam Taluk, Gobichettipalayam Division", district="Erode", lat=11.4536, lng=77.4383, status="Open", active_counters=3, avg_processing_minutes=3, open_time=time(9,0), close_time=time(17,0)),
        ]
        for c in centres:
            db.add(c)
        # Demo users/farmers
        u1 = User(id="u1", mobile="9876543210", role=UserRole.FARMER.value)
        u2 = User(id="op1", mobile="9876543211", role=UserRole.CENTRE_OPERATOR.value)
        uadmin = User(id="uadmin", mobile="9999999999", role=UserRole.ADMIN.value)
        db.add_all([u1, u2, uadmin])
        db.flush()
        # Real villages from Erode revenue divisions (erode.nic.in 375 villages): Bhavani (Kavindapadi), Perundurai (Kanjikoil)
        f1 = Farmer(id="f1", user_id=u1.id, full_name="Ravi Kumar", mobile="9876543210", farmer_id="FARM-2026-00127", village="Kavindapadi (Bhavani Firka)", district="Erode", language_code="en", primary_commodity="Paddy")
        f2 = Farmer(id="f2", user_id=str(uuid.uuid4()), full_name="Muthu Gounder", mobile="9876500001", farmer_id="FARM-2026-00128", village="Kanjikoil (Perundurai Taluk)", district="Erode", language_code="ta", primary_commodity="Ragi")
        # need user for f2
        u_f2 = User(id=f2.user_id, mobile=f2.mobile, role=UserRole.FARMER.value)
        db.add(u_f2)
        db.add_all([f1, f2])
        db.flush()
        # Slots for next 3 days
        today = date.today()
        times = [(9,0,9,30),(9,30,10,0),(10,0,10,30),(10,30,11,0),(11,0,11,30),(13,30,14,0),(14,0,14,30),(14,30,15,0)]
        for offset in range(3):
            d = today + timedelta(days=offset)
            for centre in centres:
                for idx,(sh,sm,eh,em) in enumerate(times):
                    cap = 20
                    booked = [5,3,12,2,8,2,5,12][idx] if offset==0 else 0
                    slot = Slot(centre_id=centre.id, date=d, start_time=time(sh,sm), end_time=time(eh,em), capacity=cap, booked=booked, status="AVAILABLE" if booked < cap else "FULL")
                    db.add(slot)
        db.flush()
        # Demo bookings
        # Find slot for c1 today 10:30
        slot = db.query(Slot).filter(Slot.centre_id=="c1", Slot.date==today, Slot.start_time==time(10,30)).first()
        if slot:
            b = Booking(id="b1", farmer_id=f1.id, centre_id="c1", slot_id=slot.id, commodity_name="Paddy", estimated_quantity=18.5, token_number="P27", date=today, status=BookingStatus.CONFIRMED.value)
            db.add(b)
            db.flush()
            qs = CentreQueueState(centre_id="c1", date=today.isoformat(), current_ordinal=15, next_ordinal=28)
            db.add(qs)
            qt = QueueToken(id=str(uuid.uuid4()), centre_id="c1", booking_id=b.id, token_number="P27", position=27, status=QueueStatus.WAITING.value, estimated_wait_minutes=32)
            db.add(qt)
            db.flush()
            db.add(QueueEvent(token_id=qt.id, from_status=None, to_status=QueueStatus.WAITING.value))
            db.add(Procurement(id=str(uuid.uuid4()), booking_id=b.id, stage=ProcurementStage.BOOKING_CONFIRMED.value))
            # MSP 2026-27 Paddy Common 2441 (latest Cabinet May 13 2026)
            db.add(Payment(id=str(uuid.uuid4()), booking_id=b.id, commodity="Paddy", quantity_quintal=18.5, rate_per_quintal=2441, total_amount=45158.5, status=PaymentStatus.PENDING.value))
        db.commit()
        print("Seed completed")
    finally:
        db.close()

if __name__ == "__main__":
    run()
