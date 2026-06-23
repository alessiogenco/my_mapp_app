import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:my_map_app/models/place.dart';

class PlaceRepository {
  const PlaceRepository();

  Future<List<Place>> loadPlaces() async {
    final response = await rootBundle.loadString('assets/data/places.json');
    final decodedData = jsonDecode(response);

    if (decodedData is! List) {
      throw const FormatException('Il file dei locali non è una lista.');
    }

    return decodedData.map((item) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Un locale ha un formato non valido.');
      }
      return Place.fromJson(item);
    }).toList();
  }
}
