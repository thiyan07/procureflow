import 'package:flutter/material.dart';

class AppTheme {
  // Agriculture / public-service palette - warm earth + trust blue
  static const Color primaryGreen = Color(0xFF2E7D32); // procurement / agriculture
  static const Color primaryGreenDark = Color(0xFF1B5E20);
  static const Color accentAmber = Color(0xFFFF8F00);
  static const Color background = Color(0xFFF8FAF6);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1A1C19);
  static const Color textSecondary = Color(0xFF5A5F5A);
  static const Color border = Color(0xFFE0E5DE);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFEF6C00);
  static const Color error = Color(0xFFC62828);

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      primary: primaryGreen,
      secondary: Color(0xFF4CAF50),
      surface: surface,
      error: error,
    ),
    scaffoldBackgroundColor: background,
    appBarTheme: const AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      iconTheme: IconThemeData(color: textPrimary),
      actionsIconTheme: IconThemeData(color: textPrimary),
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: border, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryGreen,
        side: const BorderSide(color: primaryGreen, width: 1.5),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primaryGreen),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: primaryGreen, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIconColor: textSecondary,
      prefixIconColor: textSecondary,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      side: const BorderSide(color: border),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: textPrimary),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: textPrimary),
      bodyLarge: TextStyle(fontSize: 16, color: textPrimary),
      bodyMedium: TextStyle(fontSize: 14, color: textSecondary),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: primaryGreen,
      brightness: Brightness.dark,
      primary: Color(0xFF66BB6A),
      secondary: Color(0xFF81C784),
      surface: Color(0xFF121412),
      error: Color(0xFFEF9A9A),
    ),
    scaffoldBackgroundColor: const Color(0xFF0F1110),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1A1E1B),
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E221F),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Color(0xFF2E352E), width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: Color(0xFF66BB6A),
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Color(0xFF81C784),
        side: const BorderSide(color: Color(0xFF81C784), width: 1.5),
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF1E221F),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E352E)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2E352E)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF66BB6A), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white),
      headlineMedium: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Colors.white),
      titleLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
      bodyLarge: TextStyle(fontSize: 16, color: Colors.white70),
      bodyMedium: TextStyle(fontSize: 14, color: Colors.white60),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white),
    ),
  );
}
