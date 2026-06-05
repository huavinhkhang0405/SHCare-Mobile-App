import 'package:flutter/material.dart';

class AppGifIcons {
  // All current GIF files are placeholders (same hash). Keep this false
  // until real per-icon assets are provided.
  static const bool enableGifAssets = false;

  static const String home = 'assets/icons/gif/home.gif';
  static const String stats = 'assets/icons/gif/stats.gif';
  static const String tips = 'assets/icons/gif/tips.gif';
  static const String journal = 'assets/icons/gif/journal.gif';

  static const String profile = 'assets/icons/gif/profile.gif';
  static const String heart = 'assets/icons/gif/heart.gif';
  static const String water = 'assets/icons/gif/water.gif';
  static const String sleep = 'assets/icons/gif/sleep.gif';
  static const String check = 'assets/icons/gif/check.gif';
  static const String walk = 'assets/icons/gif/walk.gif';
  static const String meditate = 'assets/icons/gif/meditate.gif';
  static const String route = 'assets/icons/gif/route.gif';
  static const String calendar = 'assets/icons/gif/calendar.gif';
  static const String bolt = 'assets/icons/gif/bolt.gif';
  static const String fire = 'assets/icons/gif/fire.gif';
  static const String search = 'assets/icons/gif/search.gif';
  static const String chevron = 'assets/icons/gif/chevron.gif';
  static const String save = 'assets/icons/gif/save.gif';
  static const String plus = 'assets/icons/gif/plus.gif';
  static const String minus = 'assets/icons/gif/minus.gif';
}

class GifIcon extends StatelessWidget {
  const GifIcon({
    super.key,
    required this.assetPath,
    required this.fallbackIcon,
    this.size = 24,
    this.fallbackColor,
    this.borderRadius,
  });

  final String assetPath;
  final IconData fallbackIcon;
  final double size;
  final Color? fallbackColor;
  final double? borderRadius;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? size * 0.22;

    if (!AppGifIcons.enableGifAssets) {
      return SizedBox(
        width: size,
        height: size,
        child: Icon(fallbackIcon, size: size, color: fallbackColor),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          assetPath,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) =>
              Icon(fallbackIcon, size: size, color: fallbackColor),
        ),
      ),
    );
  }
}
