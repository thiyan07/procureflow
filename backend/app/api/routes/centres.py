from fastapi import APIRouter, Depends, HTTPException, Query, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.orm import Session
from sqlalchemy import func
from datetime import date, datetime, timezone
from app.db.session import get_db
from app.models.procurement_centre import ProcurementCentre
from app.models.slot import Slot
from app.models.queue import CentreQueueState
from app.schemas.centre import CentreOut, CentreStatusOut
from app.services.scheduling_service import calculate_wait, haversine, get_farmer_coords
from pydantic import BaseModel

security_optional = HTTPBearer(auto_error=False)

def get_optional_user(credentials: HTTPAuthorizationCredentials | None = Depends(security_optional), db: Session = Depends(get_db)):
    if credentials is None:
        return None
    token = credentials.credentials
    try:
        from app.core.security import decode_token
        from app.models.user import User
        payload = decode_token(token)
        if payload.get("type") != "access":
            return None
        user_id = payload.get("sub")
        user = db.get(User, user_id)
        return user
    except Exception:
        return None

router = APIRouter()

def _computed_status(c: ProcurementCentre, db: Session) -> str:
    # Dynamic status based on occupancy/queue, not hardcoded — respects manual Closed/Emergency
    if c.status in ("Closed", "Emergency") or not c.is_active:
        return c.status
    # Check occupancy and queue for Busy vs Open
    today = date.today()
    slots = db.query(Slot).filter(Slot.centre_id == c.id, Slot.date == today).all()
    total = sum(s.capacity for s in slots)
    used = sum(s.booked for s in slots)
    occ = used/total if total else 0
    from app.models.queue import QueueToken, QueueStatus
    qsize = db.query(QueueToken).filter(QueueToken.centre_id == c.id, QueueToken.status.in_([QueueStatus.WAITING.value, QueueStatus.CALLED.value])).count()
    # Busy if high occupancy or high queue
    if occ > 0.7 or qsize > 12:
        return "Busy"
    return "Open"

