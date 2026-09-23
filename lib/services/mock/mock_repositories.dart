import 'dart:async';
import 'dart:convert';
import '../../core/constants/app_constants.dart';
import '../../core/storage/local_storage.dart';
import '../../models/farmer.dart';
import '../../models/centre.dart';
import '../../models/slot.dart';
import '../../models/booking.dart';
import '../../models/payment.dart';
import '../../models/analytics.dart';
import '../repositories.dart';
import 'mock_database.dart';

// ---------- Auth ----------
class MockAuthRepository implements AuthRepository {
  final _db = MockDatabase.instance;

  @override
  Future<AppUser?> getCurrentUser() async {
    final token = LocalStorage.instance.authToken;
    final jsonStr = LocalStorage.instance.getString(AppConstants.keyUserJson);
    if (token == null || jsonStr == null) return null;
    return AppUser.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);
  }

  @override
  Future<void> sendOtp(String mobile) async {
    await Future.delayed(AppConstants.mockDelay);
    // mock - always succeeds, OTP is 123456
  }

  @override
  Future<void> sendOtpToEmail(String email) async {
    await Future.delayed(AppConstants.mockDelay);
    // mock email OTP - always succeeds, OTP is 123456
  }

  @override
  Future<AppUser> loginWithMobileAndOtp(String mobile, String otp) async {
    await Future.delayed(AppConstants.mockDelay);
    if (otp != AppConstants.demoOtp) throw Exception('Invalid OTP. Use 123456 for demo');
    final role = mobile == AppConstants.demoOperatorMobile ? 'CENTRE_OPERATOR' : 'FARMER';
    final farmer = role == 'FARMER' ? _db.demoFarmer.copyWith() : null;
    final farmerWithMobile = farmer != null && mobile != farmer.mobile
        ? farmer.copyWith()
        : farmer;
    final user = AppUser(id: mobile == AppConstants.demoOperatorMobile ? 'op1' : _db.demoFarmer.id, mobile: mobile, role: role, farmer: farmerWithMobile);
    await LocalStorage.instance.saveAuth('mock_token_$mobile', UserRoleX.fromString(role), jsonEncode(user.toJson()));
    if (role == 'FARMER') _db.createDemoBookingIfMissing();
    return user;
  }

  @override
  Future<AppUser> loginWithMobileAndPassword(String mobile, String password) async {
    await Future.delayed(AppConstants.mockDelay);
    if (password.length < 6) throw Exception('Password must be at least 6 characters');
    final stored = _db.farmerPasswords[mobile];
    if (stored != null && stored != password) {
      throw Exception('Invalid mobile or password');
    }
    // If mobile not yet registered but password looks like demo, allow any registered demo mobiles or newly registered ones.
    // For unknown mobile with no stored password, treat as invalid unless it's a demo mobile with expected demo passwords.
    if (stored == null) {
      // Allow login for demoFarmer mobile with demo password if not yet overridden, or for any previously registered farmer
      // Check if mobile matches demoFarmer's original mobile or is known in email map
      final knownMobiles = {..._db.farmerPasswords.keys, _db.demoFarmer.mobile, AppConstants.demoOperatorMobile};
      if (!knownMobiles.contains(mobile)) {
        // If user registered via registerFarmer, their password was stored, so stored != null. Unknown mobile -> fail.
        throw Exception('Account not found. Please register first.');
      }
      // Known demo mobile but no stored check needed: accept common demo passwords
      const demoPasswords = ['password123', 'operator123', '123456', 'password'];
      if (!demoPasswords.contains(password) && stored == null && mobile == AppConstants.demoOperatorMobile) {
        throw Exception('Invalid mobile or password');
      }
    }
    final role = mobile == AppConstants.demoOperatorMobile ? 'CENTRE_OPERATOR' : 'FARMER';
    // If farmer, use stored demoFarmer or create lightweight farmer
    Farmer? farmer;
    if (role == 'FARMER') {
      if (_db.demoFarmer.mobile == mobile) {
        farmer = _db.demoFarmer;
      } else {
        // For other registered mobiles, try to find farmer by stored demoFarmer or synthesize
        farmer = Farmer(
          id: 'f_$mobile',
          fullName: _db.demoFarmer.fullName,
          mobile: mobile,
          farmerId: _db.demoFarmer.farmerId,
          village: _db.demoFarmer.village,
          district: _db.demoFarmer.district,
          languageCode: _db.demoFarmer.languageCode,
          primaryCommodity: _db.demoFarmer.primaryCommodity,
        );
      }
    }
    final user = AppUser(id: mobile == AppConstants.demoOperatorMobile ? 'op1' : farmer?.id ?? 'f_$mobile', mobile: mobile, role: role, farmer: farmer);
    await LocalStorage.instance.saveAuth('mock_token_$mobile', UserRoleX.fromString(role), jsonEncode(user.toJson()));
    if (role == 'FARMER') _db.createDemoBookingIfMissing();
    return user;
  }

  @override
  Future<AppUser> loginWithEmailAndOtp(String email, String otp) async {
    await Future.delayed(AppConstants.mockDelay);
    if (otp != AppConstants.demoOtp) throw Exception('Invalid OTP. Use 123456 for demo');
    final role = email.contains('operator') ? 'CENTRE_OPERATOR' : 'FARMER';
    final farmer = role == 'FARMER' ? _db.demoFarmer.copyWith() : null;
    final user = AppUser(id: email.hashCode.toString(), mobile: email, role: role, farmer: farmer);
    await LocalStorage.instance.saveAuth('mock_token_$email', UserRoleX.fromString(role), jsonEncode(user.toJson()));
    if (role == 'FARMER') _db.createDemoBookingIfMissing();
    return user;
  }

  @override
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
  }) async {
    await Future.delayed(AppConstants.mockDelay);
    if (password.length < 6) throw Exception('Password must be at least 6 characters');
    final farmer = Farmer(
      id: 'f_${DateTime.now().millisecondsSinceEpoch}',
      fullName: fullName,
      mobile: mobile,
      farmerId: farmerId,
      village: village,
      district: district,
      languageCode: languageCode,
      primaryCommodity: primaryCommodity,
    );
    _db.demoFarmer = farmer;
    _db.farmerPasswords[mobile] = password;
    if (email != null && email.trim().isNotEmpty) {
      _db.emailToMobile[email.trim()] = mobile;
    }
    final user = AppUser(id: farmer.id, mobile: mobile, role: 'FARMER', farmer: farmer);
    await LocalStorage.instance.saveAuth('mock_token_$mobile', UserRole.farmer, jsonEncode(user.toJson()));
    await LocalStorage.instance.saveLanguage(languageCode);
    return user;
  }

  @override
  Future<void> logout() async {
    await LocalStorage.instance.remove(AppConstants.keyAuthToken);
    await LocalStorage.instance.remove(AppConstants.keyUserJson);
    await LocalStorage.instance.remove(AppConstants.keyUserRole);
  }
}

