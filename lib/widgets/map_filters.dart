import 'package:flutter/material.dart';
import 'package:my_map_app/widgets/glass_panel.dart';

class MapFilters extends StatelessWidget {
  const MapFilters({
    required this.selectedCategories,
    required this.ratingRange,
    required this.selectedPriceLevels,
    required this.selectedVibes,
    required this.availableVibes,
    required this.availableRatings,
    required this.showOnlyWantToGo,
    required this.selectedWantToGoCities,
    required this.availableWantToGoCities,
    required this.wantToGoCount,
    required this.onCategoriesChanged,
    required this.onRatingRangeChanged,
    required this.onPriceLevelsChanged,
    required this.onVibesChanged,
    required this.onWantToGoOnlyChanged,
    required this.onWantToGoCitiesChanged,
    required this.onReset,
    super.key,
  });

  final Set<String> selectedCategories;
  final RangeValues? ratingRange;
  final Set<int> selectedPriceLevels;
  final Set<String> selectedVibes;
  final List<String> availableVibes;
  final List<int> availableRatings;
  final bool showOnlyWantToGo;
  final Set<String> selectedWantToGoCities;
  final List<String> availableWantToGoCities;
  final int wantToGoCount;
  final ValueChanged<Set<String>> onCategoriesChanged;
  final ValueChanged<RangeValues?> onRatingRangeChanged;
  final ValueChanged<Set<int>> onPriceLevelsChanged;
  final ValueChanged<Set<String>> onVibesChanged;
  final ValueChanged<bool> onWantToGoOnlyChanged;
  final ValueChanged<Set<String>> onWantToGoCitiesChanged;
  final VoidCallback onReset;

  bool get _hasActiveFilters {
    return selectedCategories.isNotEmpty ||
        ratingRange != null ||
        selectedPriceLevels.isNotEmpty ||
        selectedVibes.isNotEmpty ||
        showOnlyWantToGo;
  }

  String get _categoryLabel {
    return selectedCategories.isEmpty
        ? 'Category'
        : 'Category · ${selectedCategories.length}';
  }

  String get _ratingLabel {
    if (ratingRange == null) return 'Rating';

    final start = ratingRange!.start.round();
    final end = ratingRange!.end.round();
    return start == end ? '$start/10' : '$start–$end/10';
  }

  String get _priceLabel {
    return selectedPriceLevels.isEmpty
        ? 'Price'
        : 'Price · ${selectedPriceLevels.length}';
  }

