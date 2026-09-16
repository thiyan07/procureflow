import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/form_validators.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../services/providers.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _farmerIdCtrl = TextEditingController(text: 'FARM-2026-00');
  final _villageCtrl = TextEditingController();
  final _districtCtrl = TextEditingController(text: 'Erode');
  String _language = 'en';
  String _commodity = 'Paddy';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _farmerIdCtrl.dispose();
    _villageCtrl.dispose();
    _districtCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(authRepositoryProvider);
      await repo.registerFarmer(
        fullName: _nameCtrl.text.trim(),
        mobile: _mobileCtrl.text.trim(),
        farmerId: _farmerIdCtrl.text.trim(),
        village: _villageCtrl.text.trim(),
        district: _districtCtrl.text.trim(),
        languageCode: _language,
        primaryCommodity: _commodity,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Registration successful')));
      context.go('/');
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception:', '').trim();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farmer Registration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Create your farmer profile', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('Simple, quick and farmer-friendly.', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            if (_error != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                child: Text(_error!, style: TextStyle(color: Colors.red.shade700)),
              ),
            TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: 'Full name *'), validator: (v) => FormValidators.requiredField(v, 'Full name')),
            const SizedBox(height: 12),
            TextFormField(controller: _mobileCtrl, keyboardType: TextInputType.phone, maxLength: 10, decoration: const InputDecoration(labelText: 'Mobile number *', prefixText: '+91 ', counterText: ''), validator: (v) => FormValidators.mobile(v)),
            const SizedBox(height: 12),
            TextFormField(controller: _farmerIdCtrl, decoration: const InputDecoration(labelText: 'Farmer ID *', hintText: 'FARM-2026-00127'), validator: (v) => FormValidators.requiredField(v, 'Farmer ID')),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(controller: _villageCtrl, decoration: const InputDecoration(labelText: 'Village *'), validator: (v) => FormValidators.requiredField(v, 'Village'))),
              const SizedBox(width: 12),
              Expanded(child: TextFormField(controller: _districtCtrl, decoration: const InputDecoration(labelText: 'District *'), validator: (v) => FormValidators.requiredField(v, 'District'))),
            ]),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _language,
              decoration: const InputDecoration(labelText: 'Preferred language'),
              items: const [
                DropdownMenuItem(value: 'en', child: Text('English')),
                DropdownMenuItem(value: 'hi', child: Text('Hindi - हिंदी')),
                DropdownMenuItem(value: 'ta', child: Text('Tamil - தமிழ்')),
              ],
              onChanged: (v) => setState(() => _language = v!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _commodity,
              decoration: const InputDecoration(labelText: 'Primary commodity'),
              items: AppConstants.commodities.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _commodity = v!),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Create Account', onPressed: _register, loading: _loading, icon: Icons.person_add),
            const SizedBox(height: 12),
            Center(child: TextButton(onPressed: () => context.go('/login'), child: const Text('Already have an account? Login'))),
          ]),
        ),
      ),
    );
  }
}
