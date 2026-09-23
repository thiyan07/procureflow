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

  static String _toBackendStage(ProcurementStage stage) {
    const map = {
      ProcurementStage.bookingConfirmed: 'BOOKING_CONFIRMED',
      ProcurementStage.arrivedAtCentre: 'ARRIVED',
      ProcurementStage.weighment: 'WEIGHMENT',
      ProcurementStage.qualityCheck: 'QUALITY_CHECK',
      ProcurementStage.procurement: 'PROCUREMENT',
      ProcurementStage.completed: 'COMPLETED',
      ProcurementStage.paymentProcessing: 'COMPLETED',
      ProcurementStage.paymentCompleted: 'COMPLETED',
    };
    return map[stage] ?? 'ARRIVED';
  }

  @override
  Future<void> advanceStage(String bookingId, ProcurementStage stage) async {
    await _client.post('/api/v1/procurements/$bookingId/advance', body: {'to_stage': _toBackendStage(stage)});
  }

  @override
  Future<Map<String, dynamic>> getProcurement(String bookingId) async {
    return await _client.get('/api/v1/procurements/$bookingId');
  }

  @override
  Future<void> approveStage(String bookingId, ProcurementStage stage) async {
    await _client.post('/api/v1/procurements/$bookingId/approve', body: {'stage': _toBackendStage(stage)});
  }

  @override
  Future<ComplianceResult> complianceCheck(String bookingId, String question, String answer) async {
    final res = await _client.post('/api/v1/procurements/$bookingId/compliance-check', body: {'question': question, 'answer': answer});
    return ComplianceResult.fromJson(res);
  }
}
