from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.db.session import get_db
from app.api.deps import get_current_user, require_roles
from app.models.user import User, UserRole
from app.models.booking import Booking
from app.models.farmer import Farmer
from app.models.procurement import Procurement, ProcurementStage, Weighment, QualityCheck, ProcurementEvent
from app.models.procurement_centre import ProcurementCentre
from app.models.slot import Slot
from app.schemas.procurement import ProcurementOut, ProcurementAdvanceRequest, ProcurementApproveRequest, TimelineStepOut, ComplianceCheckRequest, ComplianceCheckResponse
from app.services.procurement_service import advance_procurement
from app.services.compliance_service import check_compliance
from app.services.notification_service import create_notification
from app.services.audit_service import log_procurement_completed
from app.models.procurement import ApprovalStatus

router = APIRouter()

STAGE_TITLES = {
    ProcurementStage.BOOKING_CONFIRMED.value: ("Booking Confirmed", "Slot confirmed"),
    ProcurementStage.ARRIVED.value: ("Arrived at Centre", "Checked-in at gate"),
    ProcurementStage.WEIGHMENT.value: ("Weighment", "Weighment in progress"),
    ProcurementStage.QUALITY_CHECK.value: ("Quality Check", "Grading and quality check"),
    ProcurementStage.PROCUREMENT.value: ("Procurement", "Procurement approval"),
    ProcurementStage.COMPLETED.value: ("Completed", "Procurement completed"),
}

# --- Approval helper: >50 quintal or >1L requires admin ---
def _requires_admin_approval(db, booking: Booking, proc: Procurement) -> bool:
    # quantity check: booking estimated + weighment net
    qty = booking.estimated_quantity if booking else 0
    # also consider commodities json total
    try:
        if booking and booking.commodities:
            qty = max(qty, sum(c.get("quantity", 0) for c in booking.commodities))
    except Exception:
        pass
    weighment = db.query(Weighment).filter(Weighment.procurement_id == proc.id).first() if proc else None
    if weighment and weighment.net_weight is not None:
        qty = max(qty, weighment.net_weight)
    if qty > 50:
        return True
    # total_amount check
    from app.models.payment import Payment
    payment = db.query(Payment).filter(Payment.booking_id == booking.id).first() if booking else None
    if payment and payment.total_amount is not None and payment.total_amount > 100000:
        return True
    return False

@router.get("/{booking_id}", response_model=ProcurementOut)
def get_procurement(booking_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    booking = db.get(Booking, booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Booking not found"})
    farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    if farmer and booking.farmer_id != farmer.id and user.role not in (UserRole.CENTRE_OPERATOR.value, UserRole.ADMIN.value):
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "Not authorized"})
    proc = db.query(Procurement).filter(Procurement.booking_id == booking_id).first()
    if not proc:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Procurement not found"})
    return proc

@router.post("/{booking_id}/advance")
def advance(booking_id: str, payload: ProcurementAdvanceRequest, db: Session = Depends(get_db), user: User = Depends(require_roles(UserRole.CENTRE_OPERATOR.value, UserRole.ADMIN.value))):
    proc = db.query(Procurement).filter(Procurement.booking_id == booking_id).first()
    if not proc:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Procurement not found"})
    booking = db.get(Booking, booking_id)
    # 2-step approval: operator proposing large procurement or final COMPLETED requires admin
    if user.role == UserRole.CENTRE_OPERATOR.value and booking and _requires_admin_approval(db, booking, proc):
        # operator cannot directly advance — mark pending
        proc.approval_status = ApprovalStatus.PENDING.value
        proc.pending_stage = payload.to_stage
        # also mark OPERATOR_APPROVED as intermediate (operator has proposed)
        # keep PENDING to signal awaiting admin; OPERATOR_APPROVED alias same as PENDING for now
        from app.services.audit_service import audit
        audit(db, user.id, "procurement_approval_requested", "procurement", booking_id, f"request {proc.stage}->{payload.to_stage} qty {booking.estimated_quantity}")
        db.commit()
        return {"message": "Pending admin approval", "stage": proc.stage, "approval_status": proc.approval_status, "pending_stage": proc.pending_stage}
    try:
        advance_procurement(db, proc, payload.to_stage, actor=user.id)
        # clear approval if directly advanced
        proc.approval_status = ApprovalStatus.ADMIN_APPROVED.value if user.role == UserRole.ADMIN.value else ApprovalStatus.OPERATOR_APPROVED.value
        proc.pending_stage = None
        # auto payment: when procurement COMPLETED, move Payment PENDING -> PROCESSING
        if payload.to_stage == ProcurementStage.COMPLETED.value:
            try:
                from app.models.payment import Payment, PaymentStatus
                pay = db.query(Payment).filter(Payment.booking_id == booking_id).first()
                if pay and pay.status == PaymentStatus.PENDING.value:
                    pay.status = PaymentStatus.PROCESSING.value
                    if booking:
                        farmer = db.get(Farmer, booking.farmer_id)
                        if farmer:
                            create_notification(db, farmer.user_id, "Payment Processing", f"Payment for {booking.token_number} is processing.", "payment_status_updated", {"booking_id": booking_id, "status": pay.status})
            except Exception:
                pass
        if booking:
            farmer = db.get(Farmer, booking.farmer_id)
            if farmer:
                create_notification(db, farmer.user_id, "Procurement Updated", f"Stage changed to {payload.to_stage}", "procurement_stage_updated", {"booking_id": booking_id, "stage": payload.to_stage})
        log_procurement_completed(db, user.id, booking_id, payload.to_stage)
        db.commit()
    except ValueError as e:
        raise HTTPException(status_code=400, detail={"code": "INVALID_TRANSITION", "message": str(e)})
    return {"message": "Advanced", "stage": proc.stage, "approval_status": proc.approval_status}

