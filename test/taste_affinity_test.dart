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
        city: index <= 3 ? 'Bari' : 'Bologna',
        category: index.isOdd ? 'restaurant' : 'cocktail_bar',
        area: 'cityCentre',
        lat: 41.0 + index,
        lng: 16.0 + index,
        rating: 8,
        priceLevel: 2,
        vibes: const [],
        notes: '',
      ),
  };

  test('identical ratings produce a reliable perfect affinity', () {
    final ratings = [
      for (var index = 1; index <= 6; index++)
        SocialPlaceRating(placeId: 'place-$index', rating: 8),
    ];

    final affinity = calculator.calculate(
      first: TasteProfile(memberId: 'alessio', ratings: ratings),
      second: TasteProfile(memberId: 'friend', ratings: ratings),
      placesById: places,
    );

    expect(affinity.score, 100);
    expect(affinity.confidence, greaterThanOrEqualTo(55));
    expect(affinity.isReliable, isTrue);
    expect(affinity.sharedRatedPlaces, 6);
  });

  test('opposite ratings on the same places produce a low affinity', () {
    final affinity = calculator.calculate(
      first: TasteProfile(
        memberId: 'alessio',
        ratings: [
          for (var index = 1; index <= 6; index++)
            SocialPlaceRating(placeId: 'place-$index', rating: 10),
        ],
      ),
      second: TasteProfile(
        memberId: 'friend',
        ratings: [
          for (var index = 1; index <= 6; index++)
            SocialPlaceRating(placeId: 'place-$index', rating: 1),
        ],
      ),
      placesById: places,
    );

    expect(affinity.score, 0);
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
  });
}
