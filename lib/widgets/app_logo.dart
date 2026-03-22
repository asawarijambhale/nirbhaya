import 'package:flutter/material.dart';

/// Displays the Nirbhaya logo.
/// Place logo.png in assets/images/ — falls back to icon if not found.
class AppLogo extends StatelessWidget {
  final double size;
  final bool withBackground;
  const AppLogo({super.key, this.size = 90, this.withBackground = false});

  @override
  Widget build(BuildContext context) {
    final img = ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Icon(
          Icons.shield,
          size: size * 0.8,
          color: Colors.white,
        ),
      ),
    );

    if (!withBackground) return img;

    return Container(
      width: size + 24,
      height: size + 24,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: ClipOval(child: Center(child: img)),
    );
  }
}
