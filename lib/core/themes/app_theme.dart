import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static ThemeData light({
    String fontFamily = 'Roboto',
    double fontSizeScale = 1.0,
    Color? canvasColor,
    Color? textColor,
    Color? highlightColor,
    ColorScheme? colorScheme,
  }) {
    final scheme = _buildScheme(
      brightness: Brightness.light,
      baseScheme: colorScheme,
      highlightColor: highlightColor,
    );
    final surface = canvasColor ?? scheme.surface;

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme.copyWith(surface: surface),
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      cardColor: surface,
    );

    return _applyCustomizations(
      base,
      fontFamily,
      fontSizeScale,
      textColor,
      surface,
    );
  }

  static ThemeData dark({
    String fontFamily = 'Roboto',
    double fontSizeScale = 1.0,
    Color? canvasColor,
    Color? textColor,
    Color? highlightColor,
    ColorScheme? colorScheme,
  }) {
    final scheme = _buildScheme(
      brightness: Brightness.dark,
      baseScheme: colorScheme,
      highlightColor: highlightColor,
    );
    final surface = canvasColor ?? scheme.surface;

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme.copyWith(surface: surface),
      scaffoldBackgroundColor: surface,
      canvasColor: surface,
      cardColor: surface,
    );

    return _applyCustomizations(
      base,
      fontFamily,
      fontSizeScale,
      textColor,
      surface,
    );
  }

  static ThemeData _applyCustomizations(
    ThemeData base,
    String fontFamily,
    double fontSizeScale,
    Color? textColor,
    Color surface,
  ) {
    TextTheme textTheme = GoogleFonts.getTextTheme(fontFamily, base.textTheme);

    if (fontSizeScale != 1.0) {
      textTheme = textTheme.copyWith(
        displayLarge: _scaleTextStyle(textTheme.displayLarge, fontSizeScale),
        displayMedium: _scaleTextStyle(textTheme.displayMedium, fontSizeScale),
        displaySmall: _scaleTextStyle(textTheme.displaySmall, fontSizeScale),
        headlineLarge: _scaleTextStyle(textTheme.headlineLarge, fontSizeScale),
        headlineMedium: _scaleTextStyle(
          textTheme.headlineMedium,
          fontSizeScale,
        ),
        headlineSmall: _scaleTextStyle(textTheme.headlineSmall, fontSizeScale),
        titleLarge: _scaleTextStyle(textTheme.titleLarge, fontSizeScale),
        titleMedium: _scaleTextStyle(textTheme.titleMedium, fontSizeScale),
        titleSmall: _scaleTextStyle(textTheme.titleSmall, fontSizeScale),
        bodyLarge: _scaleTextStyle(textTheme.bodyLarge, fontSizeScale),
        bodyMedium: _scaleTextStyle(textTheme.bodyMedium, fontSizeScale),
        bodySmall: _scaleTextStyle(textTheme.bodySmall, fontSizeScale),
        labelLarge: _scaleTextStyle(textTheme.labelLarge, fontSizeScale),
        labelMedium: _scaleTextStyle(textTheme.labelMedium, fontSizeScale),
        labelSmall: _scaleTextStyle(textTheme.labelSmall, fontSizeScale),
      );
    }

    final effectiveOnSurface = textColor ?? base.colorScheme.onSurface;

    if (textColor != null) {
      textTheme = textTheme.apply(
        bodyColor: textColor,
        displayColor: textColor,
      );
    }

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: base.appBarTheme.copyWith(
        backgroundColor: surface,
        foregroundColor: effectiveOnSurface,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: effectiveOnSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      listTileTheme: base.listTileTheme.copyWith(
        iconColor: effectiveOnSurface.withValues(alpha: 0.9),
        textColor: effectiveOnSurface,
      ),
      iconTheme: base.iconTheme.copyWith(color: effectiveOnSurface),
      popupMenuTheme: base.popupMenuTheme.copyWith(
        textStyle: textTheme.bodyMedium?.copyWith(color: effectiveOnSurface),
      ),
    );
  }

  static ColorScheme _buildScheme({
    required Brightness brightness,
    ColorScheme? baseScheme,
    Color? highlightColor,
  }) {
    if (baseScheme != null) {
      if (highlightColor == null) return baseScheme;
      final onHighlight = _onColor(highlightColor);
      return baseScheme.copyWith(
        primary: highlightColor,
        secondary: highlightColor,
        tertiary: highlightColor,
        onPrimary: onHighlight,
        onSecondary: onHighlight,
        onTertiary: onHighlight,
      );
    }

    final seed = highlightColor ?? const Color(0xFF2D6A6A);
    return ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
  }

  static Color _onColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }

  static TextStyle? _scaleTextStyle(TextStyle? style, double scale) {
    if (style == null) return null;
    return style.copyWith(fontSize: (style.fontSize ?? 14) * scale);
  }
}
