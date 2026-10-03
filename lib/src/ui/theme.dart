import 'package:flutter/material.dart';

const _defaultSeed = Color(0xFF0D6EFD);

ThemeData buildLightTheme([Color seed = _defaultSeed]) =>
    _build(ColorScheme.fromSeed(seedColor: seed));

ThemeData buildDarkTheme([Color seed = _defaultSeed]) => _build(
    ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.dark));

ThemeData _build(ColorScheme scheme) => ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
    );

/// Parses '#RRGGBB' from an organization's branding.
Color? parseHexColor(String? hex) {
  if (hex == null || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
  return Color(0xFF000000 | int.parse(hex.substring(1), radix: 16));
}
