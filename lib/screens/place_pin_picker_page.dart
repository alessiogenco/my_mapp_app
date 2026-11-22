import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:my_map_app/config/map_config.dart';

class PlacePin {
  const PlacePin({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// A temporary point chosen only to ask Google for nearby venues. The selected
/// point itself is not saved: the member must still select the real venue from
/// Google's returned list.
class PlacePinPickerPage extends StatefulWidget {
  const PlacePinPickerPage({
    required this.initialLatitude,
    required this.initialLongitude,
    super.key,
  });

  final double initialLatitude;
  final double initialLongitude;

  @override
  State<PlacePinPickerPage> createState() => _PlacePinPickerPageState();
}

class _PlacePinPickerPageState extends State<PlacePinPickerPage> {
  static const _pickedPointSourceId = 'my-locals-picked-place-source';
  static const _pickedPointHaloLayerId = 'my-locals-picked-place-halo';
  static const _pickedPointLayerId = 'my-locals-picked-place-point';

  MapboxMap? _mapboxMap;
  bool _isStyleReady = false;
  late double _selectedLatitude;
  late double _selectedLongitude;

  @override
  void initState() {
    super.initState();
    _selectedLatitude = widget.initialLatitude;
    _selectedLongitude = widget.initialLongitude;
  }

  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    unawaited(
      mapboxMap.scaleBar.updateSettings(ScaleBarSettings(enabled: false)),
    );
    mapboxMap.addInteraction(
      TapInteraction.onMap(_selectPointFromMap),
      interactionID: 'my-locals-pick-place-point',
    );
  }

  void _selectPointFromMap(MapContentGestureContext context) {
    final point = context.point.coordinates;
    setState(() {
      _selectedLatitude = point.lat.toDouble();
      _selectedLongitude = point.lng.toDouble();
    });
    unawaited(_updatePickedPoint());
  }

  Future<void> _onStyleLoaded(StyleLoadedEventData _) async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      // Match the clean Mapbox Standard basemap used by the main app map.
      await map.setStyleImportConfigProperty(
        'basemap',
        'showPointOfInterestLabels',
        false,
      );
      await map.addSource(
        GeoJsonSource(id: _pickedPointSourceId, data: _pickedPointGeoJson()),
      );
      await map.addLayer(
        CircleLayer(
          id: _pickedPointHaloLayerId,
          sourceId: _pickedPointSourceId,
          slot: 'top',
          circleRadius: 18,
          circleColor: const Color(0x332F80ED).toARGB32(),
          circleStrokeWidth: 2,
          circleStrokeColor: const Color(0xFF2F80ED).toARGB32(),
        ),
      );
      await map.addLayer(
        CircleLayer(
          id: _pickedPointLayerId,
          sourceId: _pickedPointSourceId,
          slot: 'top',
          circleRadius: 8,
          circleColor: const Color(0xFF2F80ED).toARGB32(),
          circleStrokeWidth: 3,
          circleStrokeColor: Colors.white.toARGB32(),
        ),
      );
      _isStyleReady = true;
    } catch (error) {
      debugPrint('Could not prepare the place picker map: $error');
    }
  }

  Future<void> _updatePickedPoint() async {
    final map = _mapboxMap;
    if (!_isStyleReady || map == null) return;

    try {
      await map.setStyleSourceProperty(
        _pickedPointSourceId,
        'data',
        _pickedPointGeoJson(),
      );
    } catch (error) {
      debugPrint('Could not move the selected place point: $error');
    }
  }

  String _pickedPointGeoJson() {
    return jsonEncode({
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [_selectedLongitude, _selectedLatitude],
          },
          'properties': const <String, dynamic>{},
        },
      ],
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose the area')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Text(
              'Tap the approximate location on the map. You will then choose the correct venue from a Google list.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: const Color(0xFF58717E)),
            ),
          ),
          Expanded(
            child: MapConfig.usesMapbox
                ? MapWidget(
                    styleUri: MapboxStyles.STANDARD,
                    viewport: CameraViewportState(
                      center: Point(
                        coordinates: Position(
                          _selectedLongitude,
                          _selectedLatitude,
                        ),
                      ),
                      zoom: 14,
                    ),
                    onMapCreated: _onMapCreated,
                    onStyleLoadedListener: _onStyleLoaded,
                    onMapLoadErrorListener: (error) {
                      debugPrint('Place picker map loading error: $error');
                    },
                  )
                : const Center(
                    child: Padding(
                      padding: EdgeInsets.all(28),
                      child: Text(
                        'Mapbox needs its local public token before you can choose a point.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(
                  PlacePin(
                    latitude: _selectedLatitude,
                    longitude: _selectedLongitude,
                  ),
                ),
                icon: const Icon(Icons.search_rounded),
                label: const Text('Show nearby places'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
