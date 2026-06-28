import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:my_map_app/models/place.dart';
import 'package:my_map_app/models/place_area.dart';
import 'package:my_map_app/models/place_category.dart';

class PlaceRepository {
  const PlaceRepository();

  Future<List<Place>> loadPlaces() async {
    final response = await rootBundle.loadString('assets/data/places.json');
    final decodedData = jsonDecode(response);

    if (decodedData is! List) {
      throw const FormatException('The places file is not a list.');
    }

    final places = decodedData.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('A place has an invalid format.');
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
        throw const FormatException('A place has an empty id.');
      }

      if (!ids.add(place.id)) {
        throw FormatException('Duplicated place id: ${place.id}.');
      }

      if (place.name.trim().isEmpty) {
        throw FormatException('Missing place name for id ${place.id}.');
      }

      if (!isKnownPlaceCategory(place.category)) {
        throw FormatException(
          'Invalid category for ${place.name}: ${place.category}.',
        );
      }

      if (!isKnownPlaceArea(place.area)) {
        throw FormatException(
          'Invalid area for ${place.name}: ${place.area}.',
        );
      }

      if (place.rating < 0 || place.rating > 10) {
        throw FormatException(
          'Invalid rating for ${place.name}: ${place.rating}.',
        );
      }

      if (place.priceLevel < 1 || place.priceLevel > 3) {
        throw FormatException(
          'Invalid price level for ${place.name}: ${place.priceLevel}.',
        );
      }

      if (place.lat < -90 || place.lat > 90) {
        throw FormatException(
          'Invalid latitude for ${place.name}: ${place.lat}.',
        );
      }

      if (place.lng < -180 || place.lng > 180) {
        throw FormatException(
          'Invalid longitude for ${place.name}: ${place.lng}.',
        );
      }

      final googleMapsUri = place.googleMapsUrl == null
          ? null
          : Uri.tryParse(place.googleMapsUrl!);
      if (googleMapsUri != null &&
          googleMapsUri.scheme != 'http' &&
          googleMapsUri.scheme != 'https') {
        throw FormatException(
          'Invalid Google Maps URL for ${place.name}: '
          '${place.googleMapsUrl}.',
        );
      }
    }
  }
}
