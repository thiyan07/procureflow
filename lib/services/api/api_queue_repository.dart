import 'dart:async';
import 'dart:convert';
import '../../core/network/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../models/booking.dart';
import '../repositories.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

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
    // Real-time: try WebSocket, fallback to 5s polling
    final wsBase = _client.baseUrl.replaceFirst(RegExp(r'^http'), 'ws');
    final wsUrl = Uri.parse('$wsBase/api/v1/queue/ws/$bookingId');
    WebSocketChannel? channel;
    try {
      channel = WebSocketChannel.connect(wsUrl);
      // Test connection with timeout
      await channel.ready.timeout(const Duration(seconds: 3));
      yield* channel.stream.asyncMap((event) async {
        // backend broadcasts {"status": "...", "token": "..."} - refresh from REST
        try {
          // small delay to let DB commit propagate
          await Future.delayed(const Duration(milliseconds: 200));
          return await getQueueStatus(bookingId);
        } catch (_) {
          return await getQueueStatus(bookingId);
        }
      });
    } catch (_) {
      // WS failed - polling fallback
      if (channel != null) {
        try { await channel.sink.close(); } catch (_) {}
      }
      while (true) {
        await Future.delayed(const Duration(seconds: 5));
        try {
          yield await getQueueStatus(bookingId);
        } catch (_) {}
      }
    }
  }

  // Real operator: list centre queue (used by operator screens)
  Future<List<Map<String, dynamic>>> getCentreQueue(String centreId) async {
    final list = await _client.getList('/api/v1/queue/centre/$centreId');
    return list.cast<Map<String, dynamic>>();
  }

  // Dashboard stats for operator
  Future<Map<String, dynamic>> getDashboard(String centreId) async {
    return await _client.get('/api/v1/centres/$centreId/dashboard');
  }

  @override
  Future<void> callNext(String centreId) async {
    // Deprecated dev endpoint removed — advance via per-booking transition.
    // Find first WAITING booking and transition it to CALLED.
    final queue = await getCentreQueue(centreId);
    Map<String, dynamic>? next;
    for (final m in queue) {
      if ((m['status'] as String? ?? 'WAITING').toUpperCase() == 'WAITING') {
        next = m;
        break;
      }
    }
    if (next == null) throw StateError('No WAITING farmers to call');
    final bookingId = next['booking_id'] as String? ?? next['id'] as String? ?? '';
    if (bookingId.isEmpty) throw StateError('Booking id missing');
    await updateQueueStatus(bookingId, QueueStatus.called);
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

  @override
  Future<Map<String, dynamic>> getQueueCorrection(String bookingId) async {
    try {
      final res = await _client.get('/api/v1/queue/correction/$bookingId');
      return res;
    } catch (_) {
      return {};
    }
  }
}
