class DeviceLocation {
  const DeviceLocation({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

class DeviceLocationException implements Exception {
  const DeviceLocationException(this.message);

  final String message;
}

Future<DeviceLocation> getCurrentDeviceLocation() {
  return Future<DeviceLocation>.error(
    const DeviceLocationException(
      'Location is available when you open My Locals in Chrome, Edge, or the mobile app.',
    ),
  );
}