@router.post("/{booking_id}/approve")
def approve(booking_id: str, payload: ProcurementApproveRequest, db: Session = Depends(get_db), user: User = Depends(require_roles(UserRole.ADMIN.value))):
    proc = db.query(Procurement).filter(Procurement.booking_id == booking_id).first()
    if not proc:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Procurement not found"})
    # must be pending
    target = payload.stage or proc.pending_stage
    if not target:
        raise HTTPException(status_code=400, detail={"code": "NO_PENDING_APPROVAL", "message": "No pending approval"})
    if proc.approval_status != ApprovalStatus.PENDING.value and proc.approval_status != ApprovalStatus.OPERATOR_APPROVED.value:
        # allow admin to approve even if not pending but target is valid next stage (idempotent)
        if proc.pending_stage and proc.pending_stage != target:
            raise HTTPException(status_code=400, detail={"code": "INVALID_APPROVAL_STAGE", "message": f"Pending is {proc.pending_stage}, requested {target}"})
        if proc.approval_status not in (ApprovalStatus.PENDING.value, ApprovalStatus.OPERATOR_APPROVED.value) and proc.pending_stage is None:
            # if no pending but admin wants to approve directly, treat as advance
            pass
    if proc.pending_stage and target != proc.pending_stage:
        raise HTTPException(status_code=400, detail={"code": "INVALID_APPROVAL_STAGE", "message": f"Pending is {proc.pending_stage}, requested {target}"})
    try:
        advance_procurement(db, proc, target, actor=user.id)
        proc.approval_status = ApprovalStatus.ADMIN_APPROVED.value
        proc.pending_stage = None
        # auto payment PROCESSING when approved to COMPLETED
        if target == ProcurementStage.COMPLETED.value:
            try:
                from app.models.payment import Payment, PaymentStatus
                pay = db.query(Payment).filter(Payment.booking_id == booking_id).first()
                if pay and pay.status == PaymentStatus.PENDING.value:
                    pay.status = PaymentStatus.PROCESSING.value
                    booking2 = db.get(Booking, booking_id)
                    if booking2:
                        farmer2 = db.get(Farmer, booking2.farmer_id)
                        if farmer2:
                            create_notification(db, farmer2.user_id, "Payment Processing", f"Payment for {booking2.token_number} is processing.", "payment_status_updated", {"booking_id": booking_id, "status": pay.status})
            except Exception:
                pass
        booking = db.get(Booking, booking_id)
        if booking:
            farmer = db.get(Farmer, booking.farmer_id)
            if farmer:
                create_notification(db, farmer.user_id, "Procurement Approved", f"Admin approved stage {target}", "procurement_stage_updated", {"booking_id": booking_id, "stage": target})
        from app.services.audit_service import audit
        audit(db, user.id, "procurement_approved", "procurement", booking_id, f"approved {target}")
        log_procurement_completed(db, user.id, booking_id, target)
        db.commit()
    except ValueError as e:
        raise HTTPException(status_code=400, detail={"code": "INVALID_TRANSITION", "message": str(e)})
    return {"message": "Approved", "stage": proc.stage, "approval_status": proc.approval_status}

