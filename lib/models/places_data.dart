import 'place.dart';

final List<Place> places = [
  Place.fromJson({
    "id": "trullo_garden",
    "name": "Trullo Garden",
    "category": "restaurant",
    "lat": 40.78565142,
    "lng": 17.23836116,
    "rating": 8,
    "priceLevel": 2,
    "vibes": ["cozy", "date", "locals", "family", "friends"],
    "notes": "Eccelente scelta di prodotti locali di grande qualita in un trullo con giardino caratteristico"
  }),
  Place.fromJson({
    "id": "cols",
    "name": "Cols",
    "category": "bar",
    "lat": 40.7799645,
    "lng": 17.23560064,
    "rating": 7,
    "priceLevel": 1,
    "vibes": ["coffee", "date", "authentic", "coworkers", "solo"],
    "notes": "Passione e originalita nella scelta delle miscele di caffe', grande professionalita', e gentilezza dello staff"
  }),
    Place.fromJson({
    "id": "ristorante_gli_ulivi",
    "name": "Ristorante Gli Ulivi",
    "category": "restaurant",
    "lat": 40.78572949,
    "lng": 17.24632755,
    "rating": 7,
    "priceLevel": 2,
    "vibes": ["family", "locals", "friends", "touristy"],
    "notes": "Istituzione alberobellese nell'offerta di piatti locali e buona pizza"
  }),
];