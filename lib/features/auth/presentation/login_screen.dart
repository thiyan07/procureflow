import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
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
  final _mobileCtrl = TextEditingController(text: AppConstants.demoFarmerMobile);
  final _otpCtrl = TextEditingController();
  bool _otpSent = false;
  bool _loading = false;
  bool _verifying = false;
  String? _error;

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (FormValidators.mobile(_mobileCtrl.text) != null) {
      setState(() => _error = FormValidators.mobile(_mobileCtrl.text));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.sendOtp(_mobileCtrl.text.trim());
      setState(() {
        _otpSent = true;
        _loading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OTP sent. Use 123456 for demo.')),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      final user = await repo.loginWithMobileAndOtp(_mobileCtrl.text.trim(), _otpCtrl.text.trim());
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
              Text('Welcome to ProcureFlow', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 6),
              Text('Enter your mobile number to continue. No password needed.',
                  style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 24),
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
                  counterText: '',
                ),
                validator: (v) => FormValidators.mobile(v),
                enabled: !_otpSent || _verifying == false,
              ),
              const SizedBox(height: 12),
              if (!_otpSent)
                PrimaryButton(label: 'Send OTP', onPressed: _loading ? null : _sendOtp, loading: _loading, icon: Icons.sms),
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
                  child: Row(children: [
                    const Icon(Icons.info_outline, size: 18, color: Color(0xFF2E7D32)),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Demo OTP: 123456 • Operator: ${AppConstants.demoOperatorMobile}', style: const TextStyle(fontSize: 12, color: Color(0xFF2E7D32)))),
                  ]),
                ),
                const SizedBox(height: 16),
                PrimaryButton(label: 'Verify OTP', onPressed: _verify, loading: _verifying, icon: Icons.verified_user),
                const SizedBox(height: 12),
                TextButton(onPressed: () => setState(() => _otpSent = false), child: const Text('Change mobile number')),
              ],
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              Center(
                child: Column(children: [
                  const Text("Don't have an account?", style: TextStyle(color: Colors.black54)),
                  TextButton(onPressed: () => context.push('/register'), child: const Text('Register as Farmer')),
                ]),
              ),
              const SizedBox(height: 8),
              Center(
                child: Wrap(spacing: 8, children: [
                  _DemoChip(label: 'Farmer: ${AppConstants.demoFarmerMobile}', onTap: () {
                    _mobileCtrl.text = AppConstants.demoFarmerMobile;
                    setState(() {});
                  }),
                  _DemoChip(label: 'Operator: ${AppConstants.demoOperatorMobile}', onTap: () {
                    _mobileCtrl.text = AppConstants.demoOperatorMobile;
                    setState(() {});
                  }),
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
