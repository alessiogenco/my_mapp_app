import 'package:flutter/material.dart';
import 'package:my_map_app/models/place.dart';
import 'package:my_map_app/models/place_category.dart';

class PlaceMarker extends StatelessWidget {
  const PlaceMarker({required this.place, required this.onTap, super.key});

  final Place place;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF1687C9).withValues(alpha: 0.24),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF123F59).withValues(alpha: 0.18),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              emojiForCategory(place.category),
              style: const TextStyle(fontSize: 22),
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                place.name,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
