import '../core/constants/app_constants.dart';

/// Strongly typed Procurement aggregates per spec Phase 1.
/// Covers stages: bookingConfirmed -> paymentCompleted, with sub-entities.
class Weighment {
  final double grossWeightQuintal;
  final double netWeightQuintal;
  final DateTime? weighedAt;
  final String? operatorId;

  const Weighment({required this.grossWeightQuintal, required this.netWeightQuintal, this.weighedAt, this.operatorId});

  Map<String, dynamic> toJson() => {
        'grossWeightQuintal': grossWeightQuintal,
        'netWeightQuintal': netWeightQuintal,
        'weighedAt': weighedAt?.toIso8601String(),
        'operatorId': operatorId,
      };
}

class QualityCheck {
  final String grade; // A/B/C
  final double moisturePercent;
  final bool passed;
  final String? remarks;
  final DateTime? checkedAt;

  const QualityCheck({required this.grade, required this.moisturePercent, required this.passed, this.remarks, this.checkedAt});
}

class Procurement {
  final String id;
  final String bookingId;
  final String farmerId;
  final String centreId;
  final String commodity;
  final double quantityQuintal;
  final ProcurementStage stage;
  final Weighment? weighment;
  final QualityCheck? qualityCheck;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? auditOperatorId;

  const Procurement({
    required this.id,
    required this.bookingId,
    required this.farmerId,
    required this.centreId,
    required this.commodity,
    required this.quantityQuintal,
    required this.stage,
    this.weighment,
    this.qualityCheck,
    required this.createdAt,
    this.completedAt,
    this.auditOperatorId,
  });

  Procurement copyWith({ProcurementStage? stage, Weighment? weighment, QualityCheck? qualityCheck, DateTime? completedAt}) => Procurement(
        id: id,
        bookingId: bookingId,
        farmerId: farmerId,
        centreId: centreId,
        commodity: commodity,
        quantityQuintal: quantityQuintal,
        stage: stage ?? this.stage,
        weighment: weighment ?? this.weighment,
        qualityCheck: qualityCheck ?? this.qualityCheck,
        createdAt: createdAt,
        completedAt: completedAt ?? this.completedAt,
        auditOperatorId: auditOperatorId,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'bookingId': bookingId,
        'farmerId': farmerId,
        'centreId': centreId,
        'commodity': commodity,
        'quantityQuintal': quantityQuintal,
        'stage': stage.name,
        'createdAt': createdAt.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
      };
}
