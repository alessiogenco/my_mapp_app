class WantToGoPlace {
  const WantToGoPlace({
    required this.id,
    required this.name,
    required this.city,
    required this.createdAt,
    this.latitude,
    this.longitude,
    this.googleMapsUrl,
    this.googlePlaceId,
    this.note,
    this.priority = 2,
  }) : assert(priority >= 1 && priority <= 3);

  final String id;
  final String name;
  final String city;
  final double? latitude;
  final double? longitude;
  final String? googleMapsUrl;
  final String? googlePlaceId;
  final String? note;
  final int priority;
  final DateTime createdAt;

  bool get isVisibleOnMap => latitude != null && longitude != null;

  WantToGoPlace withCoordinates({
    required double latitude,
    required double longitude,
  }) {
    return WantToGoPlace(
      id: id,
      name: name,
      city: city,
      latitude: latitude,
      longitude: longitude,
      googleMapsUrl: googleMapsUrl,
      googlePlaceId: googlePlaceId,
      note: note,
      priority: priority,
      createdAt: createdAt,
    );
  }

  WantToGoPlace withPriority(int priority) {
    return WantToGoPlace(
      id: id,
      name: name,
      city: city,
      latitude: latitude,
      longitude: longitude,
      googleMapsUrl: googleMapsUrl,
      googlePlaceId: googlePlaceId,
      note: note,
      priority: priority,
      createdAt: createdAt,
    );
  }

  factory WantToGoPlace.create({
    required String name,
    required String city,
    String? googleMapsUrl,
    String? googlePlaceId,
    String? note,
    double? latitude,
    double? longitude,
    int priority = 2,
  }) {
    final createdAt = DateTime.now();
    final normalizedName = name.trim();
    final normalizedCity = city.trim();
    return WantToGoPlace(
      id: '${createdAt.microsecondsSinceEpoch}_${_slugify(normalizedName)}',
      name: normalizedName,
      city: normalizedCity,
      latitude: latitude,
      longitude: longitude,
      googleMapsUrl:
          _optionalText(googleMapsUrl) ??
          _buildGoogleMapsSearchUrl(normalizedName, normalizedCity),
      googlePlaceId: _optionalText(googlePlaceId),
      note: _optionalText(note),
      priority: priority,
      createdAt: createdAt,
    );
  }

  factory WantToGoPlace.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final name = json['name'];
    final city = json['city'];
    final createdAt = json['createdAt'];
    final latitude = json['latitude'];
    final longitude = json['longitude'];
    final rawPriority = json['priority'];

    if (id is! String ||
        name is! String ||
        city is! String ||
        createdAt is! String ||
        id.trim().isEmpty ||
        name.trim().isEmpty ||
        city.trim().isEmpty) {
      throw const FormatException('A Want to go place has an invalid format.');
    }

    final parsedDate = DateTime.tryParse(createdAt);
    if (parsedDate == null) {
      throw const FormatException('A Want to go place has an invalid date.');
    }

    final parsedPriority = rawPriority == null
        ? 2
        : rawPriority is int
        ? rawPriority
        : null;
    if (parsedPriority == null || parsedPriority < 1 || parsedPriority > 3) {
      throw const FormatException('A Want to go place has an invalid priority.');
    }

    final parsedLatitude = latitude is num ? latitude.toDouble() : null;
    final parsedLongitude = longitude is num ? longitude.toDouble() : null;
    final hasOnlyOneCoordinate =
        (parsedLatitude == null) != (parsedLongitude == null);
    if (hasOnlyOneCoordinate ||
        (parsedLatitude != null &&
            (parsedLatitude < -90 || parsedLatitude > 90)) ||
        (parsedLongitude != null &&
            (parsedLongitude < -180 || parsedLongitude > 180))) {
      throw const FormatException('A Want to go place has invalid coordinates.');
    }

    return WantToGoPlace(
      id: id,
      name: name.trim(),
      city: city.trim(),
      latitude: parsedLatitude,
      longitude: parsedLongitude,
      googleMapsUrl:
          _optionalText(json['googleMapsUrl']) ??
          _buildGoogleMapsSearchUrl(name.trim(), city.trim()),
      googlePlaceId: _optionalText(json['googlePlaceId']),
      note: _optionalText(json['note']),
      priority: parsedPriority,
      createdAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'city': city,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (googleMapsUrl != null) 'googleMapsUrl': googleMapsUrl,
      if (googlePlaceId != null) 'googlePlaceId': googlePlaceId,
      if (note != null) 'note': note,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

String? _optionalText(dynamic value) {
  if (value is! String) {
    return null;
  }

  final trimmedValue = value.trim();
  return trimmedValue.isEmpty ? null : trimmedValue;
}

String _slugify(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
}

String _buildGoogleMapsSearchUrl(String name, String city) {
  final query = city.isEmpty ? name : '$name, $city';
  return Uri.https('www.google.com', '/maps/search/', {
    'api': '1',
    'query': query,
  }).toString();
}
