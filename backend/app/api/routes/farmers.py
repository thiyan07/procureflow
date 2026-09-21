from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.api.deps import get_current_user, require_roles
from app.models.user import User, UserRole
from app.models.farmer import Farmer
from app.schemas.farmer import FarmerCreate, FarmerUpdate, FarmerOut

router = APIRouter()

def _to_out(f: Farmer) -> dict:
    return FarmerOut(id=f.id, user_id=f.user_id, full_name=f.full_name, mobile=f.mobile, farmer_id=f.farmer_id, village=f.village, district=f.district, language_code=f.language_code, primary_commodity=f.primary_commodity).model_dump()

@router.post("", response_model=FarmerOut, status_code=201)
def create_farmer(payload: FarmerCreate, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    # Only allow farmer to create own profile or admin
    existing = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    if existing:
        raise HTTPException(status_code=400, detail={"code": "ALREADY_EXISTS", "message": "Farmer profile already exists"})
    # check farmer_id unique
    if db.query(Farmer).filter(Farmer.farmer_id == payload.farmer_id).first():
        raise HTTPException(status_code=400, detail={"code": "DUPLICATE", "message": "Farmer ID already exists"})
    # mobile must match user mobile unless admin
    # Fix for email users: if user has placeholder mobile (email_... or 999...), allow any valid mobile
    is_placeholder = user.mobile.startswith("999") or user.mobile.startswith("email_") or "@" in user.mobile or not user.mobile.isdigit() or len(user.mobile) != 10
    if payload.mobile != user.mobile and not is_placeholder and user.role != UserRole.ADMIN.value:
        raise HTTPException(status_code=400, detail={"code": "MOBILE_MISMATCH", "message": "Mobile must match authenticated user"})
    farmer = Farmer(user_id=user.id, full_name=payload.full_name, mobile=payload.mobile, farmer_id=payload.farmer_id, village=payload.village, district=payload.district, language_code=payload.language_code, primary_commodity=payload.primary_commodity)
    db.add(farmer)
    db.commit()
    db.refresh(farmer)
    return farmer

@router.get("/me", response_model=FarmerOut)
def get_my_farmer(db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    if not farmer:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Farmer profile not found"})
    return farmer

@router.patch("/me", response_model=FarmerOut)
def update_my_farmer(payload: FarmerUpdate, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    if not farmer:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Farmer profile not found"})
    if payload.full_name is not None:
        farmer.full_name = payload.full_name
    if payload.village is not None:
        farmer.village = payload.village
    if payload.district is not None:
        farmer.district = payload.district
    if payload.language_code is not None:
        farmer.language_code = payload.language_code
    if payload.primary_commodity is not None:
        farmer.primary_commodity = payload.primary_commodity
    db.commit()
    db.refresh(farmer)
    return farmer

@router.get("/{farmer_id}", response_model=FarmerOut)
def get_farmer(farmer_id: str, db: Session = Depends(get_db), user: User = Depends(require_roles(UserRole.ADMIN.value, UserRole.CENTRE_OPERATOR.value))):
    farmer = db.get(Farmer, farmer_id)
    if not farmer:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Farmer not found"})
    return farmer