@router.get("/{booking_id}/timeline", response_model=list[TimelineStepOut])
def timeline(booking_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    proc = db.query(Procurement).filter(Procurement.booking_id == booking_id).first()
    if not proc:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Procurement not found"})
    # order
    order = [s.value for s in ProcurementStage]
    try:
        idx = order.index(proc.stage)
    except ValueError:
        idx = 0
    steps = []
    events = db.query(ProcurementEvent).filter(ProcurementEvent.procurement_id == proc.id).order_by(ProcurementEvent.created_at).all()
    # map stage to event time
    stage_time = {e.to_stage: e.created_at for e in events}
    stage_time[order[0]] = proc.created_at
    for i, stage in enumerate(order):
        is_completed = i < idx
        is_current = i == idx
        title, subtitle = STAGE_TITLES.get(stage, (stage, ""))
        ts = stage_time.get(stage)
        if is_completed and not ts:
            ts = proc.created_at
        steps.append(TimelineStepOut(title=title, subtitle=subtitle, timestamp=ts if (is_completed or is_current) else None, is_completed=is_completed, is_current=is_current))
    # add payment steps as extra (not in ProcurementStage) if needed - we keep procurement only
    return steps

# Weighment — record actual quantity
from pydantic import BaseModel as _BM
class WeighmentCreate(_BM):
    gross_weight: float | None = None
    net_weight: float
    notes: str | None = None

@router.post("/{booking_id}/weighment")
def record_weighment(booking_id: str, payload: WeighmentCreate, db: Session = Depends(get_db), user: User = Depends(require_roles(UserRole.CENTRE_OPERATOR.value, UserRole.ADMIN.value))):
    proc = db.query(Procurement).filter(Procurement.booking_id == booking_id).first()
    if not proc:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Procurement not found"})
    # validate
    if payload.net_weight <= 0 or payload.net_weight > 500:
        raise HTTPException(status_code=400, detail={"code": "INVALID_WEIGHT", "message": "Net weight must be 0-500 quintal"})
    if payload.gross_weight is not None and payload.gross_weight < payload.net_weight:
        raise HTTPException(status_code=400, detail={"code": "INVALID_WEIGHT", "message": "Gross must be >= net"})
    # ensure stage is ARRIVED or WEIGHMENT
    if proc.stage not in [ProcurementStage.ARRIVED.value, ProcurementStage.WEIGHMENT.value, ProcurementStage.BOOKING_CONFIRMED.value]:
        # allow but log
        pass
    # upsert weighment
    w = db.query(Weighment).filter(Weighment.procurement_id == proc.id).first()
    if not w:
        w = Weighment(procurement_id=proc.id, gross_weight=payload.gross_weight, net_weight=payload.net_weight, operator_id=user.id)
        db.add(w)
    else:
        w.gross_weight = payload.gross_weight
        w.net_weight = payload.net_weight
        w.operator_id = user.id
    from datetime import datetime, timezone
    w.weighment_time = datetime.now(timezone.utc)
    # advance to WEIGHMENT if not already
    try:
        if proc.stage == ProcurementStage.ARRIVED.value:
            advance_procurement(db, proc, ProcurementStage.WEIGHMENT.value, actor=user.id)
        elif proc.stage == ProcurementStage.BOOKING_CONFIRMED.value:
            advance_procurement(db, proc, ProcurementStage.ARRIVED.value, actor=user.id)
            advance_procurement(db, proc, ProcurementStage.WEIGHMENT.value, actor=user.id)
    except ValueError:
        pass
    from app.services.audit_service import audit
    audit(db, user.id, "weighment_recorded", "procurement", booking_id, f"net {payload.net_weight} gross {payload.gross_weight}")
    db.commit()
    return {"message": "Weighment recorded", "stage": proc.stage, "net_weight": w.net_weight}

class QualityCreate(_BM):
    grade: str | None = None  # A/B/C
    moisture_percent: float | None = None
    remarks: str | None = None

@router.post("/{booking_id}/quality")
def record_quality(booking_id: str, payload: QualityCreate, db: Session = Depends(get_db), user: User = Depends(require_roles(UserRole.CENTRE_OPERATOR.value, UserRole.ADMIN.value))):
    proc = db.query(Procurement).filter(Procurement.booking_id == booking_id).first()
    if not proc:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Procurement not found"})
    if payload.moisture_percent is not None and (payload.moisture_percent < 0 or payload.moisture_percent > 30):
        raise HTTPException(status_code=400, detail={"code": "INVALID_MOISTURE", "message": "Moisture 0-30% only"})
    if payload.grade and payload.grade not in ["A","B","C"]:
        raise HTTPException(status_code=400, detail={"code": "INVALID_GRADE", "message": "Grade must be A/B/C"})
    qc = db.query(QualityCheck).filter(QualityCheck.procurement_id == proc.id).first()
    if not qc:
        qc = QualityCheck(procurement_id=proc.id, grade=payload.grade, moisture_percent=payload.moisture_percent, remarks=payload.remarks)
        db.add(qc)
    else:
        qc.grade = payload.grade or qc.grade
        qc.moisture_percent = payload.moisture_percent if payload.moisture_percent is not None else qc.moisture_percent
        qc.remarks = payload.remarks or qc.remarks
    from datetime import datetime, timezone
    qc.checked_at = datetime.now(timezone.utc)
    try:
        if proc.stage == ProcurementStage.WEIGHMENT.value:
            advance_procurement(db, proc, ProcurementStage.QUALITY_CHECK.value, actor=user.id)
    except ValueError:
        pass
    from app.services.audit_service import audit
    audit(db, user.id, "quality_recorded", "procurement", booking_id, f"grade {payload.grade} moisture {payload.moisture_percent}")
    db.commit()
    return {"message": "Quality recorded", "stage": proc.stage, "grade": qc.grade}

@router.get("/{booking_id}/receipt")
def get_receipt(booking_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    booking = db.get(Booking, booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Booking not found"})
    farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    if farmer and booking.farmer_id != farmer.id and user.role not in (UserRole.CENTRE_OPERATOR.value, UserRole.ADMIN.value):
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "Not authorized"})
    proc = db.query(Procurement).filter(Procurement.booking_id == booking_id).first()
    from app.models.payment import Payment
    payment = db.query(Payment).filter(Payment.booking_id == booking_id).first()
    weighment = db.query(Weighment).filter(Weighment.procurement_id == proc.id).first() if proc else None
    quality = db.query(QualityCheck).filter(QualityCheck.procurement_id == proc.id).first() if proc else None
    centre = db.get(ProcurementCentre, booking.centre_id) if booking else None
    farmer_obj = db.get(Farmer, booking.farmer_id) if booking else None
    # reference number lightweight: booking token + date
    ref = f"REC-{booking.token_number}-{booking.date.isoformat()}"
    return {
        "reference": ref,
        "farmer": {"name": farmer_obj.full_name if farmer_obj else None, "farmer_id": farmer_obj.farmer_id if farmer_obj else None, "village": farmer_obj.village if farmer_obj else None},
        "centre": {"name": centre.name if centre else None, "location": centre.location if centre else None, "district": centre.district if centre else None},
        "date": str(booking.date),
        "slot": str(db.get(Slot, booking.slot_id).start_time) if booking.slot_id else None,
        "commodities": booking.commodities if hasattr(booking, 'commodities') else [{"commodity": booking.commodity_name, "quantity": booking.estimated_quantity}],
        "weighment": {"gross": weighment.gross_weight if weighment else None, "net": weighment.net_weight if weighment else None, "time": weighment.weighment_time.isoformat() if weighment and weighment.weighment_time else None} if proc else None,
        "quality": {"grade": quality.grade if quality else None, "moisture": quality.moisture_percent if quality else None, "remarks": quality.remarks if quality else None} if proc else None,
        "procurement": {"stage": proc.stage if proc else None, "booking_id": booking_id},
        "payment": {"status": payment.status if payment else None, "amount": payment.total_amount if payment else None, "gross": payment.gross_amount if payment else None, "deductions": payment.deductions if payment else None, "net": payment.net_payable if payment else None, "transaction_id": payment.transaction_id if payment else None, "reference_id": payment.reference_id if payment else None, "date": payment.payment_date.isoformat() if payment and payment.payment_date else None, "method": payment.payment_method if payment else None} if payment else None,
    }

@router.get("/{booking_id}/receipt/pdf")
def get_receipt_pdf(booking_id: str, db: Session = Depends(get_db), user: User = Depends(get_current_user)):
    # Reuse same auth check as JSON receipt
    booking = db.get(Booking, booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Booking not found"})
    farmer = db.query(Farmer).filter(Farmer.user_id == user.id).first()
    if farmer and booking.farmer_id != farmer.id and user.role not in (UserRole.CENTRE_OPERATOR.value, UserRole.ADMIN.value):
        raise HTTPException(status_code=403, detail={"code": "FORBIDDEN", "message": "Not authorized"})
    proc = db.query(Procurement).filter(Procurement.booking_id == booking_id).first()
    from app.models.payment import Payment
    payment = db.query(Payment).filter(Payment.booking_id == booking_id).first()
    weighment = db.query(Weighment).filter(Weighment.procurement_id == proc.id).first() if proc else None
    quality = db.query(QualityCheck).filter(QualityCheck.procurement_id == proc.id).first() if proc else None
    centre = db.get(ProcurementCentre, booking.centre_id) if booking else None
    farmer_obj = db.get(Farmer, booking.farmer_id) if booking else None
    ref = f"REC-{booking.token_number}-{booking.date.isoformat()}"
    # Generate PDF with reportlab
    try:
        from reportlab.lib.pagesizes import A4
        from reportlab.lib import colors
        from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
        from reportlab.lib.units import mm
        from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, Table, TableStyle, HRFlowable
        from reportlab.lib.enums import TA_CENTER, TA_RIGHT
        import io
        buffer = io.BytesIO()
        doc = SimpleDocTemplate(buffer, pagesize=A4, leftMargin=15*mm, rightMargin=15*mm, topMargin=12*mm, bottomMargin=12*mm, title=f"ProcureFlow Receipt {ref}")
        styles = getSampleStyleSheet()
        title_style = ParagraphStyle('title', parent=styles['Heading1'], fontSize=18, textColor=colors.HexColor('#1B5E20'), alignment=TA_CENTER, spaceAfter=2*mm)
        subtitle_style = ParagraphStyle('subtitle', parent=styles['Normal'], fontSize=9, textColor=colors.HexColor('#5A5F5A'), alignment=TA_CENTER, spaceAfter=6*mm)
        heading_style = ParagraphStyle('heading', parent=styles['Heading2'], fontSize=11, textColor=colors.HexColor('#2E7D32'), spaceAfter=3*mm, spaceBefore=4*mm)
        normal = styles['Normal']
        normal.fontSize = 9
        story = []
        story.append(Paragraph("PROCUREFLOW", title_style))
        story.append(Paragraph("TNCSC Procurement Centre Management — Digital Receipt", subtitle_style))
        story.append(HRFlowable(width="100%", thickness=1, color=colors.HexColor('#2E7D32'), spaceAfter=4*mm))
        # Reference box
        story.append(Paragraph(f"Receipt: <b>{ref}</b> &nbsp;&nbsp;|&nbsp;&nbsp; Booking: <b>{booking.token_number}</b> &nbsp;&nbsp;|&nbsp;&nbsp; Date: {booking.date}", normal))
        story.append(Spacer(1, 3*mm))
        # Farmer / Centre
        farmer_data = [
            [Paragraph("<b>Farmer</b>", normal), Paragraph(f"{farmer_obj.full_name if farmer_obj else '-'} ({farmer_obj.farmer_id if farmer_obj else '-'})<br/>{farmer_obj.village if farmer_obj else ''}, {farmer_obj.district if farmer_obj else ''}<br/>Mobile: {farmer_obj.mobile if farmer_obj else booking.farmer_id}", normal)],
            [Paragraph("<b>Centre</b>", normal), Paragraph(f"{centre.name if centre else '-'}<br/>{centre.location if centre else ''}<br/>Slot: {db.get(Slot, booking.slot_id).start_time if booking.slot_id else '-'} on {booking.date}", normal)],
        ]
        t = Table(farmer_data, colWidths=[30*mm, 140*mm])
        t.setStyle(TableStyle([('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E0E5DE')), ('BACKGROUND', (0,0), (0,-1), colors.HexColor('#E8F5E9')), ('VALIGN', (0,0), (-1,-1), 'MIDDLE'), ('LEFTPADDING', (0,0), (-1,-1), 3*mm), ('RIGHTPADDING', (0,0), (-1,-1), 3*mm)]))
        story.append(t)
        story.append(Spacer(1, 3*mm))
        # Commodities
        story.append(Paragraph("Commodity & Quantity", heading_style))
        comm_rows = [[Paragraph("<b>Commodity</b>", normal), Paragraph("<b>Quantity (quintal)</b>", normal), Paragraph("<b>Rate (₹/q)</b>", normal), Paragraph("<b>Amount (₹)</b>", normal)]]
        total_qty = 0
        total_amt = 0
        if hasattr(booking, 'commodities') and booking.commodities:
            for c in booking.commodities:
                qty = c.get('quantity', 0) if isinstance(c, dict) else getattr(c, 'quantity', 0)
                comm = c.get('commodity', '') if isinstance(c, dict) else getattr(c, 'commodity', '')
                rate = payment.rate_per_quintal if payment else 0
                amt = qty * (rate or 0)
                total_qty += qty
                total_amt += amt
                comm_rows.append([Paragraph(comm, normal), Paragraph(f"{qty}", normal), Paragraph(f"{rate:.0f}" if rate else "-", normal), Paragraph(f"{amt:.0f}", normal)])
        else:
            qty = booking.estimated_quantity
            comm = booking.commodity_name
            rate = payment.rate_per_quintal if payment else 0
            amt = payment.total_amount if payment else qty*(rate or 0)
            total_qty = qty
            total_amt = amt
            comm_rows.append([Paragraph(comm, normal), Paragraph(f"{qty}", normal), Paragraph(f"{rate:.0f}" if rate else "-", normal), Paragraph(f"{amt:.0f}", normal)])
        ct = Table(comm_rows, colWidths=[50*mm, 35*mm, 35*mm, 35*mm])
        ct.setStyle(TableStyle([('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E0E5DE')), ('BACKGROUND', (0,0), (-1,0), colors.HexColor('#E8F5E9')), ('ALIGN', (1,0), (-1,-1), 'RIGHT'), ('LEFTPADDING', (0,0), (-1,-1), 2*mm)]))
        story.append(ct)
        story.append(Spacer(1, 2*mm))
        # Weighment / Quality
        story.append(Paragraph("Weighment & Quality", heading_style))
        w_rows = [
            [Paragraph("<b>Gross Weight</b>", normal), Paragraph(f"{weighment.gross_weight if weighment and weighment.gross_weight else '-'} q", normal), Paragraph("<b>Net Weight</b>", normal), Paragraph(f"{weighment.net_weight if weighment and weighment.net_weight else '-'} q", normal)],
            [Paragraph("<b>Grade</b>", normal), Paragraph(f"{quality.grade if quality else '-'}", normal), Paragraph("<b>Moisture</b>", normal), Paragraph(f"{quality.moisture_percent if quality and quality.moisture_percent else '-'} %", normal)],
            [Paragraph("<b>Quality Remarks</b>", normal), Paragraph(f"{quality.remarks if quality and quality.remarks else '-'}", normal), Paragraph("<b>Procurement Stage</b>", normal), Paragraph(f"{proc.stage if proc else '-'}", normal)],
        ]
        wt = Table(w_rows, colWidths=[30*mm, 45*mm, 30*mm, 50*mm])
        wt.setStyle(TableStyle([('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E0E5DE')), ('LEFTPADDING', (0,0), (-1,-1), 2*mm)]))
        story.append(wt)
        story.append(Spacer(1, 3*mm))
        # Payment
        story.append(Paragraph("Payment", heading_style))
        gross = payment.gross_amount if payment and payment.gross_amount else (payment.total_amount if payment else 0)
        ded = payment.deductions if payment and payment.deductions else 0
        net = payment.net_payable if payment and payment.net_payable else ((gross or 0) - (ded or 0))
        status = payment.status if payment else 'PENDING'
        method = payment.payment_method if payment and payment.payment_method else 'BANK_TRANSFER'
        txn = payment.transaction_id if payment and payment.transaction_id else '-'
        refid = payment.reference_id if payment and payment.reference_id else txn
        p_rows = [
            [Paragraph("<b>Gross Amount</b>", normal), Paragraph(f"₹ {gross:.0f}" if gross else "₹ -", normal), Paragraph("<b>Deductions</b>", normal), Paragraph(f"₹ {ded:.0f}", normal)],
            [Paragraph("<b>Net Payable</b>", normal), Paragraph(f"<b>₹ {net:.0f}</b>", normal), Paragraph("<b>Status</b>", normal), Paragraph(f"{status}", normal)],
            [Paragraph("<b>Method</b>", normal), Paragraph(f"{method}", normal), Paragraph("<b>Transaction</b>", normal), Paragraph(f"{txn}", normal)],
            [Paragraph("<b>Reference</b>", normal), Paragraph(f"{refid}", normal), Paragraph("<b>Date</b>", normal), Paragraph(f"{payment.payment_date.strftime('%d-%b-%Y %H:%M') if payment and payment.payment_date else '-'}", normal)],
        ]
        pt = Table(p_rows, colWidths=[30*mm, 45*mm, 30*mm, 50*mm])
        pt.setStyle(TableStyle([('GRID', (0,0), (-1,-1), 0.5, colors.HexColor('#E0E5DE')), ('BACKGROUND', (0,0), (0,-1), colors.HexColor('#FFF3E0')) if status in ('PENDING','PROCESSING') else ('BACKGROUND', (0,0), (0,-1), colors.HexColor('#E8F5E9')) ]))
        story.append(pt)
        story.append(Spacer(1, 6*mm))
        story.append(Paragraph("This is a system-generated digital receipt. No signature required. Rates as per MSP 2026-27. Keep for records.", ParagraphStyle('footer', parent=normal, fontSize=7, textColor=colors.HexColor('#5A5F5A'), alignment=TA_CENTER)))
        story.append(Paragraph("ProcureFlow • TNCSC • SIH26032 • demo — no real payment gateway", ParagraphStyle('footer2', parent=normal, fontSize=7, textColor=colors.grey, alignment=TA_CENTER)))
        doc.build(story)
        pdf_bytes = buffer.getvalue()
        buffer.close()
        from fastapi.responses import Response
        return Response(content=pdf_bytes, media_type="application/pdf", headers={"Content-Disposition": f'inline; filename="{ref}.pdf"'})
    except Exception as e:
        import logging
        logging.getLogger(__name__).exception(f"PDF generation failed: {e}")
        raise HTTPException(status_code=500, detail={"code": "PDF_FAILED", "message": "Failed to generate PDF receipt"})

