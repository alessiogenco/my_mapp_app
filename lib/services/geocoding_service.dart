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

  Future<CityLocation?> searchCity(String city) async {
    final url = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': city,
      'format': 'json',
      'limit': '1',
    });

    try {
      final response = await http
          .get(url, headers: const {'User-Agent': 'my_map_app/0.1'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw const GeocodingException(GeocodingFailureType.network);
      }

      final data = jsonDecode(response.body);
      if (data is! List) {
        throw const GeocodingException(GeocodingFailureType.invalidResponse);
      }
      if (data.isEmpty) return null;

      final firstResult = data.first;
      if (firstResult is! Map<String, dynamic>) {
        throw const GeocodingException(GeocodingFailureType.invalidResponse);
      }

      return CityLocation(
        latitude: double.parse(firstResult['lat'] as String),
        longitude: double.parse(firstResult['lon'] as String),
      );
    } on TimeoutException {
      throw const GeocodingException(GeocodingFailureType.timeout);
    } on http.ClientException {
      throw const GeocodingException(GeocodingFailureType.network);
    } on FormatException {
      throw const GeocodingException(GeocodingFailureType.invalidResponse);
    }
  }
}
