import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_map_app/models/place.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: MapPage(),
    );
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
  List<Place> get filteredPlaces {
    return places.where((p) {

      if (
        selectedCategory != null &&
        p.category != selectedCategory
      ) {
        return false;
      }

      if (
        minRating != null &&
        p.rating < minRating!
      ) {
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
  final String response =
      await rootBundle.loadString('assets/data/places.json');

  final List<dynamic> data = jsonDecode(response);

  setState(() {
    places = data.map((json) => Place.fromJson(json)).toList();
  });
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

        DropdownMenuItem(
          value: null,
          child: Text('Tutte'),
        ),

        DropdownMenuItem(
          value: 'restaurant',
          child: Text('🍝 Ristoranti'),
        ),

        DropdownMenuItem(
          value: 'steakhouse',
          child: Text('🥩 Steakhouse'),
        ),

        DropdownMenuItem(
          value: 'pub',
          child: Text('🍔 Pub'),
        ),

        DropdownMenuItem(
          value: 'coffee_bar',
          child: Text('☕ Coffee Bar'),
        ),

        DropdownMenuItem(
          value: 'cocktail_bar',
          child: Text('🍸 Cocktail Bar'),
        ),

        DropdownMenuItem(
          value: 'beer_bar',
          child: Text('🍺 Beer Bar'),
        ),

        DropdownMenuItem(
          value: 'bakery_savory',
          child: Text('🥪 Bakery Salato'),
        ),

        DropdownMenuItem(
          value: 'bakery_sweet',
          child: Text('🍰 Bakery Dolce'),
        ),

        DropdownMenuItem(
          value: 'gelateria',
          child: Text('🍦 Gelateria'),
        ),
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

          DropdownMenuItem(
            value: null,
            child: Text('Tutti'),
          ),

          DropdownMenuItem(
            value: 6,
            child: Text('6+'),
          ),

          DropdownMenuItem(
            value: 7,
            child: Text('7+'),
          ),

          DropdownMenuItem(
            value: 8,
            child: Text('8+'),
          ),

          DropdownMenuItem(
            value: 9,
            child: Text('9+'),
          ),
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
  final url = Uri.parse(
    'https://nominatim.openstreetmap.org/search?q=$city&format=json&limit=1',
  );

  final response = await http.get(
    url,
    headers: {
      'User-Agent': 'my_map_app'
    },
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);

    if (data.isNotEmpty) {
      final lat = double.parse(data[0]['lat']);
      final lon = double.parse(data[0]['lon']);

      mapController.move(
        LatLng(lat, lon),
        13,
      );
    }
  }
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
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(30),
          ),
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
                return Chip(
                  label: Text(vibe),
                );
              }).toList(),
            ),

            const SizedBox(height: 20),

            // description
            Text(
              place.notes,
              style: const TextStyle(
                fontSize: 16,
                height: 1.4,
              ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
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

IconData _getIcon(String category) {
  switch (category) {
    case 'restaurant':
      return Icons.restaurant;
    case 'bar':
      return Icons.local_bar;
    case 'pub':
      return Icons.sports_bar;
    case 'bakery':
      return Icons.bakery_dining;
    case 'gelateria':
      return Icons.icecream;
    default:
      return Icons.place;
  }
}

Color _getColor(int rating) {
  if (rating >= 8) return Colors.green;
  if (rating >= 6) return Colors.orange;
  return Colors.red;
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
            decoration: const InputDecoration(
              hintText: "Cerca città (es: Milano)",
              border: InputBorder.none,
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

          Expanded(
            child: FlutterMap(
              mapController: mapController,
              options: const MapOptions(
                initialCenter: LatLng(40.7857, 17.2370),
                initialZoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                    "https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png",
                  subdomains: const ['a', 'b', 'c', 'd'],
               ),

              MarkerLayer(
                markers: filteredPlaces
                    .map((p) => buildMarker(p))
                    .toList(),
              ),
            ],
          ),
        ),
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

