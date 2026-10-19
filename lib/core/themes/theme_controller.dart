import 'package:flex_color_scheme/flex_color_scheme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AppColorScheme { teal, orange, purple, blue }

class ThemeState {
  final ThemeMode mode;
  final AppColorScheme colorScheme;

  const ThemeState({required this.mode, required this.colorScheme});

  ThemeState copyWith({ThemeMode? mode, AppColorScheme? colorScheme}) {
    return ThemeState(
      mode: mode ?? this.mode,
      colorScheme: colorScheme ?? this.colorScheme,
    );
  }
}

class ThemeController extends Notifier<ThemeState> {
  @override
  ThemeState build() {
    // later: load from SharedPreferences / secure storage
    return const ThemeState(
      mode: ThemeMode.system,
      colorScheme: AppColorScheme.teal,
    );
  }

  void setMode(ThemeMode mode) => state = state.copyWith(mode: mode);

  void setColorScheme(AppColorScheme scheme) =>
      state = state.copyWith(colorScheme: scheme);
}

final themeControllerProvider = NotifierProvider<ThemeController, ThemeState>(
  ThemeController.new,
);

FlexScheme _mapScheme(AppColorScheme scheme) {
  switch (scheme) {
    case AppColorScheme.orange:
      return FlexScheme.mango;
    case AppColorScheme.purple:
      return FlexScheme.mandyRed;
    case AppColorScheme.blue:
      return FlexScheme.flutterDash;
    case AppColorScheme.teal:
      return FlexScheme.greenM3;
  }
}

ThemeData buildLightTheme(ThemeState state) {
  return FlexThemeData.light(
    scheme: _mapScheme(state.colorScheme),
    useMaterial3: true,
    surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
    blendLevel: 12,
    appBarStyle: FlexAppBarStyle.primary,
  );
}

ThemeData buildDarkTheme(ThemeState state) {
  return FlexThemeData.dark(
    scheme: _mapScheme(state.colorScheme),
    useMaterial3: true,
    surfaceMode: FlexSurfaceMode.highScaffoldLowSurface,
    blendLevel: 18,
    appBarStyle: FlexAppBarStyle.primary,
  );
}
