import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:my_map_app/config/map_config.dart';
import 'package:my_map_app/data/place_repository.dart';
import 'package:my_map_app/models/place.dart';
import 'package:my_map_app/services/geocoding_service.dart';
import 'package:my_map_app/widgets/glass_panel.dart';
import 'package:my_map_app/widgets/map_filters.dart';
import 'package:my_map_app/widgets/place_details_sheet.dart';
import 'package:my_map_app/widgets/place_marker.dart';

class MapPage extends StatefulWidget {
  const MapPage({
    this.placeRepository = const PlaceRepository(),
    this.geocodingService = const GeocodingService(),
    super.key,
  });

  final PlaceRepository placeRepository;
  final GeocodingService geocodingService;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final MapController _mapController = MapController();
  List<Place> _places = [];
  String? _selectedCategory;
  int? _maxPriceLevel;
  Set<String> _selectedVibes = {};
  bool _isLoadingPlaces = true;
  bool _isSearchingCity = false;
  String? _placesError;

  List<Place> get _filteredPlaces {
    return _places.where((place) {
      if (_selectedCategory != null && place.category != _selectedCategory) {
        return false;
      }
      if (_maxPriceLevel != null && place.priceLevel > _maxPriceLevel!) {
        return false;
      }
      if (_selectedVibes.isNotEmpty &&
          !_selectedVibes.any(place.vibes.contains)) {
        return false;
      }
      return true;
    }).toList();
  }

  List<String> get _availableVibes {
    final vibes = _places.expand((place) => place.vibes).toSet().toList();
    vibes.sort();
    return vibes;
  }

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    setState(() {
      _isLoadingPlaces = true;
      _placesError = null;
    });

    try {
      final loadedPlaces = await widget.placeRepository.loadPlaces();
      if (!mounted) return;
      setState(() {
        _places = loadedPlaces;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _placesError = 'Impossibile caricare i locali.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingPlaces = false;
        });
      }
    }
  }

  Future<void> _searchCity(String city) async {
    final normalizedCity = city.trim();
    if (normalizedCity.isEmpty) {
      _showMessage('Inserisci il nome di una città.');
      return;
    }

    setState(() {
      _isSearchingCity = true;
    });

    try {
      final location = await widget.geocodingService.searchCity(normalizedCity);
      if (location == null) {
        _showMessage('Nessuna città trovata per “$normalizedCity”.');
        return;
      }

      _mapController.move(LatLng(location.latitude, location.longitude), 13);
    } on GeocodingException catch (error) {
      final message = switch (error.type) {
        GeocodingFailureType.timeout =>
          'La ricerca sta impiegando troppo tempo. Riprova.',
        GeocodingFailureType.network => 'Errore di rete durante la ricerca.',
        GeocodingFailureType.invalidResponse =>
          'La risposta della ricerca non è valida.',
      };
      _showMessage(message);
    } catch (_) {
      _showMessage('Impossibile completare la ricerca.');
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingCity = false;
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

  Widget _buildMapContent() {
    if (_isLoadingPlaces) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_placesError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_placesError!),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadPlaces,
              icon: const Icon(Icons.refresh),
              label: const Text('Riprova'),
            ),
          ],
        ),
      );
    }

    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: LatLng(40.7857, 17.2370),
        initialZoom: 14,
        maxZoom: MapConfig.maxZoom,
      ),
      children: [
        TileLayer(
          urlTemplate: MapConfig.tileUrl,
          subdomains: MapConfig.subdomains,
          errorTileCallback: (_, error, _) {
            final statusCode = error is NetworkImageLoadException
                ? ' HTTP ${error.statusCode}'
                : '';
            debugPrint(
              'Errore caricamento tile$statusCode (${error.runtimeType})',
            );
          },
        ),
        MarkerLayer(
          markers: _filteredPlaces.map((place) {
            return Marker(
              point: LatLng(place.lat, place.lng),
              width: 140,
              height: 50,
              child: PlaceMarker(
                place: place,
                onTap: () => showPlaceDetailsSheet(context, place),
              ),
            );
          }).toList(),
        ),
        const RichAttributionWidget(
          attributions: [
            TextSourceAttribution('OpenStreetMap contributors'),
            if (MapConfig.usesMapbox)
              TextSourceAttribution('Mapbox')
            else
              TextSourceAttribution('OpenTopoMap (CC-BY-SA)'),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildMapContent(),
          Positioned(
            top: 0,
            left: 12,
            right: 12,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GlassPanel(
                      child: TextField(
                        enabled: !_isSearchingCity,
                        style: const TextStyle(
                          color: Color(0xFF173F54),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Cerca città (es: Milano)',
                          hintStyle: const TextStyle(
                            color: Color(0xFF587789),
                            fontWeight: FontWeight.w500,
                          ),
                          border: InputBorder.none,
                          prefixIcon: const Icon(
                            Icons.location_on_rounded,
                            color: Color(0xFF205A78),
                            size: 21,
                          ),
                          suffixIcon: _isSearchingCity
                              ? const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: SizedBox.square(
                                    dimension: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.search_rounded,
                                  color: Color(0xFF205A78),
                                ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 11,
                          ),
                        ),
                        onSubmitted: _searchCity,
                      ),
                    ),
                    const SizedBox(height: 10),
                    MapFilters(
                      selectedCategory: _selectedCategory,
                      maxPriceLevel: _maxPriceLevel,
                      selectedVibes: _selectedVibes,
                      availableVibes: _availableVibes,
                      onCategoryChanged: (value) {
                        setState(() {
                          _selectedCategory = value;
                        });
                      },
                      onPriceChanged: (value) {
                        setState(() {
                          _maxPriceLevel = value;
                        });
                      },
                      onVibesChanged: (value) {
                        setState(() {
                          _selectedVibes = value;
                        });
                      },
                      onReset: () {
                        setState(() {
                          _selectedCategory = null;
                          _maxPriceLevel = null;
                          _selectedVibes = {};
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'zoomIn',
            mini: true,
            backgroundColor: Colors.white.withValues(alpha: 0.94),
            foregroundColor: const Color(0xFF137DB8),
            onPressed: () {
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom + 1,
              );
            },
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'zoomOut',
            mini: true,
            backgroundColor: Colors.white.withValues(alpha: 0.94),
            foregroundColor: const Color(0xFF137DB8),
            onPressed: () {
              _mapController.move(
                _mapController.camera.center,
                _mapController.camera.zoom - 1,
              );
            },
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}
