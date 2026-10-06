import 'dart:convert';
import 'dart:io';

const _host = '127.0.0.1';
const _port = 8787;
const _placesFilePath = 'assets/data/places.json';
const _backupDirectoryPath = 'assets/data/backups';
const _allowedCategories = {
  'restaurant',
  'sushi',
  'chinese',
  'indian',
  'pizzeria',
  'panzerotteria',
  'steakhouse',
  'pub',
  'coffee_bar',
  'cocktail_bar',
  'beer_bar',
  'bakery_sweet',
  'bakery_savory',
  'gelateria',
};
const _allowedAreas = {
  'cityCentre',
  'historicalCentre',
  'periphery',
  'outsideCentre',
};

Future<void> main() async {
  final server = await HttpServer.bind(_host, _port);
  stdout.writeln('Place writer server running on http://$_host:$_port');
  stdout.writeln('Writing to $_placesFilePath');

  await for (final request in server) {
    await _handleRequest(request);
  }
}

Future<void> _handleRequest(HttpRequest request) async {
  _addCorsHeaders(request.response);

  if (request.method == 'OPTIONS') {
    request.response.statusCode = HttpStatus.noContent;
    await request.response.close();
    return;
  }

  if (request.method == 'GET' && request.uri.path == '/health') {
    _writeJson(request.response, {'ok': true});
    return;
  }

  if (request.method == 'GET' && request.uri.path == '/places') {
    await _listPlaces(request);
    return;
  }

  if (request.method == 'POST' && request.uri.path == '/places') {
    await _appendPlace(request);
    return;
  }

  if (request.method == 'PUT' &&
      request.uri.pathSegments.length == 2 &&
      request.uri.pathSegments.first == 'places') {
    await _updatePlace(request, request.uri.pathSegments[1]);
    return;
  }

  request.response.statusCode = HttpStatus.notFound;
  _writeJson(request.response, {'error': 'Route not found'});
}

Future<void> _listPlaces(HttpRequest request) async {
  try {
    final places = await _readPlaces();
    _writeJson(request.response, places);
  } catch (error) {
    request.response.statusCode = HttpStatus.internalServerError;
    _writeJson(request.response, {'error': error.toString()});
  }
}

Future<void> _appendPlace(HttpRequest request) async {
  try {
    final body = await utf8.decoder.bind(request).join();
    final decodedBody = jsonDecode(body);

    if (decodedBody is! Map<String, dynamic>) {
      request.response.statusCode = HttpStatus.badRequest;
      _writeJson(request.response, {'error': 'Request body must be an object'});
      return;
    }

    _normalizePlaceData(decodedBody);
    final validationError = _validatePlaceData(decodedBody);
    if (validationError != null) {
      request.response.statusCode = HttpStatus.badRequest;
      _writeJson(request.response, {'error': validationError});
      return;
    }

    final places = await _readPlaces();
    final newId = decodedBody['id'] as String;

    final duplicateExists = places.any((place) {
      return place is Map && place['id'] == newId;
    });

    if (duplicateExists) {
      request.response.statusCode = HttpStatus.conflict;
      _writeJson(request.response, {
        'error': 'A place with id "$newId" already exists',
      });
      return;
    }

    places.add(decodedBody);

    await _writePlaces(places);

    _writeJson(request.response, {
      'ok': true,
      'count': places.length,
      'id': newId,
    });
  } on FormatException catch (error) {
    request.response.statusCode = HttpStatus.badRequest;
    _writeJson(request.response, {'error': error.message});
  } catch (error) {
    request.response.statusCode = HttpStatus.internalServerError;
    _writeJson(request.response, {'error': error.toString()});
  }
}

Future<void> _updatePlace(HttpRequest request, String currentId) async {
  try {
    final body = await utf8.decoder.bind(request).join();
    final decodedBody = jsonDecode(body);

    if (decodedBody is! Map<String, dynamic>) {
      request.response.statusCode = HttpStatus.badRequest;
      _writeJson(request.response, {'error': 'Request body must be an object'});
      return;
    }

    _normalizePlaceData(decodedBody);
    final validationError = _validatePlaceData(decodedBody);
    if (validationError != null) {
      request.response.statusCode = HttpStatus.badRequest;
      _writeJson(request.response, {'error': validationError});
      return;
    }

    final nextId = decodedBody['id'];

    if (nextId is! String || nextId.trim().isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      _writeJson(request.response, {'error': 'Place id is required'});
      return;
    }

    final places = await _readPlaces();
    final existingIndex = places.indexWhere((place) {
      return place is Map && place['id'] == currentId;
    });

    if (existingIndex < 0) {
      request.response.statusCode = HttpStatus.notFound;
      _writeJson(request.response, {
        'error': 'Place with id "$currentId" was not found',
      });
      return;
    }

    final duplicateExists = places.indexed.any((entry) {
      final index = entry.$1;
      final place = entry.$2;
      return index != existingIndex && place is Map && place['id'] == nextId;
    });

    if (duplicateExists) {
      request.response.statusCode = HttpStatus.conflict;
      _writeJson(request.response, {
        'error': 'A place with id "$nextId" already exists',
      });
      return;
    }

    places[existingIndex] = decodedBody;
    await _writePlaces(places);

    _writeJson(request.response, {
      'ok': true,
      'count': places.length,
      'id': nextId,
      'updated': true,
    });
  } on FormatException catch (error) {
    request.response.statusCode = HttpStatus.badRequest;
    _writeJson(request.response, {'error': error.message});
  } catch (error) {
    request.response.statusCode = HttpStatus.internalServerError;
    _writeJson(request.response, {'error': error.toString()});
  }
}

