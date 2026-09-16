import '../core/constants/app_constants.dart';

/// Immutable QueueToken - digital token issued after slot booking.
/// Part of Phase 1 initial models per spec.
class QueueToken {
  final String tokenId;
  final String bookingId;
  final String centreId;
  final String centreName;
  final String tokenNumber; // e.g. "#27"
  final DateTime slotStart;
  final DateTime slotEnd;
  final QueueStatus status;
  final int ordinal; // numeric position like 27
  final DateTime issuedAt;
  final String qrData; // encoded for gate scan

  const QueueToken({
    required this.tokenId,
    required this.bookingId,
    required this.centreId,
    required this.centreName,
    required this.tokenNumber,
    required this.slotStart,
    required this.slotEnd,
    required this.status,
    required this.ordinal,
    required this.issuedAt,
    required this.qrData,
  });

  factory QueueToken.fromBooking({
    required String bookingId,
    required String centreId,
    required String centreName,
    required String tokenNumber,
    required int ordinal,
    required DateTime slotStart,
    required DateTime slotEnd,
    QueueStatus status = QueueStatus.waiting,
  }) {
    return QueueToken(
      tokenId: 'qt_$bookingId',
      bookingId: bookingId,
      centreId: centreId,
      centreName: centreName,
      tokenNumber: tokenNumber,
      slotStart: slotStart,
      slotEnd: slotEnd,
      status: status,
      ordinal: ordinal,
      issuedAt: DateTime.now(),
      qrData: 'PROCUREFLOW|$bookingId|$tokenNumber|$centreId',
    );
  }

  QueueToken copyWith({QueueStatus? status, int? ordinal}) => QueueToken(
        tokenId: tokenId,
        bookingId: bookingId,
        centreId: centreId,
        centreName: centreName,
        tokenNumber: tokenNumber,
        slotStart: slotStart,
        slotEnd: slotEnd,
        status: status ?? this.status,
        ordinal: ordinal ?? this.ordinal,
        issuedAt: issuedAt,
        qrData: qrData,
      );

  Map<String, dynamic> toJson() => {
        'tokenId': tokenId,
        'bookingId': bookingId,
        'centreId': centreId,
        'centreName': centreName,
        'tokenNumber': tokenNumber,
        'slotStart': slotStart.toIso8601String(),
        'slotEnd': slotEnd.toIso8601String(),
        'status': status.name,
        'ordinal': ordinal,
        'issuedAt': issuedAt.toIso8601String(),
        'qrData': qrData,
      };

  factory QueueToken.fromJson(Map<String, dynamic> j) => QueueToken(
        tokenId: j['tokenId'] as String,
        bookingId: j['bookingId'] as String,
        centreId: j['centreId'] as String,
        centreName: j['centreName'] as String,
        tokenNumber: j['tokenNumber'] as String,
        slotStart: DateTime.parse(j['slotStart'] as String),
        slotEnd: DateTime.parse(j['slotEnd'] as String),
        status: QueueStatus.values.byName(j['status'] as String),
        ordinal: j['ordinal'] as int,
        issuedAt: DateTime.parse(j['issuedAt'] as String),
        qrData: j['qrData'] as String,
      );
}
