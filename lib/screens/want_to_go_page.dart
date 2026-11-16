import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_map_app/config/social_config.dart';
import 'package:my_map_app/data/want_to_go_repository.dart';
import 'package:my_map_app/models/place.dart';
import 'package:my_map_app/models/place_category.dart';
import 'package:my_map_app/models/want_to_go_place.dart';
import 'package:my_map_app/services/geocoding_service.dart';
import 'package:my_map_app/services/want_to_go_backup_file_service.dart';
import 'package:my_map_app/social/google_place_search_result.dart';
import 'package:my_map_app/social/google_place_search_service.dart';
import 'package:url_launcher/url_launcher.dart';

class WantToGoPage extends StatefulWidget {
  const WantToGoPage({
    required this.mappedPlaces,
    this.repository = const WantToGoRepository(),
    this.geocodingService = const GeocodingService(),
    super.key,
  });

  final List<Place> mappedPlaces;
  final WantToGoRepository repository;
  final GeocodingService geocodingService;

  @override
  State<WantToGoPage> createState() => _WantToGoPageState();
}

class _WantToGoPageState extends State<WantToGoPage> {
  WantToGoData _data = const WantToGoData();
  bool _isLoading = true;
  bool _isSaving = false;
  String _wantToGoSearchQuery = '';
  final _wantToGoSearchController = TextEditingController();
  String? _selectedWantToGoCity;
  int? _selectedWantToGoPriority;

  List<Place> get _mappedPlaces {
    final places = widget.mappedPlaces
        .where((place) => _data.mappedPlaceIds.contains(place.id))
        .toList()
      ..sort((first, second) => first.name.compareTo(second.name));
    return places;
  }

  List<String> get _wantToGoCities {
    final cities = _data.places.map((place) => place.city).toSet().toList()
      ..sort();
    return cities;
  }

