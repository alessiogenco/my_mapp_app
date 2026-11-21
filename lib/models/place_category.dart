const allowedPlaceCategories = {
  'restaurant',
  'fish_and_chips',
  'sushi',
  'ramen',
  'chinese',
  'turkish',
  'kebab',
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
    'fish_and_chips' => '\u{1F41F}',
    'sushi' => '\u{1F363}',
    'ramen' => '\u{1F35C}',
    'chinese' => '\u{1F35C}',
    'turkish' => '\u{1F362}',
    'kebab' => '\u{1F959}',
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
    'fish_and_chips' => 'Fish and chips',
    'sushi' => 'Japanese',
    'ramen' => 'Ramen',
    'chinese' => 'Chinese',
    'turkish' => 'Turkish',
    'kebab' => 'Kebab',
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