// ---------- Farmer ----------
class MockFarmerRepository implements FarmerRepository {
  final _db = MockDatabase.instance;
  @override
  Future<Farmer> getFarmer(String id) async {
    await Future.delayed(const Duration(milliseconds: 400));
    return _db.demoFarmer;
  }

  @override
  Future<Farmer> updateFarmer(Farmer farmer) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _db.demoFarmer = farmer;
    // also update stored user json
    final userJson = LocalStorage.instance.getString(AppConstants.keyUserJson);
    if (userJson != null) {
      final user = AppUser.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      final updated = AppUser(id: user.id, mobile: user.mobile, role: user.role, farmer: farmer);
      await LocalStorage.instance.setString(AppConstants.keyUserJson, jsonEncode(updated.toJson()));
    }
    return farmer;
  }
}

// ---------- Centre ----------
class MockCentreRepository implements CentreRepository {
  final _db = MockDatabase.instance;
  @override
  Future<List<ProcurementCentre>> getCentres() async {
    await Future.delayed(AppConstants.mockDelay);
    return _db.centres;
  }

  @override
  Future<ProcurementCentre> getCentre(String id) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _db.centres.firstWhere((c) => c.id == id);
  }
}

// ---------- Slot ----------
class MockSlotRepository implements SlotRepository {
  final _db = MockDatabase.instance;

