import 'dart:async';
import '../../core/network/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../models/booking.dart';
import '../repositories.dart';

class ApiQueueRepository implements QueueRepository {
  final ApiClient _client;
  ApiQueueRepository(this._client);

  @override
  Future<QueueState> getQueueStatus(String bookingId) async {
    final res = await _client.get('/api/v1/queue/$bookingId');
    return QueueState(
      bookingId: bookingId,
      tokenNumber: res['token_number'] as String? ?? res['tokenNumber'] as String? ?? '',
      currentTokenOrdinal: res['queue_position'] as int? ?? 0,
      yourOrdinal: res['queue_position'] as int? ?? 0,
      farmersAhead: res['farmers_ahead'] as int? ?? res['farmersAhead'] as int? ?? 0,
      estimatedWaitMinutes: res['estimated_wait_minutes'] as int? ?? res['estimatedWaitMinutes'] as int? ?? 0,
      status: _parse(res['status'] as String? ?? 'waiting'),
    );
  }

  QueueStatus _parse(String s) {
    switch (s.toUpperCase()) {
      case 'WAITING': return QueueStatus.waiting;
      case 'CALLED': return QueueStatus.called;
      case 'ARRIVED': return QueueStatus.arrived;
      case 'PROCESSING': return QueueStatus.processing;
      case 'COMPLETED': return QueueStatus.completed;
      case 'CANCELLED': return QueueStatus.cancelled;
      default: return QueueStatus.waiting;
    }
  }

  @override
  Stream<QueueState> watchQueue(String bookingId) async* {
    // Polling fallback; WebSocket available at /api/v1/queue/ws/{bookingId} but use polling for simplicity
    while (true) {
      await Future.delayed(const Duration(seconds: 5));
      try {
        yield await getQueueStatus(bookingId);
      } catch (_) {
        // ignore and continue
      }
    }
  }

  @override
  Future<void> callNext(String centreId) async {
    // Operator action - not directly exposed as queue endpoint; use booking transition for next token
    // Placeholder: fetch waiting tokens and call first. For now no-op via backend future.
    await _client.post('/api/v1/queue/call-next', body: {'centre_id': centreId});
  }

  @override
  Future<void> updateQueueStatus(String bookingId, QueueStatus status) async {
    final map = {
      QueueStatus.waiting: 'WAITING',
      QueueStatus.called: 'CALLED',
      QueueStatus.arrived: 'ARRIVED',
      QueueStatus.processing: 'PROCESSING',
      QueueStatus.completed: 'COMPLETED',
      QueueStatus.cancelled: 'CANCELLED',
      QueueStatus.noShow: 'NO_SHOW',
    };
    await _client.post('/api/v1/queue/$bookingId/transition', body: {'to_status': map[status]});
  }
}
