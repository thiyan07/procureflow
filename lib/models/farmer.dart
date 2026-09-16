class Farmer {
  final String id;
  final String fullName;
  final String mobile;
  final String farmerId;
  final String village;
  final String district;
  final String languageCode; // en, hi, ta
  final String primaryCommodity;

  const Farmer({
    required this.id,
    required this.fullName,
    required this.mobile,
    required this.farmerId,
    required this.village,
    required this.district,
    required this.languageCode,
    required this.primaryCommodity,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'mobile': mobile,
        'farmerId': farmerId,
        'village': village,
        'district': district,
        'languageCode': languageCode,
        'primaryCommodity': primaryCommodity,
      };

  factory Farmer.fromJson(Map<String, dynamic> j) => Farmer(
        id: j['id'] as String,
        fullName: j['fullName'] as String,
        mobile: j['mobile'] as String,
        farmerId: j['farmerId'] as String,
        village: j['village'] as String,
        district: j['district'] as String,
        languageCode: j['languageCode'] as String? ?? 'en',
        primaryCommodity: j['primaryCommodity'] as String,
      );

  Farmer copyWith({
    String? fullName,
    String? village,
    String? district,
    String? languageCode,
    String? primaryCommodity,
  }) =>
      Farmer(
        id: id,
        fullName: fullName ?? this.fullName,
        mobile: mobile,
        farmerId: farmerId,
        village: village ?? this.village,
        district: district ?? this.district,
        languageCode: languageCode ?? this.languageCode,
        primaryCommodity: primaryCommodity ?? this.primaryCommodity,
      );
}

/// Spec requires `User` model - AppUser is the implementation.
/// Keep AppUser for repository clarity, expose User as spec name.
typedef User = AppUser;

class AppUser {
  final String id;
  final String mobile;
  final String role; // FARMER, CENTRE_OPERATOR, ADMIN
  final Farmer? farmer;

  const AppUser({required this.id, required this.mobile, required this.role, this.farmer});

  Map<String, dynamic> toJson() => {
        'id': id,
        'mobile': mobile,
        'role': role,
        if (farmer != null) 'farmer': farmer!.toJson(),
      };

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        mobile: j['mobile'] as String,
        role: j['role'] as String,
        farmer: j['farmer'] != null ? Farmer.fromJson(j['farmer'] as Map<String, dynamic>) : null,
      );
}
