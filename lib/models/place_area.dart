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
    'cityCentre' => 'City centre',
    'historicalCentre' => 'Historic centre',
    'periphery' => 'Periphery',
    'outsideCentre' => 'Outside centre',
    _ => 'Area',
  };
}
