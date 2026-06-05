import 'package:flutter/material.dart';

class AppTheme {
  static const Color cBg = Color(0xFF000000);
  static const Color cS1 = Color(0xFF080808);
  static const Color cS2 = Color(0xFF0E0E0E);
  static const Color cS3 = Color(0xFF141414);
  static const Color cBorder = Color(0xFF1C1C1C);
  static const Color cBorderHi = Color(0xFF2E2E2E);

  static const Color cCyan = Color(0xFF00FFFF);
  static const Color cMagenta = Color(0xFFFF00FF);
  static const Color cGold = Color(0xFFFFD700);
  static const Color cGreen = Color(0xFF22C55E);
  static const Color cRed = Color(0xFFEF4444);

  static const String fontMono = 'Inter';

  static String section(String text) => '  ${text.toUpperCase()}';
  static String cmd(String text) => '[CMD] ${text.toUpperCase()}';

  static final ThemeData darkTheme = _buildIndustrialTheme();
  static final ThemeData lightTheme = _buildIndustrialTheme();

  static ThemeData _buildIndustrialTheme() {
    final base = ThemeData(
      useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: cBg,
    fontFamily: fontMono,
    colorScheme: const ColorScheme.dark(
      primary: cCyan,
      secondary: cMagenta,
      surface: cS2,
      error: cRed,
      outline: cBorder,
      onSurface: Colors.white,
      onPrimary: Colors.black,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: cS1,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: fontMono,
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.4,
      ),
    ),
    cardTheme: CardTheme(
      color: cS2,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: const BorderSide(color: cBorder),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: cCyan,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
          side: const BorderSide(color: cBorderHi),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: cCyan,
        side: const BorderSide(color: cBorderHi),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.zero,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: cGold,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: cS3,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: cBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: cBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: const BorderSide(color: cBorderHi),
      ),
      labelStyle: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900),
      hintStyle: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w900),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return cCyan;
        return Colors.white54;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return cS3;
        }
        return cS2;
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: cCyan,
      inactiveTrackColor: cS3,
      thumbColor: cGold,
      overlayColor: cCyan,
      valueIndicatorColor: cS1,
      valueIndicatorTextStyle: const TextStyle(color: cGold, fontWeight: FontWeight.w900),
    ),
    dividerColor: cBorder,
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: cCyan,
      selectionColor: cS3,
      selectionHandleColor: cCyan,
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: fontMono,
        fontSize: 24,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
      headlineMedium: TextStyle(
        fontFamily: fontMono,
        fontSize: 20,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 0.4,
      ),
      titleLarge: TextStyle(
        fontFamily: fontMono,
        fontSize: 16,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 0.4,
      ),
      titleMedium: TextStyle(
        fontFamily: fontMono,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 0.3,
      ),
      bodyLarge: TextStyle(
        fontFamily: fontMono,
        fontSize: 14,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 0.3,
      ),
      bodyMedium: TextStyle(
        fontFamily: fontMono,
        fontSize: 13,
        fontWeight: FontWeight.w900,
        color: Colors.white,
        letterSpacing: 0.2,
      ),
      bodySmall: TextStyle(
        fontFamily: fontMono,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: Colors.white70,
        letterSpacing: 0.2,
      ),
      labelLarge: TextStyle(
        fontFamily: fontMono,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        color: Colors.white70,
        letterSpacing: 0.3,
      ),
    ),
    dialogTheme: DialogTheme(
      backgroundColor: cS2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.zero,
        side: const BorderSide(color: cBorder),
      ),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: cS2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
    ),
    );

    // Force uppercase visual style and sharp corners application-wide.
    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
    );
  }
}
