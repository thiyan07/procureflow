class ProcurementCentre {
  final String id;
  final String? centreCode;
  final String name;
  final String location;
  final String? address;
  final String district;
  final double lat;
  final double lng;
  final String? phone;
  final String? contactPerson;
  final String status; // Open, Closed, Busy, Emergency
  final int currentQueue;
  final int estimatedWaitMinutes;
  final int availableSlots;
  final List<String> commodities;
  // Phase 1 real data
  final double? distanceKm;
  final int? dailyCapacity;
  final int? remainingCapacityToday;
  final String? openTime;
  final String? closeTime;

  const ProcurementCentre({
    required this.id,
    this.centreCode,
    required this.name,
    required this.location,
    this.address,
    required this.district,
    required this.lat,
    required this.lng,
    this.phone,
    this.contactPerson,
    required this.status,
    required this.currentQueue,
    required this.estimatedWaitMinutes,
    required this.availableSlots,
    required this.commodities,
    this.distanceKm,
    this.dailyCapacity,
    this.remainingCapacityToday,
    this.openTime,
    this.closeTime,
  });

  bool get isOpen => status == 'Open';

  Map<String, dynamic> toJson() => {
        'id': id,
        'centre_code': centreCode,
        'name': name,
        'location': location,
        'address': address,
        'district': district,
        'lat': lat,
        'lng': lng,
        'phone': phone,
        'contact_person': contactPerson,
        'status': status,
        'currentQueue': currentQueue,
        'estimatedWaitMinutes': estimatedWaitMinutes,
        'availableSlots': availableSlots,
        'commodities': commodities,
        'distance_km': distanceKm,
        'daily_capacity': dailyCapacity,
        'remaining_capacity_today': remainingCapacityToday,
      };

  factory ProcurementCentre.fromJson(Map<String, dynamic> j) {
    // Handle both old mock and new backend formats
    final lat = (j['lat'] as num?)?.toDouble() ?? 0.0;
    final lng = (j['lng'] as num?)?.toDouble() ?? 0.0;
    // supported_commodities vs commodities
    List<String> comms = [];
    if (j['supported_commodities'] is List) {
      comms = List<String>.from(j['supported_commodities'] as List);
    } else if (j['commodities'] is List) {
      comms = List<String>.from(j['commodities'] as List);
    } else if (j['commodity'] is String) {
      comms = [j['commodity'] as String];
    }
    return ProcurementCentre(
      id: j['id'] as String,
      centreCode: j['centre_code'] as String? ?? j['centreCode'] as String?,
      name: j['name'] as String,
      location: j['location'] as String,
      address: j['address'] as String? ?? j['location'] as String?,
      district: j['district'] as String? ?? 'Erode',
      lat: lat,
      lng: lng,
      phone: j['phone'] as String?,
      contactPerson: j['contact_person'] as String? ?? j['contactPerson'] as String?,
      status: j['status'] as String? ?? 'Open',
      currentQueue: (j['currentQueue'] as int?) ?? (j['current_queue'] as int?) ?? (j['current_queue_size'] as int?) ?? 0,
      estimatedWaitMinutes: (j['estimatedWaitMinutes'] as int?) ?? (j['estimated_wait_minutes'] as int?) ?? 0,
      availableSlots: (j['availableSlots'] as int?) ?? (j['available_slots'] as int?) ?? (j['remaining_capacity_today'] as int?) ?? 0,
      commodities: comms,
      distanceKm: (j['distance_km'] as num?)?.toDouble() ?? (j['distanceKm'] as num?)?.toDouble(),
      dailyCapacity: j['daily_capacity'] as int? ?? j['dailyCapacity'] as int?,
      remainingCapacityToday: j['remaining_capacity_today'] as int? ?? j['remainingCapacityToday'] as int?,
      openTime: j['open_time'] as String? ?? j['openTime'] as String?,
      closeTime: j['close_time'] as String? ?? j['closeTime'] as String?,
    );
  }
}
