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
import numpy as np

from app.services.scheduling_service import calculate_wait

log = logging.getLogger(__name__)

# Global model coefficients (trained on synthetic data at startup)
_model = None  # dict with weights
_model_trained = False

def _synthetic_data(n=500, seed=42):
    """Generate synthetic demo data — clearly marked, not real user data."""
    random.seed(seed)
    np.random.seed(seed)
    X = []
    y = []
    for _ in range(n):
        farmers_ahead = random.randint(0, 20)
        avg_processing = random.choice([3, 4, 3, 3])  # from real centres c1-4
        active_counters = random.choice([2, 3, 3, 4])
        quantity = random.uniform(5, 30)  # quintal
        hour = random.choice([9, 10, 11, 13, 14])  # slot hours
        centre_load = random.uniform(0.1, 0.9)  # occupancy 0-1
        # rule-based base
        base = calculate_wait(farmers_ahead, avg_processing, active_counters)
        # add realistic noise: quantity factor + time factor + load
        qty_factor = max(0, (quantity - 10) * 0.02) * base * 0.1
        load_factor = centre_load * 2
        hour_factor = 1 if hour in (10, 11) else 0
        noise = random.uniform(-1, 1)
        target = base + qty_factor + load_factor + hour_factor + noise
        target = max(0, target)
        # features for linear regression
        qty_f = 1 + max(0, (quantity - 10) * 0.02)
        X.append([farmers_ahead, avg_processing, qty_f, centre_load, hour])
        y.append(target)
    return np.array(X, dtype=float), np.array(y, dtype=float)

def _train():
    global _model, _model_trained
    if _model_trained:
        return _model
    try:
        X, y = _synthetic_data(800)
        # Add bias column
        X_b = np.c_[np.ones(X.shape[0]), X]  # b0 + 5 features
        # Normal equation: (X^T X)^-1 X^T y
        # Use lstsq for stability
        coeffs, residuals, rank, s = np.linalg.lstsq(X_b, y, rcond=None)
        _model = {
            "coeffs": coeffs,  # 6 values: b0, farmers, avg, qty, load, hour
            "trained_on": "synthetic demo data 800 rows (Erode DPC operational ranges)",
            "r2": _r2(X_b, y, coeffs),
        }
        _model_trained = True
        log.info(f"AI waiting-time model trained (synthetic) R2={_model['r2']:.3f} coeffs={coeffs.round(3)}")
        return _model
    except Exception as e:
        log.warning(f"AI training failed, fallback to rule-based: {e}")
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
