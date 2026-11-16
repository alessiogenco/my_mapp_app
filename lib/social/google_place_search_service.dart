import 'package:my_map_app/config/social_config.dart';
import 'package:my_map_app/social/google_place_search_result.dart';

class GooglePlaceSearchException implements Exception {
  const GooglePlaceSearchException(this.message);

  final String message;
}

class GooglePlaceDetails {
  const GooglePlaceDetails({
    this.googleMapsUrl,
    this.countryCode,
    this.address,
  });

  final String? googleMapsUrl;
  final String? countryCode;
  final String? address;
}

class PlaceCoordinates {
  const PlaceCoordinates({
    required this.latitude,
    required this.longitude,
  });

  final double latitude;
  final double longitude;
}

/// Calls our authenticated Supabase Edge Function, never Google directly.
/// This keeps the Google Places key outside the Flutter app.
class GooglePlaceSearchService {
  const GooglePlaceSearchService();

  Future<List<GooglePlaceSearchResult>> search({
    required String name,
    required String city,
    required String countryCode,
  }) async {
    if (!SocialConfig.isAvailable) {
      throw const GooglePlaceSearchException(
        'Place search is not configured on this device yet.',
      );
    }
    if (SocialConfig.client.auth.currentUser == null) {
      throw const GooglePlaceSearchException('Sign in to search for a place.');
    }

    try {
      final response = await SocialConfig.client.functions.invoke(
        'place-search',
        body: {
          'name': name.trim(),
          'city': city.trim(),
          'countryCode': countryCode.trim().toUpperCase(),
        },
      );
      final data = response.data;
      if (data is! Map) {
        throw const GooglePlaceSearchException(
          'Place search returned an unexpected response.',
        );
      }

      final message = data['error']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        throw GooglePlaceSearchException(message);
      }

      final rawResults = data['results'];
      if (rawResults is! List) return const [];

      return rawResults
          .whereType<Map>()
          .map(GooglePlaceSearchResult.fromJson)
          .where((result) => result.placeId.isNotEmpty && result.name.isNotEmpty)
          .toList(growable: false);
    } on GooglePlaceSearchException {
      rethrow;
    } catch (_) {
      throw const GooglePlaceSearchException(
        'Could not reach the secure place search. Try again shortly.',
      );
    }
  }

  Future<GooglePlaceDetails> loadPlaceDetails({
    required String placeId,
  }) async {
    if (!SocialConfig.isAvailable) {
      throw const GooglePlaceSearchException(
        'Place search is not configured on this device yet.',
      );
    }
    if (SocialConfig.client.auth.currentUser == null) {
      throw const GooglePlaceSearchException('Sign in to search for a place.');
    }

    try {
      final response = await SocialConfig.client.functions.invoke(
        'place-search',
        body: {
          'action': 'details',
          'placeId': placeId.trim(),
        },
      );
      final data = response.data;
      if (data is! Map) {
        throw const GooglePlaceSearchException(
          'Google returned an unexpected place link.',
        );
      }

      final message = data['error']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        throw GooglePlaceSearchException(message);
      }

      final url = data['googleMapsUrl']?.toString().trim();
      final countryCode = data['countryCode']?.toString().trim().toUpperCase();
      final address = data['address']?.toString().trim();
      return GooglePlaceDetails(
        googleMapsUrl: url == null || url.isEmpty ? null : url,
        countryCode: countryCode == null ||
                !RegExp(r'^[A-Z]{2}$').hasMatch(countryCode)
            ? null
            : countryCode,
        address: address == null || address.isEmpty ? null : address,
      );
    } on GooglePlaceSearchException {
      rethrow;
    } catch (_) {
      throw const GooglePlaceSearchException(
        'Could not load the direct Google Maps link right now.',
      );
    }
  }

  /// Resolves a permanent map point through our server. Browsers cannot call
  /// the public geographic provider directly because its response is blocked
  /// by the browser security policy.
  Future<PlaceCoordinates?> resolveCoordinates({
    required String name,
    required String city,
    String address = '',
    String countryCode = '',
  }) async {
    if (!SocialConfig.isAvailable) {
      throw const GooglePlaceSearchException(
        'Place search is not configured on this device yet.',
      );
    }
    if (SocialConfig.client.auth.currentUser == null) {
      throw const GooglePlaceSearchException('Sign in to add a place.');
    }

    try {
      final response = await SocialConfig.client.functions.invoke(
        'place-search',
        body: {
          'action': 'coordinates',
          'name': name.trim(),
          'city': city.trim(),
          'address': address.trim(),
          'countryCode': countryCode.trim().toUpperCase(),
        },
      );
      final data = response.data;
      if (data is! Map) {
        throw const GooglePlaceSearchException(
          'Map coordinates returned an unexpected response.',
        );
      }

      final message = data['error']?.toString().trim();
      if (message != null && message.isNotEmpty) {
        throw GooglePlaceSearchException(message);
      }

      final latitude = double.tryParse(data['latitude']?.toString() ?? '');
      final longitude = double.tryParse(data['longitude']?.toString() ?? '');
      if (latitude == null || longitude == null) return null;
      if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
        return null;
      }
      return PlaceCoordinates(latitude: latitude, longitude: longitude);
    } on GooglePlaceSearchException {
      rethrow;
    } catch (_) {
      throw const GooglePlaceSearchException(
        'Could not resolve the map coordinates right now.',
      );
    }
  }
}
