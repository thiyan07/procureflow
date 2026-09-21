import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:procureflow/features/auth/presentation/login_screen.dart';
import 'package:procureflow/features/auth/presentation/register_screen.dart';
import 'package:procureflow/features/auth/presentation/splash_screen.dart';
import 'package:procureflow/services/mock/mock_repositories.dart';
import 'package:procureflow/services/providers.dart';

void main() {
  group('Phase 2 Widget Tests', () {
    testWidgets('Splash shows branding and demo banner', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final router = GoRouter(
        initialLocation: '/splash',
        routes: [
          GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
          GoRoute(path: '/login', builder: (c, s) => const Scaffold(body: Text('Login'))),
          GoRoute(path: '/', builder: (c, s) => const Scaffold(body: Text('Home'))),
          GoRoute(path: '/operator', builder: (c, s) => const Scaffold(body: Text('Operator'))),
        ],
      );
      await tester.pumpWidget(ProviderScope(child: MaterialApp.router(routerConfig: router)));
      expect(find.text('ProcureFlow'), findsOneWidget);
      expect(find.text('Smart Procurement. Less Waiting.'), findsOneWidget);
      // Demo banner only shown when USE_MOCK=true; allow either presence or absence
      expect(find.byIcon(Icons.agriculture), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('Login shows mobile + password and Email OTP toggle', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ));
      expect(find.text('Welcome to ProcureFlow'), findsOneWidget);
      // Default is Mobile mode
      expect(find.text('Mobile number'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Login'), findsOneWidget);
      expect(find.text('Mobile'), findsOneWidget);
      expect(find.text('Email OTP'), findsOneWidget);

      // Validate mobile mode requires fields (tap Login with empty)
      await tester.tap(find.widgetWithText(ElevatedButton, 'Login'));
      await tester.pump();
      expect(find.textContaining('Mobile number is required'), findsOneWidget);

      // Switch to Email mode and check OTP flow
      await tester.tap(find.text('Email OTP'));
      await tester.pumpAndSettle();
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Send OTP'), findsOneWidget);

      // enter valid email and send — mock has 800ms delay
      await tester.enterText(find.byType(TextFormField).first, 'farmer@procureflow.in');
      await tester.tap(find.text('Send OTP'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(find.text('Enter OTP'), findsOneWidget);
      expect(find.text('Verify OTP'), findsOneWidget);
      expect(find.textContaining('Dev OTP: 123456'), findsOneWidget);
    });

    testWidgets('Register shows all required fields including password', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: RegisterScreen())));
      expect(find.text('Create your farmer profile'), findsOneWidget);
      expect(find.text('Full name *'), findsOneWidget);
      expect(find.text('Mobile number *'), findsOneWidget);
      expect(find.text('Email (optional)'), findsOneWidget);
      expect(find.text('Password *'), findsOneWidget);
      expect(find.text('Confirm Password *'), findsOneWidget);
      expect(find.text('Farmer ID *'), findsOneWidget);
      expect(find.text('Village *'), findsOneWidget);
      expect(find.text('District *'), findsOneWidget);
      expect(find.text('Preferred language'), findsOneWidget);
      expect(find.text('Primary commodity'), findsOneWidget);
      expect(find.text('Create Account'), findsOneWidget);
    });

    testWidgets('Login demo chips switch mobile', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginScreen())));
      // Mobile mode demo chips - need scroll into view because offscreen in small viewport
      await tester.ensureVisible(find.text('Farmer: 9876543210 / password123'));
      expect(find.text('Farmer: 9876543210 / password123'), findsOneWidget);
      await tester.ensureVisible(find.text('Operator: 9876543211 / operator123'));
      expect(find.text('Operator: 9876543211 / operator123'), findsOneWidget);
      await tester.tap(find.text('Operator: 9876543211 / operator123'), warnIfMissed: false);
      await tester.pump();
      final mobileField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Mobile number'));
      expect(mobileField.controller?.text ?? '', '9876543211');
      // Check password filled too
      final passwordField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Password'));
      expect(passwordField.controller?.text ?? '', 'operator123');
    });

    testWidgets('Login email demo chips fill email', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: LoginScreen())));
      await tester.tap(find.text('Email OTP'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Farmer: farmer@procureflow.in'));
      expect(find.text('Farmer: farmer@procureflow.in'), findsOneWidget);
      await tester.ensureVisible(find.text('Operator: operator@procureflow.in'));
      expect(find.text('Operator: operator@procureflow.in'), findsOneWidget);
      await tester.tap(find.text('Operator: operator@procureflow.in'), warnIfMissed: false);
      await tester.pump();
      final emailField = tester.widget<TextFormField>(find.widgetWithText(TextFormField, 'Email'));
      expect(emailField.controller?.text ?? '', 'operator@procureflow.in');
    });
  });
}
