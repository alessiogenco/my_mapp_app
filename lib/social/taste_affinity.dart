import 'dart:math' as math;

import 'package:my_map_app/models/place.dart';
import 'package:my_map_app/social/social_place_rating.dart';

/// Ratings belonging to one member. The future social backend will assemble
/// this input after checking that both members accepted the friendship.
class TasteProfile {
  const TasteProfile({required this.memberId, required this.ratings});

  final String memberId;
  final List<SocialPlaceRating> ratings;
}

/// An explainable, non-public estimate of how similarly two members rate
/// places. A low confidence result must be presented as preliminary.
class TasteAffinity {
  const TasteAffinity({
    required this.score,
    required this.confidence,
    required this.sharedRatedPlaces,
    required this.sharedCategories,
    required this.sharedCities,
    required this.ratingAgreement,
    required this.categoryAgreement,
    required this.cityAgreement,
  });

  /// Similarity from 0 to 100. It is meaningful only together with
  /// [confidence] and is not intended as a ranking of people.
  final int score;

  /// Amount of evidence behind the score, from 0 to 100.
  final int confidence;
  final int sharedRatedPlaces;
  final int sharedCategories;
  final int sharedCities;

  /// Each component is normalized from 0.0 (opposite tastes) to 1.0.
  final double ratingAgreement;
  final double categoryAgreement;
  final double cityAgreement;

  /// Five shared rated places are the minimum for a dependable result.
  bool get isReliable => sharedRatedPlaces >= 5 && confidence >= 55;

  String get evidenceLabel {
    if (isReliable) return 'Reliable';
    if (sharedRatedPlaces == 0) return 'Not enough shared ratings yet';
    return 'Preliminary';
  }
}

/// Calculates affinity using only data that can later be explained in the UI.
///
/// Weighting: 60% agreement on the same places, 25% similarity between
/// category preferences and 15% similarity between city preferences. Missing
/// signals are excluded rather than treated as disagreement.
class TasteAffinityCalculator {
  const TasteAffinityCalculator();

  static const _samePlaceWeight = 0.60;
  static const _categoryWeight = 0.25;
  static const _cityWeight = 0.15;

  TasteAffinity calculate({
    required TasteProfile first,
    required TasteProfile second,
    required Map<String, Place> placesById,
  }) {
    final firstRatings = _ratingsByPlace(first.ratings);
    final secondRatings = _ratingsByPlace(second.ratings);
    final sharedPlaceIds = firstRatings.keys
        .where(secondRatings.containsKey)
        .where(placesById.containsKey)
        .toList();

    final ratingAgreement = _samePlaceAgreement(
      firstRatings,
      secondRatings,
      sharedPlaceIds,
    );
    final categoryComparison = _dimensionAgreement(
      firstRatings,
      secondRatings,
      placesById,
      (place) => place.category,
    );
    final cityComparison = _dimensionAgreement(
      firstRatings,
      secondRatings,
      placesById,
      (place) => place.city,
    );

    final components = <_AffinityComponent>[
      if (sharedPlaceIds.isNotEmpty)
        _AffinityComponent(ratingAgreement, _samePlaceWeight),
      if (categoryComparison.comparedDimensions > 0)
        _AffinityComponent(categoryComparison.agreement, _categoryWeight),
      if (cityComparison.comparedDimensions > 0)
        _AffinityComponent(cityComparison.agreement, _cityWeight),
    ];
    final totalWeight = components.fold<double>(
      0,
      (total, component) => total + component.weight,
    );
    final score = totalWeight == 0
        ? 0
        : (components.fold<double>(
                  0,
                  (total, component) => total + component.value * component.weight,
                ) /
                totalWeight *
                100)
            .round();

    final confidence = (_evidence(sharedPlaceIds.length, target: 8) * 0.70 +
                _evidence(categoryComparison.evidence, target: 10) * 0.20 +
                _evidence(cityComparison.evidence, target: 6) * 0.10) *
            100)
        .round();