  String get _wantToGoLabel {
    if (!showOnlyWantToGo) {
      return wantToGoCount == 0 ? 'Want to go' : 'Want to go $wantToGoCount';
    }
    if (selectedWantToGoCities.isEmpty) return 'Want to go';
    if (selectedWantToGoCities.length == 1) {
      return selectedWantToGoCities.single;
    }
    return 'Cities · ${selectedWantToGoCities.length}';
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
                isActive: selectedCategories.isNotEmpty,
                onTap: () => _showCategoryPicker(context),
              ),
            ),
            const SizedBox(width: 3),
            SizedBox(
              width: 112,
              child: _FilterButton(
                icon: Icons.star_rounded,
                label: _ratingLabel,
                isActive: ratingRange != null,
                onTap: () => _showRatingPicker(context),
              ),
            ),
            const SizedBox(width: 3),
            SizedBox(
              width: 104,
              child: _FilterButton(
                icon: Icons.payments_rounded,
                label: _priceLabel,
                isActive: selectedPriceLevels.isNotEmpty,
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
              width: showOnlyWantToGo && selectedWantToGoCities.length == 1
                  ? 130
                  : wantToGoCount == 0
                  ? 108
                  : 126,
              child: _FilterButton(
                icon: showOnlyWantToGo
                    ? Icons.explore_rounded
                    : Icons.explore_outlined,
                label: _wantToGoLabel,
                isActive: showOnlyWantToGo,
                onTap: wantToGoCount == 0
                    ? () {
                        ScaffoldMessenger.of(context)
                          ..hideCurrentSnackBar()
                          ..showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Open a place and tap Want to go to add it here.',
                              ),
                            ),
                          );
                      }
                    : () => _showWantToGoPicker(context),
              ),
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(width: 3),
              Tooltip(
                message: 'Reset filters',
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
    final localSelection = selectedCategories.toSet();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _FilterSheet(
              title: 'Choose categories',
              subtitle: 'You can select more than one.',
              footer: _MultiSelectFooter(
                onClear: () {
                  setSheetState(localSelection.clear);
                  onCategoriesChanged(const {});
                },
                onDone: () => Navigator.pop(sheetContext),
              ),
              children: _categoryOptions
                  .where((option) => option.value != null)
                  .map((option) {
                    final category = option.value!;
                    return FilterChip(
                      selected: localSelection.contains(category),
                      avatar: Text(option.emoji),
                      label: Text(option.label),
                      onSelected: (isSelected) {
                        setSheetState(() {
                          if (isSelected) {
                            localSelection.add(category);
                          } else {
                            localSelection.remove(category);
                          }
                        });
                        onCategoriesChanged(Set.unmodifiable(localSelection));
                      },
                    );
                  })
                  .toList(),
            );
          },
        );
      },
    );
  }

  Future<void> _showRatingPicker(BuildContext context) {
    if (availableRatings.isEmpty) return Future.value();

    final lowestRating = availableRatings.reduce(
      (first, second) => first < second ? first : second,
    );
    final highestRating = availableRatings.reduce(
      (first, second) => first > second ? first : second,
    );
    var localRange = ratingRange ??
        RangeValues(lowestRating.toDouble(), highestRating.toDouble());

    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final start = localRange.start.round();
            final end = localRange.end.round();
            return _FilterSheet(
              title: 'Rating range',
              subtitle: 'Show places rated from $start to $end out of 10.',
              footer: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      onRatingRangeChanged(null);
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('All ratings'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () {
                      final includesAllRatings =
                          localRange.start == lowestRating.toDouble() &&
                          localRange.end == highestRating.toDouble();
                      onRatingRangeChanged(
                        includesAllRatings ? null : localRange,
                      );
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('Apply'),
                  ),
                ],
              ),
              children: [
                SizedBox(
                  width: MediaQuery.sizeOf(context).width - 40,
                  child: Column(
                    children: [
                      Text(
                        '$start/10  –  $end/10',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      RangeSlider(
                        values: localRange,
                        min: lowestRating.toDouble(),
                        max: highestRating.toDouble(),
                        divisions: highestRating - lowestRating,
                        labels: RangeLabels('$start/10', '$end/10'),
                        onChanged: (values) {
                          setSheetState(() {
                            localRange = values;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _showPricePicker(BuildContext context) {
    final localSelection = selectedPriceLevels.toSet();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _FilterSheet(
              title: 'Choose price ranges',
              subtitle: 'You can select more than one average spend range.',
              footer: _MultiSelectFooter(
                onClear: () {
                  setSheetState(localSelection.clear);
                  onPriceLevelsChanged(const {});
                },
                onDone: () => Navigator.pop(sheetContext),
              ),
              children: _priceOptions.map((price) {
                return FilterChip(
                  selected: localSelection.contains(price),
                  avatar: const Icon(Icons.payments, size: 18),
                  label: Text(_priceRangeLabel(price)),
                  onSelected: (isSelected) {
                    setSheetState(() {
                      if (isSelected) {
                        localSelection.add(price);
                      } else {
                        localSelection.remove(price);
                      }
                    });
                    onPriceLevelsChanged(Set.unmodifiable(localSelection));
                  },
                );
              }).toList(),
            );
          },
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
              title: 'Choose vibes',
              subtitle: 'You can select more than one.',
              footer: _MultiSelectFooter(
                onClear: () {
                  setSheetState(localSelection.clear);
                  onVibesChanged(const {});
                },
                onDone: () => Navigator.pop(sheetContext),
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

  Future<void> _showWantToGoPicker(BuildContext context) {
    final localSelection = selectedWantToGoCities.toSet();

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _FilterSheet(
              title: 'Want to go',
              subtitle: 'Choose cities to show only places you want to try.',
              footer: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      onWantToGoOnlyChanged(false);
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('Hide'),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      setSheetState(localSelection.clear);
                      onWantToGoCitiesChanged(const {});
                    },
                    child: const Text('All cities'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      onWantToGoCitiesChanged(
                        Set.unmodifiable(localSelection),
                      );
                      Navigator.pop(sheetContext);
                    },
                    child: const Text('Done'),
                  ),
                ],
              ),
              children: availableWantToGoCities.map((city) {
                return FilterChip(
                  selected: localSelection.contains(city),
                  avatar: const Icon(Icons.location_city_rounded, size: 18),
                  label: Text(city),
                  onSelected: (isSelected) {
                    setSheetState(() {
                      if (isSelected) {
                        localSelection.add(city);
                      } else {
                        localSelection.remove(city);
                      }
                    });
                    onWantToGoCitiesChanged(Set.unmodifiable(localSelection));
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

class _MultiSelectFooter extends StatelessWidget {
  const _MultiSelectFooter({required this.onClear, required this.onDone});

  final VoidCallback onClear;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        TextButton(onPressed: onClear, child: const Text('Clear')),
        const Spacer(),
        FilledButton(onPressed: onDone, child: const Text('Done')),
      ],
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

String _priceRangeLabel(int priceLevel) {
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

String _displayVibe(String vibe) {
  final normalized = vibe.replaceAll('_', ' ').replaceAll('-', ' ');
  return '${normalized[0].toUpperCase()}${normalized.substring(1)}';
}

const _categoryOptions = [
  _CategoryOption(
    value: null,
    shortLabel: 'Category',
    label: 'All',
    emoji: '🗺️',
  ),
  _CategoryOption(
    value: 'restaurant',
    shortLabel: 'Restaurants',
    label: 'Restaurants',
    emoji: '🍝',
  ),
  _CategoryOption(
    value: 'sushi',
    shortLabel: 'Sushi',
    label: 'Sushi',
    emoji: '🍣',
  ),
  _CategoryOption(
    value: 'chinese',
    shortLabel: 'Chinese',
    label: 'Chinese',
    emoji: '🥡',
  ),
  _CategoryOption(
    value: 'indian',
    shortLabel: 'Indian',
    label: 'Indian',
    emoji: '🍛',
  ),
  _CategoryOption(
    value: 'pizzeria',
    shortLabel: 'Pizzeria',
    label: 'Pizzeria',
    emoji: '🍕',
  ),
  _CategoryOption(
    value: 'panzerotteria',
    shortLabel: 'Panzerotti',
    label: 'Panzerotteria',
    emoji: '🥟',
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
    shortLabel: 'Bakery',
    label: 'Savory bakery',
    emoji: '🥪',
  ),
  _CategoryOption(
    value: 'bakery_sweet',
    shortLabel: 'Pastry',
    label: 'Pastry shop',
    emoji: '🍰',
  ),
  _CategoryOption(
    value: 'gelateria',
    shortLabel: 'Gelateria',
    label: 'Gelateria',
    emoji: '🍦',
  ),
];

const _priceOptions = <int>[1, 2, 3, 4, 5];
