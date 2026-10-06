import 'dart:convert';

import 'package:my_map_app/models/want_to_go_place.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WantToGoRepository {
  const WantToGoRepository();

  static const _storageKey = 'my_map_app.want_to_go.v1';

  Future<WantToGoData> load() async {
    final preferences = SharedPreferencesAsync();
    final rawData = await preferences.getString(_storageKey);
    if (rawData == null || rawData.isEmpty) {
      return const WantToGoData();
    }

    try {
      final decodedData = jsonDecode(rawData);
      if (decodedData is! Map<String, dynamic>) {
        return const WantToGoData();
      }

      final mappedPlaceIds = (decodedData['mappedPlaceIds'] as List? ?? const [])
          .whereType<String>()
          .toSet();
      final places = (decodedData['places'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(WantToGoPlace.fromJson)
          .toList()
        ..sort((first, second) => second.createdAt.compareTo(first.createdAt));

      return WantToGoData(
        mappedPlaceIds: mappedPlaceIds,
        places: places,
      );
    } on FormatException {
      return const WantToGoData();
    } on TypeError {
      return const WantToGoData();
    }
  }

  Future<void> save(WantToGoData data) async {
    final preferences = SharedPreferencesAsync();
    final encodedData = jsonEncode({
      'mappedPlaceIds': data.mappedPlaceIds.toList()..sort(),
      'places': data.places.map((place) => place.toJson()).toList(),
    });
    await preferences.setString(_storageKey, encodedData);
  }
}

class WantToGoData {
  const WantToGoData({
    this.mappedPlaceIds = const {},
    this.places = const [],
  });

  final Set<String> mappedPlaceIds;
  final List<WantToGoPlace> places;
}
