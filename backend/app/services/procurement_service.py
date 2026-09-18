from sqlalchemy.orm import Session
from app.models.procurement import Procurement, ProcurementEvent, ProcurementStage

STAGE_ORDER = [s.value for s in ProcurementStage]

def allowed_procurement_transitions(current: str) -> list[str]:
    try:
        idx = STAGE_ORDER.index(current)
    except ValueError:
        return []
    if idx + 1 < len(STAGE_ORDER):
        return [STAGE_ORDER[idx+1]]
    return []

def advance_procurement(db: Session, proc: Procurement, to_stage: str, actor: str | None = None) -> Procurement:
    allowed = allowed_procurement_transitions(proc.stage)
    if to_stage not in allowed:
        # Allow idempotent
        if proc.stage == to_stage:
            return proc
        raise ValueError(f"Invalid procurement transition {proc.stage} -> {to_stage}. Allowed: {allowed}")
    evt = ProcurementEvent(procurement_id=proc.id, from_stage=proc.stage, to_stage=to_stage, actor=actor)
    db.add(evt)
    proc.stage = to_stage
    db.flush()
    return proc
