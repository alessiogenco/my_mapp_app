import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:my_map_app/config/map_config.dart';
import 'package:my_map_app/config/social_config.dart';
import 'package:my_map_app/data/place_repository.dart';
import 'package:my_map_app/data/want_to_go_repository.dart';
import 'package:my_map_app/models/place.dart';
import 'package:my_map_app/models/place_category.dart';
import 'package:my_map_app/models/want_to_go_place.dart';
import 'package:my_map_app/screens/account_page.dart';
import 'package:my_map_app/screens/add_place_page.dart';
import 'package:my_map_app/screens/friends_page.dart';
import 'package:my_map_app/screens/notifications_page.dart';
import 'package:my_map_app/screens/want_to_go_page.dart';
import 'package:my_map_app/services/device_location_service.dart';
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
  static const _markerBackgroundLayerId = 'my-locals-place-backgrounds';
  static const _badgeLayerId = 'my-locals-place-badges';
  static const _labelLayerId = 'my-locals-place-labels';
  static const _wantToGoLabelLayerId = 'my-locals-want-to-go-labels';
  static const _markerImagePrefix = 'my-locals-category-marker-';
  static const _wantToGoMarkerImageId = 'my-locals-want-to-go-marker';
  static const _defaultMarkerImageId = 'my-locals-default-marker';
  static const _labelImageId = 'my-locals-place-label';
  static const _wantToGoLabelImageId = 'my-locals-want-to-go-label';
  static const _userLocationSourceId = 'my-locals-user-location-source';
  static const _userLocationLayerId = 'my-locals-user-location-dot';

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
  String? _accountAvatarUrl;
  int _unreadNotificationCount = 0;
  bool _isLocatingUser = false;
  bool _isUserLocationVisible = false;
  DeviceLocation? _userLocation;

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
    _loadAccountAvatar();
    _loadNotificationState();
  }

  @override
  void dispose() {
    _viewportController.dispose();
    super.dispose();
  }

  Future<void> _loadAccountAvatar() async {
    if (!SocialConfig.isAvailable) return;
    final user = SocialConfig.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _accountAvatarUrl = null);
      return;
    }

    try {
      final profile = await SocialConfig.client
          .from('profiles')
          .select('avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      final metadata = user.userMetadata;
      final avatarUrl = (profile?['avatar_url'] as String?) ??
          (metadata?['avatar_url'] as String?) ??
          (metadata?['picture'] as String?);
      if (mounted) setState(() => _accountAvatarUrl = avatarUrl);
    } catch (_) {
      // The account entry point must still work when social data is unavailable.
    }
  }

  Future<void> _loadNotificationState() async {
    if (!SocialConfig.isAvailable) {
      if (mounted) setState(() => _unreadNotificationCount = 0);
      return;
    }

    final user = SocialConfig.client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _unreadNotificationCount = 0);
      return;
    }

    try {
      final profile = await SocialConfig.client
          .from('profiles')
          .select('notification_preference')
          .eq('id', user.id)
          .maybeSingle();
      final preference = profile?['notification_preference']?.toString();
      if (preference == 'off') {
        if (mounted) setState(() => _unreadNotificationCount = 0);
        return;
      }

      dynamic request = SocialConfig.client
          .from('app_notifications')
          .select('id')
          .eq('recipient_id', user.id)
          .isFilter('read_at', null);
      if (preference != 'all') {
        request = request.gte('importance', 2);
      }
      final rows = await request.limit(100);
      if (mounted) {
        setState(() => _unreadNotificationCount = (rows as List).length);
      }
    } catch (_) {
      // The bell stays usable even before the optional notification migration.
      if (mounted) setState(() => _unreadNotificationCount = 0);
    }
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
    mapboxMap.addInteraction(
      TapInteraction(
        FeaturesetDescriptor(layerId: _wantToGoLabelLayerId),
        _onMapFeatureTap,
      ),
      interactionID: 'my-locals-tap-want-to-go-label',
    );
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _mapboxMap;
    if (map == null) return;

    _isStyleReady = false;
    try {
      await map.setStyleImportConfigProperty(
        'basemap',
        'showPointOfInterestLabels',
        false,
      );
      await _addMarkerImages(map);
      await map.addSource(
        GeoJsonSource(id: _placesSourceId, data: _placesGeoJson()),
      );
      await map.addLayer(
        CircleLayer(
          id: _markerBackgroundLayerId,
          sourceId: _placesSourceId,
          slot: 'top',
          circleRadius: 22,
          circleColor: Colors.white.toARGB32(),
          circleStrokeWidth: 1.5,
          circleStrokeColorExpression: [
            'case',
            [
              '==',
              ['get', 'kind'],
              'want',
            ],
            '#F2C55A',
            '#D7E3E8',
          ],
        ),
      );
      await map.addLayer(
        SymbolLayer(
          id: _badgeLayerId,
          sourceId: _placesSourceId,
          slot: 'top',
          iconImageExpression: ['get', 'icon'],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
        ),
      );
      await map.addLayer(
        SymbolLayer(
          id: _labelLayerId,
          sourceId: _placesSourceId,
          slot: 'top',
          filter: const ['==', ['get', 'kind'], 'catalog'],
          minZoom: 11,
          iconImageExpression: ['get', 'labelIcon'],
          iconTextFit: IconTextFit.BOTH,
          iconTextFitPadding: const <double>[3, 8, 3, 8],
          iconOffset: const <double>[0, 1.1],
          textFieldExpression: ['get', 'name'],
          textSize: 12,
          textMaxWidth: 12,
          textAnchor: TextAnchor.TOP,
          textJustify: TextJustify.CENTER,
          textOffset: const <double>[0, 2.2],
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
          textAllowOverlap: false,
        ),
      );
      await map.addLayer(
        SymbolLayer(
          id: _wantToGoLabelLayerId,
          sourceId: _placesSourceId,
          slot: 'top',
          filter: const ['==', ['get', 'kind'], 'want'],
          iconImageExpression: ['get', 'labelIcon'],
          iconTextFit: IconTextFit.BOTH,
          iconTextFitPadding: const <double>[3, 8, 3, 8],
          iconOffset: const <double>[0, 1.1],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          textFieldExpression: ['get', 'name'],
          textSize: 12,
          textMaxWidth: 12,
          textAnchor: TextAnchor.TOP,
          textJustify: TextJustify.CENTER,
          textOffset: const <double>[0, 2.2],
          textColor: const Color(0xFF805400).toARGB32(),
          textAllowOverlap: true,
          textIgnorePlacement: true,
        ),
      );
      await _configureUserLocationLayer(map);
      _isStyleReady = true;
      await _updateMapFeatures();
    } catch (error) {
      debugPrint('Could not set up the Mapbox place layers: $error');
    }
  }

  Future<void> _addMarkerImages(MapboxMap map) async {
    for (final category in allowedPlaceCategories) {
      await _addAssetImage(
        map,
        _markerImageIdForCategory(category),
        _markerAssetPathForCategory(category),
      );
    }
    await _addAssetImage(
      map,
      _defaultMarkerImageId,
      'assets/markers/default.png',
    );
    await _addAssetImage(
      map,
      _wantToGoMarkerImageId,
      'assets/markers/want_to_go.png',
    );
    await map.addImage(
      _labelImageId,
      1,
      await _buildLabelImage(borderColor: const Color(0xFFD7E3E8)),
      stretchX: [ImageStretches(first: 8, second: 16)],
      stretchY: [ImageStretches(first: 8, second: 16)],
      content: ImageContent(left: 8, top: 4, right: 16, bottom: 20),
    );
    await map.addImage(
      _wantToGoLabelImageId,
      1,
      await _buildLabelImage(borderColor: const Color(0xFFF2C55A)),
      stretchX: [ImageStretches(first: 8, second: 16)],
      stretchY: [ImageStretches(first: 8, second: 16)],
      content: ImageContent(left: 8, top: 4, right: 16, bottom: 20),
    );
  }

  Future<void> _addAssetImage(
    MapboxMap map,
    String imageId,
    String assetPath,
  ) async {
    final byteData = await rootBundle.load(assetPath);
    await map.addImage(
      imageId,
      2,
      StyleImage.bytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      ),
    );
  }

  Future<StyleImage> _buildLabelImage({required Color borderColor}) async {
    const size = 24.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final bounds = Rect.fromLTWH(1, 1, size - 2, size - 2);
    final labelShape = RRect.fromRectAndRadius(
      bounds,
      const Radius.circular(8),
    );
    final path = Path()..addRRect(labelShape);

    canvas.drawShadow(path, const Color(0x240D2A3B), 3, false);
    canvas.drawRRect(labelShape, Paint()..color = Colors.white);
    canvas.drawRRect(
      labelShape,
      Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final image = await recorder
        .endRecording()
        .toImage(size.toInt(), size.toInt());
    try {
      return await StyleImage.fromImage(image);
    } finally {
      image.dispose();
    }
  }

  String _markerImageIdForCategory(String category) {
    if (!allowedPlaceCategories.contains(category)) {
      return _defaultMarkerImageId;
    }

    // Distinct IDs ensure Mapbox does not reuse retired category markers.
    return switch (category) {
      'chinese' => '${_markerImagePrefix}chinese-noodles',
      'ramen' => '${_markerImagePrefix}ramen-noodles',
      'kebab' => '${_markerImagePrefix}kebab-doner',
      _ => '$_markerImagePrefix$category',
    };
  }

  String _markerAssetPathForCategory(String category) {
    return switch (category) {
      'fish_and_chips' => 'assets/markers/fish_and_chips.png',
      'chinese' => 'assets/markers/chinese_noodles.png',
      'ramen' => 'assets/markers/chinese_noodles.png',
      'kebab' => 'assets/markers/turkish_doner.png',
      _ => 'assets/markers/$category.png',
    };
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

  Future<void> _goToMyLocation() async {
    if (_isLocatingUser) return;
    final map = _mapboxMap;
    if (map == null) {
      _showMessage('The map is still loading. Try again in a moment.');
      return;
    }

    setState(() => _isLocatingUser = true);
    try {
      if (!kIsWeb) {
        await map.location.updateSettings(
          LocationComponentSettings(
            enabled: true,
            pulsingEnabled: true,
            showAccuracyRing: true,
          ),
        );
        _viewportController.moveTo(
          FollowPuckViewportState(),
          transition: const DefaultViewportTransition(),
        );
        if (mounted) setState(() => _isUserLocationVisible = true);
        return;
      }

      final location = await getCurrentDeviceLocation();
      if (!mounted) return;
      setState(() {
        _userLocation = location;
        _isUserLocationVisible = true;
      });
      await _updateUserLocationFeature();
      _moveMapTo(location.latitude, location.longitude, 15);
    } on DeviceLocationException catch (error) {
      _showMessage(error.message);
    } catch (_) {
      _showMessage('Could not start location. Check browser or device permissions.');
    } finally {
      if (mounted) setState(() => _isLocatingUser = false);
    }
  }

  Future<void> _updateUserLocationFeature() async {
    final map = _mapboxMap;
    if (!_isStyleReady || map == null) return;

    try {
      await map.setStyleSourceProperty(
        _userLocationSourceId,
        'data',
        _userLocationGeoJson(),
      );
    } catch (error) {
      debugPrint('Could not update the user location marker: $error');
    }
  }

  String _userLocationGeoJson() {
    final location = _userLocation;
    if (location == null) {
      return jsonEncode({'type': 'FeatureCollection', 'features': const []});
    }

    return jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [location.longitude, location.latitude],
          },
          'properties': const <String, dynamic>{},
        },
      ],
    });
  }

  Future<void> _configureUserLocationLayer(MapboxMap map) async {
    await map.addSource(
      GeoJsonSource(id: _userLocationSourceId, data: _userLocationGeoJson()),
    );
    await map.addLayer(
      CircleLayer(
        id: _userLocationLayerId,
        sourceId: _userLocationSourceId,
        slot: 'top',
        circleRadius: 8,
        circleColor: const Color(0xFF2F80ED).toARGB32(),
        circleStrokeWidth: 3,
        circleStrokeColor: Colors.white.toARGB32(),
      ),
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
          icon: _markerImageIdForCategory(place.category),
          labelIcon: _labelImageId,
        ),
      for (final place in _visibleWantToGoPlaces)
        _mapFeature(
          featureId: featureId++,
          placeId: place.id,
          name: place.name,
          latitude: place.latitude!,
          longitude: place.longitude!,
          kind: 'want',
          icon: _wantToGoMarkerImageId,
          labelIcon: _wantToGoLabelImageId,
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
    required String icon,
    required String labelIcon,
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
        'icon': icon,
        'labelIcon': labelIcon,
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
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final citySearch = ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: mapToolbarMaxWidth,
                          ),
                          child: GlassPanel(
                            maxWidth: mapToolbarMaxWidth,
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
                        );
                        final accountAvatar = _MapAccountAvatar(
                          avatarUrl: _accountAvatarUrl,
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const AccountPage(),
                              ),
                            );
                            _loadAccountAvatar();
                            _loadNotificationState();
                          },
                        );
                        final accountControls = Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _MapNotificationBell(
                              unreadCount: _unreadNotificationCount,
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const NotificationsPage(),
                                  ),
                                );
                                _loadNotificationState();
                              },
                            ),
                            const SizedBox(width: 8),
                            accountAvatar,
                          ],
                        );

                        if (constraints.maxWidth >= 820) {
                          return SizedBox(
                            height: 54,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                citySearch,
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: accountControls,
                                ),
                              ],
                            ),
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: citySearch),
                            const SizedBox(width: 10),
                            accountControls,
                          ],
                        );
                      },
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
            heroTag: 'friends',
            mini: true,
            backgroundColor: Colors.white.withValues(alpha: 0.94),
            foregroundColor: const Color(0xFF137DB8),
            tooltip: 'Friends and affinity',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const FriendsPage(),
                ),
              );
            },
            child: const Icon(Icons.people_alt_outlined),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'addPlace',
            mini: true,
            backgroundColor: Colors.white.withValues(alpha: 0.94),
            foregroundColor: const Color(0xFF137DB8),
            tooltip: 'Add place',
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const AddPlacePage(),
                ),
              );
              if (!mounted) return;
              await _loadPlaces();
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
            heroTag: 'myLocation',
            mini: true,
            backgroundColor: _isUserLocationVisible
                ? const Color(0xFF137DB8)
                : Colors.white.withValues(alpha: 0.94),
            foregroundColor: _isUserLocationVisible
                ? Colors.white
                : const Color(0xFF137DB8),
            tooltip: 'My location',
            onPressed: _isLocatingUser ? null : _goToMyLocation,
            child: _isLocatingUser
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(
                    _isUserLocationVisible
                        ? Icons.my_location_rounded
                        : Icons.location_searching_rounded,
                  ),
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

class _MapNotificationBell extends StatelessWidget {
  const _MapNotificationBell({
    required this.unreadCount,
    required this.onPressed,
  });

  final int unreadCount;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final badgeLabel = unreadCount > 9 ? '9+' : unreadCount.toString();
    return Tooltip(
      message: 'Notifications',
      child: Material(
        color: Colors.white.withValues(alpha: 0.94),
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 50,
            height: 50,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF205A78),
                  size: 25,
                ),
                if (unreadCount > 0)
                  Positioned(
                    top: 6,
                    right: 5,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 17),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE55353),
                        border: Border.all(color: Colors.white, width: 1.5),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        badgeLabel,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapAccountAvatar extends StatelessWidget {
  const _MapAccountAvatar({required this.avatarUrl, required this.onPressed});

  final String? avatarUrl;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Tooltip(
      message: 'Account',
      child: Material(
        color: Colors.white.withValues(alpha: 0.94),
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: CircleAvatar(
              radius: 22,
              foregroundImage:
                  hasAvatar ? NetworkImage(avatarUrl!) : null,
              child: const Icon(Icons.person_outline_rounded),
            ),
          ),
        ),
      ),
    );
  }
}

String _normalizeCity(String value) {
  return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}
