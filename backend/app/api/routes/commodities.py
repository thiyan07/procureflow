from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.models.commodity import Commodity

router = APIRouter()

@router.get("")
def list_commodities(db: Session = Depends(get_db)):
    commodities = db.query(Commodity).filter(Commodity.is_active == True).order_by(Commodity.name).all()
    # Fallback to seed-like list if DB empty (dev without seed)
    if not commodities:
        return [
            {"id": "seed-paddy", "name": "Paddy", "code": "PADDY", "rate_per_quintal": 2441, "is_active": True},
            {"id": "seed-paddy-a", "name": "Paddy Grade A", "code": "PADDY-A", "rate_per_quintal": 2461, "is_active": True},
            {"id": "seed-ragi", "name": "Ragi", "code": "RAGI", "rate_per_quintal": 4886, "is_active": True},
            {"id": "seed-maize", "name": "Maize", "code": "MAIZE", "rate_per_quintal": 2400, "is_active": True},
            {"id": "seed-tur", "name": "Pulses (Tur)", "code": "PULSES-TUR", "rate_per_quintal": 8000, "is_active": True},
        ]
    return [{"id": c.id, "name": c.name, "code": c.code, "rate_per_quintal": c.rate_per_quintal, "is_active": c.is_active} for c in commodities]
