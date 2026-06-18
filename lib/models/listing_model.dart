import 'user_model.dart';

class ListingModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String? foodType;
  final List<String> images;
  final List<String> tags;
  final int quantity;
  final String unit;
  final double price;
  final DateTime? expiresAt;
  final bool isAvailable;
  final ListingOwner? owner;
  final ListingLocation location;
  final double? distance; // in meters
  final List<String> dietaryInfo;
  final List<String> allergens;
  final int viewCount;
  final DateTime createdAt;

  ListingModel({
    required this.id,
    required this.title,
    this.description = '',
    required this.category,
    this.foodType,
    this.images = const [],
    this.tags = const [],
    this.quantity = 1,
    this.unit = 'item',
    this.price = 0,
    this.expiresAt,
    this.isAvailable = true,
    this.owner,
    required this.location,
    this.distance,
    this.dietaryInfo = const [],
    this.allergens = const [],
    this.viewCount = 0,
    required this.createdAt,
  });

  static int _asInt(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  static double _asDouble(dynamic value, [double fallback = 0]) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  factory ListingModel.fromJson(Map<String, dynamic> json) {
    return ListingModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? 'free_food',
      foodType: json['foodType'],
      images: List<String>.from(json['images'] ?? []),
      tags: List<String>.from(json['tags'] ?? []),
      quantity: _asInt(json['quantity'], 1),
      unit: json['unit'] ?? 'item',
      price: _asDouble(json['price']),
      expiresAt: json['expiresAt'] != null ? DateTime.tryParse(json['expiresAt']) : null,
      isAvailable: json['isAvailable'] ?? true,
      owner: json['owner'] != null ? ListingOwner.fromJson(json['owner']) : null,
      location: ListingLocation.fromJson(json['location'] ?? {}),
      distance: json['distance'] != null ? (json['distance'] as num).toDouble() : null,
      dietaryInfo: List<String>.from(json['dietaryInfo'] ?? []),
      allergens: List<String>.from(json['allergens'] ?? []),
      viewCount: _asInt(json['viewCount']),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String _resolveImageUrl(String img) {
    if (img.startsWith('http') || img.startsWith('file://')) return img;
    if (img.startsWith('/uploads')) return 'https://foodwasteapp-production-6eaa.up.railway.app$img';
    if (img.startsWith('/')) return 'file://$img';
    if (RegExp(r'^[A-Za-z]:\\').hasMatch(img)) return 'file:///${img.replaceAll('\\', '/')}';
    return img;
  }

  String get firstImageUrl {
    if (images.isEmpty) return '';
    return _resolveImageUrl(images.first);
  }

  List<String> get imageUrls => images.map(_resolveImageUrl).toList();

  String get distanceText {
    if (distance == null) return '';
    if (distance! < 1000) return '${distance!.round()}m';
    return '${(distance! / 1000).toStringAsFixed(1)}km';
  }

  bool get isFree => price == 0;
}

class ListingOwner {
  final String id;
  final String name;
  final String? avatar;
  final UserStats? stats;

  ListingOwner({required this.id, required this.name, this.avatar, this.stats});

  factory ListingOwner.fromJson(Map<String, dynamic> json) {
    return ListingOwner(
      id: json['_id'] ?? json['id'] ?? '',
      name: json['name'] ?? '',
      avatar: json['avatar']?.toString(),
      stats: json['stats'] != null ? UserStats.fromJson(json['stats']) : null,
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

class ListingLocation {
  final double lat;
  final double lng;
  final String address;
  final String neighborhood;

  ListingLocation({
    required this.lat,
    required this.lng,
    this.address = '',
    this.neighborhood = '',
  });

  factory ListingLocation.fromJson(Map<String, dynamic> json) {
    final coords = json['coordinates'] as List?;
    return ListingLocation(
      lat: coords != null && coords.length > 1 ? (coords[1] as num).toDouble() : 0,
      lng: coords != null && coords.isNotEmpty ? (coords[0] as num).toDouble() : 0,
      address: json['address'] ?? '',
      neighborhood: json['neighborhood'] ?? '',
    );
  }
}
