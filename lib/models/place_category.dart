String emojiForCategory(String category) {
  return switch (category) {
    'restaurant' => '\u{1F35D}',
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
    'restaurant' => 'Ristorante',
    'steakhouse' => 'Steakhouse',
    'pub' => 'Pub',
    'coffee_bar' => 'Caffetteria',
    'cocktail_bar' => 'Cocktail bar',
    'beer_bar' => 'Birreria',
    'bakery_sweet' => 'Pasticceria',
    'bakery_savory' => 'Panetteria',
    'gelateria' => 'Gelateria',
    _ => 'Locale',
  };
}
