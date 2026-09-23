class ApiError implements Exception {
  final String code;
  final String message;
  const ApiError(this.code, this.message);
  @override
  String toString() => 'ApiError($code): $message';
}

/// Map HttpException messages to user-friendly — strips uri noise
String userFriendlyMessage(Object e) {
  var msg = e.toString();
  // HttpException: message, uri = http://... — strip uri part
  if (msg.contains(', uri =')) msg = msg.split(', uri =').first;
  msg = msg.replaceFirst('HttpException: ', '').replaceFirst('Exception: ', '').replaceFirst('ApiError', '').trim();
  // strip remaining prefix like (CODE): 
  msg = msg.replaceAll(RegExp(r'\(.*?\)\s*:\s*'), '');
  msg = msg.replaceAll(RegExp(r'^:\s*'), '');
  if (msg.contains('SLOT_FULL')) return 'This slot is no longer available.';
  if (msg.contains('DUPLICATE_BOOKING')) return 'You already have an active booking.';
  if (msg.contains('CENTRE_CLOSED')) return 'Centre is closed.';
  if (msg.contains('INVALID_OTP')) return 'Invalid OTP.';
  if (msg.contains('ALREADY_CANCELLED')) return 'Already cancelled.';
  if (msg.contains('CANCELLATION_BLOCKED')) return 'Cannot cancel after procurement started.';
  if (msg.contains('Something went wrong') || msg.contains('INTERNAL_ERROR')) return 'Server error — please retry. If persists, contact support.';
  // fallback: first line only, max 120 chars
  msg = msg.split('\n').first.trim();
  if (msg.length > 120) msg = msg.substring(0,120);
  return msg.isEmpty ? 'Something went wrong' : msg;
}
