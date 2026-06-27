class Place {
  final String id;
  final String name;
  final String city;
  final String category;
  final double lat;
  final double lng;
  final int rating;
  final int priceLevel;
  final List<String> vibes;
  final String notes;
  final String? googleMapsUrl;
  final String? googlePlaceId;
  final String? photoAsset;

  Place({
    required this.id,
    required this.name,
    required this.city,
    required this.category,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.priceLevel,
    required this.vibes,
    required this.notes,
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
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      rating: json['rating'],
      priceLevel: json['priceLevel'],
      vibes: _normalizeVibes(List<String>.from(json['vibes'] ?? [])),
      notes: json['notes'] ?? '',
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
      'rating': rating,
      'priceLevel': priceLevel,
      'lat': lat,
      'lng': lng,
      'vibes': vibes,
      'notes': notes,
      if (googleMapsUrl != null && googleMapsUrl!.isNotEmpty)
        'googleMapsUrl': googleMapsUrl,
      if (googlePlaceId != null && googlePlaceId!.isNotEmpty)
        'googlePlaceId': googlePlaceId,
      if (photoAsset != null && photoAsset!.isNotEmpty)
        'photoAsset': photoAsset,
    };
  }
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
