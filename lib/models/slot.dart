class Slot {
  final String id;
  final String centreId;
  final DateTime date;
  final DateTime start;
  final DateTime end;
  final int capacity;
  final int booked;
  final bool isRecommended;

  const Slot({
    required this.id,
    required this.centreId,
    required this.date,
    required this.start,
    required this.end,
    required this.capacity,
    required this.booked,
    this.isRecommended = false,
  });

  int get available => capacity - booked;
  bool get isFull => available <= 0;
  double get occupancy => booked / capacity;

  Slot copyWith({int? booked, bool? isRecommended}) => Slot(
        id: id,
        centreId: centreId,
        date: date,
        start: start,
        end: end,
        capacity: capacity,
        booked: booked ?? this.booked,
        isRecommended: isRecommended ?? this.isRecommended,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'centreId': centreId,
        'date': date.toIso8601String(),
        'start': start.toIso8601String(),
        'end': end.toIso8601String(),
        'capacity': capacity,
        'booked': booked,
        'isRecommended': isRecommended,
      };

  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
        id: j['id'] as String,
        centreId: j['centreId'] as String,
        date: DateTime.parse(j['date'] as String),
        start: DateTime.parse(j['start'] as String),
        end: DateTime.parse(j['end'] as String),
        capacity: j['capacity'] as int,
        booked: j['booked'] as int,
        isRecommended: j['isRecommended'] as bool? ?? false,
      );
}
