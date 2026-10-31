class Place {
  final String id;
  final String name;
  final String city;
  final String countryCode;
  final String currencyCode;
  final String category;
  final String area;
  final String? neighborhood;
  final double lat;
  final double lng;
  final int rating;
  final int priceLevel;
  final List<String> foodTags;
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
    this.countryCode = 'IT',
    this.currencyCode = 'EUR',
    required this.category,
    required this.area,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.priceLevel,
    this.foodTags = const [],
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
      countryCode: _countryCodeFromJson(json['countryCode']),
      currencyCode: _currencyCodeFromJson(
        json['currencyCode'],
        countryCode: _countryCodeFromJson(json['countryCode']),
      ),
      category: json['category'],
      area: json['area'] ?? '',
      neighborhood: _optionalString(json['neighborhood']),
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      rating: json['rating'],
      priceLevel: json['priceLevel'],
      foodTags: _normalizeTags(List<String>.from(json['foodTags'] ?? [])),
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
      'countryCode': countryCode,
      'currencyCode': currencyCode,
      'category': category,
      'area': area,
      if (neighborhood != null && neighborhood!.isNotEmpty)
        'neighborhood': neighborhood,
      'rating': rating,
      'priceLevel': priceLevel,
      if (foodTags.isNotEmpty) 'foodTags': foodTags,
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

String defaultCurrencyForCountry(String countryCode) {
  return switch (countryCode.toUpperCase()) {
    'IT' || 'ES' || 'FR' || 'DE' || 'PT' || 'GR' || 'NL' || 'BE' || 'AT' ||
    'IE' || 'FI' => 'EUR',
    'GB' => 'GBP',
    'NO' => 'NOK',
    'SE' => 'SEK',
    'DK' => 'DKK',
    'US' => 'USD',
    _ => 'EUR',
  };
}

String currencySymbolFor(String currencyCode) {
  return switch (currencyCode.toUpperCase()) {
    'EUR' => '€',
    'GBP' => '£',
    'NOK' || 'SEK' || 'DKK' => 'kr',
    'USD' => r'$',
    _ => currencyCode.toUpperCase(),
  };
}

String priceLabelFor(int priceLevel, String currencyCode) {
  final currency = currencyCode.toUpperCase();
  final symbol = currencySymbolFor(currency);
  final symbols = List.filled(priceLevel, symbol).join();
  final range = switch (currency) {
    'NOK' => switch (priceLevel) {
      1 => '0–200 kr',
      2 => '200–400 kr',
      3 => '400–700 kr',
      4 => '700–1000 kr',
      _ => '1000 kr+',
    },
    'GBP' || 'USD' => switch (priceLevel) {
      1 => '${symbol}0–15',
      2 => '${symbol}15–35',
      3 => '${symbol}35–70',
      4 => '${symbol}70–100',
      _ => '${symbol}100+',
    },
    _ => switch (priceLevel) {
      1 => '0–15$symbol',
      2 => '15–35$symbol',
      3 => '35–70$symbol',
      4 => '70–100$symbol',
      _ => '100$symbol+',
    },
  };
  return '$symbols · $range';
}

String _countryCodeFromJson(dynamic value) {
  if (value is! String || !RegExp(r'^[A-Za-z]{2}$').hasMatch(value.trim())) {
    return 'IT';
  }
  return value.trim().toUpperCase();
}

String _currencyCodeFromJson(dynamic value, {required String countryCode}) {
  if (value is! String || !RegExp(r'^[A-Za-z]{3}$').hasMatch(value.trim())) {
    return defaultCurrencyForCountry(countryCode);
  }
  return value.trim().toUpperCase();
}

List<String> _normalizeTags(List<String> tags) {
  return tags
      .map((tag) => tag.trim().toLowerCase().replaceAll(' ', '_'))
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
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
