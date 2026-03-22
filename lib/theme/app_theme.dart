import 'package:flutter/material.dart';

class AppColors {
  static const primary     = Color(0xFF101D68);  // royal blue
  static const primaryDark = Color(0xFF0A1245);  // darker blue
  static const accent      = Color(0xFF3B82F6);  // light blue accent
  static const background  = Color(0xFFEFF3FF);  // light blue-tinted bg
  static const surface     = Colors.white;
  static const textDark    = Color(0xFF0D1B4B);
  static const textMid     = Color(0xFF4A5568);
  static const textLight   = Color(0xFF9AA5B4);
  static const error       = Color(0xFFD32F2F);
}

class AppTheme {
  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      error: AppColors.error,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 3,
      shadowColor: AppColors.primary.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 2,
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      labelStyle: const TextStyle(color: AppColors.textMid),
    ),
    textTheme: const TextTheme(
      headlineLarge:  TextStyle(fontSize: 28, fontWeight: FontWeight.bold,   color: AppColors.textDark),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.bold,   color: AppColors.textDark),
      titleLarge:     TextStyle(fontSize: 18, fontWeight: FontWeight.w600,   color: AppColors.textDark),
      bodyLarge:      TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: AppColors.textDark),
      bodyMedium:     TextStyle(fontSize: 14, color: AppColors.textMid),
    ),
  );
}