  @override
  Future<List<Slot>> getSlots(String centreId, DateTime date) async {
    await Future.delayed(AppConstants.mockDelay);
    final slots = _db.generateSlots(centreId, date);
    // Farmer-aware: check past bookings and commodity match for demo farmer
    final pastCount = _db.bookings.values.where((b) => b.farmerId == _db.demoFarmer.id && b.centreId == centreId).length;
    final commodityMatch = _db.demoFarmer.primaryCommodity.toLowerCase() == 'paddy'.toLowerCase();
    // bias: if pastCount>0 or commodityMatch, apply slight boost to first slots (deterministic)
    // For demo, still pick lowest occupancy but annotate farmer boost
    if (slots.isNotEmpty) {
      Slot? best;
      // Simple farmer-aware scoring simulation: booked - pastCount bias
      for (final s in slots) {
        if (s.isFull) continue;
        if (best == null) {
          best = s;
        } else {
          // farmer at Bhavani gets -2 effective booked
          final effBooked = s.booked - (centreId == 'c1' && pastCount > 0 ? 2 : 0) - (commodityMatch ? 1 : 0);
          final bestEff = best.booked - (centreId == 'c1' && pastCount > 0 ? 2 : 0) - (commodityMatch ? 1 : 0);
          if (effBooked < bestEff || (effBooked == bestEff && s.start.isBefore(best.start))) {
            best = s;
          }
        }
      }
      if (best != null) {
        return slots.map((s) => s.id == best!.id ? s.copyWith(isRecommended: true) : s).toList();
      }
    }
    return slots;
  }

  Future<Map<String, dynamic>?> getRecommendation(String centreId, DateTime date, {String commodity = 'Paddy', double qty = 10}) async {
    await Future.delayed(const Duration(milliseconds: 100));
    final pastCount = _db.bookings.values.where((b) => b.farmerId == _db.demoFarmer.id && b.centreId == centreId).length;
    final slots = _db.generateSlots(centreId, date);
    final available = slots.where((s) => !s.isFull).toList();
    if (available.isEmpty) return null;
    available.sort((a, b) => a.booked.compareTo(b.booked));
    final best = available.first;
    final centreName = _db.centres.firstWhere((c) => c.id == centreId, orElse: () => _db.centres.first).name;
    final shortWord = centreName.split(' ').first;
    String? personalized;
    if (pastCount > 0) {
      personalized = 'Recommended for you (past $pastCount booking${pastCount != 1 ? 's' : ''} at $shortWord)';
      if (_db.demoFarmer.primaryCommodity.toLowerCase() == commodity.toLowerCase()) {
        personalized += ' • $commodity match';
      }
    }
    return {
      'recommended_slot': {'id': best.id},
      'personalized_reason': personalized,
      'farmer_context': {
        'past_bookings_at_centre': pastCount,
        'centre_name': centreName,
        'distance_km': centreId == 'c1' ? 5.2 : 28.0,
        'commodity_match': _db.demoFarmer.primaryCommodity.toLowerCase() == commodity.toLowerCase(),
      },
      'reason': personalized ?? 'Lower expected centre load.',
    };
  }

  @override
  Future<Booking> bookSlot({
    required String farmerId,
    required String centreId,
    required String commodity,
    required double quantity,
    required String slotId,
    List<CommodityItem>? commodities,
  }) async {
    await Future.delayed(AppConstants.mockDelay);
    final centre = _db.centres.firstWhere((c) => c.id == centreId);
    // find slot
    Slot? slot;
    for (final list in _db.slotsByKey.values) {
      for (final s in list) {
        if (s.id == slotId) slot = s;
      }
    }
    if (slot == null) throw Exception('Slot not found');
    if (slot.isFull) throw Exception('Slot is full');
    // update booked count
    final key = '${centreId}_${slot.date.year}-${slot.date.month}-${slot.date.day}';
    final list = _db.slotsByKey[key];
    if (list != null) {
      final idx = list.indexWhere((s) => s.id == slotId);
      if (idx != -1) list[idx] = list[idx].copyWith(booked: list[idx].booked + 1);
    }
    // generate token ordinal: max +1
    final maxOrdinal = _db.bookingOrdinal.values.isEmpty ? 27 : _db.bookingOrdinal.values.reduce((a, b) => a > b ? a : b);
    final newOrdinal = maxOrdinal + 1;
    // handle multi-commodity
    final effCommodities = commodities;
    final effCommodity = effCommodities != null && effCommodities.isNotEmpty ? effCommodities.map((c)=>c.commodity).join(", ") : commodity;
    final effQty = effCommodities != null && effCommodities.isNotEmpty ? effCommodities.fold(0.0, (a,c)=>a+c.quantity) : quantity;
    final booking = Booking(
      id: 'b_${DateTime.now().millisecondsSinceEpoch}',
      farmerId: farmerId,
      centreId: centreId,
      centreName: centre.name,
      commodity: effCommodity,
      quantityQuintal: effQty,
      commodities: effCommodities,
      tokenNumber: '#$newOrdinal',
      date: slot.date,
      slotStart: slot.start,
      slotEnd: slot.end,
      queueStatus: QueueStatus.waiting,
      procurementStage: ProcurementStage.bookingConfirmed,
      createdAt: DateTime.now(),
    );
    _db.bookings[booking.id] = booking;
    _db.bookingOrdinal[booking.id] = newOrdinal;
    // create payment placeholder
    _db.payments[booking.id] = Payment(
      id: 'p_${booking.id}',
      bookingId: booking.id,
      commodity: commodity,
      quantityQuintal: quantity,
      ratePerQuintal: commodity == 'Paddy' ? 2200 : 1800,
      totalAmount: quantity * (commodity == 'Paddy' ? 2200 : 1800),
      status: PaymentStatus.pending,
    );
    return booking;
  }

