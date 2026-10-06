import 'package:flutter/material.dart';
import 'package:my_map_app/models/place.dart';
import 'package:my_map_app/models/place_category.dart';

class PlaceMarker extends StatelessWidget {
  const PlaceMarker({
    required this.place,
    required this.isWantToGo,
    required this.onTap,
    super.key,
  });

  final Place place;
  final bool isWantToGo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 176,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              constraints: const BoxConstraints(minWidth: 40, minHeight: 34),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFD7E3E8)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x330D2A3B),
                    blurRadius: 8,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                emojiForCategory(place.category),
                style: const TextStyle(fontSize: 19, height: 1),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              constraints: const BoxConstraints(maxWidth: 172),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isWantToGo
                      ? const Color(0xFFF2C55A)
                      : const Color(0xFFD7E3E8),
                ),
              ),
              child: Text(
                place.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isWantToGo
                      ? const Color(0xFF9A6400)
                      : const Color(0xFF0B2E41),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