  List<WantToGoPlace> get _filteredWantToGoPlaces {
    final query = _wantToGoSearchQuery.trim().toLowerCase();
    final places = _data.places.where((place) {
      final matchesQuery = query.isEmpty ||
          place.name.toLowerCase().contains(query) ||
          place.city.toLowerCase().contains(query) ||
          (place.note?.toLowerCase().contains(query) ?? false);
      final matchesCity = _selectedWantToGoCity == null ||
          place.city == _selectedWantToGoCity;
      final matchesPriority = _selectedWantToGoPriority == null ||
          place.priority == _selectedWantToGoPriority;
      return matchesQuery && matchesCity && matchesPriority;
    }).toList()
      ..sort((first, second) {
        final priority = first.priority.compareTo(second.priority);
        return priority != 0
            ? priority
            : second.createdAt.compareTo(first.createdAt);
      });
    return places;
  }

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _wantToGoSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final loadedData = await widget.repository.load();
      if (!mounted) return;
      setState(() {
        _data = loadedData;
      });
    } catch (_) {
      _showMessage('Could not load your Want to go list.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<bool> _saveData(WantToGoData updatedData) async {
    final previousData = _data;
    setState(() {
      _data = updatedData;
      _isSaving = true;
    });

    try {
      await widget.repository.save(updatedData);
      return true;
    } catch (_) {
      if (mounted) {
        setState(() {
          _data = previousData;
        });
      }
      _showMessage('Could not save your Want to go list. Try again.');
      return false;
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _showAddPlaceSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SafeArea(
            top: false,
            child: _WantToGoAddSheet(onSubmit: _addPlaceFromSheet),
          ),
        );
      },
    );
  }

  Future<_WantToGoAddResult> _addPlaceFromSheet(WantToGoPlace place) async {
    final isDuplicate = _data.places.any(
      (existingPlace) =>
          existingPlace.name.toLowerCase() == place.name.toLowerCase() &&
          existingPlace.city.toLowerCase() == place.city.toLowerCase(),
    );
    if (isDuplicate) {
      return const _WantToGoAddResult(
        saved: false,
        message: 'This place is already on your Want to go list.',
      );
    }

    final saved = await _saveData(
      WantToGoData(
        mappedPlaceIds: _data.mappedPlaceIds,
        places: [place, ..._data.places],
      ),
    );
    if (!saved) {
      return const _WantToGoAddResult(
        saved: false,
        message: 'Could not save the place. Try again.',
      );
    }

    return _WantToGoAddResult(
      saved: true,
      message: place.isVisibleOnMap
          ? 'Added to the map. Ready for the next place.'
          : 'Saved to your Want to go list.',
    );
  }

  Future<WantToGoPlace> _locatePlace(WantToGoPlace place) async {
    final coordinatesFromUrl = _coordinatesFromGoogleMapsUrl(
      place.googleMapsUrl,
    );
    if (coordinatesFromUrl != null) {
      return place.withCoordinates(
        latitude: coordinatesFromUrl.latitude,
        longitude: coordinatesFromUrl.longitude,
      );
    }

    try {
      final location = await widget.geocodingService.searchPlace(
        name: place.name,
        city: place.city,
      );
      if (location == null) return place;

      return place.withCoordinates(
        latitude: location.latitude,
        longitude: location.longitude,
      );
    } on GeocodingException {
      return place;
    } catch (_) {
      return place;
    }
  }

  Future<void> _locateExistingPlace(WantToGoPlace place) async {
    setState(() {
      _isSaving = true;
    });

    final locatedPlace = await _locatePlace(place);
    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    final locationDidNotChange =
        locatedPlace.latitude == place.latitude &&
        locatedPlace.longitude == place.longitude;
    if (!locatedPlace.isVisibleOnMap || locationDidNotChange) {
      await _showAddressLookupSheet(place);
      return;
    }

    final saved = await _saveData(
      WantToGoData(
        mappedPlaceIds: _data.mappedPlaceIds,
        places: _data.places
            .map(
              (existingPlace) => existingPlace.id == place.id
                  ? locatedPlace
                  : existingPlace,
            )
            .toList(),
      ),
    );
    if (saved) {
      _showMessage('Added to the map.');
    }
  }

  Future<void> _showAddressLookupSheet(WantToGoPlace place) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: SafeArea(
            top: false,
            child: _AddressLookupSheet(
              place: place,
              onResolve: (address) =>
                  _saveCoordinatesFromAddress(place, address),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _saveCoordinatesFromAddress(
    WantToGoPlace place,
    String address,
  ) async {
    try {
      final coordinates = await const GooglePlaceSearchService()
          .resolveCoordinates(
            name: place.name,
            city: place.city,
            address: address,
          );
      if (coordinates == null) {
        _showMessage('No reliable point was found for that address.');
        return false;
      }
      return _saveCoordinatesForExistingPlace(
        place,
        coordinates.latitude,
        coordinates.longitude,
      );
    } on GooglePlaceSearchException catch (error) {
      _showMessage(error.message);
      return false;
    }
  }

  Future<bool> _saveCoordinatesForExistingPlace(
    WantToGoPlace place,
    double latitude,
    double longitude,
  ) async {
    final updatedPlace = place.withCoordinates(
      latitude: latitude,
      longitude: longitude,
    );
    final saved = await _saveData(
      WantToGoData(
        mappedPlaceIds: _data.mappedPlaceIds,
        places: _data.places
            .map(
              (existingPlace) => existingPlace.id == place.id
                  ? updatedPlace
                  : existingPlace,
            )
            .toList(),
      ),
    );
    if (saved) {
      _showMessage('Map location updated.');
    }
    return saved;
  }

  Future<void> _removeMappedPlace(String placeId) async {
    await _saveData(
      WantToGoData(
        mappedPlaceIds: _data.mappedPlaceIds
            .where((id) => id != placeId)
            .toSet(),
        places: _data.places,
      ),
    );
  }

  Future<void> _removePlaceToTry(String placeId) async {
    await _saveData(
      WantToGoData(
        mappedPlaceIds: _data.mappedPlaceIds,
        places: _data.places.where((place) => place.id != placeId).toList(),
      ),
    );
  }

  Future<void> _updateWantToGoPriority(
    WantToGoPlace place,
    int priority,
  ) async {
    if (priority == place.priority) return;
    final saved = await _saveData(
      WantToGoData(
        mappedPlaceIds: _data.mappedPlaceIds,
        places: _data.places
            .map(
              (existingPlace) => existingPlace.id == place.id
                  ? existingPlace.withPriority(priority)
                  : existingPlace,
            )
            .toList(),
      ),
    );
    if (saved) {
      _showMessage('Priority set to $priority.');
    }
  }

  Future<void> _showExportBackup() async {
    final backup = widget.repository.encodeBackup(_data);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Copy Want to go backup'),
          content: SingleChildScrollView(
            child: SelectableText(
              backup,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: backup));
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                _showMessage('Backup copied. Paste it on your other device.');
              },
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy backup'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadBackupFile() async {
    final saved = await downloadWantToGoBackup(
      contents: widget.repository.encodeBackup(_data),
      fileName: 'want-to-go-backup-${_backupDateLabel(DateTime.now())}.json',
    );
    if (!saved) {
      _showMessage('Use Copy backup on this version of the app.');
      return;
    }
    _showMessage('Backup file downloaded. Import it on your other device.');
  }

  Future<void> _showImportBackup() async {
    final controller = TextEditingController();
    try {
      final backup = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Import Want to go backup'),
            content: TextField(
              controller: controller,
              minLines: 8,
              maxLines: 14,
              decoration: const InputDecoration(
                hintText: 'Paste the backup copied from your other device.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(dialogContext, controller.text),
                icon: const Icon(Icons.download_rounded),
                label: const Text('Import'),
              ),
            ],
          );
        },
      );
      if (backup == null || backup.trim().isEmpty) return;
      await _importBackup(backup);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _importBackupFile() async {
    final backup = await pickWantToGoBackup();
    if (backup == null || backup.trim().isEmpty) return;
    await _importBackup(backup);
  }

  Future<void> _importBackup(String rawBackup) async {
    WantToGoData importedData;
    try {
      importedData = widget.repository.decodeBackup(rawBackup);
    } on FormatException {
      _showMessage(
        'That backup is not valid. Copy the entire backup and try again.',
      );
      return;
    } on TypeError {
      _showMessage(
        'That backup is not valid. Copy the entire backup and try again.',
      );
      return;
    }

    final mergedData = _mergeWantToGoData(_data, importedData);
    final saved = await _saveData(mergedData);
    if (!saved) return;

    _showMessage('Want to go list imported. Existing places were kept.');
  }

  WantToGoData _mergeWantToGoData(
    WantToGoData current,
    WantToGoData imported,
  ) {
    final placesByNameAndCity = <String, WantToGoPlace>{};
    for (final place in [...current.places, ...imported.places]) {
      final key =
          '${place.name.trim().toLowerCase()}|${place.city.trim().toLowerCase()}';
      placesByNameAndCity.putIfAbsent(key, () => place);
    }
    final places = placesByNameAndCity.values.toList()
      ..sort((first, second) => second.createdAt.compareTo(first.createdAt));

    return WantToGoData(
      mappedPlaceIds: {...current.mappedPlaceIds, ...imported.mappedPlaceIds},
      places: places,
    );
  }

  Future<void> _openGoogleMaps(String url) async {
    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      _showMessage('Could not open Google Maps.');
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Want to go'),
        actions: [
          PopupMenuButton<_WantToGoBackupAction>(
            tooltip: 'Backup options',
            onSelected: (action) async {
              switch (action) {
                case _WantToGoBackupAction.export:
                  await _showExportBackup();
                case _WantToGoBackupAction.download:
                  await _downloadBackupFile();
                case _WantToGoBackupAction.import:
                  await _showImportBackup();
                case _WantToGoBackupAction.importFile:
                  await _importBackupFile();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _WantToGoBackupAction.export,
                child: ListTile(
                  leading: Icon(Icons.copy_rounded),
                  title: Text('Copy backup'),
                ),
              ),
              if (supportsWantToGoBackupFiles)
                const PopupMenuItem(
                  value: _WantToGoBackupAction.download,
                  child: ListTile(
                    leading: Icon(Icons.download_rounded),
                    title: Text('Download backup file'),
                  ),
                ),
              const PopupMenuItem(
                value: _WantToGoBackupAction.import,
                child: ListTile(
                  leading: Icon(Icons.content_paste_rounded),
                  title: Text('Import backup'),
                ),
              ),
              if (supportsWantToGoBackupFiles)
                const PopupMenuItem(
                  value: _WantToGoBackupAction.importFile,
                  child: ListTile(
                    leading: Icon(Icons.upload_file_rounded),
                    title: Text('Import backup file'),
                  ),
                ),
            ],
          ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _showAddPlaceSheet,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add a place to try'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              children: [
                const Text(
                  'Private to this device. Use the menu to make a backup for another device. Places from My Locals stay separate from your personal Want to go list.',
                  style: TextStyle(color: Color(0xFF58717E)),
                ),
                const SizedBox(height: 22),
                if (_mappedPlaces.isNotEmpty) ...[
                  _SectionTitle(
                    title: 'Saved from My Locals',
                    count: _mappedPlaces.length,
                  ),
                  const SizedBox(height: 8),
                  ..._mappedPlaces.map(
                    (place) => _MappedPlaceTile(
                      place: place,
                      onRemove: () => _removeMappedPlace(place.id),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                _SectionTitle(
                  title: 'Your places to try',
                  count: _filteredWantToGoPlaces.length,
                ),
                const SizedBox(height: 12),
                _WantToGoFilters(
                  searchController: _wantToGoSearchController,
                  cities: _wantToGoCities,
                  selectedCity: _selectedWantToGoCity,
                  selectedPriority: _selectedWantToGoPriority,
                  onSearchChanged: (value) {
                    setState(() => _wantToGoSearchQuery = value);
                  },
                  onCityChanged: (value) {
                    setState(() => _selectedWantToGoCity = value);
                  },
                  onPriorityChanged: (value) {
                    setState(() => _selectedWantToGoPriority = value);
                  },
                ),
                const SizedBox(height: 12),
                if (_data.places.isEmpty)
                  const _EmptyListCard(
                    message:
                        'Add a place from Google Places to start your own list.',
                  )
                else if (_filteredWantToGoPlaces.isEmpty)
                  const _EmptyListCard(
                    message: 'No places match these filters.',
                  )
                else
                  ..._filteredWantToGoPlaces.map(
                    (place) => _PlaceToTryTile(
                      place: place,
                      isOnMap: place.isVisibleOnMap,
                      onLocate: () => _locateExistingPlace(place),
                      onPriorityChanged: (priority) =>
                          _updateWantToGoPriority(place, priority),
                      onOpenMaps: place.googleMapsUrl == null
                          ? null
                          : () => _openGoogleMaps(place.googleMapsUrl!),
                      onRemove: () => _removePlaceToTry(place.id),
                    ),
                  ),
              ],
            ),
    );
  }
}

enum _WantToGoBackupAction { export, download, import, importFile }

enum _PlaceToTryAction { locate, openMaps, remove }

class _WantToGoAddResult {
  const _WantToGoAddResult({required this.saved, required this.message});

  final bool saved;
  final String message;
}

class _AddressLookupSheet extends StatefulWidget {
  const _AddressLookupSheet({required this.place, required this.onResolve});

  final WantToGoPlace place;
  final Future<bool> Function(String address) onResolve;

  @override
  State<_AddressLookupSheet> createState() => _AddressLookupSheetState();
}

class _AddressLookupSheetState extends State<_AddressLookupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  bool _isSaving = false;
  bool _wasSaved = false;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });
    final saved = await widget.onResolve(_addressController.text.trim());
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _wasSaved = saved;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FBFD),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Center(
              child: Container(
                width: 46,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD3DDE3),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Set map location',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text('${widget.place.name} · ${widget.place.city}'),
            const SizedBox(height: 8),
            const Text(
              'The existing link did not provide a reliable location. Add only the street address and we will find the point automatically.',
              style: TextStyle(color: Color(0xFF58717E)),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _addressController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Street address',
                hintText: 'e.g. 30 Hawley Crescent, NW1 8NP',
              ),
              validator: _required,
            ),
            if (_wasSaved) ...[
              const SizedBox(height: 12),
              const Text(
                'Location saved. You can close this panel.',
                style: TextStyle(
                  color: Color(0xFF13714A),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _submit,
                icon: _isSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.location_on_rounded),
                label: Text(_isSaving ? 'Finding…' : 'Find address on map'),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WantToGoAddSheet extends StatefulWidget {
  const _WantToGoAddSheet({required this.onSubmit});

  final Future<_WantToGoAddResult> Function(WantToGoPlace place) onSubmit;

  @override
  State<_WantToGoAddSheet> createState() => _WantToGoAddSheetState();
}

class _WantToGoAddSheetState extends State<_WantToGoAddSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _cityController = TextEditingController();
  final _streetAddressController = TextEditingController();
  final _mapsUrlController = TextEditingController();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  final _noteController = TextEditingController();
  final _nameFocusNode = FocusNode();
  final _googlePlaceSearchService = const GooglePlaceSearchService();
  bool _isSaving = false;
  bool _isSearchingGooglePlaces = false;
  bool _isResolvingCoordinates = false;
  bool _needsAddressLookup = false;
  int _priority = 2;
  String? _selectedGooglePlaceId;
  String _selectedCountryCode = '';
  List<GooglePlaceSearchResult> _googlePlaceResults = const [];
  _WantToGoAddResult? _result;

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _streetAddressController.dispose();
    _mapsUrlController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _noteController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  bool get _canUseGooglePlaces =>
      SocialConfig.isAvailable && SocialConfig.client.auth.currentUser != null;

  void _showResultMessage(String message) {
    setState(() {
      _result = _WantToGoAddResult(saved: false, message: message);
    });
  }

  Future<void> _searchGooglePlaces() async {
    final name = _nameController.text.trim();
    final city = _cityController.text.trim();
    if (name.length < 2 || city.length < 2) {
      _showResultMessage('Enter the place name and city before searching.');
      return;
    }
    if (!_canUseGooglePlaces) {
      _showResultMessage('Sign in before using secure Google place search.');
      return;
    }

    setState(() {
      _isSearchingGooglePlaces = true;
      _result = null;
    });
    try {
      final results = await _googlePlaceSearchService.search(
        name: name,
        city: city,
        countryCode: '',
      );
      if (!mounted) return;
      setState(() {
        _googlePlaceResults = results;
        if (results.isEmpty) {
          _result = const _WantToGoAddResult(
            saved: false,
            message: 'No Google results found. Check the spelling or city.',
          );
        }
      });
    } on GooglePlaceSearchException catch (error) {
      if (!mounted) return;
      _showResultMessage(error.message);
    } finally {
      if (mounted) {
        setState(() => _isSearchingGooglePlaces = false);
      }
    }
  }

  void _selectGooglePlace(GooglePlaceSearchResult result) {
    final query = '${_nameController.text.trim()} ${_cityController.text.trim()}'
        .trim();
    final temporaryMapsUrl = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': query,
      'query_place_id': result.placeId,
    }).toString();

    setState(() {
      _selectedGooglePlaceId = result.placeId;
      _selectedCountryCode = '';
      _streetAddressController.text = result.address;
      _mapsUrlController.text = temporaryMapsUrl;
      _latitudeController.clear();
      _longitudeController.clear();
      _googlePlaceResults = const [];
      _needsAddressLookup = false;
      _isResolvingCoordinates = true;
      _result = null;
    });
    unawaited(_completeGooglePlaceSelection(result.placeId));
  }

  Future<void> _completeGooglePlaceSelection(String placeId) async {
    try {
      final details = await _googlePlaceSearchService.loadPlaceDetails(
        placeId: placeId,
      );
      if (!mounted || _selectedGooglePlaceId != placeId) return;
      _selectedCountryCode = details.countryCode ?? '';
      setState(() {
        if (details.googleMapsUrl != null) {
          _mapsUrlController.text = details.googleMapsUrl!;
        }
        if (details.address != null) {
          _streetAddressController.text = details.address!;
        }
      });
    } on GooglePlaceSearchException {
      // The stable link and the address returned by Text Search remain
      // available. The address fallback can still locate the venue.
    }

    if (!mounted || _selectedGooglePlaceId != placeId) return;
    await _resolveCoordinatesForSelection(placeId);
  }

  Future<void> _resolveCoordinatesForSelection(String placeId) async {
    if (!mounted || _selectedGooglePlaceId != placeId) return;
    setState(() {
      _isResolvingCoordinates = true;
      _result = null;
    });
    try {
      final coordinates = await _googlePlaceSearchService.resolveCoordinates(
        name: _nameController.text.trim(),
        city: _cityController.text.trim(),
        address: _streetAddressController.text.trim(),
        countryCode: _selectedCountryCode,
      );
      if (!mounted || _selectedGooglePlaceId != placeId) return;
      setState(() {
        if (coordinates == null) {
          _needsAddressLookup = true;
          _result = const _WantToGoAddResult(
            saved: false,
            message:
                'Coordinates were not found automatically. Add the street address below to try again.',
          );
        } else {
          _latitudeController.text = coordinates.latitude.toStringAsFixed(6);
          _longitudeController.text = coordinates.longitude.toStringAsFixed(6);
          _needsAddressLookup = false;
          _result = const _WantToGoAddResult(
            saved: true,
            message: 'Google link and coordinates are ready.',
          );
        }
      });
    } on GooglePlaceSearchException {
      if (!mounted || _selectedGooglePlaceId != placeId) return;
      setState(() {
        _needsAddressLookup = true;
        _result = const _WantToGoAddResult(
          saved: false,
          message:
              'Coordinates could not be verified automatically. Add the street address below to try again.',
        );
      });
    } finally {
      if (mounted && _selectedGooglePlaceId == placeId) {
        setState(() => _isResolvingCoordinates = false);
      }
    }
  }

  Future<void> _findAddressOnMap() async {
    final placeId = _selectedGooglePlaceId;
    if (placeId == null) return;
    if (_streetAddressController.text.trim().isEmpty) {
      _showResultMessage('Add the street address before searching for it.');
      return;
    }
    await _resolveCoordinatesForSelection(placeId);
  }

  Future<void> _submit() async {
    if (_isSaving || _isResolvingCoordinates) return;
    if (_selectedGooglePlaceId == null) {
      _showResultMessage('Select the correct place from Google before adding it.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final latitude = _tryParseCoordinate(_latitudeController.text);
    final longitude = _tryParseCoordinate(_longitudeController.text);
    if (latitude == null || longitude == null) {
      _showResultMessage(
        'Wait for the automatic map location or add a street address to retry.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isSaving = true;
      _result = null;
    });

    final result = await widget.onSubmit(
      WantToGoPlace.create(
        name: _nameController.text,
        city: _cityController.text,
        googleMapsUrl: _mapsUrlController.text,
        googlePlaceId: _selectedGooglePlaceId,
        note: _noteController.text,
        latitude: latitude,
        longitude: longitude,
        priority: _priority,
      ),
    );
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _result = result;
    });

    if (!result.saved) return;

    _nameController.clear();
    _streetAddressController.clear();
    _mapsUrlController.clear();
    _latitudeController.clear();
    _longitudeController.clear();
    _noteController.clear();
    setState(() {
      _selectedGooglePlaceId = null;
      _selectedCountryCode = '';
      _googlePlaceResults = const [];
      _needsAddressLookup = false;
    });
    _nameFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FBFD),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 46,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD3DDE3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Add places to try',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text(
                'Search Google Places, select the correct result, then add it to your list.',
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (_) => _resetSelectionForChangedQuery(),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'City'),
                onChanged: (_) => _resetSelectionForChangedQuery(),
                validator: _required,
              ),
              const SizedBox(height: 12),
              _PriorityPicker(
                value: _priority,
                onChanged: (priority) {
                  setState(() => _priority = priority);
                },
              ),
              const SizedBox(height: 12),
              _WantToGoGoogleLookupCard(
                isSearching: _isSearchingGooglePlaces,
                isResolving: _isResolvingCoordinates,
                results: _googlePlaceResults,
                enabled: _canUseGooglePlaces,
                hasSelection: _selectedGooglePlaceId != null,
                onSearch: _searchGooglePlaces,
                onSelected: _selectGooglePlace,
              ),
              if (_needsAddressLookup) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF6E8),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFF0D29A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'This place is missing from open map data',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Add only the street address. We will find the point automatically and do not save this field.',
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _streetAddressController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Street address',
                          helperText: 'For example: 30 Hawley Crescent, NW1 8NP',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonalIcon(
                        onPressed: _isResolvingCoordinates
                            ? null
                            : _findAddressOnMap,
                        icon: const Icon(Icons.location_on_rounded),
                        label: const Text('Find address on map'),
                      ),
                    ],
                  ),
                ),
              ],
              TextFormField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Note',
                  helperText: 'Optional, e.g. “Try it with Marco”.',
                ),
                maxLines: 3,
              ),
              if (result != null) ...[
                const SizedBox(height: 14),
                Text(
                  result.message,
                  style: TextStyle(
                    color: result.saved
                        ? const Color(0xFF13714A)
                        : const Color(0xFFB42318),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isSaving || _isResolvingCoordinates
                      ? null
                      : _submit,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.explore_rounded),
                  label: Text(
                    _isSaving
                        ? 'Saving…'
                        : _isResolvingCoordinates
                        ? 'Getting coordinates…'
                        : 'Add and continue',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _resetSelectionForChangedQuery() {
    if (_selectedGooglePlaceId == null && _googlePlaceResults.isEmpty) return;
    setState(() {
      _selectedGooglePlaceId = null;
      _selectedCountryCode = '';
      _streetAddressController.clear();
      _mapsUrlController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      _googlePlaceResults = const [];
      _needsAddressLookup = false;
      _isResolvingCoordinates = false;
      _result = null;
    });
  }
}

class _WantToGoGoogleLookupCard extends StatelessWidget {
  const _WantToGoGoogleLookupCard({
    required this.isSearching,
    required this.isResolving,
    required this.results,
    required this.enabled,
    required this.hasSelection,
    required this.onSearch,
    required this.onSelected,
  });

  final bool isSearching;
  final bool isResolving;
  final List<GooglePlaceSearchResult> results;
  final bool enabled;
  final bool hasSelection;
  final VoidCallback onSearch;
  final ValueChanged<GooglePlaceSearchResult> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF5FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFC9E2EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Find the correct place',
            style: theme.textTheme.titleSmall?.copyWith(
              color: const Color(0xFF102F40),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            enabled
                ? 'Search by name and city. Google link and map location are prepared after selection.'
                : 'Sign in with your account to use secure Google search.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFF58717E),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: !enabled || isSearching || isResolving ? null : onSearch,
            icon: isSearching || isResolving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.travel_explore_rounded),
            label: Text(
              isSearching
                  ? 'Searching…'
                  : isResolving
                  ? 'Getting coordinates…'
                  : hasSelection
                  ? 'Search again'
                  : 'Search Google Places',
            ),
          ),
          if (hasSelection && !isResolving) ...[
            const SizedBox(height: 8),
            const Text(
              'Google Place selected. The official Maps link is attached automatically.',
              style: TextStyle(
                color: Color(0xFF13714A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (results.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...results.map(
              (result) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: const Icon(Icons.place_outlined),
                  title: Text(result.name),
                  subtitle: result.address.isEmpty ? null : Text(result.address),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: isResolving ? null : () => onSelected(result),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PriorityPicker extends StatelessWidget {
  const _PriorityPicker({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Priority',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final priority in [1, 2, 3])
              ChoiceChip(
                label: Text(_priorityLabel(priority)),
                selected: value == priority,
                onSelected: (_) => onChanged(priority),
              ),
          ],
        ),
        const SizedBox(height: 6),
        const Text(
          '1 is first choice; 3 is lowest priority.',
          style: TextStyle(color: Color(0xFF58717E), fontSize: 12),
        ),
      ],
    );
  }
}

class _WantToGoFilters extends StatelessWidget {
  const _WantToGoFilters({
    required this.searchController,
    required this.cities,
    required this.selectedCity,
    required this.selectedPriority,
    required this.onSearchChanged,
    required this.onCityChanged,
    required this.onPriorityChanged,
  });

  final TextEditingController searchController;
  final List<String> cities;
  final String? selectedCity;
  final int? selectedPriority;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<int?> onPriorityChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9FB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD3E2E8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: searchController,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Search by name, city or note',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        searchController.clear();
                        onSearchChanged('');
                      },
                      icon: const Icon(Icons.clear_rounded),
                    ),
            ),
          ),
          if (cities.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'City',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All cities'),
                  selected: selectedCity == null,
                  onSelected: (_) => onCityChanged(null),
                ),
                for (final city in cities)
                  ChoiceChip(
                    label: Text(city),
                    selected: selectedCity == city,
                    onSelected: (_) => onCityChanged(city),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          const Text(
            'Priority',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('All priorities'),
                selected: selectedPriority == null,
                onSelected: (_) => onPriorityChanged(null),
              ),
              for (final priority in [1, 2, 3])
                ChoiceChip(
                  label: Text(_priorityLabel(priority)),
                  selected: selectedPriority == priority,
                  onSelected: (_) => onPriorityChanged(priority),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        Text(
          '$count',
          style: const TextStyle(
            color: Color(0xFF58717E),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyListCard extends StatelessWidget {
  const _EmptyListCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: const Color(0xFFEAF5FB),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message, style: const TextStyle(color: Color(0xFF58717E))),
      ),
    );
  }
}

class _MappedPlaceTile extends StatelessWidget {
  const _MappedPlaceTile({required this.place, required this.onRemove});

  final Place place;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: ListTile(
        leading: place.category == 'kebab'
            ? Image.asset(
                'assets/markers/turkish_doner.png',
                width: 24,
                height: 24,
              )
            : Text(
                emojiForCategory(place.category),
                style: const TextStyle(fontSize: 24),
              ),
        title: Text(place.name),
        subtitle: Text(place.city),
        trailing: IconButton(
          tooltip: 'Remove from Want to go',
          onPressed: onRemove,
          icon: const Icon(Icons.explore_outlined),
        ),
      ),
    );
  }
}

