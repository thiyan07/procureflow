import '../../core/constants/app_constants.dart';
import '../../models/centre.dart';
import '../../models/slot.dart';
import '../../models/booking.dart';
import '../../models/payment.dart';
import '../../models/farmer.dart';

class MockDatabase {
  MockDatabase._();
  static final MockDatabase instance = MockDatabase._();

  // Mutable in-memory state - simulates backend
  final List<ProcurementCentre> centres = [
    const ProcurementCentre(
      id: 'c1',
      name: 'Bhavani Procurement Centre',
      location: 'Bhavani, Erode',
      district: 'Erode',
      lat: 11.4475,
      lng: 77.6815,
      status: 'Open',
      currentQueue: 18,
      estimatedWaitMinutes: 32,
      availableSlots: 14,
      commodities: ['Paddy', 'Wheat', 'Millet'],
    ),
    const ProcurementCentre(
      id: 'c2',
      name: 'Perundurai Procurement Centre',
      location: 'Perundurai, Erode',
      district: 'Erode',
      lat: 11.2760,
      lng: 77.5860,
      status: 'Open',
      currentQueue: 9,
      estimatedWaitMinutes: 18,
      availableSlots: 22,
      commodities: ['Paddy', 'Onion'],
    ),
    const ProcurementCentre(
      id: 'c3',
      name: 'Sathyamangalam Procurement Centre',
      location: 'Sathyamangalam, Erode',
      district: 'Erode',
      lat: 11.5054,
      lng: 77.2380,
      status: 'Busy',
      currentQueue: 27,
      estimatedWaitMinutes: 55,
      availableSlots: 5,
      commodities: ['Paddy', 'Pulses'],
    ),
  ];

  // Slots keyed by centreId + date string
  final Map<String, List<Slot>> slotsByKey = {};

  // Bookings
  final Map<String, Booking> bookings = {};
  final Map<String, Payment> payments = {};

  // Current simulated queue head
  int globalCurrentOrdinal = 15;
  final Map<String, int> bookingOrdinal = {}; // bookingId -> ordinal like 27

  Farmer demoFarmer = const Farmer(
    id: 'f1',
    fullName: 'Ravi Kumar',
    mobile: '9876543210',
    farmerId: 'FARM-2026-00127',
    village: 'Bhavani',
    district: 'Erode',
    languageCode: 'en',
    primaryCommodity: 'Paddy',
  );

  // Procurement approval state per booking: bookingId -> status/pending
  final Map<String, String> procurementApprovalStatus = {}; // NONE, PENDING, OPERATOR_APPROVED, ADMIN_APPROVED
  final Map<String, String> procurementPendingStage = {}; // e.g. COMPLETED

  // Stored passwords for mock mobile+password login (mobile -> password) - phone+password only
  // Demo defaults: farmer 9876543210 / password123 , operator 9876543211 / password123 (unified per hardening)
  final Map<String, String> farmerPasswords = {
    '9876543210': 'password123',
    '9876543211': 'password123',
  };
  // Optional email mapping (email -> mobile) for Brevo flow
  final Map<String, String> emailToMobile = {
    'farmer@procureflow.in': '9876543210',
    'operator@procureflow.in': '9876543211',
  };

  List<Slot> generateSlots(String centreId, DateTime date) {
    final key = '${centreId}_${date.year}-${date.month}-${date.day}';
    if (slotsByKey.containsKey(key)) return slotsByKey[key]!;
    final List<Slot> slots = [];
    // 30-min slots 09:00-15:00
    // Generate correct 30-min slots 09:00-13:00 as example
    slots.clear();
    final times = [
      [9, 0, 9, 30, 18, 18],
      [9, 30, 10, 0, 12, 9],
      [10, 0, 10, 30, 15, 3],
      [10, 30, 11, 0, 20, 2],
      [11, 0, 11, 30, 20, 8],
      [13, 30, 14, 0, 20, 2],
      [14, 0, 14, 30, 20, 5],
      [14, 30, 15, 0, 20, 12],
    ];
    for (final t in times) {
      final s = DateTime(date.year, date.month, date.day, t[0], t[1]);
      final e = DateTime(date.year, date.month, date.day, t[2], t[3]);
      slots.add(Slot(
        id: '${centreId}_${s.millisecondsSinceEpoch}',
        centreId: centreId,
        date: date,
        start: s,
        end: e,
        capacity: t[4],
        booked: t[5],
      ));
    }
    slotsByKey[key] = slots;
    return slots;
  }

  void createDemoBookingIfMissing() {
    if (bookings.isEmpty) {
      final now = DateTime.now();
      final booking = Booking(
        id: 'b1',
        farmerId: demoFarmer.id,
        centreId: 'c1',
        centreName: 'Bhavani Procurement Centre',
        commodity: 'Paddy',
        quantityQuintal: 18.5,
        tokenNumber: '#27',
        date: DateTime(now.year, now.month, now.day),
        slotStart: DateTime(now.year, now.month, now.day, 10, 30),
        slotEnd: DateTime(now.year, now.month, now.day, 11, 0),
        queueStatus: QueueStatus.waiting,
        procurementStage: ProcurementStage.bookingConfirmed,
        createdAt: now.subtract(const Duration(minutes: 40)),
      );
      bookings[booking.id] = booking;
      bookingOrdinal[booking.id] = 27;
      payments[booking.id] = Payment(
        id: 'p1',
        bookingId: booking.id,
        commodity: 'Paddy',
        quantityQuintal: 18.5,
        ratePerQuintal: 2200,
        totalAmount: 40700,
        status: PaymentStatus.processing,
      );
    }
  }
}
