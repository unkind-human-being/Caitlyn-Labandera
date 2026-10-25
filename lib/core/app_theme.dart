import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF0A1744);
  static const navySoft = Color(0xFF172854);
  static const teal = Color(0xFF0E9DB1);
  static const lightTeal = Color(0xFFE4F8FA);
  static const background = Color(0xFFF5F8FC);
  static const ink = Color(0xFF18243D);
  static const muted = Color(0xFF6B7890);
  static const border = Color(0xFFE0E8F1);
  static const danger = Color(0xFFB83244);
}

ThemeData buildAppTheme() {
  final colors = ColorScheme.fromSeed(
    seedColor: AppColors.navy,
    primary: AppColors.navy,
    secondary: AppColors.teal,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.navy,
      elevation: 0,
      surfaceTintColor: Colors.white,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.navy,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.lightTeal,
    ),
  );
}
