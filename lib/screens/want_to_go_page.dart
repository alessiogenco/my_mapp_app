import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_map_app/data/want_to_go_repository.dart';
import 'package:my_map_app/models/place.dart';
import 'package:my_map_app/models/place_category.dart';
import 'package:my_map_app/models/want_to_go_place.dart';
import 'package:my_map_app/services/geocoding_service.dart';
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

  List<Place> get _mappedPlaces {
    final places = widget.mappedPlaces
        .where((place) => _data.mappedPlaceIds.contains(place.id))
        .toList()
      ..sort((first, second) => first.name.compareTo(second.name));
    return places;
  }

  List<WantToGoPlace> get _placedWantToGoPlaces {
    return _data.places.where((place) => place.isVisibleOnMap).toList();
  }

  List<WantToGoPlace> get _unplacedWantToGoPlaces {
    return _data.places.where((place) => !place.isVisibleOnMap).toList();
  }

  @override
  void initState() {
    super.initState();
    _loadData();
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

    setState(() {
      _isSaving = true;
    });

    final locatedPlace = await _locatePlace(place);
    if (!mounted) {
      return const _WantToGoAddResult(
        saved: false,
        message: 'The page was closed before the place could be saved.',
      );
    }

    setState(() {
      _isSaving = false;
    });

    final saved = await _saveData(
      WantToGoData(
        mappedPlaceIds: _data.mappedPlaceIds,
        places: [locatedPlace, ..._data.places],
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
      message: locatedPlace.isVisibleOnMap
          ? 'Added to the map. Ready for the next place.'
          : 'Saved in Places to add later. Use the location button to enter coordinates manually.',
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
      await _showManualCoordinatesSheet(place);
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

  Future<void> _showManualCoordinatesSheet(WantToGoPlace place) async {
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
            child: _ManualCoordinatesSheet(
              place: place,
              onSave: (latitude, longitude) =>
                  _saveManualCoordinates(place, latitude, longitude),
            ),
          ),
        );
      },
    );
  }

  Future<bool> _saveManualCoordinates(
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
                case _WantToGoBackupAction.import:
                  await _showImportBackup();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _WantToGoBackupAction.export,
                child: ListTile(
                  leading: Icon(Icons.copy_rounded),
                  title: Text('Copy backup'),
                ),
              ),
              PopupMenuItem(
                value: _WantToGoBackupAction.import,
                child: ListTile(
                  leading: Icon(Icons.download_rounded),
                  title: Text('Import backup'),
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
                  'Private to this device. Use the menu to make a backup for another device. Flagged places appear on the map but are not part of the curated list.',
                  style: TextStyle(color: Color(0xFF58717E)),
                ),
                const SizedBox(height: 22),
                _SectionTitle(
                  title: 'Already on the map',
                  count: _mappedPlaces.length + _placedWantToGoPlaces.length,
                ),
                const SizedBox(height: 8),
                if (_mappedPlaces.isEmpty && _placedWantToGoPlaces.isEmpty)
                  const _EmptyListCard(
                    message:
                        'Add a place with its name and city to put it on the map.',
                  )
                else
                  ...[
                    ..._mappedPlaces.map(
                      (place) => _MappedPlaceTile(
                        place: place,
                        onRemove: () => _removeMappedPlace(place.id),
                      ),
                    ),
                    ..._placedWantToGoPlaces.map(
                      (place) => _PlaceToTryTile(
                        place: place,
                        isOnMap: true,
                        onLocate: () => _locateExistingPlace(place),
                        onOpenMaps: place.googleMapsUrl == null
                            ? null
                            : () => _openGoogleMaps(place.googleMapsUrl!),
                        onRemove: () => _removePlaceToTry(place.id),
                      ),
                    ),
                  ],
                const SizedBox(height: 24),
                _SectionTitle(
                  title: 'Places to add later',
                  count: _unplacedWantToGoPlaces.length,
                ),
                const SizedBox(height: 8),
                if (_unplacedWantToGoPlaces.isEmpty)
                  const _EmptyListCard(
                    message:
                        'Anything we cannot locate safely will stay here.',
                  )
                else
                  ..._unplacedWantToGoPlaces.map(
                    (place) => _PlaceToTryTile(
                      place: place,
                      onLocate: () => _locateExistingPlace(place),
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

enum _WantToGoBackupAction { export, import }

class _WantToGoAddResult {
  const _WantToGoAddResult({required this.saved, required this.message});

  final bool saved;
  final String message;
}

class _ManualCoordinatesSheet extends StatefulWidget {
  const _ManualCoordinatesSheet({required this.place, required this.onSave});

  final WantToGoPlace place;
  final Future<bool> Function(double latitude, double longitude) onSave;

  @override
  State<_ManualCoordinatesSheet> createState() =>
      _ManualCoordinatesSheetState();
}

class _ManualCoordinatesSheetState extends State<_ManualCoordinatesSheet> {
  final _formKey = GlobalKey<FormState>();
  final _latitudeController = TextEditingController();
  final _longitudeController = TextEditingController();
  bool _isSaving = false;
  bool _wasSaved = false;

  @override
  void dispose() {
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });
    final saved = await widget.onSave(
      _parseCoordinate(_latitudeController.text),
      _parseCoordinate(_longitudeController.text),
    );
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
              'The link did not provide a precise location. Paste the latitude and longitude from Google Maps.',
              style: TextStyle(color: Color(0xFF58717E)),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _latitudeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Latitude',
                hintText: 'e.g. 44.494887',
              ),
              validator: _validateManualLatitude,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _longitudeController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Longitude',
                hintText: 'e.g. 11.342616',
              ),
              validator: _validateManualLongitude,
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
                    : const Icon(Icons.my_location_rounded),
                label: Text(_isSaving ? 'Saving…' : 'Save map location'),
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
  final _mapsUrlController = TextEditingController();
  final _noteController = TextEditingController();
  final _nameFocusNode = FocusNode();
  bool _isSaving = false;
  bool _showPreciseMapsLink = false;
  _WantToGoAddResult? _result;

  @override
  void dispose() {
    _nameController.dispose();
    _cityController.dispose();
    _mapsUrlController.dispose();
    _noteController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSaving || !_formKey.currentState!.validate()) return;

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
        note: _noteController.text,
      ),
    );
    if (!mounted) return;

    setState(() {
      _isSaving = false;
      _result = result;
    });

    if (!result.saved) return;

    _nameController.clear();
    _mapsUrlController.clear();
    _noteController.clear();
    setState(() {
      _showPreciseMapsLink = false;
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
                'Only name and city are required. The form stays open after each save.',
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: _nameController,
                focusNode: _nameFocusNode,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: _required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _cityController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'City'),
                validator: _required,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _showPreciseMapsLink = !_showPreciseMapsLink;
                    });
                  },
                  icon: Icon(
                    _showPreciseMapsLink
                        ? Icons.expand_less_rounded
                        : Icons.link_rounded,
                  ),
                  label: Text(
                    _showPreciseMapsLink
                        ? 'Hide precise Google Maps link'
                        : 'Add a precise Google Maps link (optional)',
                  ),
                ),
              ),
              if (_showPreciseMapsLink) ...[
                TextFormField(
                  controller: _mapsUrlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Google Maps URL',
                    helperText: 'Optional. Otherwise a search link is generated automatically.',
                  ),
                  validator: _validateOptionalUrl,
                ),
                const SizedBox(height: 12),
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
                  onPressed: _isSaving ? null : _submit,
                  icon: _isSaving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.explore_rounded),
                  label: Text(_isSaving ? 'Saving…' : 'Add and continue'),
                ),
              ),
            ],
          ),
        ),
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
        leading: Text(
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
    required this.onOpenMaps,
    required this.onRemove,
  });

  final WantToGoPlace place;
  final VoidCallback? onLocate;
  final bool isOnMap;
  final VoidCallback? onOpenMaps;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final subtitle = [place.city, if (place.note != null) place.note!].join(' · ');

    return Card(
      elevation: 0,
      child: ListTile(
        leading: const Icon(Icons.explore_outlined, color: Color(0xFF137DB8)),
        title: Text(place.name),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onLocate != null)
              IconButton(
                tooltip: isOnMap
                    ? 'Update map location from link'
                    : 'Try to add to the map',
                onPressed: onLocate,
                icon: Icon(
                  isOnMap
                      ? Icons.my_location_rounded
                      : Icons.add_location_alt_outlined,
                ),
              ),
            if (onOpenMaps != null)
              IconButton(
                tooltip: 'Open in Google Maps',
                onPressed: onOpenMaps,
                icon: const Icon(Icons.map_outlined),
              ),
            IconButton(
              tooltip: 'Remove from Want to go',
              onPressed: onRemove,
              icon: const Icon(Icons.delete_outline_rounded),
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

String? _validateOptionalUrl(String? value) {
  if (value == null || value.trim().isEmpty) return null;

  final uri = Uri.tryParse(value.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return 'Enter a valid link.';
  }
  return null;
}

String? _validateManualLatitude(String? value) {
  final coordinate = _tryParseCoordinate(value);
  if (coordinate == null || coordinate < -90 || coordinate > 90) {
    return 'Enter a latitude between -90 and 90.';
  }
  return null;
}

String? _validateManualLongitude(String? value) {
  final coordinate = _tryParseCoordinate(value);
  if (coordinate == null || coordinate < -180 || coordinate > 180) {
    return 'Enter a longitude between -180 and 180.';
  }
  return null;
}

double _parseCoordinate(String value) {
  return double.parse(value.trim().replaceAll(',', '.'));
}

double? _tryParseCoordinate(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  return double.tryParse(value.trim().replaceAll(',', '.'));
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