  @override
  Future<List<Booking>> getBookingsForFarmer(String farmerId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    return _db.bookings.values.where((b) => b.farmerId == farmerId).toList();
  }

  @override
  Future<Booking?> getActiveBooking(String farmerId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final list = _db.bookings.values.where((b) => b.farmerId == farmerId && b.queueStatus != QueueStatus.completed && b.queueStatus != QueueStatus.cancelled).toList();
    if (list.isEmpty) return null;
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list.first;
  }

  @override
  Future<Booking?> getBookingById(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return _db.bookings[bookingId];
  }
}

// ---------- Queue ----------
class MockQueueRepository implements QueueRepository {
  final _db = MockDatabase.instance;

  @override
  Future<QueueState> getQueueStatus(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final booking = _db.bookings[bookingId];
    if (booking == null) throw Exception('Booking not found');
    final ordinal = _db.bookingOrdinal[bookingId] ?? 27;
    final ahead = (ordinal - _db.globalCurrentOrdinal).clamp(0, 100);
    final est = _calcWait(ahead, AppConstants.defaultCounters);
    return QueueState(
      bookingId: bookingId,
      tokenNumber: booking.tokenNumber,
      currentTokenOrdinal: _db.globalCurrentOrdinal,
      yourOrdinal: ordinal,
      farmersAhead: ahead,
      estimatedWaitMinutes: est,
      status: booking.queueStatus,
    );
  }

  int _calcWait(int ahead, int counters) {
    if (ahead <= 0) return 0;
    final base = (ahead * AppConstants.avgProcessingMinutes / counters).ceil();
    // add small peak factor 10%
    return (base * 1.1).ceil();
  }

  @override
  Stream<QueueState> watchQueue(String bookingId) async* {
    // simulate live updates every 3 sec, queue moves
    while (true) {
      await Future.delayed(const Duration(seconds: 3));
      // move global head occasionally
      if (_db.globalCurrentOrdinal < (_db.bookingOrdinal[bookingId] ?? 27)) {
        _db.globalCurrentOrdinal++;
      }
      yield await getQueueStatus(bookingId);
    }
  }

  @override
  Future<void> callNext(String centreId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    _db.globalCurrentOrdinal++;
  }

