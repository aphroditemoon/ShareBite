class UserModel {
  final String id;
  final String name;
  final String email;
  final String? avatar;
  final String? phone;
  final String bio;
  final UserStats stats;
  final List<String> badges;
  final bool isVerified;
  final UserLocation? location;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatar,
    this.phone,
    this.bio = '',
    required this.stats,
    this.badges = const [],
    this.isVerified = false,
    this.location,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      avatar: json['avatar']?.toString(),
      phone: json['phone'],
      bio: json['bio'] ?? '',
      stats: UserStats.fromJson(json['stats'] ?? {}),
      badges: List<String>.from(json['badges'] ?? []),
      isVerified: json['isVerified'] ?? false,
      location: json['location'] != null ? UserLocation.fromJson(json['location']) : null,
    );
  }

  String get avatarUrl {
    if (avatar == null) return '';
    if (avatar!.startsWith('http') || avatar!.startsWith('file://')) return avatar!;
    if (avatar!.startsWith('/uploads')) return 'https://foodwasteapp-production-6eaa.up.railway.app$avatar';
    if (avatar!.startsWith('/')) return 'file://$avatar';
    return avatar!;
  }
}

class UserStats {
  final int totalShared;
  final int totalReceived;
  final int mealsaved;
  final double rating;
  final int ratingCount;

  UserStats({
    this.totalShared = 0,
    this.totalReceived = 0,
    this.mealsaved = 0,
    this.rating = 0,
    this.ratingCount = 0,
  });

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static double _asDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      totalShared: _asInt(json['totalShared']),
      totalReceived: _asInt(json['totalReceived']),
      mealsaved: _asInt(json['mealsaved']),
      rating: _asDouble(json['rating']),
      ratingCount: _asInt(json['ratingCount']),
    );
  }
}

class UserLocation {
  final double lat;
  final double lng;
  final String address;

  UserLocation({required this.lat, required this.lng, this.address = ''});

  factory UserLocation.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as List?;
    return UserLocation(
      lat: coords != null && coords.length > 1 ? (coords[1] as num).toDouble() : 0,
      lng: coords != null && coords.isNotEmpty ? (coords[0] as num).toDouble() : 0,
      address: json['address'] ?? '',
    );
  }
}
