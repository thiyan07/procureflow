import '../../core/network/api_client.dart';
import '../../models/booking.dart';
import '../../models/payment.dart';
import '../../models/slot.dart';
import '../../models/analytics.dart';
import '../repositories.dart';

class ApiAiRepository implements AIRepository {
  final ApiClient _client;
  ApiAiRepository(this._client);

  @override
  Future<AIPrediction> predictWaitingTime({required int farmersAhead, required int avgProcessingMinutes, required int activeCounters, String? commodity, int? historicalLoadFactor}) async {
    final res = await _client.get('/api/v1/ai/predict-wait', query: {
      'farmers_ahead': farmersAhead,
      'avg_processing': avgProcessingMinutes,
      'active_counters': activeCounters,
      'commodity': commodity ?? 'Paddy',
      'estimated_quantity': 10,
    });
    return AIPrediction(
      estimatedWaitMinutes: res['predicted_wait'] as int? ?? res['predictedWaitMinutes'] as int? ?? 5,
      reasoning: res['reason'] as String? ?? 'AI predicts based on queue',
    );
  }

  @override
  Future<List<LoadPrediction>> predictCentreLoad(String centreId, DateTime date) async {
    final res = await _client.get('/api/v1/ai/centre-load/$centreId', query: {'target_date': date.toIso8601String().split('T').first});
    final forecast = (res['forecast_3d'] as List?) ?? [];
    return forecast.map((e) {
      final m = e as Map<String, dynamic>;
      final level = m['level'] as String? ?? 'NORMAL';
      return LoadPrediction(
        slotLabel: m['date'] as String? ?? date.toIso8601String().split('T').first,
        expectedFarmers: m['expected_bookings'] as int? ?? 20,
        isPeak: level == 'HIGH',
      );
    }).toList();
  }

  @override
  Future<Slot?> recommendSlot(List<Slot> slots, String centreId, DateTime date) async {
    final res = await _client.get('/api/v1/ai/slot-recommendation-ai/$centreId', query: {'date': date.toIso8601String().split('T').first});
    final rec = res['recommended_slot'];
    if (rec == null) return null;
    final m = rec as Map<String, dynamic>;
    return Slot(
      id: m['id'] as String,
      centreId: m['centre_id'] as String,
      date: DateTime.parse(m['date'] as String),
      start: DateTime.parse('${m['date']}T${m['start_time']}'),
      end: DateTime.parse('${m['date']}T${m['end_time']}'),
      capacity: m['capacity'] as int,
      booked: m['booked'] as int,
      isRecommended: true,
    );
  }

  @override
  Future<String> answerAssistant(String query, {String? languageCode, Booking? activeBooking, QueueState? queueState, Payment? payment}) async {
    try {
      final res = await _client.post('/api/v1/assistant/ask', query: {'query': query, 'language_code': languageCode ?? 'en'});
      return res['answer'] as String? ?? 'Sorry, try again.';
    } catch (_) {
      // fallback deterministic local
      if (activeBooking != null && query.toLowerCase().contains('token')) {
        return 'Your token is ${activeBooking.tokenNumber} at ${activeBooking.centreName}.';
      }
      if (queueState != null && query.toLowerCase().contains('queue')) {
        return '${queueState.farmersAhead} farmers ahead, wait ~${queueState.estimatedWaitMinutes} min.';
      }
      return 'I can help with booking, token, centre, payment, procurement. Try: Where is my token?';
    }
  }
}
