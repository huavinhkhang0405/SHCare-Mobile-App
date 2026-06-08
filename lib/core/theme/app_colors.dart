import 'package:flutter/material.dart';

class DynamicPrimaryColor extends Color {
  const DynamicPrimaryColor() : super(0xFF0FA87E);
  @override
  int get value => AppColors.primaryHex;
}

class DynamicPrimaryDarkColor extends Color {
  const DynamicPrimaryDarkColor() : super(0xFF0C7A5C);
  @override
  int get value => AppColors.primaryDarkHex;
}

class DynamicPrimaryLightColor extends Color {
  const DynamicPrimaryLightColor() : super(0xFF6FDCBA);
  @override
  int get value => AppColors.primaryLightHex;
}

class DynamicPrimarySurfaceColor extends Color {
  const DynamicPrimarySurfaceColor() : super(0xFFE8FAF3);
  @override
  int get value => AppColors.primarySurfaceHex;
}

/// Hệ thống màu sắc thống nhất cho toàn bộ ứng dụng SHCare.
/// Mọi màn hình đều tham chiếu file này để đảm bảo đồng bộ.
class AppColors {
  AppColors._();

  static int primaryHex = 0xFF0FA87E;
  static int primaryDarkHex = 0xFF0C7A5C;
  static int primaryLightHex = 0xFF6FDCBA;
  static int primarySurfaceHex = 0xFFE8FAF3;

  static void updatePrimaryColor(Color newPrimary) {
    primaryHex = newPrimary.value;
    final hsl = HSLColor.fromColor(newPrimary);
    primaryDarkHex = hsl.withLightness((hsl.lightness - 0.1).clamp(0.0, 1.0)).toColor().value;
    primaryLightHex = hsl.withLightness((hsl.lightness + 0.2).clamp(0.0, 1.0)).toColor().value;
    primarySurfaceHex = hsl.withLightness(0.95).withSaturation(0.15).toColor().value;
  }

  // ─── Brand / Primary ───────────────────────────────────────
  static const Color primary = DynamicPrimaryColor();
  static const Color primaryDark = DynamicPrimaryDarkColor();
  static const Color primaryLight = DynamicPrimaryLightColor();
  static const Color primarySurface = DynamicPrimarySurfaceColor();


  // ─── Accent / Secondary ────────────────────────────────────
  static const Color accent = Color(0xFF4A90D9);
  static const Color accentLight = Color(0xFFD6E9FF);

  // ─── Backgrounds ───────────────────────────────────────────
  static const Color scaffoldBg = Color(0xFFF5F9F7);
  static const Color cardBg = Colors.white;
  static const Color cardBorder = Color(0xFFE2ECE7);

  // ─── Text ──────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F2E24);
  static const Color textSecondary = Color(0xFF5A7068);
  static const Color textHint = Color(0xFF8FA8A0);
  static const Color textOnPrimary = Colors.white;

  // ─── Status / Semantic ─────────────────────────────────────
  static const Color success = Color(0xFF22C55E);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ─── Metric card tints ─────────────────────────────────────
  static const Color heartTint = Color(0xFFFDE4EC);
  static const Color heartIcon = Color(0xFF8F4A63);
  static const Color waterTint = Color(0xFFDDF0FF);
  static const Color waterIcon = Color(0xFF2D6C9A);
  static const Color sleepTint = Color(0xFFEDE9FF);
  static const Color sleepIcon = Color(0xFF5F55A8);
  static const Color fireTint = Color(0xFFFFF2DF);
  static const Color fireIcon = Color(0xFF9D6C1F);
  static const Color boltTint = Color(0xFFE8F3FF);
  static const Color boltIcon = Color(0xFF2D6A9C);

  // ─── Nav / Surface ─────────────────────────────────────────
  static const Color navBarBg = Colors.white;
  static const Color navBarInactive = Color(0xFF8FA8A0);

  // ─── Gradient Presets ──────────────────────────────────────
  static LinearGradient get primaryGradient => LinearGradient(
        colors: [Color(primaryHex), Color(primaryLightHex)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static LinearGradient get heroGradient => LinearGradient(
        colors: [Color(primaryDarkHex), Color(primaryHex)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF162033), Color(0xFF0D1420)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ─── Shadows ───────────────────────────────────────────────
  static List<BoxShadow> get cardShadow => [
        BoxShadow(
          color: primary.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 3),
        ),
      ];

  // ─── Border Radius Presets ─────────────────────────────────
  static const double radiusSm = 12.0;
  static const double radiusMd = 18.0;
  static const double radiusLg = 24.0;
  static const double radiusXl = 32.0;
}
