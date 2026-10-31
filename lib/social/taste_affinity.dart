import 'dart:math' as math;

import 'package:my_map_app/models/place.dart';
import 'package:my_map_app/social/social_place_rating.dart';

/// Ratings belonging to one member. The social layer assembles this input only
/// after the two members have an accepted friendship and opted into sharing.
class TasteProfile {
  const TasteProfile({required this.memberId, required this.ratings});

  final String memberId;
  final List<SocialPlaceRating> ratings;
}

/// One explainable facet of taste agreement.
///
/// A missing value means that the pair has not rated that facet on a common
/// place. It never means that they disagree.
class TasteAffinityDimension {
  const TasteAffinityDimension({
    required this.id,
    required this.agreement,
    required this.comparedPlaces,
  });

  final String id;
  final double agreement;
  final int comparedPlaces;

  bool get hasEvidence => comparedPlaces > 0;
  int? get score => hasEvidence ? (agreement * 100).round() : null;
  bool get isReliable => comparedPlaces >= 5;

  String get evidenceLabel {
    if (!hasEvidence) return 'No shared detail yet';
    return isReliable ? 'Reliable' : 'Preliminary';
  }
}

/// An explainable, private estimate of how similarly two members rate places.
///
/// The global score is useful only alongside [confidence]. Individual
/// dimensions intentionally remain visible: two people may agree strongly on
/// location but disagree on food, for example.
class TasteAffinity {
  const TasteAffinity({
    required this.score,
    required this.confidence,
    required this.sharedRatedPlaces,
    required this.overall,
    required this.food,
    required this.location,
    required this.service,
    required this.value,
  });

  /// Similarity from 0 to 100, or null when there are no shared ratings.
  final int? score;

  /// Amount of evidence behind the score, from 0 to 100.
  final int confidence;
  final int sharedRatedPlaces;

  final TasteAffinityDimension overall;
  final TasteAffinityDimension food;
  final TasteAffinityDimension location;
  final TasteAffinityDimension service;
  final TasteAffinityDimension value;

  List<TasteAffinityDimension> get details => [
        food,
        location,
        service,
        value,
      ];

  /// Five common overall ratings are the first meaningful threshold. The
  /// separate confidence value continues growing as the shared sample grows.
  bool get isReliable => overall.comparedPlaces >= 5 && score != null;

  String get evidenceLabel {
    if (score == null) return 'Not enough shared ratings yet';
    return isReliable ? 'Reliable' : 'Preliminary';
  }
}

/// Calculates affinity from ratings for the same curated places.
///
/// Global weighting:
/// - 35% overall rating agreement
/// - 25% food agreement
/// - 20% location agreement
/// - 10% service agreement
/// - 10% value-for-money agreement
///
/// Missing optional details are omitted and the available weights are
/// normalized again. This prevents an unanswered field from being interpreted
/// as a negative rating.
class TasteAffinityCalculator {
  const TasteAffinityCalculator();

  static const _overallWeight = 0.35;
  static const _foodWeight = 0.25;
  static const _locationWeight = 0.20;
  static const _serviceWeight = 0.10;
  static const _valueWeight = 0.10;

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
        .toList(growable: false);

    final overall = _agreementFor(
      id: 'overall',
      first: firstRatings,
      second: secondRatings,
      sharedPlaceIds: sharedPlaceIds,
      valueFor: (rating) => rating.rating,
    );
    final food = _agreementFor(
      id: 'food',
      first: firstRatings,
      second: secondRatings,
      sharedPlaceIds: sharedPlaceIds,
      valueFor: (rating) => rating.ratingDetails['food'],
    );
    final location = _agreementFor(
      id: 'location',
      first: firstRatings,
      second: secondRatings,
      sharedPlaceIds: sharedPlaceIds,
      valueFor: (rating) => rating.ratingDetails['location'],
    );
    final service = _agreementFor(
      id: 'service',
      first: firstRatings,
      second: secondRatings,
      sharedPlaceIds: sharedPlaceIds,
      valueFor: (rating) => rating.ratingDetails['service'],
    );
    final value = _agreementFor(
      id: 'value',
      first: firstRatings,
      second: secondRatings,
      sharedPlaceIds: sharedPlaceIds,
      valueFor: (rating) => rating.ratingDetails['value'],
    );

    final components = <_AffinityComponent>[
      if (overall.hasEvidence) _AffinityComponent(overall, _overallWeight),
      if (food.hasEvidence) _AffinityComponent(food, _foodWeight),
      if (location.hasEvidence) _AffinityComponent(location, _locationWeight),
      if (service.hasEvidence) _AffinityComponent(service, _serviceWeight),
      if (value.hasEvidence) _AffinityComponent(value, _valueWeight),
    ];
    final totalWeight = components.fold<double>(
      0,
      (sum, component) => sum + component.weight,
    );
    final score = totalWeight == 0
        ? null
        : (components.fold<double>(
                    0,
                    (sum, component) =>
                        sum + component.dimension.agreement * component.weight,
                  ) /
                  totalWeight *
                  100)
              .round()
              .clamp(0, 100)
              .toInt();

    final confidence = (_overallEvidence(overall.comparedPlaces) * 100)
        .round()
        .clamp(0, 100)
        .toInt();

    return TasteAffinity(
      score: score,
      confidence: confidence,
      sharedRatedPlaces: sharedPlaceIds.length,
      overall: overall,
      food: food,
      location: location,
      service: service,
      value: value,
    );
  }

  Map<String, SocialPlaceRating> _ratingsByPlace(
    List<SocialPlaceRating> ratings,
  ) => {for (final rating in ratings) rating.placeId: rating};

  TasteAffinityDimension _agreementFor({
    required String id,
    required Map<String, SocialPlaceRating> first,
    required Map<String, SocialPlaceRating> second,
    required List<String> sharedPlaceIds,
    required int? Function(SocialPlaceRating rating) valueFor,
  }) {
    var total = 0.0;
    var count = 0;
    for (final placeId in sharedPlaceIds) {
      final firstValue = valueFor(first[placeId]!);
      final secondValue = valueFor(second[placeId]!);
      if (firstValue == null || secondValue == null) continue;
      if (firstValue < 1 || firstValue > 10 || secondValue < 1 || secondValue > 10) {
        continue;
      }
      total += _agreement(firstValue, secondValue);
      count += 1;
    }
    return TasteAffinityDimension(
      id: id,
      agreement: count == 0 ? 0 : total / count,
      comparedPlaces: count,
    );
  }

  double _agreement(num first, num second) =>
      (1 - (first - second).abs() / 9).clamp(0, 1).toDouble();

  /// Evidence must distinguish two matching ratings from 100 matching ratings.
  /// Five shared places are the first useful threshold (50%); after that the
  /// curve grows more slowly, so every additional shared place still matters
  /// without letting a large sample grow beyond 100%.
  double _overallEvidence(int sharedPlaces) {
    if (sharedPlaces <= 0) return 0;
    if (sharedPlaces < 5) return sharedPlaces / 10;

    const growthWindow = 15.0;
    return (0.5 +
            0.5 * (1 - math.exp(-(sharedPlaces - 5) / growthWindow)))
        .clamp(0, 1)
        .toDouble();
  }
}

class _AffinityComponent {
  const _AffinityComponent(this.dimension, this.weight);

  final TasteAffinityDimension dimension;
  final double weight;
}
