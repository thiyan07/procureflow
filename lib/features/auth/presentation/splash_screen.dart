import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/config/demo_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/providers.dart';
import '../../../core/network/api_client.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _decided = false;
  bool _disposed = false;
  Timer? _warmTimer;
  Completer<void>? _warmCompleter;

  @override
  void initState() {
    super.initState();
    // Use post-frame to avoid navigation during build / restart loops
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  @override
  void dispose() {
    _disposed = true;
    _warmTimer?.cancel();
    _warmCompleter?.complete();
    super.dispose();
  }

  Future<void> _cancellableDelay(Duration d) async {
    if (_disposed) return;
    final completer = Completer<void>();
    _warmCompleter = completer;
    _warmTimer = Timer(d, () {
      if (!completer.isCompleted) completer.complete();
    });
    await completer.future;
    _warmTimer = null;
    _warmCompleter = null;
  }

  String _warmStatus = 'Warming up server...';

  Future<void> _warmBackend() async {
    // Fire-and-forget warm: don't block navigation, just update status
    final client = ref.read(apiClientProvider);
    for (int i = 0; i < 3; i++) {
      if (_disposed) return;
      try {
        await client.get('/health', auth: false).timeout(const Duration(seconds: 8));
        if (mounted) setState(() => _warmStatus = 'Server ready');
        return;
      } catch (_) {
        if (mounted) setState(() => _warmStatus = i == 0 ? 'Waking up server...' : 'Waking up server... ${i + 1}/3');
        await _cancellableDelay(const Duration(seconds: 3));
      }
    }
    if (mounted) setState(() => _warmStatus = 'Server ready — you can login');
  }

  Future<void> _decide() async {
    if (_decided) return;
    // Don't block auth check on warm — warm in background
    unawaited(_warmBackend());
    await Future.delayed(const Duration(milliseconds: 1400));
    if (!mounted || _decided) return;
    _decided = true;
    final authRepo = ref.read(authRepositoryProvider);
    try {
      final user = await authRepo.getCurrentUser();
      if (!mounted) return;
      final currentLoc = GoRouterState.of(context).uri.toString();
      if (user == null) {
        if (currentLoc != '/login') context.go('/login');
      } else {
        final target = user.role == 'CENTRE_OPERATOR' ? '/operator' : '/';
        if (currentLoc != target) context.go(target);
      }
    } catch (_) {
      if (mounted) {
        final cur = GoRouterState.of(context).uri.toString();
        if (cur != '/login') context.go('/login');
      }
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
            SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
            const SizedBox(height: 12),
            Text(_warmStatus, style: TextStyle(color: Colors.white70, fontSize: 11)),
            const SizedBox(height: 68),
            if (DemoConfig.isDemoMode)
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
