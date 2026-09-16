class FormValidators {
  static String? requiredField(String? v, String field) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? mobile(String? v) {
    if (v == null || v.trim().isEmpty) return 'Mobile number is required';
    final digits = v.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 10) return 'Enter valid 10-digit mobile number';
    return null;
  }

  static String? otp(String? v) {
    if (v == null || v.trim().isEmpty) return 'OTP is required';
    if (v.length != 6) return 'OTP must be 6 digits';
    return null;
  }

  static String? quantity(String? v) {
    if (v == null || v.trim().isEmpty) return 'Quantity is required';
    final q = double.tryParse(v);
    if (q == null || q <= 0) return 'Enter valid quantity';
    if (q > 500) return 'Quantity too large (max 500)';
    return null;
  }
}
