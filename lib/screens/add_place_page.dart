import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:my_map_app/models/place.dart';
import 'package:my_map_app/models/place_area.dart';
import 'package:my_map_app/models/place_category.dart';

class AddPlacePage extends StatefulWidget {
  const AddPlacePage({super.key});

  @override
  State<AddPlacePage> createState() => _AddPlacePageState();
}

class _AddPlacePageState extends State<AddPlacePage> {
  final _formKey = GlobalKey<FormState>();
  final _idController = TextEditingController();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController(text: 'Alberobello');
  final _countryCodeController = TextEditingController(text: 'IT');
  final _currencyCodeController = TextEditingController(text: 'EUR');
  final _neighborhoodController = TextEditingController();
  final _latController = TextEditingController();
  final _lngController = TextEditingController();
  final _customVibeController = TextEditingController();
  final _notesController = TextEditingController();
  final _websiteUrlController = TextEditingController();
  final _instagramUrlController = TextEditingController();
  final _googleMapsUrlController = TextEditingController();
  final _googlePlaceIdController = TextEditingController();
  final _photoAssetController = TextEditingController();
  final _foodTagsController = TextEditingController();

  String _category = 'restaurant';
  String _area = 'cityCentre';
  int _rating = 7;
  int _priceLevel = 2;
  int _foodRating = 0;
  int _locationRating = 0;
  int _serviceRating = 0;
  int _valueRating = 0;
  final Set<String> _selectedVibes = {};
  List<Place> _existingPlaces = [];
  final List<Place> _draftPlaces = [];
  String? _editingPlaceId;
  String? _generatedJson;
  String? _exportJson;
  bool _isLoadingExistingPlaces = false;
  bool _isSavingToProject = false;
  bool _idWasEdited = false;
  bool _isAutoGeneratingId = false;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(_updateIdFromName);
    _idController.addListener(() {
      if (_isAutoGeneratingId) {
        return;
      }

      if (_idController.text.isNotEmpty) {
        _idWasEdited = true;
      }
    });
    _loadExistingPlacesFromWriter(showErrors: false);
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _cityController.dispose();
    _countryCodeController.dispose();
    _currencyCodeController.dispose();
    _neighborhoodController.dispose();
    _latController.dispose();
    _lngController.dispose();
    _customVibeController.dispose();
    _notesController.dispose();
    _websiteUrlController.dispose();
    _instagramUrlController.dispose();
    _googleMapsUrlController.dispose();
    _googlePlaceIdController.dispose();
    _photoAssetController.dispose();
    _foodTagsController.dispose();
    super.dispose();
  }

  void _updateIdFromName() {
    if (_idWasEdited) {
      return;
    }

    final generatedId = _slugify(_nameController.text);
    if (_idController.text != generatedId) {
      _isAutoGeneratingId = true;
      _idController.text = generatedId;
      _isAutoGeneratingId = false;
    }
  }

  bool get _isEditingExistingPlace => _editingPlaceId != null;

  Place? _buildPlaceFromForm() {
    if (!_formKey.currentState!.validate()) {
      return null;
    }

    if (_selectedVibes.isEmpty) {
      _showSnackBar('Select or add at least one vibe.');
      return null;
    }

    return Place(
      id: _idController.text.trim(),
      name: _nameController.text.trim(),
      city: _cityController.text.trim(),
      countryCode: _countryCodeController.text.trim().toUpperCase(),
      currencyCode: _currencyCodeController.text.trim().toUpperCase(),
      category: _category,
      area: _area,
      neighborhood: _optionalText(_neighborhoodController),
      lat: double.parse(_latController.text.trim()),
      lng: double.parse(_lngController.text.trim()),
      rating: _rating,
      priceLevel: _priceLevel,
      foodTags: _parseTags(_foodTagsController.text),
      ratingDetails: _buildRatingDetails(),
      vibes: _selectedVibes.toList()..sort(),
      notes: _notesController.text.trim(),
      websiteUrl: _optionalText(_websiteUrlController),
      instagramUrl: _optionalText(_instagramUrlController),
      googleMapsUrl: _optionalText(_googleMapsUrlController),
      googlePlaceId: _optionalText(_googlePlaceIdController),
      photoAsset: _optionalText(_photoAssetController),
    );
  }

  void _generateJson() {
    final place = _buildPlaceFromForm();
    if (place == null) {
      return;
    }

    setState(() {
      _generatedJson = const JsonEncoder.withIndent('  ').convert(
        place.toJson(),
      );
    });
  }

  void _addCurrentPlaceToDrafts() {
    final place = _buildPlaceFromForm();
    if (place == null) {
      return;
    }

    final existingIndex = _draftPlaces.indexWhere(
      (draftPlace) => draftPlace.id == place.id,
    );

    setState(() {
      if (existingIndex >= 0) {
        _draftPlaces[existingIndex] = place;
      } else {
        _draftPlaces.add(place);
      }
      _generatedJson = const JsonEncoder.withIndent('  ').convert(
        place.toJson(),
      );
      _exportJson = _buildExportJson();
    });

    _clearFormForNextPlace();

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            existingIndex >= 0
                ? 'Draft place updated.'
                : 'Draft place added.',
          ),
        ),
      );
  }

  void _clearDraftPlaces() {
    setState(() {
      _draftPlaces.clear();
      _exportJson = null;
    });
  }

  void _clearFormForNextPlace() {
    _idWasEdited = false;
    _isAutoGeneratingId = true;
    _idController.clear();
    _isAutoGeneratingId = false;
    _nameController.clear();
    _neighborhoodController.clear();
    _latController.clear();
    _lngController.clear();
    _customVibeController.clear();
    _notesController.clear();
    _websiteUrlController.clear();
    _instagramUrlController.clear();
    _googleMapsUrlController.clear();
    _googlePlaceIdController.clear();
    _photoAssetController.clear();
    _foodTagsController.clear();
    setState(() {
      _selectedVibes.clear();
      _editingPlaceId = null;
      _foodRating = 0;
      _locationRating = 0;
      _serviceRating = 0;
      _valueRating = 0;
    });
  }

  void _loadPlaceIntoForm(Place place) {
    _idWasEdited = true;
    _isAutoGeneratingId = true;
    _idController.text = place.id;
    _isAutoGeneratingId = false;
    _nameController.text = place.name;
    _cityController.text = place.city;
    _countryCodeController.text = place.countryCode;
    _currencyCodeController.text = place.currencyCode;
    _neighborhoodController.text = place.neighborhood ?? '';
    _latController.text = place.lat.toString();
    _lngController.text = place.lng.toString();
    _notesController.text = place.notes;
    _websiteUrlController.text = place.websiteUrl ?? '';
    _instagramUrlController.text = place.instagramUrl ?? '';
    _googleMapsUrlController.text = place.googleMapsUrl ?? '';
    _googlePlaceIdController.text = place.googlePlaceId ?? '';
    _photoAssetController.text = place.photoAsset ?? '';
    _foodTagsController.text = place.foodTags.join(', ');

    setState(() {
      _editingPlaceId = place.id;
      _category = isKnownPlaceCategory(place.category)
          ? place.category
          : 'restaurant';
      _area = isKnownPlaceArea(place.area) ? place.area : 'cityCentre';
      _rating = place.rating;
      _priceLevel = place.priceLevel;
      _foodRating = place.ratingDetails['food'] ?? 0;
      _locationRating = place.ratingDetails['location'] ?? 0;
      _serviceRating = place.ratingDetails['service'] ?? 0;
      _valueRating = place.ratingDetails['value'] ?? 0;
      _selectedVibes
        ..clear()
        ..addAll(place.vibes);
      _generatedJson = const JsonEncoder.withIndent('  ').convert(
        place.toJson(),
      );
    });
  }

  void _startNewPlace() {
    _clearFormForNextPlace();
    setState(() {
      _generatedJson = null;
    });
  }

  String _buildExportJson() {
    return const JsonEncoder.withIndent('  ').convert(
      _draftPlaces.map((place) => place.toJson()).toList(),
    );
  }

  Future<void> _copyJson() async {
    final json = _generatedJson;
    if (json == null) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('JSON copied.')));
  }

  Future<void> _copyExportJson() async {
    final json = _exportJson;
    if (json == null) {
      return;
    }

    await Clipboard.setData(ClipboardData(text: json));
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Export JSON copied.')));
  }

  Future<void> _loadExistingPlacesFromWriter({bool showErrors = true}) async {
    setState(() {
      _isLoadingExistingPlaces = true;
    });

    try {
      final response = await http.get(
        Uri.parse('http://127.0.0.1:8787/places'),
      );

      if (response.statusCode != 200) {
        if (showErrors) {
          _showSnackBar('Could not load existing places.');
        }
        return;
      }

      final decodedBody = jsonDecode(response.body);
      if (decodedBody is! List) {
        if (showErrors) {
          _showSnackBar('The writer returned an invalid places list.');
        }
        return;
      }

      final places = decodedBody
          .whereType<Map<String, dynamic>>()
          .map(Place.fromJson)
          .toList()
        ..sort((a, b) => a.name.compareTo(b.name));

      if (!mounted) {
        return;
      }

      setState(() {
        _existingPlaces = places;
      });

      if (showErrors) {
        _showSnackBar('Loaded ${places.length} existing places.');
      }
    } catch (_) {
      if (showErrors) {
        _showSnackBar(
          'Could not reach the local writer. Start it with: '
          'dart run tool/place_writer_server.dart',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingExistingPlaces = false;
        });
      }
    }
  }

  void _addCustomVibe() {
    final vibe = _normalizeVibe(_customVibeController.text);
    if (vibe.isEmpty) {
      return;
    }

    setState(() {
      _selectedVibes.add(vibe);
      _customVibeController.clear();
    });
  }

  void _extractCoordinatesFromGoogleMapsUrl() {
    final mapsUrl = _googleMapsUrlController.text.trim();
    if (mapsUrl.isEmpty) {
      _showSnackBar('Paste a Google Maps link first.');
      return;
    }

    final decodedUrl = Uri.decodeFull(mapsUrl);
    final coordinatePatterns = [
      RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)'),
      RegExp(r'[?&](?:q|query)=(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'),
      RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'),
    ];

    RegExpMatch? match;
    for (final pattern in coordinatePatterns) {
      match = pattern.firstMatch(decodedUrl);
      if (match != null) {
        break;
      }
    }

    if (match == null) {
      _showSnackBar(
        'No coordinates found. Use the expanded Google Maps web link or fill them manually.',
      );
      return;
    }

    final latitude = double.tryParse(match.group(1)!);
    final longitude = double.tryParse(match.group(2)!);
    if (latitude == null ||
        longitude == null ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180) {
      _showSnackBar('The coordinates in this link are not valid.');
      return;
    }

    _latController.text = latitude.toString();
    _lngController.text = longitude.toString();
    _showSnackBar('Coordinates added from the Google Maps link.');
  }

  Map<String, int> _buildRatingDetails() {
    return {
      if (_foodRating > 0) 'food': _foodRating,
      if (_locationRating > 0) 'location': _locationRating,
      if (_serviceRating > 0) 'service': _serviceRating,
      if (_valueRating > 0) 'value': _valueRating,
    };
  }

  List<String> get _suggestedVibes {
    final suggestions = _vibeSuggestionsByCategory[_category] ?? const [];
    return suggestions
        .where((vibe) => !_selectedVibes.contains(vibe))
        .toList();
  }

  List<String> get _availableVibes {
    final dynamicVibes = {
      ..._defaultVibes,
      ..._existingPlaces.expand((place) => place.vibes),
      ..._selectedVibes,
      ...(_vibeSuggestionsByCategory[_category] ?? const <String>[]),
    }.map(_normalizeVibe).where((vibe) => vibe.isNotEmpty).toList()
      ..sort();

    return dynamicVibes;
  }

  Future<void> _showVibePicker() {
    final localSelection = _selectedVibes.toSet();
    final vibeOptions = _availableVibes.toList()..sort();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              top: false,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.72,
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          width: 44,
                          height: 5,
                          decoration: BoxDecoration(
                            color: const Color(0xFF9CB8C7),
                            borderRadius: BorderRadius.circular(5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Choose vibes',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      const Text('Select existing tags, then tap Done.'),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 9,
                        runSpacing: 9,
                        children: vibeOptions.map((vibe) {
                          return FilterChip(
                            selected: localSelection.contains(vibe),
                            label: Text(_displayVibe(vibe)),
                            onSelected: (isSelected) {
                              setSheetState(() {
                                if (isSelected) {
                                  localSelection.add(vibe);
                                } else {
                                  localSelection.remove(vibe);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _selectedVibes
                                ..clear()
                                ..addAll(localSelection);
                            });
                            Navigator.pop(sheetContext);
                          },
                          child: const Text('Done'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveCurrentPlaceToProjectJson() async {
    final place = _buildPlaceFromForm();
    if (place == null) {
      return;
    }

    setState(() {
      _isSavingToProject = true;
    });

    try {
      final uri = _isEditingExistingPlace
          ? Uri.parse(
              'http://127.0.0.1:8787/places/'
              '${Uri.encodeComponent(_editingPlaceId!)}',
            )
          : Uri.parse('http://127.0.0.1:8787/places');
      final response = _isEditingExistingPlace
          ? await http.put(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(place.toJson()),
            )
          : await http.post(
              uri,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(place.toJson()),
            );

      final responseBody = jsonDecode(response.body);
      if (response.statusCode != 200) {
        final message = responseBody is Map<String, dynamic>
            ? responseBody['error']?.toString()
            : null;
        _showSnackBar(message ?? 'Could not save place.');
        return;
      }

      setState(() {
        _generatedJson = const JsonEncoder.withIndent('  ').convert(
          place.toJson(),
        );
      });
      await _loadExistingPlacesFromWriter(showErrors: false);
      if (_isEditingExistingPlace) {
        setState(() {
          _editingPlaceId = place.id;
        });
        _showSnackBar('Updated in assets/data/places.json.');
      } else {
        _clearFormForNextPlace();
        _showSnackBar('Saved to assets/data/places.json.');
      }
    } catch (_) {
      _showSnackBar(
        'Could not reach the local writer. Start it with: '
        'dart run tool/place_writer_server.dart',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSavingToProject = false;
        });
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final categoryOptions = allowedPlaceCategories.toList()..sort();
    final areaOptions = allowedPlaceAreas.toList()..sort();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add place'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [
            Text(
              'Fast entry: fill the main fields and save directly. The ID is '
              'generated automatically; optional and technical fields are '
              'kept below.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF58717E),
              ),
            ),
            const SizedBox(height: 18),
            _ExistingPlaceEditor(
              places: _existingPlaces,
              selectedPlaceId: _editingPlaceId,
              isLoading: _isLoadingExistingPlaces,
              onRefresh: () => _loadExistingPlacesFromWriter(),
              onSelected: (placeId) {
                Place? place;
                for (final existingPlace in _existingPlaces) {
                  if (existingPlace.id == placeId) {
                    place = existingPlace;
                    break;
                  }
                }
                if (place != null) {
                  _loadPlaceIntoForm(place);
                }
              },
              onNewPlace: _startNewPlace,
            ),
            const SizedBox(height: 18),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _TextInput(
                    controller: _nameController,
                    label: 'Name',
                    validator: _required,
                  ),
                  _TextInput(
                    controller: _cityController,
                    label: 'City',
                    validator: _required,
                  ),
                  _TextInput(
                    controller: _countryCodeController,
                    label: 'Country code',
                    helperText: 'Two letters: IT, GB, NO, ES…',
                    validator: _validateCountryCode,
                  ),
                  _TextInput(
                    controller: _currencyCodeController,
                    label: 'Currency',
                    helperText: 'Three letters: EUR, GBP, NOK…',
                    validator: _validateCurrencyCode,
                  ),
                  _TextInput(
                    controller: _googleMapsUrlController,
                    label: 'Google Maps URL',
                    helperText:
                        'Optional. A Google Maps search opens automatically from name and city; a full link can fill coordinates.',
                    validator: _validateOptionalUrl,
                  ),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _extractCoordinatesFromGoogleMapsUrl,
                      icon: const Icon(Icons.my_location_rounded),
                      label: const Text('Extract coordinates from link'),
                    ),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: categoryOptions.map((category) {
                      return DropdownMenuItem(
                        value: category,
                        child: Text(
                          '${labelForCategory(category)} · $category',
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _category = value);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _area,
                    decoration: const InputDecoration(labelText: 'Area'),
                    items: areaOptions.map((area) {
                      return DropdownMenuItem(
                        value: area,
                        child: Text(labelForArea(area)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _area = value);
                      }
                    },
                  ),
                  _TextInput(
                    controller: _latController,
                    label: 'Latitude',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: _validateLatitude,
                  ),
                  _TextInput(
                    controller: _lngController,
                    label: 'Longitude',
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                      signed: true,
                    ),
                    validator: _validateLongitude,
                  ),
                  _NumberStepper(
                    label: 'Rating',
                    value: _rating,
                    min: 0,
                    max: 10,
                    suffix: '/10',
                    onChanged: (value) => setState(() => _rating = value),
                  ),
                  _NumberStepper(
                    label: 'Price level (${_currencyCodeController.text.trim().toUpperCase()})',
                    value: _priceLevel,
                    min: 1,
                    max: 5,
                    suffix: '€',
                    onChanged: (value) => setState(() => _priceLevel = value),
                  ),
                  _VibeSelector(
                    selectedVibes: _selectedVibes,
                    suggestedVibes: _suggestedVibes,
                    customVibeController: _customVibeController,
                    onChooseVibes: _showVibePicker,
                    onAddSuggestedVibe: (vibe) {
                      setState(() {
                        _selectedVibes.add(vibe);
                      });
                    },
                    onAddCustomVibe: _addCustomVibe,
                    onRemoveVibe: (vibe) {
                      setState(() {
                        _selectedVibes.remove(vibe);
                      });
                    },
                  ),
                  _TextInput(
                    controller: _notesController,
                    label: 'Notes',
                    minLines: 3,
                    maxLines: 5,
                    validator: _required,
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('More details (optional)'),
                    subtitle: const Text(
                      'Ratings, links and technical data for a richer profile.',
                    ),
                    children: [
                      _TextInput(
                        controller: _idController,
                        label: 'ID',
                        helperText: 'Generated automatically. Change only when needed.',
                        validator: _validateId,
                      ),
                      _TextInput(
                        controller: _neighborhoodController,
                        label: 'Neighborhood',
                        helperText: 'Optional, e.g. Poggiofranco.',
                      ),
                      _TextInput(
                        controller: _foodTagsController,
                        label: 'Food tags',
                        helperText: 'Optional. Comma-separated, e.g. meat, grill.',
                      ),
                      _DetailedRatingEditor(
                        foodRating: _foodRating,
                        locationRating: _locationRating,
                        serviceRating: _serviceRating,
                        valueRating: _valueRating,
                        onFoodChanged: (value) {
                          setState(() => _foodRating = value);
                        },
                        onLocationChanged: (value) {
                          setState(() => _locationRating = value);
                        },
                        onServiceChanged: (value) {
                          setState(() => _serviceRating = value);
                        },
                        onValueChanged: (value) {
                          setState(() => _valueRating = value);
                        },
                      ),
                      _TextInput(
                        controller: _websiteUrlController,
                        label: 'Website URL',
                        helperText:
                            'Optional. Add the official website if present.',
                        validator: _validateOptionalUrl,
                      ),
                      _TextInput(
                        controller: _instagramUrlController,
                        label: 'Instagram URL',
                        helperText:
                            'Optional. Link to the official Instagram profile.',
                        validator: _validateOptionalInstagramUrl,
                      ),
                      _TextInput(
                        controller: _googlePlaceIdController,
                        label: 'Google Place ID',
                        helperText: 'Optional. Useful later with Places API.',
                      ),
                      _TextInput(
                        controller: _photoAssetController,
                        label: 'Photo asset',
                        helperText: 'Optional. Leave empty for now.',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSavingToProject
                          ? null
                          : _saveCurrentPlaceToProjectJson,
                      icon: _isSavingToProject
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _isSavingToProject
                            ? 'Saving...'
                            : _isEditingExistingPlace
                                ? 'Update places.json'
                                : 'Save to places.json',
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Manual JSON tools'),
                    subtitle: const Text('Only needed when the local writer is unavailable.'),
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _generateJson,
                          icon: const Icon(Icons.data_object_rounded),
                          label: const Text('Generate JSON'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _addCurrentPlaceToDrafts,
                          icon: const Icon(Icons.playlist_add_rounded),
                          label: const Text('Add to draft export'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (_generatedJson != null) ...[
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Generated JSON',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _copyJson,
                    icon: const Icon(Icons.copy_rounded),
                    label: const Text('Copy'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF102F40),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SelectableText(
                  _generatedJson!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
            ],
            if (_draftPlaces.isNotEmpty) ...[
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Draft export (${_draftPlaces.length})',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _copyExportJson,
                    icon: const Icon(Icons.copy_all_rounded),
                    label: const Text('Copy list'),
                  ),
                  IconButton(
                    tooltip: 'Clear draft list',
                    onPressed: _clearDraftPlaces,
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Copy this list once after adding multiple places. It is safer '
                'than manually managing commas between single JSON blocks.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF58717E),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF173F54),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: SelectableText(
                  _exportJson ?? _buildExportJson(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TextInput extends StatelessWidget {
  const _TextInput({
    required this.controller,
    required this.label,
    this.helperText,
    this.keyboardType,
    this.minLines,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final TextInputType? keyboardType;
  final int? minLines;
  final int? maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        minLines: minLines,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          helperText: helperText,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

class _ExistingPlaceEditor extends StatelessWidget {
  const _ExistingPlaceEditor({
    required this.places,
    required this.selectedPlaceId,
    required this.isLoading,
    required this.onRefresh,
    required this.onSelected,
    required this.onNewPlace,
  });

  final List<Place> places;
  final String? selectedPlaceId;
  final bool isLoading;
  final VoidCallback onRefresh;
  final ValueChanged<String?> onSelected;
  final VoidCallback onNewPlace;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD7E8F0)),
      ),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        initiallyExpanded: selectedPlaceId != null,
        title: Text(
          'Edit an existing place',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: const Text('Open this only when correcting a saved place.'),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Load one of ${places.length} saved places',
                  style: const TextStyle(color: Color(0xFF58717E)),
                ),
              ),
              IconButton(
                tooltip: 'Refresh existing places',
                onPressed: isLoading ? null : onRefresh,
                icon: isLoading
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: places.any((place) => place.id == selectedPlaceId)
                ? selectedPlaceId
                : null,
            decoration: const InputDecoration(
              labelText: 'Load place',
              border: OutlineInputBorder(),
            ),
            items: places.map((place) {
              return DropdownMenuItem(
                value: place.id,
                child: Text('${place.name} · ${place.city}'),
              );
            }).toList(),
            onChanged: onSelected,
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onNewPlace,
              icon: const Icon(Icons.add_location_alt_rounded),
              label: const Text('New place'),
            ),
          ),
        ],
      ),
    );
  }
}

class _VibeSelector extends StatelessWidget {
  const _VibeSelector({
    required this.selectedVibes,
    required this.suggestedVibes,
    required this.customVibeController,
    required this.onChooseVibes,
    required this.onAddSuggestedVibe,
    required this.onAddCustomVibe,
    required this.onRemoveVibe,
  });

  final Set<String> selectedVibes;
  final List<String> suggestedVibes;
  final TextEditingController customVibeController;
  final VoidCallback onChooseVibes;
  final ValueChanged<String> onAddSuggestedVibe;
  final VoidCallback onAddCustomVibe;
  final ValueChanged<String> onRemoveVibe;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Vibes',
          helperText: 'Choose existing tags or add a custom one.',
          border: OutlineInputBorder(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (selectedVibes.isEmpty)
              const Text(
                'No vibes selected yet.',
                style: TextStyle(color: Color(0xFF58717E)),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: selectedVibes.map((vibe) {
                  return InputChip(
                    label: Text(_displayVibe(vibe)),
                    onDeleted: () => onRemoveVibe(vibe),
                  );
                }).toList(),
              ),
            if (suggestedVibes.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Suggested for this category',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF58717E),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: suggestedVibes.map((vibe) {
                  return ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 16),
                    label: Text(_displayVibe(vibe)),
                    onPressed: () => onAddSuggestedVibe(vibe),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onChooseVibes,
                icon: const Icon(Icons.sell_rounded),
                label: const Text('Choose existing vibes'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: customVibeController,
                    decoration: const InputDecoration(
                      labelText: 'New vibe',
                      hintText: 'delivery',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => onAddCustomVibe(),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: IconButton.filledTonal(
                    tooltip: 'Add custom vibe',
                    onPressed: onAddCustomVibe,
                    icon: const Icon(Icons.add_rounded),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailedRatingEditor extends StatelessWidget {
  const _DetailedRatingEditor({
    required this.foodRating,
    required this.locationRating,
    required this.serviceRating,
    required this.valueRating,
    required this.onFoodChanged,
    required this.onLocationChanged,
    required this.onServiceChanged,
    required this.onValueChanged,
  });

  final int foodRating;
  final int locationRating;
  final int serviceRating;
  final int valueRating;
  final ValueChanged<int> onFoodChanged;
  final ValueChanged<int> onLocationChanged;
  final ValueChanged<int> onServiceChanged;
  final ValueChanged<int> onValueChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Detailed rating',
          helperText: 'Optional. Leave 0 for fields you do not want to save.',
          border: OutlineInputBorder(),
        ),
        child: Column(
          children: [
            _NumberStepper(
              label: 'Food / drink',
              value: foodRating,
              min: 0,
              max: 10,
              suffix: '/10',
              onChanged: onFoodChanged,
            ),
            _NumberStepper(
              label: 'Location',
              value: locationRating,
              min: 0,
              max: 10,
              suffix: '/10',
              onChanged: onLocationChanged,
            ),
            _NumberStepper(
              label: 'Service',
              value: serviceRating,
              min: 0,
              max: 10,
              suffix: '/10',
              onChanged: onServiceChanged,
            ),
            _NumberStepper(
              label: 'Value',
              value: valueRating,
              min: 0,
              max: 10,
              suffix: '/10',
              onChanged: onValueChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberStepper extends StatelessWidget {
  const _NumberStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix = '',
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String suffix;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$label: $value$suffix',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton.filledTonal(
            onPressed: value <= min ? null : () => onChanged(value - 1),
            icon: const Icon(Icons.remove_rounded),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: value >= max ? null : () => onChanged(value + 1),
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
    );
  }
}

String? _required(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required field.';
  }

  return null;
}

String? _validateId(String? value) {
  final requiredError = _required(value);
  if (requiredError != null) {
    return requiredError;
  }

  final id = value!.trim();
  final isValid = RegExp(r'^[a-z0-9_]+$').hasMatch(id);
  return isValid ? null : 'Use only lowercase letters, numbers and _.';
}

String? _validateCountryCode(String? value) {
  return RegExp(r'^[A-Za-z]{2}$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Use a two-letter code, e.g. IT, GB or NO.';
}

String? _validateCurrencyCode(String? value) {
  return RegExp(r'^[A-Za-z]{3}$').hasMatch(value?.trim() ?? '')
      ? null
      : 'Use a three-letter code, e.g. EUR, GBP or NOK.';
}

String? _validateLatitude(String? value) {
  final parsedValue = _parseRequiredDouble(value);
  if (parsedValue == null) {
    return 'Enter a valid latitude.';
  }

  return parsedValue >= -90 && parsedValue <= 90
      ? null
      : 'Latitude must be between -90 and 90.';
}

String? _validateLongitude(String? value) {
  final parsedValue = _parseRequiredDouble(value);
  if (parsedValue == null) {
    return 'Enter a valid longitude.';
  }

  return parsedValue >= -180 && parsedValue <= 180
      ? null
      : 'Longitude must be between -180 and 180.';
}

String? _validateOptionalUrl(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  final uri = Uri.tryParse(value.trim());
  if (uri == null || !uri.hasScheme) {
    return 'Enter a valid URL.';
  }

  return uri.scheme == 'http' || uri.scheme == 'https'
      ? null
      : 'URL must start with http or https.';
}

String? _validateOptionalInstagramUrl(String? value) {
  final urlError = _validateOptionalUrl(value);
  if (urlError != null) {
    return urlError;
  }

  if (value == null || value.trim().isEmpty) {
    return null;
  }

  final host = Uri.parse(value.trim()).host.toLowerCase();
  return host == 'instagram.com' || host == 'www.instagram.com'
      ? null
      : 'Use an instagram.com URL.';
}

double? _parseRequiredDouble(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }

  return double.tryParse(value.trim().replaceAll(',', '.'));
}

String? _optionalText(TextEditingController controller) {
  final text = controller.text.trim();
  return text.isEmpty ? null : text;
}

String _slugify(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized
      .replaceAll(RegExp(r"[^a-z0-9]+"), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '');
}

String _normalizeVibe(String value) {
  final normalized = value.trim().toLowerCase().replaceAll(' ', '_');
  return normalized == 'beers' ? 'beer' : normalized;
}

List<String> _parseTags(String value) {
  return value
      .split(',')
      .map((tag) => tag.trim().toLowerCase().replaceAll(' ', '_'))
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .toList()
    ..sort();
}

String _displayVibe(String vibe) {
  final normalized = vibe.replaceAll('_', ' ').replaceAll('-', ' ');
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

const _defaultVibes = {
  'aperitif',
  'authentic',
  'beer',
  'breakfast',
  'casual',
  'cocktails',
  'coffee',
  'coworkers',
  'cozy',
  'date',
  'delivery',
  'dinner',
  'family',
  'friends',
  'late-night',
  'locals',
  'lunch',
  'panini',
  'solo',
  'street_food',
  'takeaway',
  'touristy',
  'wine',
};

const _vibeSuggestionsByCategory = <String, List<String>>{
  'restaurant': ['date', 'family', 'friends', 'locals', 'wine'],
  'sushi': ['date', 'dinner', 'friends', 'takeaway'],
  'chinese': ['family', 'friends', 'takeaway', 'delivery'],
  'indian': ['dinner', 'family', 'friends', 'delivery'],
  'pizzeria': ['casual', 'family', 'friends', 'takeaway'],
  'panzerotteria': ['street_food', 'takeaway', 'locals', 'casual'],
  'steakhouse': ['dinner', 'date', 'wine', 'friends'],
  'pub': ['beer', 'friends', 'late-night', 'casual'],
  'coffee_bar': ['breakfast', 'coffee', 'solo', 'coworkers'],
  'cocktail_bar': ['cocktails', 'date', 'late-night', 'friends'],
  'beer_bar': ['beer', 'friends', 'casual', 'late-night'],
  'bakery_sweet': ['breakfast', 'coffee', 'takeaway'],
  'bakery_savory': ['street_food', 'takeaway', 'lunch', 'panini'],
  'gelateria': ['family', 'touristy', 'takeaway'],
};
