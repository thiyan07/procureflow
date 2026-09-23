import 'dart:convert';
import '../../core/storage/local_storage.dart';

class OfflineSyncService {
  static const _kPending = 'offline_pending_bookings';

  // Queue offline booking attempt (safe operations only - booking)
  // Financial mutations (payment) are NOT queued - require online validation per spec
  static Future<void> queueBooking(Map<String, dynamic> payload) async {
    final list = getPending();
    list.add({'type': 'booking', 'payload': payload, 'ts': DateTime.now().toIso8601String()});
    await LocalStorage.instance.setString(_kPending, jsonEncode(list));
  }

  static List<Map<String, dynamic>> getPending() {
    final raw = LocalStorage.instance.getString(_kPending);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearPending() async {
    await LocalStorage.instance.remove(_kPending);
  }

  static bool get hasPending => getPending().isNotEmpty;
  static int get pendingCount => getPending().length;

  // Capability doc
  static const String offlineCapabilities = '''
Offline support (read-cache + safe queue):
- Works offline: view cached centres/slots/booking/history/notifications (last synced)
- Queued offline: booking creation (synced when online via server validation)
- Requires online: payment updates, procurement transitions, auth refresh, queue position (server-authoritative)
- Conflict: server validates slot availability; offline booking may fail if slot filled -> user notified to rebook.
''';
}
