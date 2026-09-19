"""
Lightweight multilingual assistant (Phase 11).

Deterministic retrieval for account-specific questions (token, queue, payment)
via DB; structured FAQ for general questions. No LLM hallucination.
Supports en/ta/hi via simple templates.
"""
from typing import Optional
import re

# Structured FAQ — deterministic, no LLM
FAQ = {
    "en": {
        "how to book": "Go to Centres → select centre → commodity/quantity → date → recommended slot → Confirm. You get token P-number.",
        "documents": "Bring Farmer ID, Aadhaar, bank passbook, and paddy sample. TNCSC DPC verifies at gate.",
        "where centre": "Centres: Bhavani RM (Bhavani Taluk), Perundurai RM (Perundurai), Sathyamangalam RM, Gobichettipalayam RM — all Erode district 09:00-17:00.",
        "what token": "Your token is P-number like P27. Show QR at gate. Check Token screen.",
        "payment": "Payment: PENDING→PROCESSING→COMPLETED. MSP 2026-27 Paddy 2441/2461 per quintal. Check Payment screen.",
        "procurement": "Stages: BOOKING_CONFIRMED→ARRIVED→WEIGHMENT→QUALITY_CHECK→PROCUREMENT→COMPLETED.",
    },
    "ta": {
        "how to book": "மையங்கள் → மையத்தைத் தேர்ந்தெடுக்கவும் → பயிர்/அளவு → தேதி → பரிந்துரை ஸ்லாட் → உறுதிப்படுத்தவும். டோக்கன் P-எண் கிடைக்கும்.",
        "documents": "விவசாயி ஐடி, ஆதார், வங்கி புத்தகம், நெல் மாதிரி கொண்டு வரவும்.",
        "where centre": "மையங்கள்: பவானி, பெருந்துறை, சத்தியமங்கலம், கோபிசெட்டிபாளையம் — ஈரோடு 09:00-17:00.",
        "what token": "உங்கள் டோக்கன் P-எண். QR காட்டவும். டோக்கன் திரையில் பார்க்கவும்.",
        "payment": "பணம்: நிலுவை→செயலாக்கம்→முடிந்தது. MSP 2026-27 நெல் 2441/2461.",
        "procurement": "நிலைகள்: முன்பதிவு→வருகை→எடை→தரம்→கொள்முதல்→முடிந்தது.",
    },
    "hi": {
        "how to book": "केंद्र चुनें → फसल/मात्रा → तारीख → सुझाया स्लॉट → पुष्टि करें. टोकन P-नंबर मिलेगा.",
        "documents": "किसान आईडी, आधार, बैंक पासबुक, धान नमूना लाएं।",
        "where centre": "केंद्र: भवानी, पेरुंदुरई, सत्यमंगलम, गोबीचेट्टिपालयम — इरोड 09:00-17:00.",
        "what token": "आपका टोकन P-नंबर है। QR दिखाएं। टोकन स्क्रीन देखें।",
        "payment": "भुगतान: लंबित→प्रसंस्करण→पूर्ण. MSP 2026-27 धान 2441/2461.",
        "procurement": "चरण: बुकिंग→आगमन→तौल→गुणवत्ता→खरीद→पूर्ण.",
    },
}

def answer(query: str, lang: str = "en", context: Optional[dict] = None) -> str:
    q = query.lower().strip()
    l = lang if lang in ("en", "ta", "hi") else "en"
    faq = FAQ[l]

    # Account-specific retrieval — never hallucinate, use context only
    if context:
        if any(k in q for k in ["token", "टोकन", "டோக்கன்"]):
            if context.get("token"):
                return f"Your token is {context['token']} at {context.get('centre','Bhavani')} slot {context.get('slot','09:00')}." if l=="en" else (f"உங்கள் டோக்கன் {context['token']}." if l=="ta" else f"आपका टोकन {context['token']} है।")
            else:
                return "No active booking found. Book a slot first." if l=="en" else "செயலில் முன்பதிவு இல்லை." if l=="ta" else "कोई सक्रिय बुकिंग नहीं।"
        if any(k in q for k in ["queue", "ahead", "waiting", "कतार", "வரிசை"]):
            if context.get("farmers_ahead") is not None:
                return f"{context['farmers_ahead']} farmers ahead, wait ~{context.get('wait',0)} min." if l=="en" else f"{context['farmers_ahead']} பேர் முன்னால்." if l=="ta" else f"{context['farmers_ahead']} किसान आगे।"
        if any(k in q for k in ["payment", "पैसे", "பணம்"]):
            if context.get("payment_status"):
                return f"Payment status: {context['payment_status']} amount ₹{context.get('amount',0)}." if l=="en" else f"பணம் நிலை: {context['payment_status']}." if l=="ta" else f"भुगतान: {context['payment_status']}।"
        if any(k in q for k in ["procurement", "stage", "स्थिति", "நிலை"]):
            if context.get("proc_stage"):
                return f"Procurement stage: {context['proc_stage']}." if l=="en" else f"கொள்முதல் நிலை: {context['proc_stage']}." if l=="ta" else f"खरीद चरण: {context['proc_stage']}।"
        if any(k in q for k in ["slot", "when", "कब", "எப்போது"]):
            if context.get("slot"):
                return f"Your slot is {context['slot']} at {context.get('centre','')}." if l=="en" else f"உங்கள் ஸ்லாட் {context['slot']}." if l=="ta" else f"आपका स्लॉट {context['slot']}।"

    # General FAQ fallback
    if any(k in q for k in ["book", "slot", "how", "कैसे", "எப்படி"]):
        return faq["how to book"]
    if any(k in q for k in ["document", "कागज", "ஆவணம்"]):
        return faq["documents"]
    if any(k in q for k in ["centre", "where", "कहाँ", "எங்கே", "center"]):
        return faq["where centre"]
    if any(k in q for k in ["token", "टोकन", "டோக்கன்"]):
        return faq["what token"]
    if any(k in q for k in ["payment", "पैसे", "பணம்"]):
        return faq["payment"]
    if any(k in q for k in ["procurement", "stage", "tapas", "நிலை"]):
        return faq["procurement"]
    # default
    prefix = {"en": "I can help with booking, token, centre, payment, procurement. Try:", "ta": "முன்பதிவு, டோக்கன், மையம், பணம் பற்றி கேட்கலாம்.", "hi": "बुकिंग, टोकन, केंद्र, भुगतान के बारे में पूछें।"}[l]
    return f"{prefix} 'Where is my token?' / 'Payment status?' / 'How to book?'"
