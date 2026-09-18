import '../../core/network/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../models/booking.dart';
import '../repositories.dart';

class ApiProcurementRepository implements ProcurementRepository {
  final ApiClient _client;
  ApiProcurementRepository(this._client);

  @override
  Future<List<TimelineStep>> getProcurementTimeline(String bookingId) async {
    final list = await _client.getList('/api/v1/procurements/$bookingId/timeline');
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return TimelineStep(
        title: m['title'] as String,
        subtitle: m['subtitle'] as String,
        timestamp: m['timestamp'] != null ? DateTime.tryParse(m['timestamp'] as String) : null,
        isCompleted: m['is_completed'] as bool? ?? m['isCompleted'] as bool? ?? false,
        isCurrent: m['is_current'] as bool? ?? m['isCurrent'] as bool? ?? false,
      );
    }).toList();
  }

  @override
  Future<void> advanceStage(String bookingId, ProcurementStage stage) async {
    final map = {
      ProcurementStage.bookingConfirmed: 'BOOKING_CONFIRMED',
      ProcurementStage.arrivedAtCentre: 'ARRIVED',
      ProcurementStage.weighment: 'WEIGHMENT',
      ProcurementStage.qualityCheck: 'QUALITY_CHECK',
      ProcurementStage.procurement: 'PROCUREMENT',
      ProcurementStage.completed: 'COMPLETED',
      ProcurementStage.paymentProcessing: 'COMPLETED', // backend has 6 stages; payment handled separately
      ProcurementStage.paymentCompleted: 'COMPLETED',
    };
    await _client.post('/api/v1/procurements/$bookingId/advance', body: {'to_stage': map[stage] ?? 'ARRIVED'});
  }
}
