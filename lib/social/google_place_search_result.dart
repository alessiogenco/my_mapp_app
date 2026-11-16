/// A short-lived result returned by Google Places while a member selects a
/// venue. Only [placeId] is intended to be retained after selection.
class GooglePlaceSearchResult {
  const GooglePlaceSearchResult({
    required this.placeId,
    required this.name,
    required this.address,
  });

  final String placeId;
  final String name;
  final String address;

  factory GooglePlaceSearchResult.fromJson(Map<dynamic, dynamic> json) {
    return GooglePlaceSearchResult(
      placeId: json['placeId']?.toString().trim() ?? '',
      name: json['name']?.toString().trim() ?? '',
      address: json['address']?.toString().trim() ?? '',
    );
  }
}
