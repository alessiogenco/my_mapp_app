import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:my_map_app/models/place.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: MapPage());
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController mapController = MapController();
  List<Place> places = [];
  String? selectedCategory;
  int? minRating;
  bool isLoadingPlaces = true;
  bool isSearchingCity = false;
  String? placesError;

  List<Place> get filteredPlaces {
    return places.where((p) {
      if (selectedCategory != null && p.category != selectedCategory) {
        return false;
      }

      if (minRating != null && p.rating < minRating!) {
        return false;
      }

      return true;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    loadPlaces();
  }

  Future<void> loadPlaces() async {
    setState(() {
      isLoadingPlaces = true;
      placesError = null;
    });

    try {
      final response = await rootBundle.loadString('assets/data/places.json');
      final decodedData = jsonDecode(response);

      if (decodedData is! List) {
        throw const FormatException('Il file dei locali non è una lista.');
      }

      final loadedPlaces = decodedData.map((item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Un locale ha un formato non valido.');
        }
        return Place.fromJson(item);
      }).toList();

      if (!mounted) return;
      setState(() {
        places = loadedPlaces;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        placesError = 'Impossibile caricare i locali.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingPlaces = false;
        });
      }
    }
  }

  Widget buildCategoryFilter() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: DropdownButtonFormField<String>(
        initialValue: selectedCategory,
        decoration: const InputDecoration(
          labelText: 'Categoria',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: null, child: Text('Tutte')),

          DropdownMenuItem(value: 'restaurant', child: Text('🍝 Ristoranti')),

          DropdownMenuItem(value: 'steakhouse', child: Text('🥩 Steakhouse')),

          DropdownMenuItem(value: 'pub', child: Text('🍔 Pub')),

          DropdownMenuItem(value: 'coffee_bar', child: Text('☕ Coffee Bar')),

          DropdownMenuItem(
            value: 'cocktail_bar',
            child: Text('🍸 Cocktail Bar'),
          ),

          DropdownMenuItem(value: 'beer_bar', child: Text('🍺 Beer Bar')),

          DropdownMenuItem(
            value: 'bakery_savory',
            child: Text('🥪 Bakery Salato'),
          ),

          DropdownMenuItem(
            value: 'bakery_sweet',
            child: Text('🍰 Bakery Dolce'),
          ),

          DropdownMenuItem(value: 'gelateria', child: Text('🍦 Gelateria')),
        ],
        onChanged: (value) {
          setState(() {
            selectedCategory = value;
          });
        },
      ),
    );
  }

  Widget buildRatingFilter() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: DropdownButtonFormField<int>(
        initialValue: minRating,
        decoration: const InputDecoration(
          labelText: 'Rating minimo',
          border: OutlineInputBorder(),
        ),
        items: const [
          DropdownMenuItem(value: null, child: Text('Tutti')),

          DropdownMenuItem(value: 6, child: Text('6+')),

          DropdownMenuItem(value: 7, child: Text('7+')),

          DropdownMenuItem(value: 8, child: Text('8+')),

          DropdownMenuItem(value: 9, child: Text('9+')),
        ],
        onChanged: (value) {
          setState(() {
            minRating = value;
          });
        },
      ),
    );
  }

  Future<void> searchCity(String city) async {
    final normalizedCity = city.trim();
    if (normalizedCity.isEmpty) {
      _showMessage('Inserisci il nome di una città.');
      return;
    }

    setState(() {
      isSearchingCity = true;
    });

    try {
      final url = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': normalizedCity,
        'format': 'json',
        'limit': '1',
      });

      final response = await http
          .get(url, headers: const {'User-Agent': 'my_map_app/0.1'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        throw http.ClientException('Risposta HTTP ${response.statusCode}', url);
      }

      final data = jsonDecode(response.body);
      if (data is! List || data.isEmpty) {
        _showMessage('Nessuna città trovata per “$normalizedCity”.');
        return;
      }

      final firstResult = data.first;
      if (firstResult is! Map<String, dynamic>) {
        throw const FormatException('Risposta del geocoder non valida.');
      }

      final lat = double.parse(firstResult['lat'] as String);
      final lon = double.parse(firstResult['lon'] as String);
      mapController.move(LatLng(lat, lon), 13);
    } on TimeoutException {
      _showMessage('La ricerca sta impiegando troppo tempo. Riprova.');
    } on http.ClientException {
      _showMessage('Errore di rete durante la ricerca.');
    } on FormatException {
      _showMessage('La risposta della ricerca non è valida.');
    } catch (_) {
      _showMessage('Impossibile completare la ricerca.');
    } finally {
      if (mounted) {
        setState(() {
          isSearchingCity = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Widget buildMapContent() {
    if (isLoadingPlaces) {
      return const Center(child: CircularProgressIndicator());
    }

    if (placesError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(placesError!),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: loadPlaces,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      );
    }

    return FlutterMap(
      mapController: mapController,
      options: const MapOptions(
        initialCenter: LatLng(40.7857, 17.2370),
        initialZoom: 14,
      ),
      children: [
        TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
        ),
        MarkerLayer(
          markers: filteredPlaces.map((p) => buildMarker(p)).toList(),
        ),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
            TextSourceAttribution('CARTO'),
          ],
        ),
      ],
    );
  }

  void showPlaceDetails(Place place) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // handle
              Center(
                child: Container(
                  width: 50,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // title
              Row(
                children: [
                  Text(
                    _getEmoji(place.category),
                    style: const TextStyle(fontSize: 30),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: Text(
                      place.name,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // rating
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber),

                  const SizedBox(width: 5),

                  Text(
                    "${place.rating}/10",
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // vibes
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: place.vibes.map((vibe) {
                  return Chip(label: Text(vibe));
                }).toList(),
              ),

              const SizedBox(height: 20),

              // description
              Text(
                place.notes,
                style: const TextStyle(fontSize: 16, height: 1.4),
              ),

              const SizedBox(height: 25),
            ],
          ),
        );
      },
    );
  }

  Marker buildMarker(Place place) {
    return Marker(
      point: LatLng(place.lat, place.lng),
      width: 140,
      height: 50,
      child: GestureDetector(
        onTap: () {
          showPlaceDetails(place);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 4,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _getEmoji(place.category),
                style: const TextStyle(fontSize: 22),
              ),

              const SizedBox(width: 6),

              Flexible(
                child: Text(
                  place.name,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getEmoji(String category) {
    switch (category) {
      case 'restaurant':
        return '🍝';

      case 'steakhouse':
        return '🥩';

      case 'pub':
        return '🍔';

      case 'coffee_bar':
        return '☕';

      case 'cocktail_bar':
        return '🍸';

      case 'beer_bar':
        return '🍺';

      case 'bakery_sweet':
        return '🍰';

      case 'bakery_savory':
        return '🥪';

      case 'gelateria':
        return '🍦';

      default:
        return '📍';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            enabled: !isSearchingCity,
            decoration: InputDecoration(
              hintText: "Cerca città (es: Milano)",
              border: InputBorder.none,
              suffixIcon: isSearchingCity
                  ? const Padding(
                      padding: EdgeInsets.all(10),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.search),
            ),
            onSubmitted: (value) async {
              await searchCity(value);
            },
          ),
        ),
      ),
      body: Column(
        children: [
          buildCategoryFilter(),

          buildRatingFilter(),

          Expanded(child: buildMapContent()),
        ],
      ),

      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: "zoomIn",
            mini: true,
            child: const Icon(Icons.add),
            onPressed: () {
              mapController.move(
                mapController.camera.center,
                mapController.camera.zoom + 1,
              );
            },
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: "zoomOut",
            mini: true,
            child: const Icon(Icons.remove),
            onPressed: () {
              mapController.move(
                mapController.camera.center,
                mapController.camera.zoom - 1,
              );
            },
          ),
        ],
      ),
    );
  }
}
