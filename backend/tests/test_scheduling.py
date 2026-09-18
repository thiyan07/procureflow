import pytest
from datetime import date, time, datetime, timezone, timedelta
from types import SimpleNamespace

from app.services.scheduling_service import SlotCandidate, compute_scheduling, get_recommendation, calculate_wait

def make_centre(active_counters=3, avg_processing=3, status="Open", is_active=True):
    return SimpleNamespace(
        open_time=time(9,0), close_time=time(17,0),
        status=status, is_active=is_active,
        active_counters=active_counters, avg_processing_minutes=avg_processing
    )

def make_slot(date_, start, end, capacity=20, booked=0, sid="s1"):
    return SimpleNamespace(id=sid, centre_id="c1", date=date_, start_time=start, end_time=end, capacity=capacity, booked=booked, status="AVAILABLE")

def test_case1_eligible():
    centre = make_centre()
    slot = make_slot(date(2026,9,18), time(10,30), time(11,0), 20, 5)
    candidates = [SlotCandidate(slot, centre)]
    eligible = compute_scheduling(candidates, centre, date(2026,9,18), "Paddy", 10, now=datetime(2026,9,17, tzinfo=timezone.utc))
    assert len(eligible)==1

def test_case2_full_rejected():
    centre = make_centre()
    slot = make_slot(date(2026,9,18), time(10,30), time(11,0), 20, 20)
    candidates = [SlotCandidate(slot, centre)]
    eligible = compute_scheduling(candidates, centre, date(2026,9,18), "Paddy", 10, now=datetime(2026,9,17, tzinfo=timezone.utc))
    assert len(eligible)==0

def test_case3_past_rejected():
    centre = make_centre()
    slot = make_slot(date(2026,9,17), time(9,0), time(9,30), 20, 0)
    candidates = [SlotCandidate(slot, centre)]
    eligible = compute_scheduling(candidates, centre, date(2026,9,17), "Paddy", 10, now=datetime(2026,9,18, tzinfo=timezone.utc))
    assert len(eligible)==0

def test_case4_centre_closed():
    centre = make_centre(status="Closed")
    slot = make_slot(date(2026,9,18), time(10,30), time(11,0), 20, 0)
    candidates = [SlotCandidate(slot, centre)]
    eligible = compute_scheduling(candidates, centre, date(2026,9,18), "Paddy", 10, now=datetime(2026,9,17, tzinfo=timezone.utc))
    assert len(eligible)==0

def test_case5_high_congestion_lower_score():
    centre = make_centre()
    low = make_slot(date(2026,9,18), time(14,0), time(14,30), 20, 2, "s_low")
    high = make_slot(date(2026,9,18), time(10,0), time(10,30), 20, 18, "s_high")
    candidates = [SlotCandidate(high, centre), SlotCandidate(low, centre)]
    eligible = compute_scheduling(candidates, centre, date(2026,9,18), "Paddy", 10, now=datetime(2026,9,17, tzinfo=timezone.utc))
    assert eligible[0].slot.id == "s_low"

def test_case6_low_congestion_higher_priority():
    centre = make_centre()
    slots = [make_slot(date(2026,9,18), time(9+i,0), time(9+i,30), 20, booked=i*2, sid=f"s{i}") for i in range(4)]
    candidates = [SlotCandidate(s, centre) for s in slots]
    eligible = compute_scheduling(candidates, centre, date(2026,9,18), "Paddy", 10, now=datetime(2026,9,17, tzinfo=timezone.utc))
    assert eligible[0].slot.booked <= eligible[-1].slot.booked

def test_case7_large_quantity_load():
    centre = make_centre()
    slot = make_slot(date(2026,9,18), time(10,30), time(11,0), 20, 5)
    cand_small = SlotCandidate(slot, centre)
    cand_large = SlotCandidate(make_slot(date(2026,9,18), time(10,30), time(11,0),20,5,"s2"), centre)
    r_small = compute_scheduling([cand_small], centre, date(2026,9,18), "Paddy", 5, now=datetime(2026,9,17, tzinfo=timezone.utc))
    r_large = compute_scheduling([cand_large], centre, date(2026,9,18), "Paddy", 50, now=datetime(2026,9,17, tzinfo=timezone.utc))
    assert r_large[0].score > r_small[0].score

def test_case8_no_active_counters_safe():
    assert calculate_wait(10, 3, 0) == 30  # uses 1 as fallback
    assert calculate_wait(0, 3, 0) == 0

def test_case9_no_available_slots():
    centre = make_centre()
    slots = [make_slot(date(2026,9,18), time(9+i,0), time(9+i,30), 20, 20, sid=f"s{i}") for i in range(3)]
    candidates = [SlotCandidate(s, centre) for s in slots]
    eligible = compute_scheduling(candidates, centre, date(2026,9,18), "Paddy", 10, now=datetime(2026,9,17, tzinfo=timezone.utc))
    best, alts, wait, reason = get_recommendation(eligible)
    assert best is None
    assert reason == "No available slots"

def test_case10_deterministic_tie():
    centre = make_centre()
    s1 = make_slot(date(2026,9,18), time(10,0), time(10,30),20,5,"a")
    s2 = make_slot(date(2026,9,18), time(10,0), time(10,30),20,5,"b")
    c1 = compute_scheduling([SlotCandidate(s1, centre), SlotCandidate(s2, centre)], centre, date(2026,9,18), "Paddy", 10, now=datetime(2026,9,17, tzinfo=timezone.utc))
    c2 = compute_scheduling([SlotCandidate(s2, centre), SlotCandidate(s1, centre)], centre, date(2026,9,18), "Paddy", 10, now=datetime(2026,9,17, tzinfo=timezone.utc))
    # deterministic by id
    assert c1[0].slot.id == c2[0].slot.id
