class ProcurementCentre {
  final String id;
  final String name;
  final String location;
  final String district;
  final double lat;
  final double lng;
  final String status; // Open, Closed, Busy
  final int currentQueue;
  final int estimatedWaitMinutes;
  final int availableSlots;
  final List<String> commodities;

  const ProcurementCentre({
    required this.id,
    required this.name,
    required this.location,
    required this.district,
    required this.lat,
    required this.lng,
    required this.status,
    required this.currentQueue,
    required this.estimatedWaitMinutes,
    required this.availableSlots,
    required this.commodities,
  });

  bool get isOpen => status == 'Open';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'location': location,
        'district': district,
        'lat': lat,
        'lng': lng,
        'status': status,
        'currentQueue': currentQueue,
        'estimatedWaitMinutes': estimatedWaitMinutes,
        'availableSlots': availableSlots,
        'commodities': commodities,
      };

  factory ProcurementCentre.fromJson(Map<String, dynamic> j) => ProcurementCentre(
        id: j['id'] as String,
        name: j['name'] as String,
        location: j['location'] as String,
        district: j['district'] as String,
        lat: (j['lat'] as num).toDouble(),
        lng: (j['lng'] as num).toDouble(),
        status: j['status'] as String,
        currentQueue: j['currentQueue'] as int,
        estimatedWaitMinutes: j['estimatedWaitMinutes'] as int,
        availableSlots: j['availableSlots'] as int,
        commodities: List<String>.from(j['commodities'] as List),
      );
}
