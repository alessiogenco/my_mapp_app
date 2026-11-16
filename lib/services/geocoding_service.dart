import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

enum GeocodingFailureType { timeout, network, invalidResponse }

class GeocodingException implements Exception {
  const GeocodingException(this.type);

  final GeocodingFailureType type;
}

class CityLocation {
  const CityLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class GeocodingService {
  const GeocodingService();

  static DateTime? _lastRequestStartedAt;
  static const _minimumRequestSpacing = Duration(milliseconds: 1100);

  Future<CityLocation?> searchCity(String city) async {
    return _search(city);
  }

  Future<CityLocation?> searchPlace({
    required String name,
    required String city,
  }) {
    // Some entries include the city in their display name (for example,
    // "Mozza - St Andrews" or "Tailend Restaurant St Andrews"). Searching
    // that city twice makes matching less reliable, so use the venue part.
    final venueName = _venueNameWithoutTrailingCity(name, city);
    return _search('$venueName, $city', expectedPlaceName: venueName);
  }

  Future<CityLocation?> _search(
    String query, {
    String? expectedPlaceName,
  }) async {
    final url = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': query,
      'format': 'json',
      // The first result is not always the venue, especially for names that
      // are also part of a street, chain, or town. Inspect a small candidate
      // set and keep only a matching venue below.
      'limit': expectedPlaceName == null ? '1' : '5',
    });

    try {
      var response = await _getNominatimResponse(url);

      // Nominatim is a shared public service. A short retry handles a
      // temporary rate-limit response without making the contributor repeat
      // their Google Place selection.
      if (response.statusCode == 429) {
        await Future<void>.delayed(_minimumRequestSpacing);
        response = await _getNominatimResponse(url);
      }

      if (response.statusCode != 200) {
        throw const GeocodingException(GeocodingFailureType.network);
      }

      final data = jsonDecode(response.body);
      if (data is! List) {
        throw const GeocodingException(GeocodingFailureType.invalidResponse);
      }
      if (data.isEmpty) return null;

      for (final candidate in data) {
        if (candidate is! Map<String, dynamic>) continue;
        if (expectedPlaceName != null &&
            !_isMatchingPlaceResult(candidate, expectedPlaceName)) {
          continue;
        }

        final latitude = double.tryParse(candidate['lat']?.toString() ?? '');
        final longitude = double.tryParse(candidate['lon']?.toString() ?? '');
        if (latitude == null || longitude == null) continue;
        return CityLocation(latitude: latitude, longitude: longitude);
      }

      return null;
    } on TimeoutException {
      throw const GeocodingException(GeocodingFailureType.timeout);
    } on http.ClientException {
      throw const GeocodingException(GeocodingFailureType.network);
    } on FormatException {
      throw const GeocodingException(GeocodingFailureType.invalidResponse);
    }
  }

  Future<http.Response> _getNominatimResponse(Uri url) async {
    final previousRequestAt = _lastRequestStartedAt;
    if (previousRequestAt != null) {
      final elapsed = DateTime.now().difference(previousRequestAt);
      final remaining = _minimumRequestSpacing - elapsed;
      if (!remaining.isNegative) {
        await Future<void>.delayed(remaining);
      }
    }
    _lastRequestStartedAt = DateTime.now();

    return http
        .get(url, headers: const {'User-Agent': 'my_map_app/0.1'})
        .timeout(const Duration(seconds: 10));
  }
}

bool _isMatchingPlaceResult(
  Map<String, dynamic> result,
  String expectedPlaceName,
) {
  final displayName = result['display_name'];
  if (displayName is! String) return false;

  final normalizedExpectedName = _normalizeForComparison(expectedPlaceName);
  final normalizedDisplayName = _normalizeForComparison(displayName);
  return normalizedExpectedName.isNotEmpty &&
      normalizedDisplayName.contains(normalizedExpectedName);
}

String _normalizeForComparison(String value) {
  return value
      .toLowerCase()
      // Treat possessives as the same venue name: "Jannetta's" and
      // "Jannettas" should both match the same independent map listing.
      .replaceAll(RegExp(r"['’]"), '')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r' +'), ' ');
}

String _venueNameWithoutTrailingCity(String name, String city) {
  final cleanName = name.trim();
  final cleanCity = city.trim();
  if (cleanName.isEmpty || cleanCity.isEmpty) return cleanName;

  final trailingCity = RegExp(
    r'(?:\s*[-,–—]\s*|\s+)' + RegExp.escape(cleanCity) + r'\s*$',
    caseSensitive: false,
  );
  final venueName = cleanName.replaceFirst(trailingCity, '').trim();
  return venueName.isEmpty ? cleanName : venueName;
}