    return TasteAffinity(
      score: score.clamp(0, 100).toInt(),
      confidence: confidence.clamp(0, 100).toInt(),
      sharedRatedPlaces: sharedPlaceIds.length,
      sharedCategories: categoryComparison.comparedDimensions,
      sharedCities: cityComparison.comparedDimensions,
      ratingAgreement: ratingAgreement,
      categoryAgreement: categoryComparison.agreement,
      cityAgreement: cityComparison.agreement,
    );
  }

  Map<String, SocialPlaceRating> _ratingsByPlace(
    List<SocialPlaceRating> ratings,
  ) {
    return {for (final rating in ratings) rating.placeId: rating};
  }

  double _samePlaceAgreement(
    Map<String, SocialPlaceRating> first,
    Map<String, SocialPlaceRating> second,
    List<String> sharedPlaceIds,
  ) {
    if (sharedPlaceIds.isEmpty) return 0;
    final total = sharedPlaceIds.fold<double>(
      0,
      (sum, placeId) =>
          sum + _agreement(first[placeId]!.rating, second[placeId]!.rating),
    );
    return total / sharedPlaceIds.length;
  }

  _DimensionComparison _dimensionAgreement(
    Map<String, SocialPlaceRating> firstRatings,
    Map<String, SocialPlaceRating> secondRatings,
    Map<String, Place> placesById,
    String Function(Place place) dimensionForPlace,
  ) {
    final firstByDimension = _ratingsByDimension(
      firstRatings,
      placesById,
      dimensionForPlace,
    );
    final secondByDimension = _ratingsByDimension(
      secondRatings,
      placesById,
      dimensionForPlace,
    );
    final sharedDimensions = firstByDimension.keys
        .where(secondByDimension.containsKey)
        .toList();
    if (sharedDimensions.isEmpty) return const _DimensionComparison.empty();

    var agreementTotal = 0.0;
    var evidence = 0;
    for (final dimension in sharedDimensions) {
      final firstStats = firstByDimension[dimension]!;
      final secondStats = secondByDimension[dimension]!;
      final sharedEvidence =
          math.min(firstStats.count, secondStats.count).toInt();
      agreementTotal +=
          _agreement(firstStats.average, secondStats.average) * sharedEvidence;
      evidence += sharedEvidence;
    }

    return _DimensionComparison(
      agreement: evidence == 0 ? 0 : agreementTotal / evidence,
      comparedDimensions: sharedDimensions.length,
      evidence: evidence,
    );
  }

  Map<String, _RatingStats> _ratingsByDimension(
    Map<String, SocialPlaceRating> ratings,
    Map<String, Place> placesById,
    String Function(Place place) dimensionForPlace,
  ) {
    final sums = <String, int>{};
    final counts = <String, int>{};
    for (final entry in ratings.entries) {
      final place = placesById[entry.key];
      if (place == null) continue;
      final dimension = dimensionForPlace(place).trim();
      if (dimension.isEmpty) continue;
      sums.update(dimension, (sum) => sum + entry.value.rating,
          ifAbsent: () => entry.value.rating);
      counts.update(dimension, (count) => count + 1, ifAbsent: () => 1);
    }
    return {
      for (final dimension in sums.keys)
        dimension: _RatingStats(
          total: sums[dimension]!,
          count: counts[dimension]!,
        ),
    };
  }

  double _agreement(num first, num second) {
    return (1 - (first - second).abs() / 9).clamp(0, 1).toDouble();
  }

  double _evidence(int actual, {required int target}) {
    return (actual / target).clamp(0, 1).toDouble();
  }
}

class _AffinityComponent {
  const _AffinityComponent(this.value, this.weight);

  final double value;
  final double weight;
}

class _DimensionComparison {
  const _DimensionComparison({
    required this.agreement,
    required this.comparedDimensions,
    required this.evidence,
  });

  const _DimensionComparison.empty()
      : agreement = 0,
        comparedDimensions = 0,
        evidence = 0;

  final double agreement;
  final int comparedDimensions;
  final int evidence;
}

class _RatingStats {
  const _RatingStats({required this.total, required this.count});

  final int total;
  final int count;

  double get average => total / count;
}