  @override
  Future<void> updateQueueStatus(String bookingId, QueueStatus status) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final b = _db.bookings[bookingId];
    if (b != null) _db.bookings[bookingId] = b.copyWith(queueStatus: status);
  }

  @override
  Future<Map<String, dynamic>> getQueueCorrection(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final booking = _db.bookings[bookingId];
    if (booking == null) return {};
    final ordinal = _db.bookingOrdinal[bookingId] ?? 27;
    // deterministic: simulate PROCESSING counted naive vs corrected
    // For mock, assume 1 PROCESSING ahead if ordinal>16 (so corrected differs by 1)
    final aheadCorrected = (ordinal - _db.globalCurrentOrdinal).clamp(0, 100);
    // naive includes PROCESSING as well (here same+1 if gap)
    final hasProcessingAhead = ordinal > 18 ? 1 : 0;
    final aheadNaive = aheadCorrected + hasProcessingAhead;
    final correctionApplied = aheadNaive != aheadCorrected;
    // gap detection: if ordinal gap >2 from global (simulated missed call)
    final gap = (ordinal - _db.globalCurrentOrdinal - aheadCorrected - 1).abs();
    final missedCall = gap > 2;
    // duplicate risk: check if another booking same date exists (mock)
    bool duplicateRisk = false;
    Map<String, dynamic> fraudFlags = {};
    for (final other in _db.bookings.values) {
      if (other.id != bookingId && other.farmerId == booking.farmerId && other.date.year == booking.date.year && other.date.month == booking.date.month && other.date.day == booking.date.day) {
        duplicateRisk = true;
        fraudFlags['cross_centre_duplicate'] = true;
        fraudFlags['cross_centre_token'] = other.tokenNumber;
        break;
      }
    }
    // mobile duplicate check (same mobile different farmerId)
    for (final other in _db.bookings.values) {
      if (other.id != bookingId && other.date.year == booking.date.year && other.date.month == booking.date.month && other.date.day == booking.date.day) {
        // find farmer mobile match: demoFarmer mobile vs other farmer
        // In mock, all bookings share demoFarmer, so skip
      }
    }
    return {
      'booking_id': bookingId,
      'token_number': booking.tokenNumber,
      'queue_position': ordinal,
      'farmers_ahead_corrected': aheadCorrected,
      'farmers_ahead_naive': aheadNaive,
      'farmers_ahead': aheadCorrected,
      'estimated_wait_corrected': _calcWait(aheadCorrected, AppConstants.defaultCounters),
      'estimated_wait_naive': _calcWait(aheadNaive, AppConstants.defaultCounters),
      'correction_applied': correctionApplied,
      'queueCorrectionNote': 'Queue position calculated from database, PROCESSING not counted as ahead',
      'correction_note': correctionApplied ? 'Queue position corrected — processing not counted' : null,
      'missed_call_flag': missedCall,
      'position_gap': gap,
      'gap': gap,
      'fraud_flags': fraudFlags,
      'duplicate_risk': duplicateRisk,
    };
  }
}

// ---------- Procurement ----------
class MockProcurementRepository implements ProcurementRepository {
  final _db = MockDatabase.instance;

  bool _requiresApproval(String bookingId) {
    final b = _db.bookings[bookingId];
    final p = _db.payments[bookingId];
    if (b != null && b.quantityQuintal > 50) return true;
    if (p != null && p.totalAmount > 100000) return true;
    return false;
  }

  String _stageToBackend(ProcurementStage s) {
    const map = {
      ProcurementStage.bookingConfirmed: 'BOOKING_CONFIRMED',
      ProcurementStage.arrivedAtCentre: 'ARRIVED',
      ProcurementStage.weighment: 'WEIGHMENT',
      ProcurementStage.qualityCheck: 'QUALITY_CHECK',
      ProcurementStage.procurement: 'PROCUREMENT',
      ProcurementStage.completed: 'COMPLETED',
      ProcurementStage.paymentProcessing: 'COMPLETED',
      ProcurementStage.paymentCompleted: 'COMPLETED',
    };
    return map[s] ?? 'ARRIVED';
  }

