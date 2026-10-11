import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:my_map_app/config/map_config.dart';
import 'package:my_map_app/data/place_repository.dart';
import 'package:my_map_app/data/want_to_go_repository.dart';
import 'package:my_map_app/models/place.dart';
import 'package:my_map_app/models/want_to_go_place.dart';
import 'package:my_map_app/screens/add_place_page.dart';
import 'package:my_map_app/screens/want_to_go_page.dart';
import 'package:my_map_app/services/geocoding_service.dart';
import 'package:my_map_app/widgets/glass_panel.dart';
import 'package:my_map_app/widgets/map_filters.dart';
import 'package:my_map_app/widgets/place_details_sheet.dart';

class MapPage extends StatefulWidget {
  const MapPage({
    this.placeRepository = const PlaceRepository(),
    this.geocodingService = const GeocodingService(),
    this.wantToGoRepository = const WantToGoRepository(),
    super.key,
  });

  final PlaceRepository placeRepository;
  final GeocodingService geocodingService;
  final WantToGoRepository wantToGoRepository;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _placesSourceId = 'my-locals-places-source';
  static const _badgeLayerId = 'my-locals-place-badges';
  static const _badgeTextLayerId = 'my-locals-place-badge-text';
  static const _labelLayerId = 'my-locals-place-labels';

  final ViewportController _viewportController = ViewportController();
  MapboxMap? _mapboxMap;
  bool _isStyleReady = false;

  List<Place> _places = [];
  Set<String> _selectedCategories = {};
  RangeValues? _ratingRange;
  Set<int> _selectedPriceLevels = {};
  Set<String> _selectedVibes = {};
  Set<String> _wantToGoPlaceIds = {};
  List<WantToGoPlace> _placesToTry = [];
  bool _showOnlyWantToGo = false;
  Set<String> _selectedWantToGoCities = {};
  bool _isLoadingPlaces = true;
  bool _isSearchingCity = false;
  String? _placesError;

  List<Place> get _filteredPlaces {
    return _places.where((place) {
      if (_selectedCategories.isNotEmpty &&
          !_selectedCategories.contains(place.category)) {
        return false;
      }
      if (_ratingRange != null &&
          (place.rating < _ratingRange!.start.round() ||
              place.rating > _ratingRange!.end.round())) {
        return false;
      }
      if (_selectedPriceLevels.isNotEmpty &&
          !_selectedPriceLevels.contains(place.priceLevel)) {
        return false;
      }
      if (_selectedVibes.isNotEmpty &&
          !_selectedVibes.any(place.vibes.contains)) {
        return false;
      }
      if (_showOnlyWantToGo && !_wantToGoPlaceIds.contains(place.id)) {
        return false;
      }
      if (_showOnlyWantToGo &&
          _selectedWantToGoCities.isNotEmpty &&
          !_isSelectedWantToGoCity(place.city)) {
        return false;
      }
      return true;
    }).toList();
  }

  bool get _hasCatalogFilters {
    return _selectedCategories.isNotEmpty ||
        _ratingRange != null ||
        _selectedPriceLevels.isNotEmpty ||
        _selectedVibes.isNotEmpty;
  }

  List<WantToGoPlace> get _visibleWantToGoPlaces {
    if (!_showOnlyWantToGo || _hasCatalogFilters) return const [];
    return _placesToTry
        .where(
          (place) =>
              place.isVisibleOnMap &&
              (_selectedWantToGoCities.isEmpty ||
                  _isSelectedWantToGoCity(place.city)),
        )
        .toList();
  }

  List<String> get _availableWantToGoCities {
    final citiesByNormalizedName = <String, String>{};

    void addCity(String city) {
      final normalizedCity = _normalizeCity(city);
      if (normalizedCity.isEmpty) return;
      citiesByNormalizedName.putIfAbsent(normalizedCity, () => city.trim());
    }

    for (final place in _placesToTry.where((place) => place.isVisibleOnMap)) {
      addCity(place.city);
    }
    for (final place in _places.where(
      (place) => _wantToGoPlaceIds.contains(place.id),
    )) {
      addCity(place.city);
    }

    final cities = citiesByNormalizedName.values.toList();
    cities.sort(
      (first, second) => first.toLowerCase().compareTo(second.toLowerCase()),
    );
    return cities;
  }

  bool _isSelectedWantToGoCity(String city) {
    final normalizedCity = _normalizeCity(city);
    return _selectedWantToGoCities.any(
      (selectedCity) => _normalizeCity(selectedCity) == normalizedCity,
    );
  }

