import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_map_app/models/place.dart';
import 'package:my_map_app/models/place_area.dart';
import 'package:my_map_app/models/place_category.dart';
import 'package:my_map_app/services/maps_launcher_service.dart';
import 'package:my_map_app/social/google_place_search_service.dart';
import 'package:my_map_app/widgets/personal_place_rating_card.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showPlaceDetailsSheet(
  BuildContext context,
  Place place, {
  required bool isWantToGo,
  required ValueChanged<bool> onWantToGoChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => PlaceDetailsSheet(
      place: place,
      initialIsWantToGo: isWantToGo,
      onWantToGoChanged: onWantToGoChanged,
    ),
  );
}

class PlaceDetailsSheet extends StatefulWidget {
  const PlaceDetailsSheet({
    required this.place,
    required this.initialIsWantToGo,
    required this.onWantToGoChanged,
    this.mapsLauncher = const MapsLauncherService(),
    super.key,
  });

  final Place place;
  final bool initialIsWantToGo;
  final ValueChanged<bool> onWantToGoChanged;
  final MapsLauncherService mapsLauncher;

  @override
  State<PlaceDetailsSheet> createState() => _PlaceDetailsSheetState();
}

class _PlaceDetailsSheetState extends State<PlaceDetailsSheet> {
  late bool _isWantToGo;
  final _googlePlaceSearchService = const GooglePlaceSearchService();
  String? _businessStatus;
  bool? _isOpenNow;
  String? _nextOpenTime;
  String? _nextCloseTime;
  int? _utcOffsetMinutes;
  String? _businessStatusUnavailableMessage;
  bool _isLoadingBusinessStatus = false;

  @override
  void initState() {
    super.initState();
    _isWantToGo = widget.initialIsWantToGo;
    unawaited(_loadBusinessStatus());
  }

  Future<void> _loadBusinessStatus() async {
    final placeId = widget.place.googlePlaceId?.trim() ?? '';
    if (placeId.isEmpty) return;

    setState(() => _isLoadingBusinessStatus = true);
    try {
      final details = await _googlePlaceSearchService.loadPlaceDetails(
        placeId: placeId,
      );
      if (!mounted) return;
      setState(() {
        _businessStatus = details.businessStatus;
        _isOpenNow = details.isOpenNow;
        _nextOpenTime = details.nextOpenTime;
        _nextCloseTime = details.nextCloseTime;
        _utcOffsetMinutes = details.utcOffsetMinutes;
        _businessStatusUnavailableMessage = details.businessStatus == null
            ? 'Live opening hours are unavailable for this place.'
            : null;
      });
    } on GooglePlaceSearchException catch (error) {
      if (!mounted) return;
      setState(() => _businessStatusUnavailableMessage = error.message);
    } finally {
      if (mounted) {
        setState(() => _isLoadingBusinessStatus = false);
      }
    }
  }

