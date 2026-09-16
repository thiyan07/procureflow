import '../core/constants/app_constants.dart';

class Payment {
  final String id;
  final String bookingId;
  final String commodity;
  final double quantityQuintal;
  final double ratePerQuintal;
  final double totalAmount;
  final PaymentStatus status;
  final DateTime? paymentDate;
  final String? transactionId;

  const Payment({
    required this.id,
    required this.bookingId,
    required this.commodity,
    required this.quantityQuintal,
    required this.ratePerQuintal,
    required this.totalAmount,
    required this.status,
    this.paymentDate,
    this.transactionId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookingId': bookingId,
        'commodity': commodity,
        'quantityQuintal': quantityQuintal,
        'ratePerQuintal': ratePerQuintal,
        'totalAmount': totalAmount,
        'status': status.name,
        'paymentDate': paymentDate?.toIso8601String(),
        'transactionId': transactionId,
      };

  factory Payment.fromJson(Map<String, dynamic> j) => Payment(
        id: j['id'] as String,
        bookingId: j['bookingId'] as String,
        commodity: j['commodity'] as String,
        quantityQuintal: (j['quantityQuintal'] as num).toDouble(),
        ratePerQuintal: (j['ratePerQuintal'] as num).toDouble(),
        totalAmount: (j['totalAmount'] as num).toDouble(),
        status: PaymentStatus.values.byName(j['status'] as String),
        paymentDate: j['paymentDate'] != null ? DateTime.parse(j['paymentDate'] as String) : null,
        transactionId: j['transactionId'] as String?,
      );
}

class AppNotification {
  final String id;
  final String title;
  final String body;
  final String type; // slot_confirmed, queue, payment, etc
  final DateTime createdAt;
  final bool isRead;
  const AppNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.isRead = false,
  });

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        title: title,
        body: body,
        type: type,
        createdAt: createdAt,
        isRead: isRead ?? this.isRead,
      );
}
