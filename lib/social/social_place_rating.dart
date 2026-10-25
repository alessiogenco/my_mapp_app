/// A private rating that a signed-in member gives to one curated place.
///
/// This model deliberately contains only the information needed for social
/// recommendations and affinity. Profile information, friendship state and
/// permissions belong to the future backend, not to the affinity algorithm.
class SocialPlaceRating {
  const SocialPlaceRating({
    required this.placeId,
    required this.rating,
    this.ratingDetails = const {},
  }) : assert(rating >= 1 && rating <= 10);

  final String placeId;
  final int rating;
  final Map<String, int> ratingDetails;
}