  Future<void> _openGoogleMaps(BuildContext context) async {
    final opened = await widget.mapsLauncher.openPlace(widget.place);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  Future<void> _openWebsite(BuildContext context) async {
    final websiteUrl = widget.place.websiteUrl;
    if (websiteUrl == null || websiteUrl.isEmpty) {
      return;
    }

    final opened = await launchUrl(
      Uri.parse(websiteUrl),
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open website.')));
    }
  }

  Future<void> _openInstagram(BuildContext context) async {
    final instagramUrl = widget.place.instagramUrl;
    if (instagramUrl == null || instagramUrl.isEmpty) {
      return;
    }

    final opened = await launchUrl(
      Uri.parse(instagramUrl),
      mode: LaunchMode.externalApplication,
    );

    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Instagram.')),
      );
    }
  }

  void _toggleWantToGo() {
    setState(() {
      _isWantToGo = !_isWantToGo;
    });
    widget.onWantToGoChanged(_isWantToGo);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final place = widget.place;

    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFFF8FBFD),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
              const SizedBox(height: 14),
              _PlaceHero(place: place),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Flexible(
                    child: Text(
                      place.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF102F40),
                      ),
                    ),
                  ),
                  if (_isLoadingBusinessStatus) ...[
                    const SizedBox(width: 8),
                    const _BusinessStatusLoadingBadge(),
                  ] else if (_businessStatus != null) ...[
                    const SizedBox(width: 8),
                    Align(
                      alignment: Alignment.topRight,
                      child: _BusinessStatusBadge(
                        status: _businessStatus!,
                        isOpenNow: _isOpenNow,
                        nextOpenTime: _nextOpenTime,
                        nextCloseTime: _nextCloseTime,
                        utcOffsetMinutes: _utcOffsetMinutes,
                      ),
                    ),
                  ] else if (_businessStatusUnavailableMessage != null) ...[
                    const SizedBox(width: 8),
                    Align(
                      alignment: Alignment.topRight,
                      child: _BusinessStatusUnavailableBadge(
                        message: _businessStatusUnavailableMessage!,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoPill(
                    icon: Icons.restaurant_menu_rounded,
                    label: labelForCategory(place.category),
                  ),
                  _InfoPill(
                    icon: Icons.map_rounded,
                    label: labelForArea(place.area),
                  ),
                  _InfoPill(
                    icon: Icons.star_rounded,
                    label: '${place.rating}/10',
                    iconColor: const Color(0xFFF6A800),
                  ),
                  _InfoPill(
                    icon: Icons.sell_outlined,
                    label: priceLabelFor(place.priceLevel, place.currencyCode),
                  ),
                ],
              ),
              if (place.ratingDetails.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Detailed rating',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: place.ratingDetails.entries.map((entry) {
                    return _InfoPill(
                      icon: Icons.star_half_rounded,
                      label: '${_displayVibe(entry.key)} ${entry.value}/10',
                      iconColor: const Color(0xFFF6A800),
                    );
                  }).toList(),
                ),
              ],
              if (place.vibes.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Vibes',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: place.vibes
                      .map(
                        (vibe) => Chip(
                          label: Text(_displayVibe(vibe)),
                          backgroundColor: const Color(0xFFEAF5FB),
                          side: BorderSide.none,
                        ),
                      )
                      .toList(),
                ),
              ],
              if (place.notes.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  place.notes,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    height: 1.45,
                    color: const Color(0xFF3B515E),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              PersonalPlaceRatingCard(place: place),
              if (place.instagramUrl != null &&
                  place.instagramUrl!.isNotEmpty) ...[
                const SizedBox(height: 18),
                Text(
                  'Social',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _openInstagram(context),
                  icon: const Icon(Icons.camera_alt_rounded),
                  label: const Text('Instagram'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _toggleWantToGo,
                  icon: Icon(
                    _isWantToGo
                        ? Icons.explore_rounded
                        : Icons.explore_outlined,
                  ),
                  label: Text(
                    _isWantToGo ? 'On your Want to go list' : 'Want to go',
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (place.websiteUrl != null && place.websiteUrl!.isNotEmpty) ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _openWebsite(context),
                    icon: const Icon(Icons.language_rounded),
                    label: const Text('Open website'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _openGoogleMaps(context),
                  icon: const Icon(Icons.map_rounded),
                  label: const Text('Open in Google Maps'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceHero extends StatelessWidget {
  const _PlaceHero({required this.place});

  final Place place;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: double.infinity,
        height: 180,
        child: place.photoAsset == null
            ? _CategoryPlaceholder(category: place.category)
            : Image.asset(
                place.photoAsset!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) =>
                    _CategoryPlaceholder(category: place.category),
              ),
      ),
    );
  }
}

class _CategoryPlaceholder extends StatelessWidget {
  const _CategoryPlaceholder({required this.category});

  final String category;

  @override
  Widget build(BuildContext context) {
    final colors = _colorsForCategory(category);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -42,
            child: Icon(
              Icons.location_on_rounded,
              size: 190,
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                category == 'kebab' || category == 'fish_and_chips'
                    ? Image.asset(
                        category == 'fish_and_chips'
                            ? 'assets/markers/fish_and_chips.png'
                            : 'assets/markers/turkish_doner.png',
                        width: category == 'fish_and_chips' ? 96 : 58,
                        height: category == 'fish_and_chips' ? 96 : 58,
                      )
                    : Text(
                        emojiForCategory(category),
                        style: const TextStyle(fontSize: 58),
                      ),
                const SizedBox(height: 8),
                Text(
                  labelForCategory(category),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Representative image',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BusinessStatusLoadingBadge extends StatelessWidget {
  const _BusinessStatusLoadingBadge();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 24,
      width: 24,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _BusinessStatusUnavailableBadge extends StatelessWidget {
  const _BusinessStatusUnavailableBadge({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: message,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F5F8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD3E1E8)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.info_outline_rounded,
              size: 17,
              color: Color(0xFF58717E),
            ),
            SizedBox(width: 5),
            Text(
              'Live status unavailable',
              style: TextStyle(
                color: Color(0xFF58717E),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BusinessStatusBadge extends StatelessWidget {
  const _BusinessStatusBadge({
    required this.status,
    required this.isOpenNow,
    required this.nextOpenTime,
    required this.nextCloseTime,
    required this.utcOffsetMinutes,
  });

  final String status;
  final bool? isOpenNow;
  final String? nextOpenTime;
  final String? nextCloseTime;
  final int? utcOffsetMinutes;

  @override
  Widget build(BuildContext context) {
    final presentation = _presentationFor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: presentation.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: presentation.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(presentation.icon, size: 17, color: presentation.foreground),
          const SizedBox(width: 5),
          Text(
            presentation.label,
            style: TextStyle(
              color: presentation.foreground,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  _BusinessStatusPresentation _presentationFor(BuildContext context) {
    if (status == 'OPERATIONAL' && isOpenNow == true) {
      final closingTime = _formatPlaceTime(context, nextCloseTime);
      return _BusinessStatusPresentation(
        label: closingTime == null
            ? 'Open now'
            : 'Open · closes at $closingTime',
        icon: Icons.check_circle_rounded,
        foreground: const Color(0xFF137333),
        background: const Color(0xFFE6F4EA),
        border: const Color(0xFFA8DAB5),
      );
    }
    if (status == 'OPERATIONAL' && isOpenNow == false) {
      final openingTime = _formatPlaceTime(context, nextOpenTime);
      return _BusinessStatusPresentation(
        label: openingTime == null
            ? 'Closed now'
            : 'Closed · opens at $openingTime',
        icon: Icons.schedule_rounded,
        foreground: const Color(0xFFB3261E),
        background: const Color(0xFFFCE8E6),
        border: const Color(0xFFF3B5B1),
      );
    }

    return switch (status) {
      'CLOSED_TEMPORARILY' => _BusinessStatusPresentation(
        label: 'Temporarily closed',
        icon: Icons.error_rounded,
        foreground: const Color(0xFFB3261E),
        background: const Color(0xFFFCE8E6),
        border: const Color(0xFFF3B5B1),
      ),
      'CLOSED_PERMANENTLY' => _BusinessStatusPresentation(
        label: 'Permanently closed',
        icon: Icons.cancel_rounded,
        foreground: const Color(0xFFB3261E),
        background: const Color(0xFFFCE8E6),
        border: const Color(0xFFF3B5B1),
      ),
      'FUTURE_OPENING' => _BusinessStatusPresentation(
        label: 'Opening soon',
        icon: Icons.schedule_rounded,
        foreground: const Color(0xFF825500),
        background: const Color(0xFFFFF3CD),
        border: const Color(0xFFF2D68A),
      ),
      _ => _BusinessStatusPresentation(
        label: 'Opening hours unavailable',
        icon: Icons.info_outline_rounded,
        foreground: const Color(0xFF58717E),
        background: const Color(0xFFF0F5F8),
        border: const Color(0xFFD3E1E8),
      ),
    };
  }

  String? _formatPlaceTime(BuildContext context, String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return null;
    final time = DateTime.tryParse(timestamp);
    if (time == null) return null;
    final placeTime = utcOffsetMinutes == null
        ? time.toLocal()
        : time.toUtc().add(Duration(minutes: utcOffsetMinutes!));
    return MaterialLocalizations.of(context).formatTimeOfDay(
      TimeOfDay.fromDateTime(placeTime),
      alwaysUse24HourFormat: true,
    );
  }
}

class _BusinessStatusPresentation {
  const _BusinessStatusPresentation({
    required this.label,
    required this.icon,
    required this.foreground,
    required this.background,
    required this.border,
  });

  final String label;
  final IconData icon;
  final Color foreground;
  final Color background;
  final Color border;
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    this.iconColor = const Color(0xFF1687C9),
  });

  final IconData icon;
  final String label;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDDE9EF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

List<Color> _colorsForCategory(String category) {
  return switch (category) {
    'coffee_bar' => const [Color(0xFF8A5A44), Color(0xFFD5A06F)],
    'fish_and_chips' => const [Color(0xFF277E9C), Color(0xFF74C5C3)],
    'sushi' => const [Color(0xFF237E83), Color(0xFF75C5C2)],
    'japanese' => const [Color(0xFF516A91), Color(0xFF9AB4D5)],
    'chinese' ||
    'ramen' ||
    'indian' => const [Color(0xFFB85A38), Color(0xFFE6A95C)],
    'cocktail_bar' ||
    'beer_bar' ||
    'pub' => const [Color(0xFF5744A1), Color(0xFFB46EC4)],
    'bakery_sweet' ||
    'bakery_savory' => const [Color(0xFFE07A64), Color(0xFFF3B46F)],
    'gelateria' => const [Color(0xFF4D9EB4), Color(0xFF7FD0C5)],
    _ => const [Color(0xFF1687C9), Color(0xFF53B9C9)],
  };
}

String _displayVibe(String vibe) {
  final normalized = vibe.replaceAll('_', ' ').replaceAll('-', ' ');
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}
