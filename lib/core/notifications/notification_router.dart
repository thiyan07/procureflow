import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Routes notification types to appropriate screens.
/// Called when user taps a push notification.
class NotificationRouter {
  static void handleTap(BuildContext context, Map<String, dynamic> data) {
    final type = data['type'] as String? ?? data['notification_type'] as String? ?? 'general';
    final bookingId = data['booking_id'] as String? ?? data['bookingId'] as String?;
    switch (type) {
      case 'turn_approaching':
      case 'token_called':
      case 'queue_position_changed':
      case 'queue':
        // Go to queue screen
        if (bookingId != null) {
          context.go('/queue', extra: bookingId);
        } else {
          context.go('/queue');
        }
        break;
      case 'procurement_stage_updated':
      case 'procurement_completed':
        if (bookingId != null) {
          context.go('/procurement', extra: bookingId);
        } else {
          context.go('/procurement');
        }
        break;
      case 'payment_status_updated':
        if (bookingId != null) {
          context.go('/payment', extra: bookingId);
        } else {
          context.go('/payment');
        }
        break;
      case 'slot_confirmed':
      case 'slot_reminder':
        context.go('/home');
        break;
      default:
        context.go('/notifications');
    }
  }

  /// For background handler (no context) - store pending route for next launch
  static String routeForType(String type, String? bookingId) {
    switch (type) {
      case 'turn_approaching':
      case 'token_called':
        return '/queue';
      case 'procurement_stage_updated':
        return '/procurement';
      case 'payment_status_updated':
        return '/payment';
      default:
        return '/notifications';
    }
  }
}