# --- P1 Compliance Agent light — deterministic Q&A before approval ---
@router.post("/{booking_id}/compliance-check", response_model=ComplianceCheckResponse)
def compliance_check(
    booking_id: str,
    payload: ComplianceCheckRequest,
    db: Session = Depends(get_db),
    user: User = Depends(require_roles(UserRole.CENTRE_OPERATOR.value, UserRole.ADMIN.value)),
):
    booking = db.get(Booking, booking_id)
    if not booking:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Booking not found"})
    proc = db.query(Procurement).filter(Procurement.booking_id == booking_id).first()
    if not proc:
        raise HTTPException(status_code=404, detail={"code": "NOT_FOUND", "message": "Procurement not found"})
    weighment = db.query(Weighment).filter(Weighment.procurement_id == proc.id).first()
    quality = db.query(QualityCheck).filter(QualityCheck.procurement_id == proc.id).first()

    if not payload.question or not payload.question.strip():
        raise HTTPException(status_code=400, detail={"code": "INVALID_INPUT", "message": "Question required"})
    if not payload.answer or not payload.answer.strip():
        raise HTTPException(status_code=400, detail={"code": "INVALID_INPUT", "message": "Answer required"})

    verified, generated, reason = check_compliance(booking, proc, weighment, quality, payload.question, payload.answer)

    from app.services.audit_service import audit
    audit(db, user.id, "compliance_check", "procurement", booking_id,
          f"Q:{payload.question[:120]} A:{payload.answer[:200]} verified={verified} grade={quality.grade if quality else None} moisture={quality.moisture_percent if quality else None}")
    db.commit()

    return ComplianceCheckResponse(
        verified=verified,
        generated_justification=generated,
        reason=reason,
        booking_id=booking_id,
        commodity=booking.commodity_name,
        quantity=weighment.net_weight if weighment and weighment.net_weight is not None else booking.estimated_quantity,
        grade=quality.grade if quality else None,
        moisture=quality.moisture_percent if quality else None,
    )
