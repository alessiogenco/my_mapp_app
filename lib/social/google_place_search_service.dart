import 'dart:convert';

import 'package:supabase_flutter/supabase_flutter.dart' show FunctionException;
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
    this.city,
    this.businessStatus,
    this.isOpenNow,
    this.nextOpenTime,
    this.nextCloseTime,
    this.utcOffsetMinutes,
  });

  final String? googleMapsUrl;
  final String? countryCode;
  final String? address;
  final String? city;
  final String? businessStatus;
  final bool? isOpenNow;
  final String? nextOpenTime;
  final String? nextCloseTime;
  final int? utcOffsetMinutes;
}

class PlaceCoordinates {
  const PlaceCoordinates({required this.latitude, required this.longitude});

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
          .where(
            (result) => result.placeId.isNotEmpty && result.name.isNotEmpty,
          )
          .toList(growable: false);
    } on GooglePlaceSearchException {
      rethrow;
    } catch (_) {
      throw const GooglePlaceSearchException(
        'Could not reach the secure place search. Try again shortly.',
      );
    }
  }

  /// Finds food and drink venues close to a user-selected point. The server
  /// keeps the Google key private and enforces the same per-member daily
  /// lookup allowance as a name-and-city search.
  Future<List<GooglePlaceSearchResult>> searchNearby({
    required double latitude,
    required double longitude,
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
          'action': 'nearby',
          'latitude': latitude,
          'longitude': longitude,
        },
      );
      final data = response.data;
      if (data is! Map) {
        throw const GooglePlaceSearchException(
          'Nearby places returned an unexpected response.',
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
          .where(
            (result) => result.placeId.isNotEmpty && result.name.isNotEmpty,
          )
          .toList(growable: false);
    } on GooglePlaceSearchException {
      rethrow;
    } catch (_) {
      throw const GooglePlaceSearchException(
        'Could not reach the secure nearby search. Try again shortly.',
      );
    }
  }

  Future<GooglePlaceDetails> loadPlaceDetails({required String placeId}) async {
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
        body: {'action': 'details', 'placeId': placeId.trim()},
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
      final city = data['city']?.toString().trim();
      final businessStatus = data['businessStatus']?.toString().trim();
      final openNow = data['openNow'];
      final nextOpenTime = data['nextOpenTime']?.toString().trim();
      final nextCloseTime = data['nextCloseTime']?.toString().trim();
      final utcOffsetMinutes = int.tryParse(
        data['utcOffsetMinutes']?.toString() ?? '',
      );
      return GooglePlaceDetails(
        googleMapsUrl: url == null || url.isEmpty ? null : url,
        countryCode:
            countryCode == null || !RegExp(r'^[A-Z]{2}$').hasMatch(countryCode)
            ? null
            : countryCode,
        address: address == null || address.isEmpty ? null : address,
        city: city == null || city.isEmpty ? null : city,
        businessStatus: businessStatus == null || businessStatus.isEmpty
            ? null
            : businessStatus,
        isOpenNow: openNow is bool ? openNow : null,
        nextOpenTime: nextOpenTime == null || nextOpenTime.isEmpty
            ? null
            : nextOpenTime,
        nextCloseTime: nextCloseTime == null || nextCloseTime.isEmpty
            ? null
            : nextCloseTime,
        utcOffsetMinutes: utcOffsetMinutes,
      );
    } on GooglePlaceSearchException {
      rethrow;
    } on FunctionException catch (error) {
      throw GooglePlaceSearchException(
        _placeDetailsErrorMessage(error.details),
      );
    } catch (_) {
      throw const GooglePlaceSearchException(
        'Could not load the direct Google Maps link right now.',
      );
    }
  }

  String _placeDetailsErrorMessage(dynamic details) {
    dynamic payload = details;
    if (payload is String) {
      try {
        payload = jsonDecode(payload);
      } on FormatException {
        return 'Live opening hours are temporarily unavailable.';
      }
    }

    if (payload is Map) {
      final message = payload['error']?.toString().trim();
      if (message != null && message.isNotEmpty) return message;
    }

    return 'Live opening hours are temporarily unavailable.';
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
      if (latitude < -90 ||
          latitude > 90 ||
          longitude < -180 ||
          longitude > 180) {
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
