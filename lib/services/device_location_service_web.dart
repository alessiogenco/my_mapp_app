import 'dart:html' as html;

class DeviceLocation {
  const DeviceLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.message);

  final String message;
}

Future<DeviceLocation> getCurrentDeviceLocation() async {
  try {
    final position = await html.window.navigator.geolocation.getCurrentPosition(
      enableHighAccuracy: true,
      timeout: const Duration(seconds: 15),
      maximumAge: Duration.zero,
    );
    final coordinates = position.coords;
    final latitude = coordinates?.latitude;
    final longitude = coordinates?.longitude;
    if (latitude == null || longitude == null) {
      throw const DeviceLocationException('Your browser did not return a usable location.');
    }
    return DeviceLocation(
      latitude: latitude.toDouble(),
      longitude: longitude.toDouble(),
    );
  } on DeviceLocationException {
    rethrow;
  } on html.PositionError catch (error) {
    switch (error.code) {
      case html.PositionError.PERMISSION_DENIED:
        throw const DeviceLocationException(
          'Location is blocked. Allow it for localhost in your browser, then try again.',
        );
      case html.PositionError.POSITION_UNAVAILABLE:
        throw const DeviceLocationException(
          'Your device cannot provide a location right now. Check Windows Location Services and your connection.',
        );
      case html.PositionError.TIMEOUT:
        throw const DeviceLocationException(
          'It took too long to find your location. Try again in a moment.',
        );
      default:
        throw const DeviceLocationException(
          'Your browser could not determine a location. Check its location permission and try again.',
        );
    }
  } catch (_) {
    throw const DeviceLocationException(
      'Location is unavailable. Allow it in your browser and try again.',
    );
  }
}
