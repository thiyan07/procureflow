from app.services.scheduling_service import calculate_wait
from app.services.queue_service import allowed_transitions
from app.models.queue import QueueStatus

def test_wait_zero_counters():
    assert calculate_wait(5, 3, 0) == 15

def test_wait_normal():
    assert calculate_wait(6, 3, 3) == 6

def test_wait_zero_ahead():
    assert calculate_wait(0, 3, 3) == 0

def test_allowed_transitions():
    assert QueueStatus.CALLED.value in allowed_transitions(QueueStatus.WAITING.value)
    assert QueueStatus.COMPLETED.value not in allowed_transitions(QueueStatus.WAITING.value)
    assert allowed_transitions(QueueStatus.COMPLETED.value) == []

def test_procurement_order():
    from app.services.procurement_service import allowed_procurement_transitions
    from app.models.procurement import ProcurementStage
    assert ProcurementStage.ARRIVED.value in allowed_procurement_transitions(ProcurementStage.BOOKING_CONFIRMED.value)
