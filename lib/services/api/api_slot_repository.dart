import 'dart:convert';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/storage/local_storage.dart';
import '../../models/slot.dart';
import '../../models/booking.dart';
import '../repositories.dart';

class ApiSlotRepository implements SlotRepository {
  final ApiClient _client;
  ApiSlotRepository(this._client);

  String? _farmerIdFromStorage() {
    try {
      final jsonStr = LocalStorage.instance.getString(AppConstants.keyUserJson);
      if (jsonStr == null) return null;
      final j = jsonDecode(jsonStr) as Map<String, dynamic>;
      // farmer may be nested
      if (j['farmer'] is Map && (j['farmer'] as Map)['id'] != null) {
        return (j['farmer'] as Map)['id'] as String;
      }
      // fallback: id is farmer id for farmer role
      if (j['role'] == 'FARMER' && j['id'] != null) return j['id'] as String;
      return null;
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _farmerAwareQuery(DateTime date, {String commodity = 'Paddy', double qty = 10}) {
    final q = <String, dynamic>{
      'date': date.toIso8601String().split('T').first,
      'estimated_quantity': qty,
      'commodity_id': commodity,
    };
    final fid = _farmerIdFromStorage();
    if (fid != null) q['farmer_id'] = fid;
    return q;
  }

  @override
  Future<List<Slot>> getSlots(String centreId, DateTime date) async {
    final dateStr = date.toIso8601String().split('T').first;
    final list = await _client.getList('/api/v1/slots', query: {'centre_id': centreId, 'date': dateStr});
    // try farmer-aware recommendation (uses auth token + farmer_id query)
    final rec = await _tryRecommend(centreId, date);
    String? recId = rec?['recommended_slot']?['id'] as String?;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      final start = DateTime.parse(m['start_time'] != null ? '${m['date']}T${m['start_time']}' : m['start'] as String);
      final end = DateTime.parse(m['end_time'] != null ? '${m['date']}T${m['end_time']}' : m['end'] as String);
      final d = DateTime.parse(m['date'] as String);
      return Slot(
        id: m['id'] as String,
        centreId: m['centre_id'] as String? ?? centreId,
        date: d,
        start: start,
        end: end,
        capacity: m['capacity'] as int,
        booked: m['booked'] as int,
        isRecommended: recId != null && m['id'] == recId,
      );
    }).toList();
  }

  Future<Map<String, dynamic>?> _tryRecommend(String centreId, DateTime date, {String commodity = 'Paddy', double qty = 10}) async {
    try {
      return await _client.get('/api/v1/centres/$centreId/slot-recommendations', query: _farmerAwareQuery(date, commodity: commodity, qty: qty));
    } catch (_) {
      return null;
    }
  }

  /// Public farmer-aware recommendation for UI chip (exposed for slot_booking_screen.dart)
  Future<Map<String, dynamic>?> getRecommendation(String centreId, DateTime date, {String commodity = 'Paddy', double qty = 10}) async {
    return _tryRecommend(centreId, date, commodity: commodity, qty: qty);
  }

  @override
  Future<Booking> bookSlot({required String farmerId, required String centreId, required String commodity, required double quantity, required String slotId, List<CommodityItem>? commodities}) async {
    final body = {
      'centre_id': centreId,
      'slot_id': slotId,
      'commodity': commodity,
      'estimated_quantity': quantity,
    };
    if (commodities != null && commodities.isNotEmpty) {
      body['commodities'] = commodities.map((c)=> {'commodity': c.commodity, 'quantity': c.quantity, 'unit': c.unit}).toList();
    }
    final res = await _client.post('/api/v1/bookings', body: body);
    final booking = _mapBooking(res);
    // immediately cache new booking so refresh never makes it vanish
    try {
      final existingCached = LocalStorage.instance.cachedBooking;
      List<dynamic> list = [];
      if (existingCached != null) {
        try { list = jsonDecode(existingCached) as List; } catch (_) {}
      }
      list.insert(0, res);
      await LocalStorage.instance.cacheBooking(jsonEncode(list));
    } catch (_) {}
    return booking;
  }

