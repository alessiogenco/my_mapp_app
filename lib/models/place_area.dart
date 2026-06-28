const allowedPlaceAreas = {
  'cityCentre',
  'historicalCentre',
  'periphery',
  'outsideCentre',
};

bool isKnownPlaceArea(String area) {
  return allowedPlaceAreas.contains(area);
}

String labelForArea(String area) {
  return switch (area) {
    'cityCentre' => 'Centro',
    'historicalCentre' => 'Centro storico',
    'periphery' => 'Periferia',
    'outsideCentre' => 'Fuori centro',
    _ => 'Area',
  };
}