  @override
  Future<ComplianceResult> complianceCheck(String bookingId, String question, String answer) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final b = _db.bookings[bookingId];
    if (b == null) throw Exception('Booking not found');
    final al = answer.toLowerCase();
    // Deterministic rule mirrors backend compliance_service
    // For mock we don't have grade/moisture stored; assume Grade B scenario if question mentions Grade B
    final isGradeB = al.contains('iso') || al.contains('moisture');
    final verified = isGradeB && answer.length >= 10;
    final reason = verified
        ? 'Grade B justified — answer cites ISO/moisture spec matching recorded data.'
        : (answer.length < 10 ? 'Answer too brief for audit (min 10 chars).' : 'Answer does not cite required evidence (ISO/moisture) for grade B.');
    final verdict = verified ? 'VERIFIED' : 'NEEDS REVIEW';
    final justification = 'Audit Justification — TNCSC DPC Erode | Booking $bookingId | Token ${b.tokenNumber} | '
        'Commodity ${b.commodity} ${b.quantityQuintal} quintal | Grade ${isGradeB ? "B" : "PENDING"} | '
        'Moisture — | MSP ₹2441/q | Q: "$question" | A: "$answer" | Verdict: $verdict — $reason | Ref: $bookingId/${b.date.toIso8601String()} | Deterministic check, no ML.';
    return ComplianceResult(
      verified: verified,
      generatedJustification: justification,
      reason: reason,
      commodity: b.commodity,
      quantity: b.quantityQuintal,
      grade: isGradeB ? 'B' : null,
      moisture: null,
    );
  }

  @override
  Future<List<TimelineStep>> getProcurementTimeline(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final b = _db.bookings[bookingId];
    if (b == null) throw Exception('Booking not found');
    final stageIndex = ProcurementStage.values.indexOf(b.procurementStage);
    final titles = [
      'Booking Confirmed',
      'Arrived at Centre',
      'Weighment',
      'Quality Check',
      'Procurement',
      'Completed',
      'Payment Processing',
      'Payment Completed',
    ];
    final subs = [
      'Slot confirmed at ${b.centreName}',
      'Checked-in at gate',
      'Weighment in progress',
      'Grading and quality check',
      'Procurement approval',
      'Procurement completed',
      'Payment initiated to bank',
      'Payment credited',
    ];
    final List<TimelineStep> steps = [];
    for (int i = 0; i < titles.length; i++) {
      final isCompleted = i < stageIndex;
      final isCurrent = i == stageIndex;
      steps.add(TimelineStep(
        title: titles[i],
        subtitle: subs[i],
        timestamp: isCompleted || isCurrent ? b.createdAt.add(Duration(minutes: i * 10)) : null,
        isCompleted: isCompleted,
        isCurrent: isCurrent,
      ));
    }
    return steps;
  }

  @override
  Future<Map<String, dynamic>> getProcurement(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final b = _db.bookings[bookingId];
    if (b == null) throw Exception('Booking not found');
    final status = _db.procurementApprovalStatus[bookingId] ?? 'NONE';
    final pending = _db.procurementPendingStage[bookingId];
    return {
      'id': bookingId,
      'booking_id': bookingId,
      'stage': _stageToBackend(b.procurementStage),
      'approval_status': status,
      'pending_stage': pending,
      'created_at': b.createdAt.toIso8601String(),
    };
  }

  @override
  Future<void> approveStage(String bookingId, ProcurementStage stage) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // only admin path — set approved and advance
    final backendStage = _stageToBackend(stage);
    final pending = _db.procurementPendingStage[bookingId];
    if (pending != null && pending != backendStage) {
      throw Exception('Pending is $pending, requested $backendStage');
    }
    _db.procurementApprovalStatus[bookingId] = 'ADMIN_APPROVED';
    _db.procurementPendingStage.remove(bookingId);
    final b = _db.bookings[bookingId];
    if (b != null) _db.bookings[bookingId] = b.copyWith(procurementStage: stage);
    if (stage == ProcurementStage.paymentProcessing) {
      final p = _db.payments[bookingId];
      if (p != null) _db.payments[bookingId] = Payment(
        id: p.id, bookingId: p.bookingId, commodity: p.commodity, quantityQuintal: p.quantityQuintal, ratePerQuintal: p.ratePerQuintal, totalAmount: p.totalAmount, status: PaymentStatus.processing);
    } else if (stage == ProcurementStage.paymentCompleted) {
      final p = _db.payments[bookingId];
      if (p != null) _db.payments[bookingId] = Payment(
        id: p.id, bookingId: p.bookingId, commodity: p.commodity, quantityQuintal: p.quantityQuintal, ratePerQuintal: p.ratePerQuintal, totalAmount: p.totalAmount, status: PaymentStatus.completed, paymentDate: DateTime.now(), transactionId: 'TXN${DateTime.now().millisecondsSinceEpoch}');
    }
  }

  @override
  Future<void> advanceStage(String bookingId, ProcurementStage stage) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // Check if requires approval and not already pending admin path (simulate operator role)
    // For mock, we inspect current stored user role via LocalStorage
    String? role;
    try {
      final jsonStr = LocalStorage.instance.getString(AppConstants.keyUserJson);
      if (jsonStr != null) {
        final m = jsonDecode(jsonStr) as Map<String, dynamic>;
        role = m['role'] as String?;
      }
    } catch (_) {}
    final needsApproval = _requiresApproval(bookingId);
    if (role == 'CENTRE_OPERATOR' && needsApproval) {
      // operator request -> pending admin
      _db.procurementApprovalStatus[bookingId] = 'PENDING';
      _db.procurementPendingStage[bookingId] = _stageToBackend(stage);
      // store OPERATOR_APPROVED as intermediate? Keep PENDING for admin gate
      return;
    }
    // direct advance (admin or small quantity)
    _db.procurementApprovalStatus[bookingId] = role == 'ADMIN' ? 'ADMIN_APPROVED' : 'OPERATOR_APPROVED';
    _db.procurementPendingStage.remove(bookingId);
    final b = _db.bookings[bookingId];
    if (b != null) _db.bookings[bookingId] = b.copyWith(procurementStage: stage);
    // also sync payment when reaching payment stages
    if (stage == ProcurementStage.paymentProcessing) {
      final p = _db.payments[bookingId];
      if (p != null) _db.payments[bookingId] = Payment(
        id: p.id, bookingId: p.bookingId, commodity: p.commodity, quantityQuintal: p.quantityQuintal, ratePerQuintal: p.ratePerQuintal, totalAmount: p.totalAmount, status: PaymentStatus.processing);
    } else if (stage == ProcurementStage.paymentCompleted) {
      final p = _db.payments[bookingId];
      if (p != null) _db.payments[bookingId] = Payment(
        id: p.id, bookingId: p.bookingId, commodity: p.commodity, quantityQuintal: p.quantityQuintal, ratePerQuintal: p.ratePerQuintal, totalAmount: p.totalAmount, status: PaymentStatus.completed, paymentDate: DateTime.now(), transactionId: 'TXN${DateTime.now().millisecondsSinceEpoch}');
    }
  }
}

