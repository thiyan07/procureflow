import '../core/constants/app_constants.dart';
import '../models/farmer.dart';
import '../models/centre.dart';
import '../models/slot.dart';
import '../models/booking.dart';
import '../models/payment.dart';
import '../models/analytics.dart';

// Auth abstraction - mockable, later replace with Firebase/API
// Dual login: Mobile + Password (DB stored) and Email + OTP (Brevo)
abstract class AuthRepository {
  Future<AppUser?> getCurrentUser();
  Future<AppUser> loginWithMobileAndOtp(String mobile, String otp);
  Future<AppUser> loginWithMobileAndPassword(String mobile, String password);
  Future<AppUser> loginWithEmailAndOtp(String email, String otp);
  Future<AppUser> registerFarmer({
    required String fullName,
    required String mobile,
    required String password,
    String? email,
    required String farmerId,
    required String village,
    required String district,
    required String languageCode,
    required String primaryCommodity,
  });
  Future<void> logout();
  Future<void> sendOtp(String mobile);
  Future<void> sendOtpToEmail(String email);
}

abstract class FarmerRepository {
  Future<Farmer> getFarmer(String id);
  Future<Farmer> updateFarmer(Farmer farmer);
}

abstract class CentreRepository {
  Future<List<ProcurementCentre>> getCentres();
  Future<ProcurementCentre> getCentre(String id);
}

abstract class SlotRepository {
  Future<List<Slot>> getSlots(String centreId, DateTime date);
  Future<Booking> bookSlot({
    required String farmerId,
    required String centreId,
    required String commodity,
    required double quantity,
    required String slotId,
    List<CommodityItem>? commodities, // multi-commodity optional
  });
  Future<List<Booking>> getBookingsForFarmer(String farmerId);
  Future<Booking?> getActiveBooking(String farmerId);
  Future<Booking?> getBookingById(String bookingId);
}

abstract class QueueRepository {
  Future<QueueState> getQueueStatus(String bookingId);
  Stream<QueueState> watchQueue(String bookingId);
  // Operator actions
  Future<void> callNext(String centreId);
  Future<void> updateQueueStatus(String bookingId, QueueStatus status);
  Future<Map<String, dynamic>> getQueueCorrection(String bookingId);
}

class ComplianceResult {
  final bool verified;
  final String generatedJustification;
  final String reason;
  final String commodity;
  final double quantity;
  final String? grade;
  final double? moisture;
  const ComplianceResult({required this.verified, required this.generatedJustification, required this.reason, required this.commodity, required this.quantity, this.grade, this.moisture});
  factory ComplianceResult.fromJson(Map<String,dynamic> j) => ComplianceResult(
    verified: j['verified'] as bool, generatedJustification: j['generated_justification'] as String, reason: j['reason'] as String,
    commodity: j['commodity'] as String, quantity: (j['quantity'] as num).toDouble(), grade: j['grade'] as String?, moisture: (j['moisture'] as num?)?.toDouble());
}

abstract class ProcurementRepository {
  Future<List<TimelineStep>> getProcurementTimeline(String bookingId);
  Future<void> advanceStage(String bookingId, ProcurementStage stage);
  Future<ComplianceResult> complianceCheck(String bookingId, String question, String answer);
  Future<Map<String, dynamic>> getProcurement(String bookingId);
  Future<void> approveStage(String bookingId, ProcurementStage stage);
}

abstract class PaymentRepository {
  Future<Payment> getPayment(String bookingId);
}

abstract class NotificationRepository {
  Future<List<AppNotification>> getNotifications(String farmerId);
  Stream<AppNotification> watchNotifications(String farmerId);
  Future<void> markRead(String notificationId);
}

abstract class AIRepository {
  // Rule-based for MVP, replace with ML later
  Future<AIPrediction> predictWaitingTime({
    required int farmersAhead,
    required int avgProcessingMinutes,
    required int activeCounters,
    String? commodity,
    int? historicalLoadFactor,
  });
  Future<List<LoadPrediction>> predictCentreLoad(String centreId, DateTime date);
  Future<Slot?> recommendSlot(List<Slot> slots, String centreId, DateTime date);
  Future<String> answerAssistant(String query, {String? languageCode, Booking? activeBooking, QueueState? queueState, Payment? payment});
}
