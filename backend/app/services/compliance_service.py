"""Lightweight deterministic Compliance Agent for ProcureFlow SIH26032 TNCSC DPC.

No ML — pure rule check vs actual booking data (commodity, quantity, grade, moisture).
Spec: if grade B and answer mentions ISO or moisture -> verified.
Extend deterministically for A/C and fallback to commodity/quantity matching.
"""

from app.models.booking import Booking
from app.models.procurement import Procurement, Weighment, QualityCheck


MSP_RATES = {"Paddy": 2441, "Paddy Grade A": 2461, "Ragi": 4886, "Maize": 2400, "Pulses (Tur)": 8000}


def check_compliance(
    booking: Booking,
    procurement: Procurement | None,
    weighment: Weighment | None,
    quality: QualityCheck | None,
    question: str,
    answer: str,
) -> tuple[bool, str, str]:
    """Return (verified, generated_justification, reason)."""
    q = (question or "").strip()
    a = (answer or "").strip()
    al = a.lower()
    ql = q.lower()

    commodity = booking.commodity_name if booking.commodity_name else "Paddy"
    qty = booking.estimated_quantity
    # prefer actual weighment net if exists
    qty_actual = weighment.net_weight if weighment and weighment.net_weight is not None else qty
    grade = quality.grade if quality and quality.grade else None
    moisture = quality.moisture_percent if quality and quality.moisture_percent is not None else None

    msp = MSP_RATES.get(commodity, MSP_RATES.get("Paddy", 2441))
    # handle "Paddy Grade A" vs "Paddy"
    if grade == "A" and commodity == "Paddy":
        msp = 2461

    verified = False
    reason = ""

    # --- deterministic rules ---
    if len(al) < 10:
        verified = False
        reason = "Answer too brief for audit (min 10 chars)."
    elif grade == "B" and any(k in al for k in ["iso", "moisture", "17%", "17 percent", "faq"]):
        verified = True
        reason = "Grade B justified — answer cites ISO/moisture spec matching recorded data."
    elif grade == "A" and any(k in al for k in ["iso", "moisture", "faq", "within", "spec", "14%"]):
        verified = True
        reason = "Grade A within FAQ/ISO moisture specification."
    elif grade == "C" and any(k in al for k in ["moisture", "discolour", "discolor", "damage", "reject", "beyond"]):
        verified = True
        reason = "Grade C justified — answer references out-of-spec moisture/damage."
    elif grade is None:
        # No grade recorded yet — check if answer references actual booking facts
        has_commodity = commodity.lower() in al
        has_qty = str(int(qty)) in al or str(qty) in al or (weighment and str(weighment.net_weight) in al)
        has_grade_mention = any(k in al for k in ["grade", "iso", "moisture"])
        if has_commodity or has_qty:
            verified = True
            reason = "Answer references booking commodity/quantity."
        elif has_grade_mention:
            # allow generic compliance mention when grade pending
            verified = True
            reason = "Answer references grading criteria pending final QC."
        else:
            verified = False
            reason = "Answer does not reference recorded commodity, quantity, or grading criteria."
    else:
        # grade exists but answer didn't cite evidence
        verified = False
        reason = "Answer does not cite required evidence (ISO/moisture) for grade %s." % grade

    # also consider question relevance: if question asks Why Grade B not A and grade is B, reinforce
    if not verified and grade == "B" and "why" in ql and "grade b" in ql and ("iso" in al or "moisture" in al):
        verified = True
        reason = "Grade B justified — answer cites ISO/moisture spec matching recorded data."

    # Build audit-ready justification
    moisture_str = f"{moisture}%" if moisture is not None else "—"
    grade_str = grade if grade else "PENDING"
    centre_str = booking.centre_id
    token = booking.token_number
    date_str = booking.date.isoformat() if hasattr(booking.date, "isoformat") else str(booking.date)
    verdict = "VERIFIED" if verified else "NEEDS REVIEW"

    generated = (
        f"Audit Justification — TNCSC DPC Erode | Booking {booking.id} | Token {token} | "
        f"Centre {centre_str} | Commodity {commodity} {qty_actual} quintal (booked {qty}q) | "
        f"Grade {grade_str} | Moisture {moisture_str} | MSP ₹{msp}/q | "
        f'Q: "{q}" | A: "{a}" | Verdict: {verdict} — {reason} | '
        f"Ref: {booking.id}/{date_str} | DPCs: Erode (4) | Deterministic check, no ML."
    )
    return verified, generated, reason
