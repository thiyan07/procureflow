import '../../core/network/api_client.dart';
import '../../models/centre.dart';
import '../repositories.dart';

class ApiCentreRepository implements CentreRepository {
  final ApiClient _client;
  ApiCentreRepository(this._client);

  ProcurementCentre _map(Map<String, dynamic> j) => ProcurementCentre.fromJson(j);

  @override
  Future<List<ProcurementCentre>> getCentres() async {
    return getNearbyCentres();
  }

  Future<List<ProcurementCentre>> getNearbyCentres({double? lat, double? lng, double radiusKm = 50, String? commodity, String? district}) async {
    // Try real nearby with location, fallback to plain list
    if (lat != null && lng != null) {
      try {
        final query = <String, dynamic>{'lat': lat, 'lng': lng, 'radius_km': radiusKm};
        if (commodity != null) query['commodity'] = commodity;
        if (district != null) query['district'] = district;
        final list = await _client.getList('/api/v1/centres/nearby', query: query);
        return list.map((e) => _map(e as Map<String, dynamic>)).toList();
      } catch (_) {
        // fallback to list with lat/lng query
        try {
          final query = <String, dynamic>{'lat': lat, 'lng': lng, 'radius_km': radiusKm};
          if (commodity != null) query['commodity'] = commodity;
          if (district != null) query['district'] = district;
          final list = await _client.getList('/api/v1/centres', query: query);
          return list.map((e) => _map(e as Map<String, dynamic>)).toList();
        } catch (_) {}
      }
    }
    final list = await _client.getList('/api/v1/centres');
    final centres = list.map((e) => _map(e as Map<String, dynamic>)).toList();
    // Enrich with real queue/status from GET /centres/{id}/status (real DB)
    final enriched = <ProcurementCentre>[];
    for (final c in centres) {
      try {
        final status = await _client.get('/api/v1/centres/${c.id}/status');
        enriched.add(ProcurementCentre(
          id: c.id,
          centreCode: c.centreCode,
          name: c.name,
          location: c.location,
          address: c.address,
          district: c.district,
          lat: c.lat,
          lng: c.lng,
          phone: c.phone,
          contactPerson: c.contactPerson,
          status: (status['centre'] as Map?)?['status'] as String? ?? c.status,
          currentQueue: status['current_queue_size'] as int? ?? c.currentQueue,
          estimatedWaitMinutes: status['estimated_wait_minutes'] as int? ?? c.estimatedWaitMinutes,
          availableSlots: status['available_slots'] as int? ?? c.availableSlots,
          commodities: c.commodities,
          distanceKm: c.distanceKm,
          dailyCapacity: c.dailyCapacity,
          remainingCapacityToday: c.remainingCapacityToday,
          openTime: c.openTime,
          closeTime: c.closeTime,
        ));
      } catch (_) {
        enriched.add(c);
      }
    }
    return enriched;
  }

  @override
  Future<ProcurementCentre> getCentre(String id) async {
    final res = await _client.get('/api/v1/centres/$id');
    return _map(res);
  }

  @override
  Future<List<Map<String, dynamic>>> getCentreCommodities(String centreId) async {
    final list = await _client.getList('/api/v1/centres/$centreId/commodities');
    return list.cast<Map<String, dynamic>>();
  }

  @override
  Future<Map<String, dynamic>> getCentreOperational(String centreId, {double? lat, double? lng}) async {
    final query = <String, dynamic>{};
    if (lat != null) query['lat'] = lat;
    if (lng != null) query['lng'] = lng;
    return await _client.get('/api/v1/centres/$centreId/operational', query: query.isEmpty ? null : query);
  }

  @override
  Future<Map<String, dynamic>> getRecommendations({double? lat, double? lng, double radiusKm = 50, String? commodity, String? district, double estimatedQuantity = 10}) async {
    final query = <String, dynamic>{'radius_km': radiusKm, 'estimated_quantity': estimatedQuantity};
    if (lat != null) query['lat'] = lat;
    if (lng != null) query['lng'] = lng;
    if (commodity != null) query['commodity'] = commodity;
    if (district != null) query['district'] = district;
    return await _client.get('/api/v1/centres/recommendations', query: query);
  }

  // Extra helper for status (not in base interface but used by Flutter)
  Future<Map<String, dynamic>> getCentreStatus(String id) async {
    final res = await _client.get('/api/v1/centres/$id/status');
    return res;
  }

  Future<Map<String, dynamic>> getSlotRecommendations(String centreId, DateTime date, String commodity, double qty) async {
    final q = {
      'date': date.toIso8601String().split('T').first,
      'commodity_id': commodity,
      'estimated_quantity': qty,
    };
    return await _client.get('/api/v1/centres/$centreId/slot-recommendations', query: q);
  }
}
