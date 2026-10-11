import 'package:flutter/material.dart';

@immutable
class SignalColors extends ThemeExtension<SignalColors> {
  final Color excellent;
  final Color good;
  final Color fair;
  final Color weak;
  final Color band24Ghz;
  final Color band5Ghz;
  final Color band6Ghz;

  const SignalColors({
    required this.excellent,
    required this.good,
    required this.fair,
    required this.weak,
    required this.band24Ghz,
    required this.band5Ghz,
    required this.band6Ghz,
  });

  static const dark = SignalColors(
    excellent: Color(0xFF05944F), // Uber Green
    good: Color(0xFF276EF1),      // Uber Blue
    fair: Color(0xFFFFC043),      // Uber Amber
    weak: Color(0xFFE11900),      // Uber Red
    band24Ghz: Color(0xFF8E8E93),
    band5Ghz: Color(0xFF8E8E93),
    band6Ghz: Color(0xFF8E8E93),
  );

  static const light = SignalColors(
    excellent: Color(0xFF05944F),
    good: Color(0xFF276EF1),
    fair: Color(0xFFFFC043),
    weak: Color(0xFFE11900),
    band24Ghz: Color(0xFF545454),
    band5Ghz: Color(0xFF545454),
    band6Ghz: Color(0xFF545454),
  );

  Color colorForRssi(int rssi) {
    if (rssi >= -60) return excellent;
    if (rssi >= -70) return good;
    if (rssi >= -80) return fair;
    return weak;
  }

  Color colorForQuality(int score) {
    if (score >= 80) return excellent;
    if (score >= 60) return good;
    if (score >= 40) return fair;
    return weak;
  }

  Color colorForBand(String band) {
    if (band.contains('2.4')) return band24Ghz;
    if (band.contains('5')) return band5Ghz;
    if (band.contains('6')) return band6Ghz;
    return good;
  }

  @override
  SignalColors copyWith({
    Color? excellent,
    Color? good,
    Color? fair,
    Color? weak,
    Color? band24Ghz,
    Color? band5Ghz,
    Color? band6Ghz,
  }) {
    return SignalColors(
      excellent: excellent ?? this.excellent,
      good: good ?? this.good,
      fair: fair ?? this.fair,
      weak: weak ?? this.weak,
      band24Ghz: band24Ghz ?? this.band24Ghz,
      band5Ghz: band5Ghz ?? this.band5Ghz,
      band6Ghz: band6Ghz ?? this.band6Ghz,
    );
  }

  @override
  SignalColors lerp(ThemeExtension<SignalColors>? other, double t) {
    if (other is! SignalColors) return this;
    return SignalColors(
      excellent: Color.lerp(excellent, other.excellent, t) ?? excellent,
      good: Color.lerp(good, other.good, t) ?? good,
      fair: Color.lerp(fair, other.fair, t) ?? fair,
      weak: Color.lerp(weak, other.weak, t) ?? weak,
      band24Ghz: Color.lerp(band24Ghz, other.band24Ghz, t) ?? band24Ghz,
      band5Ghz: Color.lerp(band5Ghz, other.band5Ghz, t) ?? band5Ghz,
      band6Ghz: Color.lerp(band6Ghz, other.band6Ghz, t) ?? band6Ghz,
    );
  }
}

class AppTheme {
  // Dark Palette (Uber Base True OLED Black)
  static const Color darkScaffold = Color(0xFF000000);
  static const Color darkSurface = Color(0xFF121212);
  static const Color darkSurfaceContainer = Color(0xFF1F1F1F);
  static const Color darkInputFill = Color(0xFF141414);
  static const Color darkDivider = Color(0xFF222222);
  static const Color darkPrimaryText = Color(0xFFFFFFFF);
  static const Color darkSecondaryText = Color(0xFF8E8E93);
  static const Color darkPrimaryAction = Color(0xFFFFFFFF);

