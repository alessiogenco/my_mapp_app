import 'dart:ui';

import 'package:flutter/material.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    required this.child,
    this.height = 54,
    this.maxWidth = 520,
    this.padding = const EdgeInsets.all(5),
    super.key,
  });

  final Widget child;
  final double height;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            height: height,
            padding: padding,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.86),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: Colors.white.withValues(alpha: 0.72)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF134F70).withValues(alpha: 0.16),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
