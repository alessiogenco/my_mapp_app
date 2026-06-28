import 'package:flutter/material.dart';
import 'package:my_map_app/models/place_area.dart';
import 'package:my_map_app/widgets/glass_panel.dart';

class MapFilters extends StatelessWidget {
  const MapFilters({
    required this.selectedCategory,
    required this.selectedArea,
    required this.maxPriceLevel,
    required this.selectedVibes,
    required this.availableVibes,
    required this.availableAreas,
    required this.showOnlySaved,
    required this.savedCount,
    required this.onCategoryChanged,
    required this.onAreaChanged,
    required this.onPriceChanged,
    required this.onVibesChanged,
    required this.onSavedOnlyChanged,
    required this.onReset,
    super.key,
  });

  final String? selectedCategory;
  final String? selectedArea;
  final int? maxPriceLevel;
  final Set<String> selectedVibes;
  final List<String> availableVibes;
  final List<String> availableAreas;
  final bool showOnlySaved;
  final int savedCount;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onAreaChanged;
  final ValueChanged<int?> onPriceChanged;
  final ValueChanged<Set<String>> onVibesChanged;
  final ValueChanged<bool> onSavedOnlyChanged;
  final VoidCallback onReset;

  bool get _hasActiveFilters {
    return selectedCategory != null ||
        selectedArea != null ||
        maxPriceLevel != null ||
        selectedVibes.isNotEmpty ||
        showOnlySaved;
  }

  String get _categoryLabel {
    return _categoryOptions
        .firstWhere((option) => option.value == selectedCategory)
        .shortLabel;
  }