Future<List<dynamic>> _readPlaces() async {
  final placesFile = File(_placesFilePath);
  final decodedPlaces = jsonDecode(await placesFile.readAsString());

  if (decodedPlaces is! List) {
    throw const FormatException('places.json is not a list');
  }

  return decodedPlaces.cast<dynamic>();
}

Future<void> _writePlaces(List<dynamic> places) async {
  final placesFile = File(_placesFilePath);
  const encoder = JsonEncoder.withIndent('  ');
  await _backupPlacesFile(placesFile);
  await placesFile.writeAsString('${encoder.convert(places)}\n');
}

Future<void> _backupPlacesFile(File placesFile) async {
  if (!await placesFile.exists()) {
    return;
  }

  final backupDirectory = Directory(_backupDirectoryPath);
  await backupDirectory.create(recursive: true);

  final timestamp = DateTime.now()
      .toIso8601String()
      .replaceAll(':', '-')
      .replaceAll('.', '-');
  final backupFile = File('$_backupDirectoryPath/places_$timestamp.json');
  await placesFile.copy(backupFile.path);
}

void _normalizePlaceData(Map<String, dynamic> place) {
  final category = place['category'];
  if (category is String) {
    place['category'] = category.trim().toLowerCase();
  }

  final area = place['area'];
  if (area is String) {
    place['area'] = area.trim();
  }

  for (final urlField in ['websiteUrl', 'instagramUrl', 'googleMapsUrl']) {
    final value = place[urlField];
    if (value is String) {
      place[urlField] = value.trim();
    }
  }

  final vibes = place['vibes'];
  if (vibes is List) {
    place['vibes'] = vibes
        .whereType<String>()
        .map((vibe) => vibe.trim().toLowerCase().replaceAll(' ', '_'))
        .map((vibe) => vibe == 'beers' ? 'beer' : vibe)
        .where((vibe) => vibe.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
  }
}

String? _validatePlaceData(Map<String, dynamic> place) {
  final id = place['id'];
  if (id is! String || id.trim().isEmpty) {
    return 'Place id is required';
  }

  if (!RegExp(r'^[a-z0-9_]+$').hasMatch(id)) {
    return 'Place id can only contain lowercase letters, numbers and _';
  }

  final name = place['name'];
  if (name is! String || name.trim().isEmpty) {
    return 'Place name is required';
  }

  final category = place['category'];
  if (category is! String || !_allowedCategories.contains(category)) {
    return 'Invalid category: $category';
  }

  final area = place['area'];
  if (area is! String || !_allowedAreas.contains(area)) {
    return 'Invalid area: $area';
  }

  final rating = place['rating'];
  if (rating is! num || rating < 0 || rating > 10) {
    return 'Rating must be between 0 and 10';
  }

  final priceLevel = place['priceLevel'];
  if (priceLevel is! num || priceLevel < 1 || priceLevel > 5) {
    return 'Price level must be between 1 and 5';
  }

  final lat = place['lat'];
  if (lat is! num || lat < -90 || lat > 90) {
    return 'Latitude must be between -90 and 90';
  }

  final lng = place['lng'];
  if (lng is! num || lng < -180 || lng > 180) {
    return 'Longitude must be between -180 and 180';
  }

  final vibes = place['vibes'];
  if (vibes is! List || vibes.whereType<String>().isEmpty) {
    return 'Add at least one vibe';
  }

  final ratingDetails = place['ratingDetails'];
  if (ratingDetails != null) {
    if (ratingDetails is! Map) {
      return 'ratingDetails must be an object';
    }

    for (final entry in ratingDetails.entries) {
      if (entry.key == 'priceLevel') {
        return 'priceLevel must stay a top-level field';
      }

      final value = entry.value;
      if (value is! num || value < 1 || value > 10) {
        return 'Detailed ratings must be between 1 and 10';
      }
    }
  }

  for (final urlField in ['websiteUrl', 'instagramUrl', 'googleMapsUrl']) {
    final value = place[urlField];
    if (value == null || value == '') {
      continue;
    }
    if (value is! String) {
      return '$urlField must be a URL';
    }
    final uri = Uri.tryParse(value);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return '$urlField must start with http or https';
    }
    if (urlField == 'instagramUrl' &&
        uri.host.toLowerCase() != 'instagram.com' &&
        uri.host.toLowerCase() != 'www.instagram.com') {
      return 'instagramUrl must be an instagram.com URL';
    }
  }

  return null;
}

void _addCorsHeaders(HttpResponse response) {
  response.headers
    ..set(HttpHeaders.accessControlAllowOriginHeader, '*')
    ..set('Access-Control-Allow-Private-Network', 'true')
    ..set(
      HttpHeaders.accessControlAllowMethodsHeader,
      'GET, POST, PUT, OPTIONS',
    )
    ..set(
      HttpHeaders.accessControlAllowHeadersHeader,
      'Content-Type',
    );
}

void _writeJson(HttpResponse response, Object body) {
  response.headers.contentType = ContentType.json;
  response.write(jsonEncode(body));
  response.close();
}
