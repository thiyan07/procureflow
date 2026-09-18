class ApiError implements Exception {
  final String code;
  final String message;
  const ApiError(this.code, this.message);
  @override
  String toString() => 'ApiError($code): $message';
}

/// Map HttpException messages to user-friendly
String userFriendlyMessage(Object e) {
  final msg = e.toString();
  if (msg.contains('SLOT_FULL')) return 'This slot is no longer available.';
  if (msg.contains('DUPLICATE_BOOKING')) return 'You already have an active booking.';
  if (msg.contains('CENTRE_CLOSED')) return 'Centre is closed.';
  if (msg.contains('INVALID_OTP')) return 'Invalid OTP.';
  return msg.replaceFirst('HttpException: ', '');
}
