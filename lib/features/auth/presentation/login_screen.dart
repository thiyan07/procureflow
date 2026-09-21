import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/providers.dart';

enum _LoginMode { mobile, email }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();

  _LoginMode _mode = _LoginMode.mobile;
  bool _obscurePassword = true;
  bool _otpSent = false;
  bool _loadingMobile = false;
  bool _loadingOtpSend = false;
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _passwordCtrl.dispose();
    _emailCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginMobile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loadingMobile = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.loginWithMobileAndPassword(_mobileCtrl.text.trim(), _passwordCtrl.text);
      if (!mounted) return;
      if (user.role == 'CENTRE_OPERATOR') {
        context.go('/operator');
      } else {
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception:', '').trim();
        _loadingMobile = false;
      });
    }
  }

  Future<void> _sendOtp() async {
    final emailError = FormValidators.email(_emailCtrl.text.trim());
    if (emailError != null) {
      setState(() => _error = emailError);
      return;
    }
    setState(() {
      _loadingOtpSend = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.sendOtpToEmail(_emailCtrl.text.trim());
      setState(() {
        _otpSent = true;
        _loadingOtpSend = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent to email (Brevo). Use 123456 in dev.')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception:', '').trim();
        _loadingOtpSend = false;
      });
    }
  }

  Future<void> _verifyEmail() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.loginWithEmailAndOtp(_emailCtrl.text.trim(), _otpCtrl.text.trim());
      if (!mounted) return;
      if (user.role == 'CENTRE_OPERATOR') {
        context.go('/operator');
      } else {
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception:', '').trim();
        _verifying = false;
      });
    }
  }

  void _switchMode(_LoginMode m) {
    if (_mode == m) return;
    setState(() {
      _mode = m;
      _error = null;
      // do not clear controllers to preserve input when toggling
      if (m == _LoginMode.email) {
        // keep mobile vals
      } else {
        _otpSent = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = _mode == _LoginMode.mobile;
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
                isMobile
                    ? 'Login with your mobile number and password (stored in DB).'
                    : 'Enter your email to receive OTP via Brevo. No SMS needed.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 14),
              // Toggle ChoiceChip / SegmentedButton — theme-aware for dark mode visibility
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.phone, size: 16), SizedBox(width: 6), Text('Mobile')]),
                      selected: isMobile,
                      selectedColor: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      onSelected: (v) { if (v) _switchMode(_LoginMode.mobile); },
                      showCheckmark: false,
                      labelStyle: TextStyle(color: isMobile ? const Color(0xFF2E7D32) : Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ChoiceChip(
                      label: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.email_outlined, size: 16), SizedBox(width: 6), Text('Email OTP')]),
                      selected: !isMobile,
                      selectedColor: const Color(0xFF2E7D32).withValues(alpha: 0.15),
                      backgroundColor: Theme.of(context).colorScheme.surface,
                      onSelected: (v) { if (v) _switchMode(_LoginMode.email); },
                      showCheckmark: false,
                      labelStyle: TextStyle(color: !isMobile ? const Color(0xFF2E7D32) : Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.w600),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              if (!isMobile)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFFE8F5E9), borderRadius: BorderRadius.circular(8)),
                  child: const Row(children: [
                    Icon(Icons.mail_outline, size: 14, color: Color(0xFF2E7D32)),
                    SizedBox(width: 6),
                    Text('Brevo Email OTP', style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32), fontWeight: FontWeight.w600)),
                  ]),
                ),
              if (isMobile)
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

              // ----- Mobile mode -----
              if (isMobile) ...[
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
                PrimaryButton(label: 'Login', onPressed: _loadingMobile ? null : _loginMobile, loading: _loadingMobile, icon: Icons.login),
                const SizedBox(height: 8),
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
              ],

              // ----- Email mode -----
              if (!isMobile) ...[
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'farmer@procureflow.in',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (v) => FormValidators.email(v),
                  enabled: !_otpSent,
                ),
                const SizedBox(height: 12),
                if (!_otpSent)
                  PrimaryButton(label: 'Send OTP', onPressed: _loadingOtpSend ? null : _sendOtp, loading: _loadingOtpSend, icon: Icons.sms),
                if (_otpSent) ...[
                  TextFormField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      labelText: 'Enter OTP',
                      hintText: '123456',
                    ),
                    validator: (v) => FormValidators.otp(v),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF1F8E9), borderRadius: BorderRadius.circular(10)),
                    child: const Row(children: [
                      Icon(Icons.info_outline, size: 18, color: Color(0xFF2E7D32)),
                      SizedBox(width: 8),
                      Expanded(child: Text('Dev OTP: 123456 • Farmer: farmer@procureflow.in • Operator: operator@procureflow.in', style: TextStyle(fontSize: 11, color: Color(0xFF2E7D32)))),
                    ]),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(label: 'Verify OTP', onPressed: _verifyEmail, loading: _verifying, icon: Icons.verified_user),
                  const SizedBox(height: 12),
                  TextButton(onPressed: () => setState(() => _otpSent = false), child: const Text('Change email')),
                ],
                const SizedBox(height: 8),
                Center(
                  child: Wrap(spacing: 8, children: [
                    _DemoChip(label: 'Farmer: farmer@procureflow.in', onTap: () {
                      _emailCtrl.text = 'farmer@procureflow.in';
                      setState(() {});
                    }),
                    _DemoChip(label: 'Operator: operator@procureflow.in', onTap: () {
                      _emailCtrl.text = 'operator@procureflow.in';
                      setState(() {});
                    }),
                  ]),
                ),
              ],

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
