"""
Deterministic rule-based scheduling engine.

Rules (as per spec):
1. Reject full slots.
2. Outside operating hours -> rejected (slots generated within hours).
3. Prefer lower occupancy.
4. Avoid concentrating large quantities in same slot.
5. Consider processing capacity (avg_processing * quantity factor).
6. Consider active counters.
7. Safety buffer respected.
8. No duplicate active bookings (checked at booking service).
9. No past slots.
10. Capacity protected at DB transaction level (booking service).

Scoring (explainable):
slot_score = availability_score * congestion_score * processing_load_score * time_preference_score
Lower score = better. But we return ranking where lower is more recommended.

We implement deterministic weights and tie-breaking by start_time.
"""
from datetime import datetime, date, time, timezone
from typing import List, Optional, Tuple

from app.core.config import get_settings

settings = get_settings()

class SlotCandidate:
    def __init__(self, slot, centre):
        self.slot = slot
        self.centre = centre
        self.score: float = 0
        self.reason: str = ""
        self.debug: dict = {}
        self.eligible: bool = True
        self.rejection_reason: str = ""

def compute_scheduling(slot_candidates: List[SlotCandidate],
                       centre,
                       target_date: date,
                       commodity: str,
                       estimated_quantity: float,
                       now: Optional[datetime] = None) -> List[SlotCandidate]:
    now = now or datetime.now(timezone.utc)
    # Filter.
    for cand in slot_candidates:
        slot = cand.slot
        # RULE 9: past
        slot_dt = datetime.combine(slot.date, slot.start_time, tzinfo=timezone.utc)
        if slot_dt < now:
            cand.eligible = False
            cand.rejection_reason = "Slot in the past"
            continue
        # RULE 1: full
        if slot.booked >= slot.capacity:
            cand.eligible = False
            cand.rejection_reason = "Slot full"
            continue
        # RULE 2: outside operating hours
        if slot.start_time < centre.open_time or slot.end_time > centre.close_time:
            cand.eligible = False
            cand.rejection_reason = "Outside operating hours"
            continue
        # RULE: centre closed
        if centre.status == "Closed" or not centre.is_active:
            cand.eligible = False
            cand.rejection_reason = "Centre closed"
            continue
        # RULE 7: safety buffer
        available = slot.capacity - slot.booked
        if available <= settings.scheduler_safety_buffer and slot.capacity > settings.scheduler_safety_buffer:
            # still eligible but penalized heavily; if buffer is strict we could reject last slots
            pass

        # Compute scores
        # availability_score: booked/capacity (0..1) lower is better
        availability_score = slot.booked / slot.capacity if slot.capacity else 1

        # congestion: occupancy penalized; also number ahead influences wait
        congestion_score = 0.5 + availability_score  # 0.5..1.5

        # processing_load: quantity factor - large quantity adds load
        # Assume 10 quintal baseline; per extra quintal 2% increase
        quantity_factor = 1 + max(0, (estimated_quantity - 10) * 0.02)
        # active counters reduce load
        counters = centre.active_counters if centre.active_counters > 0 else 1
        load_score = quantity_factor / counters  # larger counters => smaller score

        # time preference: mid-day peak penalized slightly; deterministic
        # slots at 10:30-11:30 considered moderate
        hour = slot.start_time.hour
        if 10 <= hour <= 11:
            time_score = 1.1
        elif 13 <= hour <= 14:
            time_score = 0.95  # prefer post-lunch lower load
        else:
            time_score = 1.0

        # Safety buffer penalty
        if available <= settings.scheduler_safety_buffer:
            buffer_penalty = 1.3
        elif available <= settings.scheduler_safety_buffer + 2:
            buffer_penalty = 1.1
        else:
            buffer_penalty = 1.0

        cand.score = availability_score * congestion_score * load_score * time_score * buffer_penalty
        cand.debug = {
            "availability": round(availability_score, 3),
            "congestion": round(congestion_score, 3),
            "quantity_factor": round(quantity_factor, 3),
            "load": round(load_score, 3),
            "time_pref": round(time_score, 3),
            "buffer_penalty": round(buffer_penalty, 3),
            "score": round(cand.score, 4),
            "available": available,
            "booked": slot.booked,
            "capacity": slot.capacity,
        }
        # Reason: explain best factor
        if availability_score < 0.3:
            cand.reason = "Lower expected centre load."
        elif availability_score < 0.6:
            cand.reason = "Moderate load — balanced availability."
        else:
            cand.reason = "Higher load — consider alternative slot."
        if estimated_quantity > 20:
            cand.reason += " Large quantity considered."

    eligible = [c for c in slot_candidates if c.eligible]
    # Sort by score ascending, then start_time deterministic tie-break, then id
    eligible.sort(key=lambda c: (c.score, c.slot.start_time, c.slot.id))
    return eligible

def get_recommendation(eligible_sorted: List[SlotCandidate]) -> Tuple[Optional[SlotCandidate], List[SlotCandidate], int, str]:
    if not eligible_sorted:
        return None, [], 0, "No available slots"
    best = eligible_sorted[0]
    alternatives = eligible_sorted[1:4]
    # expected wait: (position proxy) = booked count ahead in that slot? For simplicity use booked * avg_processing / counters
    centre = best.centre
    counters = centre.active_counters if centre.active_counters > 0 else 1
    est = int((best.slot.booked * centre.avg_processing_minutes) / counters) if counters else best.slot.booked * centre.avg_processing_minutes
    # add small for quantity
    if best.slot.booked == 0:
        est = 2
    reason = best.reason
    return best, alternatives, est, reason

def calculate_wait(farmers_ahead: int, avg_processing: int, active_counters: int) -> int:
    if farmers_ahead <= 0:
        return 0
    counters = active_counters if active_counters > 0 else 1  # avoid division by zero
    base = (farmers_ahead * avg_processing) / counters
    return int(base) if base.is_integer() else int(base) + 1  # ceil
