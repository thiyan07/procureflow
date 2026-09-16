import 'package:intl/intl.dart';

class AppDateUtils {
  static String formatDate(DateTime d) => DateFormat('dd MMM, yyyy').format(d);
  static String formatTime(DateTime d) => DateFormat('hh:mm a').format(d);
  static String formatSlot(DateTime start, DateTime end) =>
      '${DateFormat('hh:mm a').format(start)} - ${DateFormat('hh:mm a').format(end)}';
  static String timeAgo(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return formatDate(d);
  }

  static String greeting(DateTime now) {
    final h = now.hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }
}