// ---------- Payment ----------
class MockPaymentRepository implements PaymentRepository {
  final _db = MockDatabase.instance;
  @override
  Future<Payment> getPayment(String bookingId) async {
    await Future.delayed(const Duration(milliseconds: 300));
    final p = _db.payments[bookingId];
    if (p == null) throw Exception('Payment not found');
    return p;
  }
}

// ---------- Notification ----------
class MockNotificationRepository implements NotificationRepository {
  @override
  Future<List<AppNotification>> getNotifications(String farmerId) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final now = DateTime.now();
    return [
      AppNotification(id: 'n1', title: 'Slot Confirmed', body: 'Your slot at Bhavani Centre at 10:30 AM confirmed. Token #27', type: 'slot_confirmed', createdAt: now.subtract(const Duration(minutes: 35))),
      AppNotification(id: 'n2', title: 'Your turn is approaching', body: '12 farmers ahead. Estimated wait 35 minutes.', type: 'queue', createdAt: now.subtract(const Duration(minutes: 5))),
      AppNotification(id: 'n3', title: 'Queue Started', body: 'Procurement centre is now processing tokens.', type: 'queue', createdAt: now.subtract(const Duration(minutes: 10))),
    ];
  }

  @override
  Stream<AppNotification> watchNotifications(String farmerId) async* {
    await Future.delayed(const Duration(seconds: 10));
    yield AppNotification(id: 'n4', title: 'Token Called', body: 'Token #27 is next. Please proceed to counter.', type: 'queue', createdAt: DateTime.now());
  }

  @override
  Future<void> markRead(String notificationId) async {
    await Future.delayed(const Duration(milliseconds: 200));
  }
}