class _PlaceToTryTile extends StatelessWidget {
  const _PlaceToTryTile({
    required this.place,
    this.onLocate,
    this.isOnMap = false,
    required this.onPriorityChanged,
    required this.onOpenMaps,
    required this.onRemove,
  });

  final WantToGoPlace place;
  final VoidCallback? onLocate;
  final bool isOnMap;
  final ValueChanged<int> onPriorityChanged;
  final VoidCallback? onOpenMaps;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      place.city,
      _priorityLabel(place.priority),
      if (!isOnMap) 'Needs map location',
      if (place.note != null) place.note!,
    ].join(' · ');

    return Card(
      elevation: 0,
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: _priorityColor(place.priority),
          child: Text(
            '${place.priority}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        title: Text(place.name),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<int>(
              tooltip: 'Change priority',
              onSelected: onPriorityChanged,
              itemBuilder: (context) => [
                for (final priority in [1, 2, 3])
                  CheckedPopupMenuItem(
                    value: priority,
                    checked: place.priority == priority,
                    child: Text(_priorityLabel(priority)),
                  ),
              ],
              icon: const Icon(Icons.flag_outlined),
            ),
            PopupMenuButton<_PlaceToTryAction>(
              tooltip: 'Place options',
              onSelected: (action) {
                switch (action) {
                  case _PlaceToTryAction.locate:
                    onLocate?.call();
                    return;
                  case _PlaceToTryAction.openMaps:
                    onOpenMaps?.call();
                    return;
                  case _PlaceToTryAction.remove:
                    onRemove();
                    return;
                }
              },
              itemBuilder: (context) => [
                if (onLocate != null)
                  PopupMenuItem(
                    value: _PlaceToTryAction.locate,
                    child: Text(
                      isOnMap
                          ? 'Update map location'
                          : 'Find map location',
                    ),
                  ),
                if (onOpenMaps != null)
                  const PopupMenuItem(
                    value: _PlaceToTryAction.openMaps,
                    child: Text('Open in Google Maps'),
                  ),
                const PopupMenuItem(
                  value: _PlaceToTryAction.remove,
                  child: Text('Remove from Want to go'),
                ),
              ],
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

String? _required(String? value) {
  return value == null || value.trim().isEmpty ? 'Required.' : null;
}

String _priorityLabel(int priority) {
  return switch (priority) {
    1 => '1 · First',
    2 => '2 · Soon',
    3 => '3 · Later',
    _ => 'Priority $priority',
  };
}

Color _priorityColor(int priority) {
  return switch (priority) {
    1 => const Color(0xFFC64A37),
    2 => const Color(0xFFDA8B19),
    3 => const Color(0xFF4A7D9A),
    _ => const Color(0xFF58717E),
  };
}

double? _tryParseCoordinate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return double.tryParse(value.trim().replaceAll(',', '.'));
}

String _backupDateLabel(DateTime value) {
  String twoDigits(int number) => number.toString().padLeft(2, '0');
  return '${value.year}${twoDigits(value.month)}${twoDigits(value.day)}';
}

CityLocation? _coordinatesFromGoogleMapsUrl(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  try {
    final decodedUrl = Uri.decodeFull(value);
    final patterns = [
      RegExp(r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)'),
      RegExp(r'[?&](?:q|query)=(-?\d+(?:\.\d+)?)[,+](-?\d+(?:\.\d+)?)'),
      RegExp(r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(decodedUrl);
      if (match == null) continue;

      final latitude = double.tryParse(match.group(1)!);
      final longitude = double.tryParse(match.group(2)!);
      if (latitude == null || longitude == null) continue;
      if (latitude < -90 || latitude > 90) continue;
      if (longitude < -180 || longitude > 180) continue;

      return CityLocation(latitude: latitude, longitude: longitude);
    }
  } catch (_) {
    return null;
  }

  return null;
}
