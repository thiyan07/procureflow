"""
Lightweight AI waiting-time prediction (Phase 8).

- Classical Linear Regression via numpy (no sklearn, no heavy deps)
- Synthetic demo training data clearly marked
- Fallback to rule-based `calculate_wait` on any failure
- Inputs: farmers_ahead, avg_processing, active_counters, commodity, quantity, hour, centre_load
- Never breaks booking; AI is enhancement, not replacement.

Model: y = b0 + b1*farmers_ahead + b2*avg_processing + b3*quantity_factor + b4*load + b5*hour_factor
Trained on synthetic data derived from operational ranges (Erode DPCs).
"""
import logging
import random
from typing import Optional

try:
    import numpy as np
    _HAS_NUMPY = True
except ImportError:
    np = None  # type: ignore
    _HAS_NUMPY = False
    logging.getLogger(__name__).warning("numpy not installed - AI waiting time will fallback to rule-based")

from app.services.scheduling_service import calculate_wait

log = logging.getLogger(__name__)

# Global model coefficients — 100% real: no synthetic training data
# AI disabled until real historical wait dataset is sufficient; fallback to rule-based calculate_wait()
_model = None  # dict with weights
_model_trained = False

def _synthetic_data(n=500, seed=42):
    """Deprecated — synthetic disabled for 100% real mode."""
    raise RuntimeError("synthetic data disabled — 100% real mode")

def _train():
    global _model, _model_trained
    # 100% real — do not train on synthetic demo data
    log.info("AI waiting-time model disabled — 100% real mode, using rule-based calculate_wait")
    _model_trained = False
    return None

def _r2(X_b, y, coeffs):
    y_pred = X_b @ coeffs
    ss_res = np.sum((y - y_pred) ** 2)
    ss_tot = np.sum((y - np.mean(y)) ** 2)
    return 1 - ss_res / ss_tot if ss_tot else 0

def _ensure_model():
    if _model is None and not _model_trained:
        return _train()
    return _model

def predict_waiting_time(
    farmers_ahead: int,
    avg_processing: int,
    active_counters: int,
    commodity: Optional[str] = None,
    estimated_quantity: float = 10,
    hour: Optional[int] = None,
    centre_load: Optional[float] = None,
    current_queue_size: Optional[int] = None,
) -> dict:
    # Fallback if numpy not available
    if not _HAS_NUMPY:
        rule_wait = calculate_wait(farmers_ahead, avg_processing, active_counters)
        return {
            "predicted_wait": rule_wait,
            "rule_wait": rule_wait,
            "used_ai": False,
            "reason": f"Rule-based {rule_wait} min (numpy not installed)",
            "model_info": "fallback rule-based (no numpy)",
        }
    """
    Returns dict with:
    - predicted_wait (int, minutes)
    - rule_wait (int)
    - used_ai (bool)
    - reason (str)
    - model_info (str)
    Falls back to rule-based on any error or invalid input.
    """
    rule_wait = calculate_wait(farmers_ahead, avg_processing, active_counters)
    # Edge: zero counters already handled in calculate_wait via fallback 1
    try:
        if farmers_ahead < 0 or avg_processing <= 0:
            raise ValueError("invalid inputs")
        model = _ensure_model()
        if model is None:
            raise RuntimeError("model not available")

        # Feature engineering same as training
        qty_factor = 1 + max(0, (estimated_quantity - 10) * 0.02)
        # centre_load: if not provided, estimate from farmers_ahead/20
        if centre_load is None:
            centre_load = min(0.9, farmers_ahead / 20.0)
        if hour is None:
            hour = 10  # default mid-morning
        # commodity one-hot not needed for linear — keep lightweight
        X = np.array([1, farmers_ahead, avg_processing, qty_factor, centre_load, hour], dtype=float)
        coeffs = model["coeffs"]
        pred = float(X @ coeffs)
        pred = max(0, pred)
        # Clamp to reasonable: rule ±50% + buffer
        pred_int = int(round(pred))
        # Safety: never predict negative, never far from rule
        if pred_int < 0:
            pred_int = rule_wait
        if abs(pred_int - rule_wait) > 15:
            # large deviation → blend
            pred_int = int((pred_int + rule_wait) / 2)
        reason = f"AI predicts {pred_int} min (rule {rule_wait} min) based on {farmers_ahead} ahead, {active_counters} counters, qty {estimated_quantity}q"
        if estimated_quantity > 20:
            reason += " — large quantity considered."
        return {
            "predicted_wait": pred_int,
            "rule_wait": rule_wait,
            "used_ai": True,
            "reason": reason,
            "model_info": f"LinearRegression synthetic R2={model['r2']:.2f}",
        }
    except Exception as e:
        log.warning(f"AI predict fallback to rule: {e}")
        return {
            "predicted_wait": rule_wait,
            "rule_wait": rule_wait,
            "used_ai": False,
            "reason": f"Rule-based {rule_wait} min for {farmers_ahead} ahead, {active_counters} counters (AI fallback).",
            "model_info": "fallback rule-based",
        }

# Pre-train on import (lightweight, <10ms)
_train()
