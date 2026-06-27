import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:my_map_app/models/place.dart';
import 'package:my_map_app/models/place_category.dart';

class PlaceRepository {
  const PlaceRepository();

  Future<List<Place>> loadPlaces() async {
    final response = await rootBundle.loadString('assets/data/places.json');
    final decodedData = jsonDecode(response);

    if (decodedData is! List) {
      throw const FormatException('Il file dei locali non è una lista.');
    }

    final places = decodedData.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Un locale ha un formato non valido.');
      }
      return Place.fromJson(item);
    }).toList();

    _validatePlaces(places);

    return places;
  }

  void _validatePlaces(List<Place> places) {
    final ids = <String>{};

    for (final place in places) {
      if (place.id.trim().isEmpty) {
        throw const FormatException('Un locale ha id vuoto.');
      }

      if (!ids.add(place.id)) {
        throw FormatException('Id locale duplicato: ${place.id}.');
      }

      if (place.name.trim().isEmpty) {
        throw FormatException('Nome locale mancante per id ${place.id}.');
      }

      if (!isKnownPlaceCategory(place.category)) {
        throw FormatException(
          'Categoria non valida per ${place.name}: ${place.category}.',
        );
      }

      if (place.rating < 0 || place.rating > 10) {
        throw FormatException(
          'Rating non valido per ${place.name}: ${place.rating}.',
        );
      }

      if (place.priceLevel < 1 || place.priceLevel > 3) {
        throw FormatException(
          'Prezzo non valido per ${place.name}: ${place.priceLevel}.',
        );
      }

      if (place.lat < -90 || place.lat > 90) {
        throw FormatException(
          'Latitudine non valida per ${place.name}: ${place.lat}.',
        );
      }

      if (place.lng < -180 || place.lng > 180) {
        throw FormatException(
          'Longitudine non valida per ${place.name}: ${place.lng}.',
        );
      }

      final googleMapsUri = place.googleMapsUrl == null
          ? null
          : Uri.tryParse(place.googleMapsUrl!);
      if (googleMapsUri != null &&
          googleMapsUri.scheme != 'http' &&
          googleMapsUri.scheme != 'https') {
        throw FormatException(
          'Google Maps URL non valido per ${place.name}: '
          '${place.googleMapsUrl}.',
        );
      }
    }
  }
}