  // Light Palette (Uber Base Pure White)
  static const Color lightScaffold = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF6F6F6);
  static const Color lightSurfaceContainer = Color(0xFFEEEEEE);
  static const Color lightInputFill = Color(0xFFF3F3F3);
  static const Color lightDivider = Color(0xFFE5E5E5);
  static const Color lightPrimaryText = Color(0xFF000000);
  static const Color lightSecondaryText = Color(0xFF545454);
  static const Color lightPrimaryAction = Color(0xFF000000);

  static const SignalColors darkSignalColors = SignalColors.dark;
  static const SignalColors lightSignalColors = SignalColors.light;

  // Typography scale
  static TextStyle pageTitleStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 26,
      fontWeight: FontWeight.w700,
      letterSpacing: -0.7,
      color: isDark ? darkPrimaryText : lightPrimaryText,
    );
  }

  static TextStyle sectionHeaderStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: isDark ? darkSecondaryText : lightSecondaryText,
    );
  }

  static TextStyle itemTitleStyle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.3,
      color: isDark ? darkPrimaryText : lightPrimaryText,
    );
  }

  static TextStyle monoStyle(
    BuildContext context, {
    double fontSize = 12,
    FontWeight weight = FontWeight.w500,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextStyle(
      fontFamily: 'monospace',
      fontFeatures: const [FontFeature.tabularFigures()],
      fontSize: fontSize,
      fontWeight: weight,
      color: color ?? (isDark ? darkSecondaryText : lightSecondaryText),
    );
  }

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: darkPrimaryAction,
      onPrimary: Color(0xFF000000),
      secondary: darkPrimaryAction,
      onSecondary: Color(0xFF000000),
      error: Color(0xFFE11900),
      onError: Color(0xFFFFFFFF),
      surface: darkSurface,
      onSurface: darkPrimaryText,
      surfaceContainerHighest: darkSurfaceContainer,
      onSurfaceVariant: darkSecondaryText,
      outline: darkSecondaryText,
      outlineVariant: darkDivider,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: darkScaffold,
      dividerColor: darkDivider,
      dividerTheme: const DividerThemeData(
        color: darkDivider,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: darkScaffold,
        foregroundColor: darkPrimaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: darkPrimaryText,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: darkPrimaryAction,
          foregroundColor: const Color(0xFF000000),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkInputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: darkSecondaryText, fontSize: 14),
        labelStyle: const TextStyle(color: darkSecondaryText, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFFFFFFFF), width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 64,
        backgroundColor: darkScaffold,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: darkPrimaryText,
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: darkSecondaryText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: darkPrimaryText, size: 22);
          }
          return const IconThemeData(color: darkSecondaryText, size: 22);
        }),
      ),
      extensions: const [SignalColors.dark],
    );
  }

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: lightPrimaryAction,
      onPrimary: Color(0xFFFFFFFF),
      secondary: lightPrimaryAction,
      onSecondary: Color(0xFFFFFFFF),
      error: Color(0xFFE11900),
      onError: Color(0xFFFFFFFF),
      surface: lightSurface,
      onSurface: lightPrimaryText,
      surfaceContainerHighest: lightSurfaceContainer,
      onSurfaceVariant: lightSecondaryText,
      outline: lightSecondaryText,
      outlineVariant: lightDivider,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: lightScaffold,
      dividerColor: lightDivider,
      dividerTheme: const DividerThemeData(
        color: lightDivider,
        thickness: 1,
        space: 1,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: lightScaffold,
        foregroundColor: lightPrimaryText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          color: lightPrimaryText,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: lightSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: lightPrimaryAction,
          foregroundColor: const Color(0xFFFFFFFF),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightInputFill,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: const TextStyle(color: lightSecondaryText, fontSize: 14),
        labelStyle: const TextStyle(color: lightSecondaryText, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF000000), width: 1.5),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 64,
        backgroundColor: lightScaffold,
        indicatorColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: lightPrimaryText,
            );
          }
          return const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: lightSecondaryText,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: lightPrimaryText, size: 22);
          }
          return const IconThemeData(color: lightSecondaryText, size: 22);
        }),
      ),
      extensions: const [SignalColors.light],
    );
  }
}