// ---------- AI ----------
class MockAIRepository implements AIRepository {
  @override
  Future<AIPrediction> predictWaitingTime({
    required int farmersAhead,
    required int avgProcessingMinutes,
    required int activeCounters,
    String? commodity,
    int? historicalLoadFactor,
  }) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final counters = activeCounters <= 0 ? 1 : activeCounters;
    final base = (farmersAhead * avgProcessingMinutes / counters).ceil();
    final factor = (historicalLoadFactor ?? 10) / 100; // 0.1
    final est = (base * (1 + factor)).ceil();
    String reason;
    if (farmersAhead == 0) reason = 'You are next';
    else if (est < 15) reason = 'Low centre load';
    else if (est < 40) reason = 'Moderate queue';
    else reason = 'High load - consider off-peak';
    return AIPrediction(estimatedWaitMinutes: est, reasoning: reason);
  }

  @override
  Future<List<LoadPrediction>> predictCentreLoad(String centreId, DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 300));
    // deterministic mock per time slot
    return const [
      LoadPrediction(slotLabel: '08:00-09:00', expectedFarmers: 32),
      LoadPrediction(slotLabel: '09:00-10:00', expectedFarmers: 48),
      LoadPrediction(slotLabel: '10:00-11:00', expectedFarmers: 67, isPeak: true),
      LoadPrediction(slotLabel: '11:00-12:00', expectedFarmers: 71, isPeak: true),
      LoadPrediction(slotLabel: '13:30-14:30', expectedFarmers: 41),
      LoadPrediction(slotLabel: '14:30-15:30', expectedFarmers: 28),
    ];
  }

  @override
  Future<Slot?> recommendSlot(List<Slot> slots, String centreId, DateTime date) async {
    await Future.delayed(const Duration(milliseconds: 200));
    final available = slots.where((s) => !s.isFull).toList();
    if (available.isEmpty) return null;
    available.sort((a, b) => a.booked.compareTo(b.booked));
    return available.first;
  }

  @override
  Future<String> answerAssistant(String query, {String? languageCode, Booking? activeBooking, QueueState? queueState, Payment? payment}) async {
    await Future.delayed(const Duration(milliseconds: 400));
    final q = query.toLowerCase();
    String lang = languageCode ?? 'en';
    String t(String en, String hi, String ta) {
      if (lang == 'hi') return hi;
      if (lang == 'ta') return ta;
      return en;
    }

    if (q.contains('token') || q.contains('टोकन') || q.contains('டோக்கன்')) {
      if (activeBooking != null && queueState != null) {
        return t(
          'Your token is ${activeBooking.tokenNumber}. ${queueState.farmersAhead} farmers ahead. Estimated wait ${queueState.estimatedWaitMinutes} minutes at ${activeBooking.centreName}.',
          'आपका टोकन ${activeBooking.tokenNumber} है। ${queueState.farmersAhead} किसान आगे हैं। अनुमानित प्रतीक्षा ${queueState.estimatedWaitMinutes} मिनट।',
          'உங்கள் டோக்கன் ${activeBooking.tokenNumber}. ${queueState.farmersAhead} விவசாயிகள் முன்னால். மதிப்பிடப்பட்ட காத்திருப்பு ${queueState.estimatedWaitMinutes} நிமிடங்கள்.',
        );
      }
      return t('No active token found. Please book a slot.', 'कोई सक्रिय टोकन नहीं। कृपया स्लॉट बुक करें।', 'செயலில் டோக்கன் இல்லை. ஸ்லாட் முன்பதிவு செய்க.');
    }
    if (q.contains('when') || q.contains('reach') || q.contains('kab') || q.contains('எப்போது')) {
      if (activeBooking != null) {
        return t(
          'Please reach ${activeBooking.centreName} by ${activeBooking.slotStart.hour}:${activeBooking.slotStart.minute.toString().padLeft(2, '0')} . Your slot is ${activeBooking.slotStart.hour}:${activeBooking.slotStart.minute.toString().padLeft(2, '0')} - ${activeBooking.slotEnd.hour}:${activeBooking.slotEnd.minute.toString().padLeft(2, '0')}.',
          '${activeBooking.centreName} पर ${activeBooking.slotStart.hour}:${activeBooking.slotStart.minute.toString().padLeft(2, '0')} तक पहुंचें।',
          '${activeBooking.centreName}க்கு ${activeBooking.slotStart.hour}:${activeBooking.slotStart.minute.toString().padLeft(2, '0')} க்குள் வரவும்.',
        );
      }
    }
    if (q.contains('payment') || q.contains('भुगतान') || q.contains('பணம்')) {
      if (payment != null) {
        return t(
          'Payment for ${payment.commodity}: ₹${payment.totalAmount.toStringAsFixed(0)} - Status: ${payment.status.name}. ${payment.status == PaymentStatus.completed ? "Credited on ${payment.paymentDate}" : "Will be credited after procurement."}',
          '${payment.commodity} के लिए भुगतान ₹${payment.totalAmount.toStringAsFixed(0)} - स्थिति: ${payment.status.name}',
          '${payment.commodity} கொடுப்பனவு ₹${payment.totalAmount.toStringAsFixed(0)} - நிலை: ${payment.status.name}',
        );
      }
    }
    if (q.contains('procurement') || q.contains('status')) {
      if (activeBooking != null) {
        return t(
          'Procurement stage: ${activeBooking.procurementStage.name}. Centre: ${activeBooking.centreName}',
          'खरीद चरण: ${activeBooking.procurementStage.name}',
          'கொள்முதல் நிலை: ${activeBooking.procurementStage.name}',
        );
      }
    }
    return t(
      'I can help with token, queue, procurement and payment. Try: "Where is my token?" or "When is my payment?"',
      'मैं टोकन, कतार, खरीद और भुगतान में मदद कर सकता हूँ। पूछें: "मेरा टोकन क्या है?"',
      'டோக்கன், வரிசை, கொள்முதல், பணம் பற்றி உதவ முடியும். "என்னோட டோக்கன் எத்தனை?" என கேளுங்கள்.',
    );
  }
}