  void _focusWantToGoCity(String city) {
    final normalizedCity = _normalizeCity(city);
    final latitudes = <double>[
      ..._placesToTry
          .where(
            (place) =>
                place.isVisibleOnMap &&
                _normalizeCity(place.city) == normalizedCity,
          )
          .map((place) => place.latitude!),
      ..._places
          .where(
            (place) =>
                _wantToGoPlaceIds.contains(place.id) &&
                _normalizeCity(place.city) == normalizedCity,
          )
          .map((place) => place.lat),
    ];
    final longitudes = <double>[
      ..._placesToTry
          .where(
            (place) =>
                place.isVisibleOnMap &&
                _normalizeCity(place.city) == normalizedCity,
          )
          .map((place) => place.longitude!),
      ..._places
          .where(
            (place) =>
                _wantToGoPlaceIds.contains(place.id) &&
                _normalizeCity(place.city) == normalizedCity,
          )
          .map((place) => place.lng),
    ];
    if (latitudes.isEmpty) return;

    final latitude = latitudes.reduce((sum, value) => sum + value) /
        latitudes.length;
    final longitude = longitudes.reduce((sum, value) => sum + value) /
        longitudes.length;
    _moveMapTo(latitude, longitude, latitudes.length == 1 ? 15 : 13);
  }

  List<String> get _availableVibes {
    final vibes = _places.expand((place) => place.vibes).toSet().toList();
    vibes.sort();
    return vibes;
  }