  Booking _mapBooking(Map<String, dynamic> j) {
    final dateStr = j['date'] as String? ?? DateTime.now().toIso8601String().split('T').first;
    final slotStart = j['slot_start'] != null ? DateTime.parse('${dateStr}T${j['slot_start']}') : (j['slotStart'] != null ? DateTime.parse(j['slotStart'] as String) : DateTime.now());
    final slotEnd = j['slot_end'] != null ? DateTime.parse('${dateStr}T${j['slot_end']}') : (j['slotEnd'] != null ? DateTime.parse(j['slotEnd'] as String) : DateTime.now().add(const Duration(minutes: 30)));
    List<CommodityItem>? commodities;
    if (j['commodities'] is List) {
      commodities = (j['commodities'] as List).map((e)=> CommodityItem.fromJson(e as Map<String,dynamic>)).toList();
    } else if (j['commodities_json'] is String) {
      try {
        final decoded = (j['commodities_json'] as String);
        // may be json string
        final list = decoded.isNotEmpty ? (const Object() != null ? [] : []) : [];
      } catch (_) {}
    }
    return Booking(
      id: j['id'] as String,
      farmerId: j['farmer_id'] as String? ?? j['farmerId'] as String? ?? '',
      centreId: j['centre_id'] as String? ?? j['centreId'] as String? ?? '',
      centreName: j['centre_name'] as String? ?? j['centreName'] as String? ?? '',
      commodity: j['commodity_name'] as String? ?? j['commodity'] as String? ?? '',
      quantityQuintal: (j['estimated_quantity'] as num? ?? j['quantityQuintal'] as num? ?? 0).toDouble(),
      commodities: commodities,
      tokenNumber: j['token_number'] as String? ?? j['tokenNumber'] as String? ?? '',
      date: j['date'] != null ? DateTime.parse(j['date'] as String) : DateTime.now(),
      slotStart: slotStart,
      slotEnd: slotEnd,
      queueStatus: _parseQueue(j['status'] as String? ?? 'waiting'),
      procurementStage: _parseProcurement('bookingConfirmed'),
      createdAt: j['created_at'] != null ? DateTime.parse(j['created_at'] as String) : DateTime.now(),
    );
  }

  QueueStatus _parseQueue(String s) {
    switch (s.toUpperCase()) {
      case 'WAITING': return QueueStatus.waiting;
      case 'CALLED': return QueueStatus.called;
      case 'ARRIVED': return QueueStatus.arrived;
      case 'PROCESSING': return QueueStatus.processing;
      case 'COMPLETED': return QueueStatus.completed;
      case 'CANCELLED': return QueueStatus.cancelled;
      default: return QueueStatus.waiting;
    }
  }
  ProcurementStage _parseProcurement(String s) => ProcurementStage.bookingConfirmed;

  @override
  Future<List<Booking>> getBookingsForFarmer(String farmerId) async {
    try {
      final list = await _client.getList('/api/v1/bookings');
      final bookings = list.map((e) => _mapBooking(e as Map<String, dynamic>)).toList();
      // cache for offline refresh — never vanishes on transient network error
      try {
        final jsonStr = jsonEncode(list);
        await LocalStorage.instance.cacheBooking(jsonStr);
      } catch (_) {}
      return bookings;
    } catch (e) {
      // fallback to cached bookings if network fails (fixes "vanishes on refresh")
      final cached = LocalStorage.instance.cachedBooking;
      if (cached != null) {
        try {
          final decoded = jsonDecode(cached) as List;
          return decoded.map((x) => _mapBooking(x as Map<String, dynamic>)).toList();
        } catch (_) {}
      }
      // if no cache, rethrow with user-friendly message
      throw Exception(_userFriendly(e));
    }
  }

  String _userFriendly(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('Connection refused') || s.contains('Failed host lookup')) {
      return 'Network error — check internet or server. Booking is cached and will sync when online.';
    }
    if (s.contains('TimeoutException') || s.contains('Server waking up')) {
      return s.contains('Server waking up') ? s : 'Server waking up (cold start) — please retry in 30s';
    }
    return s;
  }

  @override
  Future<Booking?> getActiveBooking(String farmerId) async {
    final list = await getBookingsForFarmer(farmerId);
    if (list.isEmpty) return null;
    list.sort((a,b)=> b.createdAt.compareTo(a.createdAt));
    final active = list.where((b)=> b.queueStatus != QueueStatus.completed && b.queueStatus != QueueStatus.cancelled);
    return active.isEmpty ? null : active.first;
  }

  @override
  Future<Booking?> getBookingById(String bookingId) async {
    final res = await _client.get('/api/v1/bookings/$bookingId');
    return _mapBooking(res);
  }
}
