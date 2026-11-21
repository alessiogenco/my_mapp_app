import 'package:flutter_test/flutter_test.dart';
import 'package:my_map_app/models/place.dart';

void main() {
  test('price bands use equivalent rounded local amounts', () {
    expect(priceRangeFor(1, 'EUR'), '0–15€');
    expect(priceRangeFor(2, 'EUR'), '15–35€');

    expect(priceRangeFor(1, 'NOK'), '0–150 kr');
    expect(priceRangeFor(2, 'NOK'), '150–350 kr');

    expect(priceRangeFor(1, 'GBP'), '£0–13');
    expect(priceRangeFor(2, 'GBP'), '£13–30');

    expect(priceRangeFor(1, 'SEK'), '0–170 kr');
    expect(priceRangeFor(2, 'DKK'), '110–260 kr');
    expect(priceRangeFor(3, 'USD'), r'$40–80');

    expect(priceLabelFor(3, 'NOK'), '💵💵💵 · 350–750 kr');
    expect(priceLabelFor(2, 'EUR'), '💵💵 · 15–35€');
    expect(priceLabelFor(1, 'GBP'), '💵 · £0–13');
  });
}
