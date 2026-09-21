import '../../core/network/api_client.dart';
import '../../models/centre.dart';
import '../repositories.dart';

class ApiCentreRepository implements CentreRepository {
  final ApiClient _client;
  ApiCentreRepository(this._client);

  ProcurementCentre _map(Map<String, dynamic> j) => ProcurementCentre(
        id: j['id'] as String,
        name: j['name'] as String,
        location: j['location'] as String,
        district: j['district'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        status: j['status'] as String? ?? 'Open',
        currentQueue: j['current_queue'] as int? ?? j['currentQueue'] as int? ?? 0,
        estimatedWaitMinutes: j['estimated_wait_minutes'] as int? ?? j['estimatedWaitMinutes'] as int? ?? 0,
        availableSlots: j['available_slots'] as int? ?? j['availableSlots'] as int? ?? 0,
        commodities: (j['commodities'] as List?)?.map((e) => e.toString()).toList() ?? ['Paddy'],
      );

  @override
  Future<List<ProcurementCentre>> getCentres() async {
    final list = await _client.getList('/api/v1/centres');
    final centres = list.map((e) => _map(e as Map<String, dynamic>)).toList();
    // Enrich with real queue/status from GET /centres/{id}/status (real DB)
    final enriched = <ProcurementCentre>[];
    for (final c in centres) {
      try {
        final status = await _client.get('/api/v1/centres/${c.id}/status');
        enriched.add(ProcurementCentre(
          id: c.id,
          name: c.name,
          location: c.location,
          district: c.district,
          lat: c.lat,
          lng: c.lng,
          status: (status['centre'] as Map?)?['status'] as String? ?? c.status,
          currentQueue: status['current_queue_size'] as int? ?? c.currentQueue,
          estimatedWaitMinutes: status['estimated_wait_minutes'] as int? ?? c.estimatedWaitMinutes,
          availableSlots: status['available_slots'] as int? ?? c.availableSlots,
          commodities: c.commodities,
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
