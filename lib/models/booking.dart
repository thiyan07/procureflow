import '../core/constants/app_constants.dart';

class Booking {
  final String id;
  final String farmerId;
  final String centreId;
  final String centreName;
  final String commodity;
  final double quantityQuintal;
  final String tokenNumber; // e.g. #27
  final DateTime date;
  final DateTime slotStart;
  final DateTime slotEnd;
  final QueueStatus queueStatus;
  final ProcurementStage procurementStage;
  final DateTime createdAt;
  final DateTime? completedAt;

  const Booking({
    required this.id,
    required this.farmerId,
    required this.centreId,
    required this.centreName,
    required this.commodity,
    required this.quantityQuintal,
    required this.tokenNumber,
    required this.date,
    required this.slotStart,
    required this.slotEnd,
    required this.queueStatus,
    required this.procurementStage,
    required this.createdAt,
    this.completedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'farmerId': farmerId,
        'centreId': centreId,
        'centreName': centreName,
        'commodity': commodity,
        'quantityQuintal': quantityQuintal,
        'tokenNumber': tokenNumber,
        'date': date.toIso8601String(),
        'slotStart': slotStart.toIso8601String(),
        'slotEnd': slotEnd.toIso8601String(),
        'queueStatus': queueStatus.name,
        'procurementStage': procurementStage.name,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as String,
        farmerId: j['farmerId'] as String,
        centreId: j['centreId'] as String,
        centreName: j['centreName'] as String,
        commodity: j['commodity'] as String,
        quantityQuintal: (j['quantityQuintal'] as num).toDouble(),
        tokenNumber: j['tokenNumber'] as String,
        date: DateTime.parse(j['date'] as String),
        slotStart: DateTime.parse(j['slotStart'] as String),
        slotEnd: DateTime.parse(j['slotEnd'] as String),
        queueStatus: QueueStatus.values.byName(j['queueStatus'] as String),
        procurementStage: ProcurementStage.values.byName(j['procurementStage'] as String),
        createdAt: DateTime.parse(j['createdAt'] as String),
        completedAt: j['completedAt'] != null ? DateTime.parse(j['completedAt'] as String) : null,
      );

  Booking copyWith({QueueStatus? queueStatus, ProcurementStage? procurementStage}) => Booking(
        id: id,
        farmerId: farmerId,
        centreId: centreId,
        centreName: centreName,
        commodity: commodity,
        quantityQuintal: quantityQuintal,
        tokenNumber: tokenNumber,
        date: date,
        slotStart: slotStart,
        slotEnd: slotEnd,
        queueStatus: queueStatus ?? this.queueStatus,
        procurementStage: procurementStage ?? this.procurementStage,
        createdAt: createdAt,
        completedAt: completedAt,
      );
}

class QueueState {
  final String bookingId;
  final String tokenNumber;
  final int currentTokenOrdinal;
  final int yourOrdinal;
  final int farmersAhead;
  final int estimatedWaitMinutes;
  final QueueStatus status;

  const QueueState({
    required this.bookingId,
    required this.tokenNumber,
    required this.currentTokenOrdinal,
    required this.yourOrdinal,
    required this.farmersAhead,
    required this.estimatedWaitMinutes,
    required this.status,
  });
}

class TimelineStep {
  final String title;
  final String subtitle;
  final DateTime? timestamp;
  final bool isCompleted;
  final bool isCurrent;
  const TimelineStep({
    required this.title,
    required this.subtitle,
    this.timestamp,
    required this.isCompleted,
    required this.isCurrent,
  });
}
