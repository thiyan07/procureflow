import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final authRepo = ref.read(authRepositoryProvider);
    try {
      final user = await authRepo.getCurrentUser();
      if (!mounted) return;
      if (user == null) {
        context.go('/login');
      } else {
        if (user.role == 'CENTRE_OPERATOR') {
          context.go('/operator');
        } else {
          context.go('/');
        }
      }
    } catch (_) {
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryGreen,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.agriculture, size: 56, color: AppTheme.primaryGreen),
            ),
            const SizedBox(height: 24),
            const Text(
              'ProcureFlow',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            const Text(
              'Smart Procurement. Less Waiting.',
              style: TextStyle(fontSize: 16, color: Colors.white70, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 48),
            const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
            const SizedBox(height: 80),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(20)),
              child: const Text('DEMO MODE • OTP: 123456', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.8)),
            ),
          ],
        ),
      ),
    );
  }
}
