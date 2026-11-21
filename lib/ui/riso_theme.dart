import 'package:flutter/material.dart';

import 'riso.dart';

ThemeData risoTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Riso.blue,
    primary: Riso.ink,
    onPrimary: Riso.paper,
    secondary: Riso.red,
    onSecondary: Riso.paper,
    tertiary: Riso.green,
    surface: Riso.paper,
    onSurface: Riso.ink,
    surfaceContainerHighest: Riso.paperShade,
    error: const Color(0xFFC3283A),
  );
  const title = TextStyle(
    color: Riso.ink,
    fontWeight: FontWeight.w900,
    letterSpacing: -0.3,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Riso.paper,
    textTheme: Typography.blackMountainView.apply(
      bodyColor: Riso.ink,
      displayColor: Riso.ink,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: Riso.paper,
      foregroundColor: Riso.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      titleTextStyle: title.copyWith(fontSize: 22),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Riso.paperShade,
      indicatorColor: Riso.yellow,
      surfaceTintColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.all(
        const TextStyle(fontWeight: FontWeight.w700, color: Riso.ink),
      ),
      iconTheme: WidgetStateProperty.all(const IconThemeData(color: Riso.ink)),
    ),
    cardTheme: const CardThemeData(
      color: Riso.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Riso.ink, width: 1.5),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: Riso.ink,
        foregroundColor: Riso.paper,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: Riso.ink,
        side: const BorderSide(color: Riso.ink, width: 1.5),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: BorderSide(color: Riso.ink, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Riso.ink, width: 1.5),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: Riso.ink,
      contentTextStyle: TextStyle(color: Riso.paper),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

/// Hard offset "misprint" shadow used for cards on paper.
List<BoxShadow> risoShadow({Color color = Riso.pink, double offset = 5}) => [
  BoxShadow(
    color: color.withValues(alpha: 0.85),
    offset: Offset(offset, offset),
  ),
];
