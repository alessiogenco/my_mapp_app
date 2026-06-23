import 'package:my_map_app/models/place.dart';
import 'package:url_launcher/url_launcher.dart';

class MapsLauncherService {
  const MapsLauncherService();

  Uri buildPlaceUrl(Place place) {
    final location = place.city.isEmpty
        ? '${place.name}, ${place.lat}, ${place.lng}'
        : '${place.name}, ${place.city}';

    return Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': location,
      if (place.googlePlaceId != null && place.googlePlaceId!.isNotEmpty)
        'query_place_id': place.googlePlaceId!,
    });
  }

  Future<bool> openPlace(Place place) async {
    try {
      return await launchUrl(
        buildPlaceUrl(place),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}
