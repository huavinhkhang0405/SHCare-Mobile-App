import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'PlusJakartaSans',
      colorScheme: ColorScheme.fromSeed(
        seedColor: Color(AppColors.primaryHex),
        primary: Color(AppColors.primaryHex),
        onPrimary: AppColors.textOnPrimary,
        surface: AppColors.scaffoldBg,
        onSurface: AppColors.textPrimary,
        outline: AppColors.textHint,
      ),
      scaffoldBackgroundColor: AppColors.scaffoldBg,

      // ─── App Bar ──────────────────────────────────────
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),

      // ─── Typography ───────────────────────────────────
      textTheme: TextTheme(
        displayLarge: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        headlineLarge: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: AppColors.textPrimary,
          letterSpacing: -0.3,
        ),
        headlineMedium: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        headlineSmall: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: AppColors.textPrimary,
        ),
        titleLarge: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
        titleMedium: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        bodyMedium: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        bodySmall: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textHint,
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(AppColors.primaryHex),
        ),
      ),

      // ─── Navigation Bar ───────────────────────────────
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.navBarBg,
        elevation: 0,
        height: 72,
        indicatorColor: Color(AppColors.primaryHex).withValues(alpha: 0.1),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return TextStyle(
              fontFamily: 'PlusJakartaSans',
              color: Color(AppColors.primaryHex),
              fontWeight: FontWeight.w700,
              fontSize: 12,
            );
          }
          return const TextStyle(
            fontFamily: 'PlusJakartaSans',
            color: AppColors.navBarInactive,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: Color(AppColors.primaryHex), size: 24);
          }
          return const IconThemeData(
            color: AppColors.navBarInactive,
            size: 24,
          );
        }),
      ),

      // ─── Cards ────────────────────────────────────────
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusLg),
          side: const BorderSide(color: AppColors.cardBorder),
        ),
      ),

      // ─── Filled Button ────────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Color(AppColors.primaryHex),
          foregroundColor: AppColors.textOnPrimary,
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
        ),
      ),

      // ─── Outlined Button ──────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimary,
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          side: const BorderSide(color: AppColors.cardBorder, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
        ),
      ),

      // ─── Elevated Button ──────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Color(AppColors.primaryHex),
          foregroundColor: AppColors.textOnPrimary,
          elevation: 0,
          textStyle: const TextStyle(
            fontFamily: 'PlusJakartaSans',
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
        ),
      ),

      // ─── Input Decoration ─────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.scaffoldBg,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 14,
          color: AppColors.textHint,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: BorderSide(color: Color(AppColors.primaryHex), width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),

      // ─── Slider ───────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: Color(AppColors.primaryHex),
        inactiveTrackColor: Color(AppColors.primaryHex).withValues(alpha: 0.15),
        thumbColor: Color(AppColors.primaryHex),
        overlayColor: Color(AppColors.primaryHex).withValues(alpha: 0.1),
      ),

      // ─── Chip ─────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.cardBg,
        selectedColor: Color(AppColors.primarySurfaceHex),
        labelStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(99),
        ),
        side: const BorderSide(color: AppColors.cardBorder),
      ),

      // ─── SnackBar ─────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.textPrimary,
        contentTextStyle: const TextStyle(
          fontFamily: 'PlusJakartaSans',
          color: Colors.white,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ─── Divider ──────────────────────────────────────
      dividerTheme: const DividerThemeData(
        color: AppColors.cardBorder,
        thickness: 1,
        space: 20,
      ),
    );
  }
}
