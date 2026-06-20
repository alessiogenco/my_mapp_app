class Place {
  final String id;
  final String name;
  final String category;
  final double lat;
  final double lng;
  final int rating;
  final int priceLevel;
  final List<String> vibes;
  final String notes;

  Place({
    required this.id,
    required this.name,
    required this.category,
    required this.lat,
    required this.lng,
    required this.rating,
    required this.priceLevel,
    required this.vibes,
    required this.notes,
  });

  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      id: json['id'],
      name: json['name'],
      category: json['category'],
      lat: json['lat'],
      lng: json['lng'],
      rating: json['rating'],
      priceLevel: json['priceLevel'],
      vibes: List<String>.from(json['vibes'] ?? []),
      notes: json['notes'] ?? '',
    );
  }
}