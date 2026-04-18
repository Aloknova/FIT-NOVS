import 'package:flutter/material.dart';

import '../config/app_branding.dart';

ThemeData buildDarkTheme() {
  const seed = AppBranding.accentDark;
  const background = AppBranding.darkBackground;
  final colorScheme = ColorScheme.fromSeed(
    seedColor: seed,
    brightness: Brightness.dark,
  );

  final textTheme = Typography.material2021().white.apply(
    fontFamily: AppBranding.fontFamily,
    bodyColor: colorScheme.onSurface,
    displayColor: colorScheme.onSurface,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: background,
    fontFamily: AppBranding.fontFamily,
    textTheme: textTheme,
    cardColor: AppBranding.darkSurface,
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: colorScheme.onSurface,
      centerTitle: false,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppBranding.darkSurface,
      indicatorColor: colorScheme.primary.withValues(alpha: 0.24),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final isSelected = states.contains(WidgetState.selected);
        return textTheme.labelMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
        );
      }),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppBranding.darkSurface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colorScheme.primary, width: 1.6),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF2A2435),
      contentTextStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
      ),
    ),
  );
}
