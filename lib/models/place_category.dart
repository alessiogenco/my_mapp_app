const allowedPlaceCategories = {
  'restaurant',
  'sushi',
  'chinese',
  'indian',
  'pizzeria',
  'panzerotteria',
  'steakhouse',
  'pub',
  'coffee_bar',
  'cocktail_bar',
  'beer_bar',
  'bakery_sweet',
  'bakery_savory',
  'gelateria',
};

bool isKnownPlaceCategory(String category) {
  return allowedPlaceCategories.contains(category);
}

String emojiForCategory(String category) {
  return switch (category) {
    'restaurant' => '\u{1F35D}',
    'sushi' => '\u{1F363}',
    'chinese' => '\u{1F961}',
    'indian' => '\u{1F35B}',
    'pizzeria' => '\u{1F355}',
    'panzerotteria' => '\u{1F95F}',
    'steakhouse' => '\u{1F969}',
    'pub' => '\u{1F354}',
    'coffee_bar' => '\u{2615}',
    'cocktail_bar' => '\u{1F378}',
    'beer_bar' => '\u{1F37A}',
    'bakery_sweet' => '\u{1F370}',
    'bakery_savory' => '\u{1F96A}',
    'gelateria' => '\u{1F366}',
    _ => '\u{1F4CD}',
  };
}

String labelForCategory(String category) {
  return switch (category) {
    'restaurant' => 'Restaurant',
    'sushi' => 'Sushi',
    'chinese' => 'Chinese',
    'indian' => 'Indian',
    'pizzeria' => 'Pizzeria',
    'panzerotteria' => 'Panzerotteria',
    'steakhouse' => 'Steakhouse',
    'pub' => 'Pub',
    'coffee_bar' => 'Coffee bar',
    'cocktail_bar' => 'Cocktail bar',
    'beer_bar' => 'Beer bar',
    'bakery_sweet' => 'Pastry shop',
    'bakery_savory' => 'Savory bakery',
    'gelateria' => 'Gelato shop',
    _ => 'Place',
  };
}