@router.get("/nearby", response_model=list[CentreOut])
def nearby_centres(
    lat: float = Query(..., description="Farmer latitude"),
    lng: float = Query(..., description="Farmer longitude"),
    radius_km: float = Query(20, ge=0.1, le=500, description="Search radius km"),
    commodity: str | None = Query(None, description="Filter by commodity name e.g. Paddy"),
    district: str | None = Query(None),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    # Real data: filter by commodity via M2M, district, distance via haversine, sort by distance
    q = db.query(ProcurementCentre).filter(ProcurementCentre.is_active == True)
    if district:
        q = q.filter(ProcurementCentre.district.ilike(f"%{district}%"))
    centres = q.all()
    # Commodity filter via M2M
    if commodity:
        from app.models.procurement_centre import centre_commodities
        from app.models.commodity import Commodity
        comm = db.query(Commodity).filter(Commodity.name.ilike(commodity)).first()
        if comm:
            # filter centres that have this commodity
            allowed_ids = {r[0] for r in db.query(centre_commodities.c.centre_id).filter(centre_commodities.c.commodity_id == comm.id).all()}
            centres = [c for c in centres if c.id in allowed_ids]
        else:
            # no such commodity -> empty
            centres = []
    # Compute distance and filter by radius
    out = []
    for c in centres:
        try:
            d = haversine(lat, lng, c.lat, c.lng)
        except Exception:
            d = 9999
        if d <= radius_km:
            c.status = _computed_status(c, db)
            # attach distance for response
            c.distance_km = round(d, 2)  # transient, not persisted
            # supported commodities
            try:
                c.supported_commodities = [com.name for com in (c.commodities or [])]
            except Exception:
                c.supported_commodities = []
            # remaining capacity today
            from datetime import date as _date
            today = _date.today()
            slots = db.query(Slot).filter(Slot.centre_id == c.id, Slot.date == today).all()
            total = sum(s.capacity for s in slots)
            used = sum(s.booked for s in slots)
            c.remaining_capacity_today = (total - used) if total else (c.daily_capacity or 120)
            out.append((d, c))
        # else skip
    out.sort(key=lambda x: x[0])
    result = [c for _, c in out[:limit]]
    return result

@router.get("", response_model=list[CentreOut])
def list_centres(
    lat: float | None = Query(None, description="Optional farmer lat for distance sort"),
    lng: float | None = Query(None, description="Optional farmer lng"),
    radius_km: float | None = Query(None, ge=0.1, le=500),
    commodity: str | None = Query(None),
    district: str | None = Query(None),
    limit: int | None = Query(None, ge=1, le=100),
    db: Session = Depends(get_db),
):
    # If nearby params provided, delegate to nearby logic for consistency
    if lat is not None and lng is not None:
        r = radius_km if radius_km is not None else 500
        lim = limit if limit is not None else 50
        return nearby_centres(lat=lat, lng=lng, radius_km=r, commodity=commodity, district=district, limit=lim, db=db)
    # Otherwise classic list with optional commodity/district filter
    q = db.query(ProcurementCentre).filter(ProcurementCentre.is_active == True)
    if district:
        q = q.filter(ProcurementCentre.district.ilike(f"%{district}%"))
    centres = q.all()
    if commodity:
        from app.models.procurement_centre import centre_commodities
        from app.models.commodity import Commodity
        comm = db.query(Commodity).filter(Commodity.name.ilike(commodity)).first()
        if comm:
            allowed_ids = {r[0] for r in db.query(centre_commodities.c.centre_id).filter(centre_commodities.c.commodity_id == comm.id).all()}
            centres = [c for c in centres if c.id in allowed_ids]
        else:
            centres = []
    for c in centres:
        c.status = _computed_status(c, db)
        try:
            c.supported_commodities = [com.name for com in (c.commodities or [])]
        except Exception:
            c.supported_commodities = []
        c.distance_km = None
        c.remaining_capacity_today = None
    if limit is not None:
        centres = centres[:limit]
    return centres

@router.get("/recommendations")
def recommend_centres(
    lat: float | None = Query(None, description="Farmer lat for distance scoring"),
    lng: float | None = Query(None),
    radius_km: float = Query(50, ge=0.1, le=500),
    commodity: str | None = Query(None),
    district: str | None = Query(None),
    estimated_quantity: float = Query(10, ge=0.1, le=500),
    limit: int = Query(10, ge=1, le=20),
    db: Session = Depends(get_db),
    current_user = Depends(get_optional_user),
):
    """
    Transparent multi-factor centre ranking:
    real-data-first — distance (haversine), queue size, estimated wait, occupancy, remaining capacity.
    Farmer history (past bookings at centre, commodity match, distance) as deterministic boost (<1 better).
    No ML hallucination: scores are explainable weighted sum, debug returned.
    If GPS missing → distance factor ignored (weight redistributed). If insufficient history → personalized boost 1.0.
    """
    from app.models.queue import QueueToken, QueueStatus
    from app.models.booking import Booking
    from app.models.farmer import Farmer
    from app.models.commodity import Commodity
    from app.models.procurement_centre import centre_commodities

    # Resolve farmer
    farmer = None
    try:
        if current_user is not None:
            farmer = db.query(Farmer).filter(Farmer.user_id == current_user.id).first()
            if not farmer:
                farmer = db.get(Farmer, current_user.id)
    except Exception:
        pass

    # Base query
    q = db.query(ProcurementCentre).filter(ProcurementCentre.is_active == True)
    if district:
        q = q.filter(ProcurementCentre.district.ilike(f"%{district}%"))
    centres = q.all()

    # Commodity pre-filter via M2M if supplied
    if commodity:
        comm = db.query(Commodity).filter(Commodity.name.ilike(commodity)).first()
        if comm:
            allowed = {r[0] for r in db.query(centre_commodities.c.centre_id).filter(centre_commodities.c.commodity_id == comm.id).all()}
            centres = [c for c in centres if c.id in allowed]
        else:
            centres = []  # no such commodity

    # Pre-compute for each centre
    ranked = []
    today = date.today()
    for c in centres:
        # distance
        dist = None
        if lat is not None and lng is not None:
            try:
                dist = haversine(lat, lng, c.lat, c.lng)
                if dist > radius_km:
                    continue
            except Exception:
                dist = None
        # else no GPS: keep centre (no radius filter)
        # queue
        qsize = db.query(QueueToken).filter(QueueToken.centre_id == c.id, QueueToken.status.in_([QueueStatus.WAITING.value, QueueStatus.CALLED.value, QueueStatus.ARRIVED.value])).count()
        wait = calculate_wait(qsize, c.avg_processing_minutes, c.active_counters)
        slots = db.query(Slot).filter(Slot.centre_id == c.id, Slot.date == today).all()
        total = sum(s.capacity for s in slots)
        used = sum(s.booked for s in slots)
        occ = used / total if total else 0.0
        remaining = (total - used) if total else (c.daily_capacity or 120)
        avail = sum(1 for s in slots if s.booked < s.capacity) if slots else (1 if c.status == "Open" else 0)
        # next slot
        next_slot = None
        for s in sorted(slots, key=lambda x: x.start_time):
            if s.booked < s.capacity and s.status != "CLOSED":
                next_slot = {"id": s.id, "start_time": str(s.start_time), "end_time": str(s.end_time), "available": s.capacity - s.booked}
                break

        # supports commodity?
        supports = True
        if commodity:
            try:
                names = [co.name.lower() for co in (c.commodities or [])]
                supports = commodity.lower() in names
            except Exception:
                supports = True

        # farmer factors
        farmer_past = 0
        farmer_dist = dist  # reuse haversine if we have user lat/lng; else fallback to village coords
        farmer_match = False
        if farmer:
            try:
                farmer_past = db.query(Booking).filter(Booking.farmer_id == farmer.id, Booking.centre_id == c.id, Booking.status != "CANCELLED").count()
                farmer_match = (farmer.primary_commodity or "").strip().lower() == (commodity or farmer.primary_commodity or "").strip().lower() if commodity else (farmer.primary_commodity or "").lower() in [co.lower() for co in [co.name for co in (c.commodities or [])]]
                # if lat/lng not provided, try village coords
                if dist is None:
                    coords = get_farmer_coords(farmer.district, farmer.village)
                    if coords:
                        farmer_dist = haversine(coords[0], coords[1], c.lat, c.lng)
            except Exception:
                pass

        # Normalized scores 0..1 lower better
        dist_norm = min(dist or 40, 80) / 80 if dist is not None else 0.5  # 0.5 neutral if no GPS
        queue_norm = min(qsize, 30) / 30
        wait_norm = min(wait, 60) / 60
        occ_norm = occ  # already 0-1
        # supports penalty
        support_penalty = 0 if supports else 1.0

        # weights: distance 0.30, queue 0.25, wait 0.15, occupancy 0.30 (adds to 1.0)
        # if no GPS, redistribute distance weight to queue/occ
        if dist is None:
            raw = 0.35 * queue_norm + 0.25 * wait_norm + 0.40 * occ_norm + support_penalty * 0.5
        else:
            raw = 0.30 * dist_norm + 0.25 * queue_norm + 0.15 * wait_norm + 0.30 * occ_norm + support_penalty * 0.5

        # farmer boost multiplicative (<1 better)
        boost = 1.0
        if farmer_past >= 3:
            boost *= 0.80
        elif farmer_past >= 2:
            boost *= 0.85
        elif farmer_past >= 1:
            boost *= 0.90
        if farmer_match:
            boost *= 0.92
        if farmer_dist is not None:
            if farmer_dist < 15:
                boost *= 0.90
            elif farmer_dist < 30:
                boost *= 0.95

        score = raw * boost
        # status penalty: closed/emergency hard reject, busy mild penalty
        status = _computed_status(c, db)
        if status in ("Closed", "Emergency"):
            score += 2.0  # push to bottom
        elif status == "Busy":
            score += 0.15

        # Reason transparent
        parts = []
        if dist is not None:
            parts.append(f"{dist:.1f}km")
        parts.append(f"Queue {qsize}")
        parts.append(f"Wait {wait}min")
        parts.append(f"{remaining} slots left")
        if farmer_past > 0:
            parts.append(f"past {farmer_past} at {c.name.split(' - ')[-1].split()[0] if ' - ' in c.name else c.name.split()[0]}")
        if farmer_match:
            parts.append(f"{commodity or farmer.primary_commodity} match")
        reason = " • ".join(parts)

        # Attach transient for serialization
        c.status = status
        c.distance_km = round(dist, 2) if dist is not None else None
        try:
            c.supported_commodities = [co.name for co in (c.commodities or [])]
        except Exception:
            c.supported_commodities = []
        c.remaining_capacity_today = remaining

        ranked.append({
            "centre": CentreOut.model_validate(c).model_dump(),
            "score": round(score, 4),
            "raw_score": round(raw, 4),
            "boost": round(boost, 3),
            "distance_km": round(dist, 2) if dist is not None else None,
            "queue_size": qsize,
            "estimated_wait_minutes": wait,
            "occupancy": round(occ, 2),
            "remaining_capacity": remaining,
            "available_slots": avail,
            "next_available_slot": next_slot,
            "status": status,
            "reason": reason,
            "debug": {
                "dist_norm": round(dist_norm, 3),
                "queue_norm": round(queue_norm, 3),
                "wait_norm": round(wait_norm, 3),
                "occ": round(occ, 3),
                "supports_commodity": supports,
                "farmer_past": farmer_past,
                "farmer_match": farmer_match,
                "farmer_dist": round(farmer_dist, 1) if farmer_dist is not None else None,
            },
        })

    ranked.sort(key=lambda x: (x["score"], x["distance_km"] if x["distance_km"] is not None else 999, x["centre"]["name"]))
    # limit
    result = ranked[:limit]
    # add top recommendation flag
    for i, r in enumerate(result):
        r["is_recommended"] = (i == 0 and r["score"] < 1.5)  # threshold to avoid recommending bad centres
    return {"count": len(result), "ranked": result, "query": {"lat": lat, "lng": lng, "radius_km": radius_km, "commodity": commodity, "estimated_quantity": estimated_quantity}}

@router.get("/{centre_id}", response_model=CentreOut)
def get_centre(centre_id: str, lat: float | None = Query(None), lng: float | None = Query(None), db: Session = Depends(get_db)):
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    c.status = _computed_status(c, db)
    try:
        c.supported_commodities = [com.name for com in (c.commodities or [])]
    except Exception:
        c.supported_commodities = []
    if lat is not None and lng is not None:
        try:
            c.distance_km = round(haversine(lat, lng, c.lat, c.lng), 2)
        except Exception:
            c.distance_km = None
    else:
        c.distance_km = None
    # remaining capacity today
    from datetime import date as _date
    today = _date.today()
    slots = db.query(Slot).filter(Slot.centre_id == c.id, Slot.date == today).all()
    total = sum(s.capacity for s in slots)
    used = sum(s.booked for s in slots)
    c.remaining_capacity_today = (total - used) if total else (c.daily_capacity or 120)
    return c

@router.get("/{centre_id}/commodities")
def get_centre_commodities(centre_id: str, db: Session = Depends(get_db)):
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    try:
        comms = c.commodities or []
    except Exception:
        comms = []
    return [{"id": co.id, "name": co.name, "code": co.code, "rate_per_quintal": co.rate_per_quintal} for co in comms]

@router.get("/{centre_id}/operational")
def get_centre_operational(centre_id: str, lat: float | None = Query(None), lng: float | None = Query(None), db: Session = Depends(get_db)):
    # Consolidated operational data for Phase 2: queue + capacity + slots + status + distance
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    # reuse existing helpers
    status_out = get_centre_status(centre_id, db)
    cap = centre_capacity(centre_id, None, db)
    # distance
    dist = None
    if lat is not None and lng is not None:
        try:
            dist = round(haversine(lat, lng, c.lat, c.lng), 2)
        except Exception:
            pass
    # next available slot today
    today = date.today()
    slots = db.query(Slot).filter(Slot.centre_id == centre_id, Slot.date == today).order_by(Slot.start_time).all()
    next_slot = None
    for s in slots:
        if s.booked < s.capacity and s.status != "CLOSED":
            next_slot = {"id": s.id, "start_time": str(s.start_time), "end_time": str(s.end_time), "available": s.capacity - s.booked}
            break
    return {
        "centre": CentreOut.model_validate(c).model_dump(),
        "status": status_out,
        "capacity": cap,
        "distance_km": dist,
        "next_available_slot": next_slot,
        "supported_commodities": [{"id": co.id, "name": co.name} for co in (c.commodities or [])],
    }

@router.get("/{centre_id}/status", response_model=CentreStatusOut)
def get_centre_status(centre_id: str, db: Session = Depends(get_db)):
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    today = date.today()
    # queue size: count queue tokens waiting/called
    from app.models.queue import QueueToken, QueueStatus
    from app.models.booking import Booking
    qsize = db.query(QueueToken).filter(QueueToken.centre_id == centre_id, QueueToken.status.in_([QueueStatus.WAITING.value, QueueStatus.CALLED.value, QueueStatus.ARRIVED.value])).count()
    # available slots today
    avail = db.query(Slot).filter(Slot.centre_id == centre_id, Slot.date == today, Slot.booked < Slot.capacity).count()
    est = calculate_wait(qsize, c.avg_processing_minutes, c.active_counters)
    is_open = c.status == "Open" and c.is_active and (c.open_time <= datetime.now().time() <= c.close_time)
    return CentreStatusOut(centre=c, is_open=is_open, current_queue_size=qsize, estimated_wait_minutes=est, active_counters=c.active_counters, available_slots=avail)

@router.get("/{centre_id}/dashboard")
def centre_dashboard(centre_id: str, db: Session = Depends(get_db)):
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    from app.models.queue import QueueToken, QueueStatus
    from app.models.procurement import Procurement, ProcurementStage
    from app.models.payment import Payment, PaymentStatus
    from app.models.booking import Booking, BookingStatus
    # Filter to today and exclude cancelled for accurate daily stats
    today = date.today()
    today_bookings = db.query(Booking).filter(Booking.centre_id==centre_id, Booking.date==today, Booking.status != BookingStatus.CANCELLED.value).all()
    today_bids = [b.id for b in today_bookings]
    # Queue counts for today only (join via booking date)
    if today_bids:
        total = db.query(QueueToken).filter(QueueToken.booking_id.in_(today_bids)).count()
        waiting = db.query(QueueToken).filter(QueueToken.booking_id.in_(today_bids), QueueToken.status==QueueStatus.WAITING.value).count()
        processing = db.query(QueueToken).filter(QueueToken.booking_id.in_(today_bids), QueueToken.status==QueueStatus.PROCESSING.value).count()
        completed = db.query(QueueToken).filter(QueueToken.booking_id.in_(today_bids), QueueToken.status==QueueStatus.COMPLETED.value).count()
        called = db.query(QueueToken).filter(QueueToken.booking_id.in_(today_bids), QueueToken.status==QueueStatus.CALLED.value).count()
        payment_pending = db.query(Payment).filter(Payment.booking_id.in_(today_bids), Payment.status==PaymentStatus.PENDING.value).count()
    else:
        total = waiting = processing = completed = called = payment_pending = 0
    # Fallback to all-time if today empty (for demo centres with bookings on other dates like tomorrow)
    if total == 0:
        all_bids = [b.id for b in db.query(Booking).filter(Booking.centre_id==centre_id, Booking.status != BookingStatus.CANCELLED.value).all()]
        if all_bids:
            total = db.query(QueueToken).filter(QueueToken.booking_id.in_(all_bids)).count()
            waiting = db.query(QueueToken).filter(QueueToken.booking_id.in_(all_bids), QueueToken.status==QueueStatus.WAITING.value).count()
            processing = db.query(QueueToken).filter(QueueToken.booking_id.in_(all_bids), QueueToken.status==QueueStatus.PROCESSING.value).count()
            completed = db.query(QueueToken).filter(QueueToken.booking_id.in_(all_bids), QueueToken.status==QueueStatus.COMPLETED.value).count()
            called = db.query(QueueToken).filter(QueueToken.booking_id.in_(all_bids), QueueToken.status==QueueStatus.CALLED.value).count()
            payment_pending = db.query(Payment).filter(Payment.booking_id.in_(all_bids), Payment.status==PaymentStatus.PENDING.value).count()
    # avg wait / processing - simple
    avg_wait = calculate_wait(waiting, c.avg_processing_minutes, c.active_counters) if waiting else 0
    return {"centre_id": centre_id, "centre_name": c.name, "today_farmers": total, "waiting": waiting, "processing": processing, "completed": completed, "called": called, "payment_pending": payment_pending, "avg_wait_minutes": avg_wait, "active_counters": c.active_counters}

class CentreUpdate(BaseModel):
    active_counters: int | None = None
    slot_capacity: int | None = None
    status: str | None = None
    is_active: bool | None = None
    closure_reason: str | None = None

@router.patch("/{centre_id}", response_model=CentreOut)
def update_centre(centre_id: str, payload: CentreUpdate, db: Session = Depends(get_db), user=Depends(__import__('app.api.deps', fromlist=['get_current_user']).get_current_user)):
    from app.models.user import User as U
    # require operator/admin
    if user.role not in ("CENTRE_OPERATOR", "ADMIN"):
        from fastapi import HTTPException as HE
        raise HE(status_code=403, detail={"code": "FORBIDDEN", "message": "Only operator/admin"})
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    if payload.active_counters is not None:
        if payload.active_counters < 0 or payload.active_counters > 10:
            raise HTTPException(status_code=400, detail={"code": "INVALID_COUNTERS", "message": "0-10"})
        c.active_counters = payload.active_counters
    if payload.slot_capacity is not None:
        if payload.slot_capacity < 5 or payload.slot_capacity > 50:
            raise HTTPException(status_code=400, detail={"code": "INVALID_CAPACITY", "message": "5-50"})
        # update today's slots capacity for centre
        today = date.today()
        for s in db.query(Slot).filter(Slot.centre_id == centre_id, Slot.date >= today).all():
            s.capacity = payload.slot_capacity
            if s.booked >= s.capacity:
                s.status = "FULL"
            else:
                s.status = "AVAILABLE"
    if payload.status is not None:
        if payload.status not in ("Open", "Closed", "Busy", "Emergency"):
            raise HTTPException(status_code=400, detail={"code": "INVALID_STATUS", "message": "Open/Closed/Busy/Emergency"})
        c.status = payload.status
        c.is_active = payload.status not in ("Closed","Emergency")
        # store closure reason if provided (lightweight: audit details + notification)
        if payload.closure_reason:
            from app.services.audit_service import audit as _audit
            _audit(db, user.id if hasattr(user,'id') else None, "centre_closure_reason", "procurement_centre", centre_id, payload.closure_reason[:200])
    if payload.is_active is not None:
        c.is_active = payload.is_active
    from app.services.audit_service import audit
    audit(db, user.id if hasattr(user,'id') else None, "centre_updated", "procurement_centre", centre_id, f"counters={payload.active_counters} cap={payload.slot_capacity} status={payload.status} reason={payload.closure_reason or ''}")
    # notify affected farmers if closed/emergency
    if payload.status in ("Closed","Emergency"):
        try:
            from app.models.booking import Booking as _B
            from app.models.queue import QueueToken as _QT, QueueStatus as _QS
            from app.services.notification_service import create_notification as _cn
            # find today's bookings for centre that are still CONFIRMED/WAITING
            today_bk = db.query(_B).filter(_B.centre_id==centre_id, _B.status=="CONFIRMED").all()
            for bk in today_bk[:5]:  # notify first 5 to avoid spam
                from app.models.farmer import Farmer as _F
                farmer = db.get(_F, bk.farmer_id)
                if farmer:
                    _cn(db, farmer.user_id, f"Centre {c.status}", f"{c.name} is {c.status.lower()}. {payload.closure_reason or ''} Alternative: consider nearby centre c2/c4.", "centre_closure", {"centre_id": centre_id, "booking_id": bk.id})
        except:
            pass
    db.commit()
    db.refresh(c)
    return c

@router.get("/{centre_id}/slot-recommendations")
def slot_recommendations(
    centre_id: str,
    date: date = Query(...),
    commodity_id: str | None = None,
    estimated_quantity: float = Query(10),
    farmer_id: str | None = Query(None, description="Optional farmer_id for explicit lookup; else derived from auth token"),
    db: Session = Depends(get_db),
    current_user = Depends(get_optional_user),
):
    from app.models.commodity import Commodity
    from app.models.farmer import Farmer
    from app.models.booking import Booking
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    commodity_name = "Paddy"
    if commodity_id:
        comm = db.get(Commodity, commodity_id)
        if comm:
            commodity_name = comm.name
        else:
            # try by name
            commodity_name = commodity_id
    # --- farmer-aware context (deterministic, no external APIs) ---
    farmer = None
    farmer_past_count = 0
    farmer_distance_km = None
    farmer_commodity_match = False
    farmer_context = None
    personalized_reason = None
    # Resolve farmer: prefer explicit farmer_id query, else auth token mapping user->farmer
    try:
        if farmer_id:
            farmer = db.get(Farmer, farmer_id)
            # also allow farmer_id as farmer farmer_id code like FARM-xxx
            if not farmer:
                farmer = db.query(Farmer).filter(Farmer.farmer_id == farmer_id).first()
        if not farmer and current_user is not None:
            farmer = db.query(Farmer).filter(Farmer.user_id == current_user.id).first()
            # fallback: if current_user.id itself is farmer.id (mock mode may store farmer id as user id)
            if not farmer:
                farmer = db.get(Farmer, current_user.id)
        if farmer:
            # past bookings count for that farmer per centre (exclude cancelled)
            farmer_past_count = db.query(Booking).filter(Booking.farmer_id == farmer.id, Booking.centre_id == centre_id, Booking.status != "CANCELLED").count()
            farmer_commodity_match = (farmer.primary_commodity or "").strip().lower() == commodity_name.strip().lower()
            coords = get_farmer_coords(farmer.district, farmer.village)
            if coords and c.lat is not None and c.lng is not None:
                farmer_distance_km = haversine(coords[0], coords[1], c.lat, c.lng)
            farmer_context = {
                "farmer_id": farmer.id,
                "farmer_code": farmer.farmer_id,
                "village": farmer.village,
                "district": farmer.district,
                "primary_commodity": farmer.primary_commodity,
                "past_bookings_at_centre": farmer_past_count,
                "distance_km": round(farmer_distance_km, 1) if farmer_distance_km is not None else None,
                "commodity_match": farmer_commodity_match,
                "centre_name": c.name,
            }
            # Build personalized chip text as required: "Recommended for you (past 2 bookings at Bhavani)"
            # Use short centre name (last part after ' - ')
            short_name = c.name.split(" - ")[-1] if " - " in c.name else c.name
            # shorten further to first word for chip consistency (e.g. Bhavani)
            short_word = short_name.split()[0] if short_name else c.name
            if farmer_past_count > 0:
                personalized_reason = f"Recommended for you (past {farmer_past_count} booking{'s' if farmer_past_count != 1 else ''} at {short_word})"
                if farmer_commodity_match:
                    personalized_reason += f" • {commodity_name} match"
                if farmer_distance_km is not None and farmer_distance_km < 30:
                    personalized_reason += f" • {round(farmer_distance_km,1)} km away"
            elif farmer_commodity_match or (farmer_distance_km is not None and farmer_distance_km < 30):
                parts = []
                if farmer_commodity_match:
                    parts.append(f"{commodity_name} match")
                if farmer_distance_km is not None and farmer_distance_km < 30:
                    parts.append(f"{round(farmer_distance_km,1)} km away")
                if parts:
                    personalized_reason = f"Recommended for you ({', '.join(parts)})"
    except Exception:
        # farmer-aware must never break generic flow
        pass

    slots = db.query(Slot).filter(Slot.centre_id == centre_id, Slot.date == date).all()
    from app.services.scheduling_service import SlotCandidate, compute_scheduling, get_recommendation
    candidates = [SlotCandidate(s, c) for s in slots]
    eligible = compute_scheduling(candidates, c, date, commodity_name, estimated_quantity, farmer_past_count=farmer_past_count, farmer_distance_km=farmer_distance_km, farmer_commodity_match=farmer_commodity_match)
    best, alts, wait, reason = get_recommendation(eligible)
    def to_out(slot):
        return {"id": slot.id, "centre_id": slot.centre_id, "date": slot.date, "start_time": slot.start_time, "end_time": slot.end_time, "capacity": slot.capacity, "booked": slot.booked, "available": slot.capacity - slot.booked, "status": slot.status}
    if not best:
        return {"recommended_slot": None, "expected_wait_minutes": 0, "reason": reason, "alternatives": [], "debug": {"eligible_count": 0}, "farmer_context": farmer_context, "personalized_reason": personalized_reason}
    # If personalized_reason exists, prefer it as main reason augmentation (still keep deterministic base reason)
    final_reason = personalized_reason if personalized_reason else reason
    # Ensure debug includes farmer info even if no farmer
    debug = best.debug.copy()
    debug["farmer_context"] = farmer_context
    return {
        "recommended_slot": to_out(best.slot),
        "expected_wait_minutes": wait,
        "reason": final_reason,
        "base_reason": reason,
        "personalized_reason": personalized_reason,
        "alternatives": [to_out(a.slot) for a in alts],
        "debug": debug,
        "farmer_context": farmer_context,
    }

@router.get("/{centre_id}/documents")
def centre_documents(centre_id: str, commodity: str = Query("Paddy"), db: Session = Depends(get_db)):
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    # Configurable checklist — demo-oriented, clearly marked
    base = [
        {"id":"farmer_id","label":"Farmer ID (FARM-*)","required":True,"description":"TNCSC Farmer ID"},
        {"id":"aadhaar","label":"Aadhaar","required":True,"description":"Identity proof"},
        {"id":"bank_passbook","label":"Bank passbook (for payment)","required":True,"description":"Payment credit"},
        {"id":"land_doc","label":"Land document (Patta/Chitta)","required":False,"description":"If required for verification"},
    ]
    # commodity-specific
    commodity_map = {
        "Paddy": [{"id":"paddy_sample","label":"Paddy sample (500g)","required":True,"description":"For moisture/quality check"}],
        "Ragi": [{"id":"ragi_sample","label":"Ragi sample","required":True,"description":"Sample"}],
        "Maize": [{"id":"maize_sample","label":"Maize sample","required":True}],
    }
    extra = commodity_map.get(commodity, [{"id":"sample","label":f"{commodity} sample","required":True}])
    docs = base + extra
    return {"centre_id": centre_id, "commodity": commodity, "documents": docs, "note": "Demo requirements — not official government list. Bring originals + photocopy."}

@router.get("/{centre_id}/capacity")
def centre_capacity(centre_id: str, target_date: date = Query(None), db: Session = Depends(get_db)):
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    d = target_date or date.today()
    slots = db.query(Slot).filter(Slot.centre_id==centre_id, Slot.date==d).all()
    total = sum(s.capacity for s in slots)
    used = sum(s.booked for s in slots)
    remaining = total - used if total else 0
    qsize = db.query(Slot).filter(Slot.centre_id==centre_id).count()  # dummy to use func?
    from app.models.queue import QueueToken, QueueStatus
    qsize = db.query(QueueToken).filter(QueueToken.centre_id==centre_id, QueueToken.status.in_([QueueStatus.WAITING.value, QueueStatus.CALLED.value])).count()
    occupancy = used/total if total else 0
    # warnings
    warnings=[]
    if occupancy > 0.85:
        warnings.append("Centre approaching capacity (>85%)")
    if occupancy > 0.95:
        warnings.append("Centre almost full (>95%) — consider alternative centre/slot")
    if qsize > 15:
        warnings.append(f"High queue ({qsize} farmers) — expect delay")
    if c.active_counters < 2:
        warnings.append("Too few active counters — waiting time high")
    return {"centre_id":centre_id,"date":str(d),"total_capacity":total,"used_capacity":used,"remaining_capacity":remaining,"occupancy":round(occupancy,2),"current_queue":qsize,"active_counters":c.active_counters,"warnings":warnings,"status":c.status}

@router.get("/{centre_id}/alerts")
def centre_alerts(centre_id: str, db: Session = Depends(get_db)):
    c = db.get(ProcurementCentre, centre_id)
    if not c:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Centre not found"})
    from app.models.queue import QueueToken, QueueStatus
    from app.models.booking import Booking
    from datetime import timedelta
    today = date.today()
    alerts=[]
    # queue exceeds threshold
    qsize = db.query(QueueToken).filter(QueueToken.centre_id==centre_id, QueueToken.status.in_([QueueStatus.WAITING.value, QueueStatus.CALLED.value, QueueStatus.ARRIVED.value])).count()
    if qsize > 15:
        alerts.append({"type":"queue_high","severity":"high","message":f"Queue high: {qsize} farmers waiting","action":"Add counter or extend slots"})
    # waiting time exceeds 30
    est = calculate_wait(qsize, c.avg_processing_minutes, c.active_counters)
    if est > 30:
        alerts.append({"type":"wait_high","severity":"medium","message":f"Estimated wait {est} min exceeds 30 min","action":"Activate additional counter"})
    # centre near capacity
    slots_today = db.query(Slot).filter(Slot.centre_id==centre_id, Slot.date==today).all()
    total = sum(s.capacity for s in slots_today)
    used = sum(s.booked for s in slots_today)
    occ = used/total if total else 0
    if occ > 0.8:
        alerts.append({"type":"capacity_warning","severity":"medium","message":f"Centre {int(occ*100)}% booked today","action":"Suggest alternative centre/date"})
    # too few counters
    if c.active_counters < 2:
        alerts.append({"type":"counters_low","severity":"high","message":f"Only {c.active_counters} active counters","action":"Activate maintenance counters"})
    # booking spike last 2 days vs avg 7d
    daily=[]
    for i in range(7):
        d = today - timedelta(days=i)
        cnt = db.query(Booking).filter(Booking.centre_id==centre_id, Booking.date==d).count()
        daily.append(cnt)
    avg7 = sum(daily)/7 if daily else 0
    today_cnt = daily[0] if daily else 0
    if avg7 > 0 and today_cnt > avg7*1.5:
        alerts.append({"type":"booking_spike","severity":"low","message":f"Today {today_cnt} bookings vs avg {avg7:.1f} (+50%)","action":"Monitor queue"})
    if not alerts:
        alerts.append({"type":"normal","severity":"info","message":"Centre operating normally","action":"No action"})
    return {"centre_id":centre_id,"alerts":alerts,"queue_size":qsize,"estimated_wait":est,"occupancy":round(occ,2)}
