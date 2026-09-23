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
import math
from typing import List, Optional, Tuple

from app.core.config import get_settings

settings = get_settings()

# Farmer village/district approximate coordinates (deterministic, no external APIs)
# Centroids for Tamil Nadu districts + village aliases used in seed data.
DISTRICT_COORDS: dict[str, tuple[float, float]] = {
    "erode": (11.3400, 77.7172),
    "coimbatore": (11.0168, 76.9558),
    "tiruppur": (11.1085, 77.3411),
    "salem": (11.6643, 78.1460),
    "namakkal": (11.2189, 78.1679),
    "karur": (10.9602, 78.0766),
    "dharmapuri": (12.1278, 78.1582),
    "nilgiris": (11.4102, 76.7037),
    "dindigul": (10.3673, 77.9803),
    "trichy": (10.7905, 78.7047),
    "tiruchirappalli": (10.7905, 78.7047),
    "madurai": (9.9252, 78.1198),
    "chennai": (13.0827, 80.2707),
    # village-level overrides from seed / mock DB (approx to nearest centre)
    "bhavani": (11.4475, 77.6815),
    "kavindapadi": (11.4480, 77.6820),
    "kanjikoil": (11.2760, 77.5860),
    "perundurai": (11.2760, 77.5860),
    "sathyamangalam": (11.5054, 77.2380),
    "sathy": (11.5054, 77.2380),
    "gobichettipalayam": (11.4536, 77.4383),
    "gobi": (11.4536, 77.4383),
    "thindal": (11.3400, 77.7172),
    "erode firka": (11.3400, 77.7172),
}


def haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Great-circle distance in km between two lat/lng points, deterministic."""
    r = 6371.0
    dlat = math.radians(lat2 - lat1)
    dlng = math.radians(lng2 - lng1)
    a = math.sin(dlat / 2) ** 2 + math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlng / 2) ** 2
    c = 2 * math.asin(math.sqrt(a))
    return r * c


def get_farmer_coords(district: str | None, village: str | None) -> tuple[float, float] | None:
    """Resolve farmer approx coords from village then district; deterministic fallback."""
    # village first (more specific)
    for key in [village or "", district or ""]:
        if not key:
            continue
        k = key.strip().lower()
        # direct match
        if k in DISTRICT_COORDS:
            return DISTRICT_COORDS[k]
        # substring match (e.g. "Kavindapadi (Bhavani Firka)" contains "kavindapadi")
        for coord_key, coords in DISTRICT_COORDS.items():
            if coord_key in k or k in coord_key:
                return coords
    return DISTRICT_COORDS.get("erode")

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
                       now: Optional[datetime] = None,
                       farmer_past_count: int = 0,
                       farmer_distance_km: Optional[float] = None,
                       farmer_commodity_match: bool = False) -> List[SlotCandidate]:
    now = now or datetime.now(timezone.utc)
    # Pre-compute farmer boost multiplicative factor (deterministic, <1 is boost)
    farmer_boost = 1.0
    if farmer_past_count >= 3:
        farmer_boost *= 0.80
    elif farmer_past_count >= 2:
        farmer_boost *= 0.85
    elif farmer_past_count >= 1:
        farmer_boost *= 0.90
    if farmer_commodity_match:
        farmer_boost *= 0.92
    distance_factor = 1.0
    if farmer_distance_km is not None:
        if farmer_distance_km < 15:
            distance_factor = 0.90
        elif farmer_distance_km < 30:
            distance_factor = 0.95
        elif farmer_distance_km < 50:
            distance_factor = 0.98
        elif farmer_distance_km > 80:
            distance_factor = 1.08
        else:
            distance_factor = 1.02
        farmer_boost *= distance_factor
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

        base_score = availability_score * congestion_score * load_score * time_score * buffer_penalty
        # farmer-aware boost (lower score = better)
        cand.score = base_score * farmer_boost
        cand.debug = {
            "availability": round(availability_score, 3),
            "congestion": round(congestion_score, 3),
            "quantity_factor": round(quantity_factor, 3),
            "load": round(load_score, 3),
            "time_pref": round(time_score, 3),
            "buffer_penalty": round(buffer_penalty, 3),
            "base_score": round(base_score, 4),
            "farmer_boost": round(farmer_boost, 3),
            "farmer_past_count": farmer_past_count,
            "farmer_distance_km": round(farmer_distance_km, 1) if farmer_distance_km is not None else None,
            "farmer_commodity_match": farmer_commodity_match,
            "distance_factor": round(distance_factor, 3) if farmer_distance_km is not None else 1.0,
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
        # Farmer-aware personalized suffix (deterministic, shown in UI chip)
        if farmer_past_count > 0 or farmer_commodity_match or (farmer_distance_km is not None and farmer_distance_km < 30):
            parts = []
            if farmer_past_count > 0:
                parts.append(f"past {farmer_past_count} booking{'s' if farmer_past_count!=1 else ''} at {centre.name.split(' - ')[-1] if ' - ' in centre.name else centre.name}")
            if farmer_commodity_match:
                parts.append(f"{commodity} match")
            if farmer_distance_km is not None and farmer_distance_km < 30:
                parts.append(f"{round(farmer_distance_km,1)} km away")
            if parts:
                cand.reason += " Recommended for you (" + ", ".join(parts) + ")."

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