  String get _areaLabel {
    return selectedArea == null ? 'Area' : labelForArea(selectedArea!);
  }

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            SizedBox(
              width: 118,
              child: _FilterButton(
                icon: Icons.restaurant_menu_rounded,
                label: _categoryLabel,
                isActive: selectedCategory != null,
                onTap: () => _showCategoryPicker(context),
              ),
            ),
            const SizedBox(width: 3),
            SizedBox(
              width: 112,
              child: _FilterButton(
                icon: Icons.map_rounded,
                label: _areaLabel,
                isActive: selectedArea != null,
                onTap: () => _showAreaPicker(context),
              ),
            ),
            const SizedBox(width: 3),
            SizedBox(
              width: 104,
              child: _FilterButton(
                icon: Icons.payments_rounded,
                label: maxPriceLevel == null
                    ? 'Prezzo'
                    : '≤ ${_priceLabel(maxPriceLevel!)}',
                isActive: maxPriceLevel != null,
                onTap: () => _showPricePicker(context),
              ),
            ),
            const SizedBox(width: 3),
            SizedBox(
              width: 104,
              child: _FilterButton(
                icon: Icons.auto_awesome_rounded,
                label: selectedVibes.isEmpty
                    ? 'Vibes'
                    : 'Vibes · ${selectedVibes.length}',
                isActive: selectedVibes.isNotEmpty,
                onTap: () => _showVibesPicker(context),
              ),
            ),
            const SizedBox(width: 3),
            SizedBox(
              width: savedCount == 0 ? 104 : 116,
              child: _FilterButton(
                icon: showOnlySaved
                    ? Icons.bookmark_rounded
                    : Icons.bookmark_border_rounded,
                label: savedCount == 0 ? 'Salvati' : 'Salvati $savedCount',
                isActive: showOnlySaved,
                onTap: savedCount == 0
                    ? () {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Apri un locale e tocca Salva per aggiungerlo.',
                              ),
                            ),
                          );
                      }
                    : () => onSavedOnlyChanged(!showOnlySaved),
              ),
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(width: 3),
              Tooltip(
                message: 'Azzera filtri',
                child: IconButton.filledTonal(
                  onPressed: onReset,
                  icon: const Icon(Icons.close_rounded, size: 19),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showCategoryPicker(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _FilterSheet(
          title: 'Scegli una categoria',
          subtitle: 'Mostra solo i locali che ti interessano.',
          children: _categoryOptions.map((option) {
            return ChoiceChip(
              selected: selectedCategory == option.value,
              avatar: Text(option.emoji),
              label: Text(option.label),
              onSelected: (_) {
                onCategoryChanged(option.value);
                Navigator.pop(sheetContext);
              },
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _showAreaPicker(BuildContext context) {
    final options = <String?>[null, ...availableAreas];

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _FilterSheet(
          title: 'Scegli un’area',
          subtitle: 'Filtra i locali in base alla zona.',
          children: options.map((area) {
            return ChoiceChip(
              selected: selectedArea == area,
              avatar: Icon(
                area == null ? Icons.all_inclusive_rounded : Icons.map,
                size: 18,
              ),
              label: Text(area == null ? 'Tutte' : labelForArea(area)),
              onSelected: (_) {
                onAreaChanged(area);
                Navigator.pop(sheetContext);
              },
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _showPricePicker(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return _FilterSheet(
          title: 'Prezzo massimo',
          subtitle: 'Mostra i locali entro il budget selezionato.',
          children: _priceOptions.map((price) {
            return ChoiceChip(
              selected: maxPriceLevel == price,
              avatar: Icon(
                price == null ? Icons.all_inclusive_rounded : Icons.payments,
                size: 18,
              ),
              label: Text(price == null ? 'Tutti' : _priceLabel(price)),
              onSelected: (_) {
                onPriceChanged(price);
                Navigator.pop(sheetContext);
              },
            );
          }).toList(),
        );
      },
    );
  }

  Future<void> _showVibesPicker(BuildContext context) {
    final localSelection = selectedVibes.toSet();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _FilterSheet(
              title: 'Scegli le vibes',
              subtitle: 'Puoi selezionarne più di una.',
              footer: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(sheetContext),
                  child: const Text('Fatto'),
                ),
              ),
              children: availableVibes.map((vibe) {
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
                    onVibesChanged(Set.unmodifiable(localSelection));
                  },
                );
              }).toList(),
            );
          },
        );
      },
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final activeColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: isActive ? activeColor : Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 7),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isActive ? Colors.white : const Color(0xFF205A78),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? Colors.white : const Color(0xFF173F54),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 1),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: isActive
                    ? Colors.white.withValues(alpha: 0.88)
                    : const Color(0xFF527789),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({
    required this.title,
    required this.subtitle,
    required this.children,
    this.footer,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: Color(0xFFF5FBFE),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
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
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF58717E),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(spacing: 9, runSpacing: 9, children: children),
              if (footer != null) ...[const SizedBox(height: 20), footer!],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryOption {
  const _CategoryOption({
    required this.value,
    required this.shortLabel,
    required this.label,
    required this.emoji,
  });

  final String? value;
  final String shortLabel;
  final String label;
  final String emoji;
}

String _priceLabel(int priceLevel) {
  return List.filled(priceLevel, '€').join();
}

String _displayVibe(String vibe) {
  final normalized = vibe.replaceAll('_', ' ').replaceAll('-', ' ');
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

const _categoryOptions = [
  _CategoryOption(
    value: null,
    shortLabel: 'Categoria',
    label: 'Tutte',
    emoji: '🗺️',
  ),
  _CategoryOption(
    value: 'restaurant',
    shortLabel: 'Ristoranti',
    label: 'Ristoranti',
    emoji: '🍝',
  ),
  _CategoryOption(
    value: 'steakhouse',
    shortLabel: 'Steakhouse',
    label: 'Steakhouse',
    emoji: '🥩',
  ),
  _CategoryOption(value: 'pub', shortLabel: 'Pub', label: 'Pub', emoji: '🍔'),
  _CategoryOption(
    value: 'coffee_bar',
    shortLabel: 'Coffee bar',
    label: 'Coffee bar',
    emoji: '☕',
  ),
  _CategoryOption(
    value: 'cocktail_bar',
    shortLabel: 'Cocktail',
    label: 'Cocktail bar',
    emoji: '🍸',
  ),
  _CategoryOption(
    value: 'beer_bar',
    shortLabel: 'Beer bar',
    label: 'Beer bar',
    emoji: '🍺',
  ),
  _CategoryOption(
    value: 'bakery_savory',
    shortLabel: 'Bakery salata',
    label: 'Bakery salata',
    emoji: '🥪',
  ),
  _CategoryOption(
    value: 'bakery_sweet',
    shortLabel: 'Pasticceria',
    label: 'Bakery dolce',
    emoji: '🍰',
  ),
  _CategoryOption(
    value: 'gelateria',
    shortLabel: 'Gelateria',
    label: 'Gelateria',
    emoji: '🍦',
  ),
];

const _priceOptions = <int?>[null, 1, 2, 3];
