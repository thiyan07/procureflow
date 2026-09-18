import '../../core/network/api_client.dart';
import '../../core/constants/app_constants.dart';
import '../../models/payment.dart';
import '../repositories.dart';

class ApiPaymentRepository implements PaymentRepository {
  final ApiClient _client;
  ApiPaymentRepository(this._client);

  @override
  Future<Payment> getPayment(String bookingId) async {
    final res = await _client.get('/api/v1/payments/$bookingId');
    return Payment(
      id: res['id'] as String,
      bookingId: res['booking_id'] as String? ?? bookingId,
      commodity: res['commodity'] as String,
      quantityQuintal: (res['quantity_quintal'] as num).toDouble(),
      ratePerQuintal: (res['rate_per_quintal'] as num).toDouble(),
      totalAmount: (res['total_amount'] as num).toDouble(),
      status: _parse(res['status'] as String),
      paymentDate: res['payment_date'] != null ? DateTime.tryParse(res['payment_date'] as String) : null,
      transactionId: res['transaction_id'] as String?,
    );
  }

  PaymentStatus _parse(String s) {
    switch (s.toUpperCase()) {
      case 'PENDING': return PaymentStatus.pending;
      case 'PROCESSING': return PaymentStatus.processing;
      case 'COMPLETED': return PaymentStatus.completed;
      case 'FAILED': return PaymentStatus.failed;
      default: return PaymentStatus.pending;
    }
  }
}
