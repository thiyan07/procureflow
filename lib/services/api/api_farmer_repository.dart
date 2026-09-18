import '../../core/network/api_client.dart';
import '../../models/farmer.dart';
import '../repositories.dart';

class ApiFarmerRepository implements FarmerRepository {
  final ApiClient _client;
  ApiFarmerRepository(this._client);

  Map<String, dynamic> _normalize(Map<String, dynamic> j) => {
        'id': j['id'],
        'fullName': j['full_name'] ?? j['fullName'],
        'mobile': j['mobile'],
        'farmerId': j['farmer_id'] ?? j['farmerId'],
        'village': j['village'],
        'district': j['district'],
        'languageCode': j['language_code'] ?? j['languageCode'] ?? 'en',
        'primaryCommodity': j['primary_commodity'] ?? j['primaryCommodity'] ?? 'Paddy',
      };

  @override
  Future<Farmer> getFarmer(String id) async {
    final res = await _client.get('/api/v1/farmers/me');
    return Farmer.fromJson(_normalize(res));
  }

  @override
  Future<Farmer> updateFarmer(Farmer farmer) async {
    final res = await _client.patch('/api/v1/farmers/me', body: {
      'full_name': farmer.fullName,
      'village': farmer.village,
      'district': farmer.district,
      'language_code': farmer.languageCode,
      'primary_commodity': farmer.primaryCommodity,
    });
    return Farmer.fromJson(_normalize(res));
  }
}
