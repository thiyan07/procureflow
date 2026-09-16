enum Commodity {
  paddy,
  wheat,
  onion,
  millet,
  pulses;

  String get displayName => switch (this) {
        Commodity.paddy => 'Paddy',
        Commodity.wheat => 'Wheat',
        Commodity.onion => 'Onion',
        Commodity.millet => 'Millet',
        Commodity.pulses => 'Pulses',
      };

  String get code => name.toUpperCase();

  static Commodity fromString(String v) {
    final lower = v.toLowerCase();
    return Commodity.values.firstWhere(
      (c) => c.name == lower || c.displayName.toLowerCase() == lower,
      orElse: () => Commodity.paddy,
    );
  }

  static List<Commodity> get all => Commodity.values;
}
