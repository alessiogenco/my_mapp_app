import 'package:flutter_test/flutter_test.dart';
import 'package:my_map_app/models/place.dart';
import 'package:my_map_app/social/social_place_rating.dart';
import 'package:my_map_app/social/taste_affinity.dart';

void main() {
  const calculator = TasteAffinityCalculator();
  final places = {
    for (var index = 1; index <= 6; index++)
      'place-$index': Place(
        id: 'place-$index',
        name: 'Place $index',
        city: 'Bari',
        category: 'restaurant',
        area: 'cityCentre',
        lat: 41.0 + index,
        lng: 16.0 + index,
        rating: 8,
        priceLevel: 2,
        vibes: const [],
        notes: '',
      ),
  };

  test('identical overall and detailed ratings produce perfect affinity', () {
    final ratings = [
      for (var index = 1; index <= 6; index++)
        SocialPlaceRating(
          placeId: 'place-$index',
          rating: 8,
          ratingDetails: const {
            'food': 8,
            'location': 8,
            'service': 8,
            'value': 8,
          },
        ),
    ];

    final affinity = calculator.calculate(
      first: TasteProfile(memberId: 'alessio', ratings: ratings),
      second: TasteProfile(memberId: 'friend', ratings: ratings),
      placesById: places,
    );

    expect(affinity.score, 100);
    expect(affinity.food.score, 100);
    expect(affinity.location.score, 100);
    expect(affinity.service.score, 100);
    expect(affinity.value.score, 100);
    expect(affinity.isReliable, isTrue);
  });

  test('location can be high while food is low', () {
    final first = [
      for (var index = 1; index <= 6; index++)
        SocialPlaceRating(
          placeId: 'place-$index',
          rating: 8,
          ratingDetails: const {'food': 9, 'location': 8},
        ),
    ];
    final second = [
      for (var index = 1; index <= 6; index++)
        SocialPlaceRating(
          placeId: 'place-$index',
          rating: 8,
          ratingDetails: const {'food': 4, 'location': 8},
        ),
    ];

    final affinity = calculator.calculate(
      first: TasteProfile(memberId: 'alessio', ratings: first),
      second: TasteProfile(memberId: 'friend', ratings: second),
      placesById: places,
    );

    expect(affinity.location.score, 100);
    expect(affinity.food.score, 44);
    expect(affinity.service.score, isNull);
    expect(affinity.value.score, isNull);
    expect(affinity.score, lessThan(100));
  });

  test('missing detailed ratings do not lower overall agreement', () {
    final affinity = calculator.calculate(
      first: TasteProfile(
        memberId: 'alessio',
        ratings: [
          for (var index = 1; index <= 6; index++)
            SocialPlaceRating(placeId: 'place-$index', rating: 8),
        ],
      ),
      second: TasteProfile(
        memberId: 'friend',
        ratings: [
          for (var index = 1; index <= 6; index++)
            SocialPlaceRating(placeId: 'place-$index', rating: 6),
        ],
      ),
      placesById: places,
    );

    expect(affinity.score, 78);
    expect(affinity.food.score, isNull);
    expect(affinity.location.score, isNull);
    expect(affinity.isReliable, isTrue);
  });

  test('few shared ratings remain preliminary', () {
    final affinity = calculator.calculate(
      first: const TasteProfile(
        memberId: 'alessio',
        ratings: [SocialPlaceRating(placeId: 'place-1', rating: 8)],
      ),
      second: const TasteProfile(
        memberId: 'friend',
        ratings: [SocialPlaceRating(placeId: 'place-1', rating: 8)],
      ),
      placesById: places,
    );

    expect(affinity.score, 100);
    expect(affinity.isReliable, isFalse);
    expect(affinity.evidenceLabel, 'Preliminary');
    expect(affinity.confidence, 10);
  });

  test('more shared places increase confidence without distorting agreement', () {
    final twoPlaces = calculator.calculate(
      first: const TasteProfile(
        memberId: 'alessio',
        ratings: [
          SocialPlaceRating(placeId: 'place-1', rating: 8),
          SocialPlaceRating(placeId: 'place-2', rating: 8),
        ],
      ),
      second: const TasteProfile(
        memberId: 'friend',
        ratings: [
          SocialPlaceRating(placeId: 'place-1', rating: 8),
          SocialPlaceRating(placeId: 'place-2', rating: 8),
        ],
      ),
      placesById: places,
    );
    final sixPlaces = calculator.calculate(
      first: TasteProfile(
        memberId: 'alessio',
        ratings: [
          for (var index = 1; index <= 6; index++)
            SocialPlaceRating(placeId: 'place-$index', rating: 8),
        ],
      ),
      second: TasteProfile(
        memberId: 'friend',
        ratings: [
          for (var index = 1; index <= 6; index++)
            SocialPlaceRating(placeId: 'place-$index', rating: 8),
        ],
      ),
      placesById: places,
    );

    expect(twoPlaces.score, 100);
    expect(sixPlaces.score, 100);
    expect(twoPlaces.confidence, 20);
    expect(sixPlaces.confidence, greaterThan(twoPlaces.confidence));
    expect(twoPlaces.isReliable, isFalse);
    expect(sixPlaces.isReliable, isTrue);
  });
}
