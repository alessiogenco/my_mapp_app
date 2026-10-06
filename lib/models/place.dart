class Place {
  final String id;
  final String name;
  final String city;
  final String category;
  final String area;
  final String? neighborhood;
  final double lat;
  final double lng;
  final int rating;
  final int priceLevel;
  final Map<String, int> ratingDetails;
  final List<String> vibes;
  final String notes;
  final String? websiteUrl;
  final String? instagramUrl;
  final String? googleMapsUrl;
  final String? googlePlaceId;
  final String? photoAsset;

  Place({
    required this.id,
    required this.name,
    required this.city,
    required this.category,
    required this.area,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.priceLevel,
    this.ratingDetails = const {},
    required this.vibes,
    required this.notes,
    this.websiteUrl,
    this.instagramUrl,
    this.neighborhood,
    this.googleMapsUrl,
    this.googlePlaceId,
    this.photoAsset,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'],
      name: json['name'],
      city: json['city'] ?? '',
      category: json['category'],
      area: json['area'] ?? '',
      neighborhood: _optionalString(json['neighborhood']),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      rating: json['rating'],
      priceLevel: json['priceLevel'],
      ratingDetails: _ratingDetailsFromJson(json['ratingDetails']),
      vibes: _normalizeVibes(List<String>.from(json['vibes'] ?? [])),
      notes: json['notes'] ?? '',
      websiteUrl: _optionalString(json['websiteUrl']),
      instagramUrl: _optionalString(json['instagramUrl']),
      googleMapsUrl: _optionalString(json['googleMapsUrl']),
      googlePlaceId: _optionalString(json['googlePlaceId']),
      photoAsset: _optionalString(json['photoAsset']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'category': category,
      'area': area,
      if (neighborhood != null && neighborhood!.isNotEmpty)
        'neighborhood': neighborhood,
      'rating': rating,
      'priceLevel': priceLevel,
      if (ratingDetails.isNotEmpty) 'ratingDetails': ratingDetails,
      'lat': lat,
      'lng': lng,
      'vibes': vibes,
      'notes': notes,
      if (websiteUrl != null && websiteUrl!.isNotEmpty)
        'websiteUrl': websiteUrl,
      if (instagramUrl != null && instagramUrl!.isNotEmpty)
        'instagramUrl': instagramUrl,
      if (googleMapsUrl != null && googleMapsUrl!.isNotEmpty)
        'googleMapsUrl': googleMapsUrl,
      if (googlePlaceId != null && googlePlaceId!.isNotEmpty)
        'googlePlaceId': googlePlaceId,
      if (photoAsset != null && photoAsset!.isNotEmpty)
        'photoAsset': photoAsset,
    };
  }
}

Map<String, int> _ratingDetailsFromJson(dynamic value) {
  if (value is! Map) {
    return const {};
  }

  final details = <String, int>{};
  for (final entry in value.entries) {
    final key = entry.key;
    final rating = entry.value;
    if (key is String && key != 'priceLevel' && rating is num) {
      details[key] = rating.toInt();
    }
  }

  return details;
}

List<String> _normalizeVibes(List<String> vibes) {
  return vibes.map(_normalizeVibe).toSet().toList()..sort();
}

String _normalizeVibe(String vibe) {
  return switch (vibe.trim().toLowerCase()) {
    'beers' => 'beer',
    _ => vibe.trim().toLowerCase(),
  };
}

String? _optionalString(dynamic value) {
  if (value is! String) {
    return null;
  }

  final trimmedValue = value.trim();
  return trimmedValue.isEmpty ? null : trimmedValue;
}
