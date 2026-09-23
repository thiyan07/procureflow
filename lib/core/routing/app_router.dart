import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/farmer/presentation/farmer_home_screen.dart';
import '../../features/farmer/presentation/profile_screen.dart';
import '../../features/farmer/presentation/settings_screen.dart';
import '../../features/procurement_centres/presentation/centres_screen.dart';
import '../../features/slots/presentation/slot_booking_screen.dart';
import '../../features/queue/presentation/token_screen.dart';
import '../../features/queue/presentation/queue_screen.dart';
import '../../features/procurement/presentation/procurement_screen.dart';
import '../../features/payments/presentation/payment_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/assistant/presentation/assistant_screen.dart';
import '../../features/staff/presentation/operator_dashboard_screen.dart';
import '../../features/staff/presentation/operator_queue_screen.dart';
import '../../features/staff/presentation/qr_scanner_screen.dart';
import '../../features/analytics/presentation/analytics_screen.dart';
import '../../features/planner/presentation/day_planner_screen.dart';
import '../../features/feedback/presentation/feedback_screen.dart';
import '../../features/bookings/presentation/booking_history_screen.dart';
import '../../features/receipt/presentation/receipt_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/register', builder: (c, s) => const RegisterScreen()),
      // Farmer
      GoRoute(path: '/', builder: (c, s) => const FarmerHomeScreen()),
      GoRoute(path: '/home', builder: (c, s) => const FarmerHomeScreen()),
      GoRoute(path: '/centres', builder: (c, s) => const CentresScreen()),
      // Booking aliases: spec /booking and legacy /slots
      GoRoute(path: '/booking', builder: (c, s) => const SlotBookingScreen()),
      GoRoute(path: '/slots', builder: (c, s) => const SlotBookingScreen()),
      GoRoute(path: '/token', builder: (c, s) => const TokenScreen()),
      GoRoute(path: '/queue', builder: (c, s) => const QueueScreen()),
      GoRoute(path: '/procurement', builder: (c, s) => const ProcurementScreen()),
      GoRoute(path: '/payment', builder: (c, s) => const PaymentScreen()),
      GoRoute(path: '/notifications', builder: (c, s) => const NotificationsScreen()),
      GoRoute(path: '/assistant', builder: (c, s) => const AssistantScreen()),
      GoRoute(path: '/planner', builder: (c, s) => const DayPlannerScreen()),
      GoRoute(path: '/feedback', builder: (c, s) => const FeedbackScreen()),
      GoRoute(path: '/history', builder: (c, s) => const BookingHistoryScreen()),
      GoRoute(path: '/receipt', builder: (c, s) => const ReceiptScreen()),
      GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      // Operator per spec
      GoRoute(path: '/operator', builder: (c, s) => const OperatorDashboardScreen()),
      GoRoute(path: '/operator/queue', builder: (c, s) => const OperatorQueueScreen()),
      GoRoute(path: '/operator/scan', builder: (c, s) => const QrScannerScreen()),
      GoRoute(path: '/operator/procurement', builder: (c, s) => const ProcurementScreen()),
      GoRoute(path: '/operator/analytics', builder: (c, s) => const AnalyticsScreen()),
      // Legacy alias for analytics
      GoRoute(path: '/analytics', builder: (c, s) => const AnalyticsScreen()),
    ],
    errorBuilder: (c, s) => Scaffold(body: Center(child: Text(s.error.toString()))),
  );
}
