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
      // Splash uses GoRouter for navigation, provide minimal router
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
      expect(find.text('DEMO MODE • OTP: 123456'), findsOneWidget);
      expect(find.byIcon(Icons.agriculture), findsOneWidget);
      // pump past timer
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
      // after splash, should navigate to login when unauthenticated
      expect(find.text('Login'), findsOneWidget);
    });

    testWidgets('Login shows mobile and OTP flow', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ));
      expect(find.text('Welcome to ProcureFlow'), findsOneWidget);
      expect(find.text('Mobile number'), findsOneWidget);
      expect(find.text('Send OTP'), findsOneWidget);
      // clear and test validation shows error
      await tester.enterText(find.byType(TextFormField).first, '');
      await tester.tap(find.text('Send OTP'));
      await tester.pump();
      expect(find.textContaining('Mobile number is required'), findsOneWidget);
      // enter valid and send — mock has 800ms delay
      await tester.enterText(find.byType(TextFormField).first, '9876543210');
      await tester.tap(find.text('Send OTP'));
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();
      expect(find.text('Enter OTP'), findsOneWidget);
      expect(find.text('Verify OTP'), findsOneWidget);
      expect(find.text('Demo OTP: 123456 • Operator: 9876543211'), findsOneWidget);
    });

    testWidgets('Register shows all required fields', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(const ProviderScope(child: MaterialApp(home: RegisterScreen())));
      expect(find.text('Create your farmer profile'), findsOneWidget);
      expect(find.text('Full name *'), findsOneWidget);
      expect(find.text('Mobile number *'), findsOneWidget);
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
      expect(find.text('Farmer: 9876543210'), findsOneWidget);
      expect(find.text('Operator: 9876543211'), findsOneWidget);
      await tester.tap(find.text('Operator: 9876543211'));
      await tester.pump();
      final field = tester.widget<TextFormField>(find.byType(TextFormField).first);
      expect((field.controller?.text ?? ''), '9876543211');
    });
  });
}