  List<int> get _availableRatings {
    final ratings = _places.map((place) => place.rating).toSet().toList();
    ratings.sort((first, second) => second.compareTo(first));
    return ratings;
  }

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    _loadWantToGo();
  }

  @override
  void dispose() {
    _viewportController.dispose();
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
      _refreshMapFeatures();
    } on FormatException catch (error) {
      if (!mounted) return;
      setState(() {
        _placesError = error.message;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _placesError = 'Could not load places: $error';
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
      _showMessage('Enter a city name.');
      return;
    }

    setState(() {
      _isSearchingCity = true;
    });

    try {
      final location = await widget.geocodingService.searchCity(normalizedCity);
      if (location == null) {
        _showMessage('No city found for “$normalizedCity”.');
        return;
      }

      _moveMapTo(location.latitude, location.longitude, 13);
    } on GeocodingException catch (error) {
      final message = switch (error.type) {
        GeocodingFailureType.timeout =>
          'The search is taking too long. Try again.',
        GeocodingFailureType.network => 'Network error while searching.',
        GeocodingFailureType.invalidResponse =>
          'The search response is not valid.',
      };
      _showMessage(message);
    } catch (_) {
      _showMessage('Could not complete the search.');
    } finally {
      if (mounted) {
        setState(() {
          _isSearchingCity = false;
        });
      }
    }
  }

  Future<void> _loadWantToGo() async {
    try {
      final data = await widget.wantToGoRepository.load();
      if (!mounted) return;
      setState(() {
        _wantToGoPlaceIds = data.mappedPlaceIds;
        _placesToTry = data.places;
      });
      _refreshMapFeatures();
    } catch (_) {
      debugPrint('Could not load Want to go data.');
    }
  }

  Future<void> _saveWantToGo() async {
    try {
      await widget.wantToGoRepository.save(
        WantToGoData(
          mappedPlaceIds: _wantToGoPlaceIds,
          places: _placesToTry,
        ),
      );
    } catch (_) {
      _showMessage('Could not save your Want to go list. Try again.');
    }
  }

  Future<void> _openWantToGo() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => WantToGoPage(
          mappedPlaces: _places,
          repository: widget.wantToGoRepository,
        ),
      ),
    );
    await _loadWantToGo();
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _setPlaceWantToGo(Place place, bool isWantToGo) {
    setState(() {
      if (isWantToGo) {
        _wantToGoPlaceIds = {..._wantToGoPlaceIds, place.id};
      } else {
        _wantToGoPlaceIds = _wantToGoPlaceIds
            .where((id) => id != place.id)
            .toSet();
        if (_wantToGoPlaceIds.isEmpty) {
          _showOnlyWantToGo = false;
        }
      }
    });
    _refreshMapFeatures();

    _showMessage(
      isWantToGo
          ? 'Added to your Want to go list.'
          : 'Removed from your Want to go list.',
    );
    unawaited(_saveWantToGo());
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    unawaited(
      mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false)),
    );
    mapboxMap.addInteraction(
      TapInteraction(
        FeaturesetDescriptor(layerId: _badgeLayerId),
        _onMapFeatureTap,
      ),
      interactionID: 'my-locals-tap-badge',
    );
    mapboxMap.addInteraction(
      TapInteraction(
        FeaturesetDescriptor(layerId: _labelLayerId),
        _onMapFeatureTap,
      ),
      interactionID: 'my-locals-tap-label',
    );
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _mapboxMap;
    if (map == null) return;

    _isStyleReady = false;
    try {
      await map.addSource(
        GeoJsonSource(id: _placesSourceId, data: _placesGeoJson()),
      );
      await map.addLayer(
        CircleLayer(
          id: _badgeLayerId,
          sourceId: _placesSourceId,
          slot: 'top',
          circleRadius: 17,
          circleColorExpression: [
            'case',
            [
              '==',
              ['get', 'kind'],
              'want',
            ],
            '#FFF6DA',
            '#FFFFFF',
          ],
          circleStrokeWidth: 2.5,
          circleStrokeColorExpression: [
            'case',
            [
              '==',
              ['get', 'kind'],
              'want',
            ],
            '#E5AD28',
            '#197EAF',
          ],
        ),
      );
      await map.addLayer(
        SymbolLayer(
          id: _badgeTextLayerId,
          sourceId: _placesSourceId,
          slot: 'top',
          textFieldExpression: ['get', 'badge'],
          textSize: 11,
          textAnchor: TextAnchor.CENTER,
          textJustify: TextJustify.CENTER,
          textColor: const Color(0xFF12374D).toARGB32(),
          textAllowOverlap: true,
          textIgnorePlacement: true,
        ),
      );
      await map.addLayer(
        SymbolLayer(
          id: _labelLayerId,
          sourceId: _placesSourceId,
          slot: 'top',
          minZoom: 11,
          textFieldExpression: ['get', 'name'],
          textSize: 12,
          textMaxWidth: 12,
          textAnchor: TextAnchor.TOP,
          textJustify: TextJustify.CENTER,
          textOffset: const [0, 1.65],
          textColorExpression: [
            'case',
            [
              '==',
              ['get', 'kind'],
              'want',
            ],
            '#805400',
            '#0B2E41',
          ],
          textHaloColor: Colors.white.toARGB32(),
          textHaloWidth: 2.4,
          textAllowOverlap: false,
        ),
      );
      _isStyleReady = true;
      await _updateMapFeatures();
    } catch (error) {
      debugPrint('Could not set up the Mapbox place layers: $error');
    }
  }

  void _onMapFeatureTap(
    TypedFeaturesetFeature<FeaturesetDescriptor> feature,
    MapContentGestureContext _,
  ) {
    final kind = feature.properties['kind'];
    final placeId = feature.properties['placeId'];
    if (kind is! String || placeId is! String) return;

    if (kind == 'want') {
      unawaited(_openWantToGo());
      return;
    }

    Place? selectedPlace;
    for (final place in _places) {
      if (place.id == placeId) {
        selectedPlace = place;
        break;
      }
    }
    if (selectedPlace == null) return;

    final place = selectedPlace;
    showPlaceDetailsSheet(
      context,
      place,
      isWantToGo: _wantToGoPlaceIds.contains(place.id),
      onWantToGoChanged: (isWantToGo) => _setPlaceWantToGo(place, isWantToGo),
    );
  }

  void _moveMapTo(
    double latitude,
    double longitude,
    double zoom, {
    bool animated = true,
  }) {
    _viewportController.moveTo(
      CameraViewportState(
        center: Point(coordinates: Position(longitude, latitude)),
        zoom: zoom,
      ),
      transition: animated ? const DefaultViewportTransition() : null,
    );
  }

  Future<void> _adjustZoom(double delta) async {
    final map = _mapboxMap;
    if (map == null) return;

    final camera = await map.getCameraState();
    _moveMapTo(
      camera.center.coordinates.lat.toDouble(),
      camera.center.coordinates.lng.toDouble(),
      (camera.zoom + delta).clamp(1, 22).toDouble(),
      animated: false,
    );
  }

  void _refreshMapFeatures() {
    unawaited(_updateMapFeatures());
  }

  Future<void> _updateMapFeatures() async {
    final map = _mapboxMap;
    if (!_isStyleReady || map == null) return;

    try {
      await map.setStyleSourceProperty(
        _placesSourceId,
        'data',
        _placesGeoJson(),
      );
    } catch (error) {
      debugPrint('Could not update Mapbox places: $error');
    }
  }

  String _placesGeoJson() {
    var featureId = 0;
    final features = <Map<String, dynamic>>[
      for (final place in _filteredPlaces)
        _mapFeature(
          featureId: featureId++,
          placeId: place.id,
          name: place.name,
          latitude: place.lat,
          longitude: place.lng,
          kind: 'catalog',
          badge: '★ ${place.rating}',
        ),
      for (final place in _visibleWantToGoPlaces)
        _mapFeature(
          featureId: featureId++,
          placeId: place.id,
          name: place.name,
          latitude: place.latitude!,
          longitude: place.longitude!,
          kind: 'want',
          badge: '⚑',
        ),
    ];

    return jsonEncode({'type': 'FeatureCollection', 'features': features});
  }

  Map<String, dynamic> _mapFeature({
    required int featureId,
    required String placeId,
    required String name,
    required double latitude,
    required double longitude,
    required String kind,
    required String badge,
  }) {
    return {
      'type': 'Feature',
      'id': featureId,
      'geometry': {
        'type': 'Point',
        'coordinates': [longitude, latitude],
      },
      'properties': {
        'placeId': placeId,
        'name': name,
        'kind': kind,
        'badge': badge,
      },
    };
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                _placesError!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFF102F40),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadPlaces,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (!MapConfig.usesMapbox) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Text(
            'Mapbox needs its local public token. Start the app with '
            'the project run script or its local mapbox.env.json file.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Color(0xFF102F40),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      );
    }

    return MapWidget(
      styleUri: MapboxStyles.STANDARD,
      viewport: CameraViewportState(
        center: Point(coordinates: Position(17.2370, 40.7857)),
        zoom: 14,
      ),
      viewportController: _viewportController,
      onMapCreated: _onMapCreated,
      onStyleLoadedListener: _onStyleLoaded,
      onMapLoadErrorListener: (error) {
        debugPrint('Mapbox map loading error: $error');
      },
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
                          hintText: 'Search city (e.g. Milan)',
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
                      selectedCategories: _selectedCategories,
                      ratingRange: _ratingRange,
                      selectedPriceLevels: _selectedPriceLevels,
                      selectedVibes: _selectedVibes,
                      availableVibes: _availableVibes,
                      availableRatings: _availableRatings,
                      showOnlyWantToGo: _showOnlyWantToGo,
                      selectedWantToGoCities: _selectedWantToGoCities,
                      availableWantToGoCities: _availableWantToGoCities,
                      wantToGoCount:
                          _wantToGoPlaceIds.length +
                          _placesToTry
                              .where((place) => place.isVisibleOnMap)
                              .length,
                      onCategoriesChanged: (value) {
                        setState(() {
                          _selectedCategories = value;
                        });
                        _refreshMapFeatures();
                      },
                      onRatingRangeChanged: (value) {
                        setState(() {
                          _ratingRange = value;
                        });
                        _refreshMapFeatures();
                      },
                      onPriceLevelsChanged: (value) {
                        setState(() {
                          _selectedPriceLevels = value;
                        });
                        _refreshMapFeatures();
                      },
                      onVibesChanged: (value) {
                        setState(() {
                          _selectedVibes = value;
                        });
                        _refreshMapFeatures();
                      },
                      onWantToGoOnlyChanged: (value) {
                        setState(() {
                          _showOnlyWantToGo = value;
                          if (!value) {
                            _selectedWantToGoCities = {};
                          }
                        });
                        _refreshMapFeatures();
                      },
                      onWantToGoCitiesChanged: (value) {
                        setState(() {
                          _selectedWantToGoCities = value;
                          _showOnlyWantToGo = true;
                        });
                        _refreshMapFeatures();
                        if (value.length == 1) {
                          _focusWantToGoCity(value.single);
                        }
                      },
                      onReset: () {
                        setState(() {
                          _selectedCategories = {};
                          _ratingRange = null;
                          _selectedPriceLevels = {};
                          _selectedVibes = {};
                          _showOnlyWantToGo = false;
                          _selectedWantToGoCities = {};
                        });
                        _refreshMapFeatures();
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
            heroTag: 'addPlace',
            mini: true,
            backgroundColor: Colors.white.withValues(alpha: 0.94),
            foregroundColor: const Color(0xFF137DB8),
            tooltip: 'Add place',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AddPlacePage(),
                ),
              );
            },
            child: const Icon(Icons.edit_location_alt_rounded),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'wantToGo',
            mini: true,
            backgroundColor: Colors.white.withValues(alpha: 0.94),
            foregroundColor: const Color(0xFF137DB8),
            tooltip: 'Want to go list',
            onPressed: _openWantToGo,
            child: const Icon(Icons.explore_outlined),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'zoomIn',
            mini: true,
            backgroundColor: Colors.white.withValues(alpha: 0.94),
            foregroundColor: const Color(0xFF137DB8),
            onPressed: () => _adjustZoom(1),
            child: const Icon(Icons.add),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'zoomOut',
            mini: true,
            backgroundColor: Colors.white.withValues(alpha: 0.94),
            foregroundColor: const Color(0xFF137DB8),
            onPressed: () => _adjustZoom(-1),
            child: const Icon(Icons.remove),
          ),
        ],
      ),
    );
  }
}

String _normalizeCity(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
