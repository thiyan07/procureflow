import 'dart:async';
import '../../core/network/api_client.dart';
import '../../models/payment.dart';
import '../repositories.dart';

class ApiNotificationRepository implements NotificationRepository {
  final ApiClient _client;
  ApiNotificationRepository(this._client);

  @override
  Future<List<AppNotification>> getNotifications(String farmerId) async {
    return getNotificationsPaginated(farmerId, limit: 50, offset: 0);
  }

  Future<List<AppNotification>> getNotificationsPaginated(String farmerId, {int limit=20, int offset=0}) async {
    final list = await _client.getList('/api/v1/notifications', query: {'limit': limit, 'offset': offset});
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      return AppNotification(
        id: m['id'] as String,
        title: m['title'] as String,
        body: m['body'] as String,
        type: m['type'] as String? ?? 'general',
        createdAt: DateTime.parse(m['created_at'] as String),
        isRead: m['is_read'] as bool? ?? false,
      );
    }).toList();
  }

  @override
  Stream<AppNotification> watchNotifications(String farmerId) async* {
    // Polling fallback
    while (true) {
      await Future.delayed(const Duration(seconds: 10));
      final list = await getNotifications(farmerId);
      if (list.isNotEmpty) yield list.first;
    }
  }

  @override
  Future<void> markRead(String notificationId) async {
    await _client.post('/api/v1/notifications/$notificationId/read');
  }

  Future<void> registerDeviceToken(String token, String platform) async {
    await _client.post('/api/v1/notifications/device-token', body: {'token': token, 'platform': platform});
  }
}
