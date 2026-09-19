"""
Lightweight centre load prediction (Phase 10).

Predicts LOW/NORMAL/HIGH load for next 3 days per centre using
time-series aggregation + linear trend (numpy only).

Inputs: historical bookings per day (synthetic demo if no history),
        day_of_week, recent queue size, slot occupancy.

No deep learning. Returns label + confidence + explanation.
Fallback to rule-based occupancy if insufficient data.
"""
from datetime import date, timedelta
from typing import List, Dict
import logging
import random
import numpy as np

log = logging.getLogger(__name__)

def predict_centre_load(
    centre_id: str,
    target_date: date,
    historical_counts: List[int] | None = None,
    current_queue: int = 0,
    avg_occupancy: float = 0.3,
) -> dict:
    """
    historical_counts: bookings per day for last 7 days (synthetic if None)
    Returns: {level, score, reason, forecast_3d: [{date, level, expected_bookings}]}
    """
    try:
        if historical_counts is None:
            # synthetic demo history: Erode avg 20-30 bookings/day per centre
            random.seed(hash(centre_id) % 1000)
            historical_counts = [random.randint(12, 35) for _ in range(7)]
        if len(historical_counts) < 3:
            raise ValueError("insufficient history")

        # Linear trend via numpy polyfit degree 1
        x = np.arange(len(historical_counts))
        y = np.array(historical_counts, dtype=float)
        # slope
        A = np.vstack([x, np.ones(len(x))]).T
        m, c = np.linalg.lstsq(A, y, rcond=None)[0]
        # forecast next 3 days
        forecast = []
        for i in range(3):
            idx = len(historical_counts) + i
            pred = m * idx + c + avg_occupancy * 5 + current_queue * 0.1
            pred = max(5, int(round(pred)))
            level = "LOW" if pred < 18 else "HIGH" if pred > 28 else "NORMAL"
            forecast.append({
                "date": (target_date + timedelta(days=i)).isoformat(),
                "expected_bookings": pred,
                "level": level,
            })
        # today level
        today_pred = forecast[0]["expected_bookings"]
        level = forecast[0]["level"]
        score = today_pred / 35.0  # 0-1
        reason = f"Centre {centre_id} {level} load — approx {today_pred} bookings expected (trend slope {m:.1f})"
        if m > 1.5:
            reason += ", rising trend."
        elif m < -1.5:
            reason += ", declining trend."
        return {
            "level": level,
            "score": round(score, 2),
            "reason": reason,
            "forecast_3d": forecast,
            "model_info": "linear trend on 7-day synthetic history (fallback if no DB)",
        }
    except Exception as e:
        log.warning(f"load predict fallback: {e}")
        # fallback rule: occupancy based
        level = "HIGH" if avg_occupancy > 0.7 else "LOW" if avg_occupancy < 0.3 else "NORMAL"
        return {
            "level": level,
            "score": round(avg_occupancy, 2),
            "reason": f"{level} load from occupancy {avg_occupancy:.0%}",
            "forecast_3d": [],
            "model_info": "fallback rule",
        }
