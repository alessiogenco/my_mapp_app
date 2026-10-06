import 'package:flutter/material.dart';
import 'package:my_map_app/models/place.dart';
import 'package:my_map_app/models/place_area.dart';
import 'package:my_map_app/models/place_category.dart';
import 'package:my_map_app/services/maps_launcher_service.dart';
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

  @override
  void initState() {
    super.initState();
    _isWantToGo = widget.initialIsWantToGo;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open website.')),
      );
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
              Text(
                place.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF102F40),
                ),
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
                    icon: Icons.euro_rounded,
                    label: _priceLabel(place.priceLevel),
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
                Text(
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
    'sushi' => const [Color(0xFF237E83), Color(0xFF75C5C2)],
    'chinese' || 'indian' => const [Color(0xFFB85A38), Color(0xFFE6A95C)],
    'cocktail_bar' || 'beer_bar' || 'pub' => const [
      Color(0xFF5744A1),
      Color(0xFFB46EC4),
    ],
    'bakery_sweet' || 'bakery_savory' => const [
      Color(0xFFE07A64),
      Color(0xFFF3B46F),
    ],
    'gelateria' => const [Color(0xFF4D9EB4), Color(0xFF7FD0C5)],
    _ => const [Color(0xFF1687C9), Color(0xFF53B9C9)],
  };
}

String _displayVibe(String vibe) {
  final normalized = vibe.replaceAll('_', ' ').replaceAll('-', ' ');
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

String _priceLabel(int priceLevel) {
  final symbols = List.filled(priceLevel, '€').join();
  final range = switch (priceLevel) {
    1 => '0–15€',
    2 => '15–35€',
    3 => '35–70€',
    4 => '70–100€',
    _ => '100€+',
  };

  return '$symbols · $range';
}
