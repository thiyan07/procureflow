import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.loginWithMobileAndPassword(_mobileCtrl.text.trim(), _passwordCtrl.text).timeout(const Duration(seconds: 60), onTimeout: () => throw Exception('Server waking up (Render cold start) — took >60s. Please tap Login again in 10s. If still fails, check https://procureflow-api.onrender.com/health'));
      if (!mounted) return;
      setState(() => _loading = false);
      if (user.role == 'CENTRE_OPERATOR') {
        context.go('/operator');
      } else {
        context.go('/');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        var msg = e.toString().replaceAll('Exception:', '').trim();
        if (msg.contains('TimeoutException') || msg.contains('Future not completed')) {
          msg = 'Server waking up (Render cold start) — please wait 30s and tap Login again';
        } else if (msg.contains('SocketException') || msg.contains('Connection refused') || msg.contains('Failed host lookup')) {
          msg = 'Network error — cannot reach online server. Check internet. Local fallback: adb reverse tcp:8000 tcp:8000 + http://127.0.0.1:8000';
        } else if (msg.contains('ClientException')) {
          msg = msg.replaceAll('ClientException:', '').trim();
          if (msg.contains('Connection refused')) msg = 'Online server waking up — please retry in 30s (Render cold start)';
        }
        _error = msg;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              const Icon(Icons.agriculture, size: 48, color: Color(0xFF2E7D32)),
              const SizedBox(height: 12),
              Semantics(
                label: 'Welcome to ProcureFlow',
                child: Text('Welcome to ProcureFlow', style: Theme.of(context).textTheme.headlineMedium),
              ),
              const SizedBox(height: 6),
              Text(
                'Login with your mobile number and password.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [
                  Icon(Icons.lock_outline, size: 14, color: Color(0xFF1565C0)),
                  SizedBox(width: 6),
                  Text('Password stored securely in DB', style: TextStyle(fontSize: 11, color: Color(0xFF1565C0), fontWeight: FontWeight.w600)),
                ]),
              ),
              const SizedBox(height: 14),
              if (_error != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade700, fontSize: 13)),
                ),
              if (_error != null) const SizedBox(height: 16),
              TextFormField(
                controller: _mobileCtrl,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                decoration: const InputDecoration(
                  labelText: 'Mobile number',
                  hintText: '9876543210',
                  prefixText: '+91 ',
                  prefixIcon: Icon(Icons.phone_outlined),
                  counterText: '',
                ),
                validator: (v) => FormValidators.mobile(v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: '••••••',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                validator: (v) => FormValidators.password(v),
              ),
              const SizedBox(height: 16),
              PrimaryButton(label: 'Login', onPressed: _loading ? null : _login, loading: _loading, icon: Icons.login),
              const SizedBox(height: 12),
              Center(
                child: Wrap(spacing: 8, children: [
                  _DemoChip(label: 'Farmer: 9876543210 / password123', onTap: () {
                    _mobileCtrl.text = '9876543210';
                    _passwordCtrl.text = 'password123';
                    setState(() {});
                  }),
                  _DemoChip(label: 'Operator: 9876543211 / password123', onTap: () {
                    _mobileCtrl.text = '9876543211';
                    _passwordCtrl.text = 'password123';
                    setState(() {});
                  }),
                ]),
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Center(
                child: Column(children: [
                  Text("Don't have an account?", style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
                  TextButton(onPressed: () => context.push('/register'), child: const Text('Register as Farmer')),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DemoChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _DemoChip({required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return ActionChip(label: Text(label, style: const TextStyle(fontSize: 11)), onPressed: onTap);
  }
}
