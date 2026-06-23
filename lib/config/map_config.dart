class MapConfig {
  const MapConfig._();

  static const mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );

  static const usesMapbox = mapboxAccessToken != '';

  static const tileUrl = usesMapbox
      ? 'https://api.mapbox.com/styles/v1/mapbox/satellite-streets-v12/'
            'tiles/256/{z}/{x}/{y}{r}?access_token=$mapboxAccessToken'
      : 'https://{s}.tile.opentopomap.org/{z}/{x}/{y}.png';

  static const subdomains = usesMapbox ? <String>[] : ['a', 'b', 'c'];

  static const maxZoom = usesMapbox ? 22.0 : 17.0;
}
