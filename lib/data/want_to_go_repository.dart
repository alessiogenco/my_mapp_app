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
      return decodeBackup(rawData);
    } on FormatException {
      return const WantToGoData();
    } on TypeError {
      return const WantToGoData();
    }
  }

  Future<void> save(WantToGoData data) async {
    final preferences = SharedPreferencesAsync();
    await preferences.setString(_storageKey, encodeBackup(data));
  }

  String encodeBackup(WantToGoData data) {
    return jsonEncode(data.toJson());
  }

  WantToGoData decodeBackup(String rawBackup) {
    final decodedData = jsonDecode(rawBackup);
    if (decodedData is! Map) {
      throw const FormatException('The backup is not a valid object.');
    }

    return WantToGoData.fromJson(Map<String, dynamic>.from(decodedData));
  }
}

class WantToGoData {
  const WantToGoData({
    this.mappedPlaceIds = const {},
    this.places = const [],
  });

  final Set<String> mappedPlaceIds;
  final List<WantToGoPlace> places;

  factory WantToGoData.fromJson(Map<String, dynamic> json) {
    final rawPlaces = json['places'];
    if (rawPlaces != null && rawPlaces is! List) {
      throw const FormatException('The backup has invalid places.');
    }

    final places = <WantToGoPlace>[];
    final rawPlaceList = rawPlaces as List? ?? const <Object>[];
    for (final rawPlace in rawPlaceList) {
      if (rawPlace is! Map) {
        throw const FormatException('The backup has an invalid place.');
      }
      places.add(WantToGoPlace.fromJson(Map<String, dynamic>.from(rawPlace)));
    }
    places.sort((first, second) => second.createdAt.compareTo(first.createdAt));

    return WantToGoData(
      mappedPlaceIds: (json['mappedPlaceIds'] as List? ?? const [])
          .whereType<String>()
          .toSet(),
      places: places,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'format': 'my_map_app.want_to_go.v1',
      'mappedPlaceIds': mappedPlaceIds.toList()..sort(),
      'places': places.map((place) => place.toJson()).toList(),
    };
  }
}
