import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../data/sources/settings_local_source.dart';
import 'di.dart';

class AppSettingsState {
  final ThemeMode themeMode;
  final Locale locale;
  final String fontFamily;
  final double fontSizeScale;
  final bool isBiometricEnabled;
  final int autoLockMinutes;
  final bool keepScreenOn;
  final Color? canvasColor;
  final Color? textColor;
  final Color? highlightColor;

  const AppSettingsState({
    this.themeMode = ThemeMode.system,
    this.locale = const Locale('en'),
    this.fontFamily = 'Roboto',
    this.fontSizeScale = 1.0,
    this.isBiometricEnabled = false,
    this.autoLockMinutes = 5,
    this.keepScreenOn = false,
    this.canvasColor,
    this.textColor,
    this.highlightColor,
  });

  AppSettingsState copyWith({
    ThemeMode? themeMode,
    Locale? locale,
    String? fontFamily,
    double? fontSizeScale,
    bool? isBiometricEnabled,
    int? autoLockMinutes,
    bool? keepScreenOn,
    Color? canvasColor,
    Color? textColor,
    Color? highlightColor,
  }) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSizeScale: fontSizeScale ?? this.fontSizeScale,
      isBiometricEnabled: isBiometricEnabled ?? this.isBiometricEnabled,
      autoLockMinutes: autoLockMinutes ?? this.autoLockMinutes,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      canvasColor: canvasColor ?? this.canvasColor,
      textColor: textColor ?? this.textColor,
      highlightColor: highlightColor ?? this.highlightColor,
    );
  }
}

class AppSettingsViewModel extends StateNotifier<AppSettingsState> {
  final SettingsLocalSource _source;

  AppSettingsViewModel(this._source) : super(const AppSettingsState()) {
    _loadSettings();
  }

  void _loadSettings() {
    final mode = _source.getThemeMode();
    final locale = _source.getLocale();
    final family = _source.getFontFamily();
    final scale = _source.getFontSizeScale();
    final bio = _source.getBiometricEnabled();
    final lock = _source.getAutoLockMinutes();
    final canvas = _source.getCanvasColor();
    final text = _source.getTextColor();
    final highlight = _source.getHighlightColor();
    final keepAwake = _source.getKeepScreenOn();
    if (keepAwake) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }

    state = AppSettingsState(
      themeMode: mode,
      locale: locale,
      fontFamily: family,
      fontSizeScale: scale,
      isBiometricEnabled: bio,
      autoLockMinutes: lock,
      canvasColor: canvas,
      textColor: text,
      highlightColor: highlight,
      keepScreenOn: keepAwake,
    );
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    await _source.setThemeMode(mode);
  }

  Future<void> setLocale(Locale locale) async {
    state = state.copyWith(locale: locale);
    await _source.setLocale(locale);
  }

  Future<void> setFontFamily(String family) async {
    state = state.copyWith(fontFamily: family);
    await _source.setFontFamily(family);
  }

  Future<void> setFontSizeScale(double scale) async {
    state = state.copyWith(fontSizeScale: scale);
    await _source.setFontSizeScale(scale);
  }

  Future<void> setBiometricEnabled(bool enabled) async {
    state = state.copyWith(isBiometricEnabled: enabled);
    await _source.setBiometricEnabled(enabled);
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    state = state.copyWith(autoLockMinutes: minutes);
    await _source.setAutoLockMinutes(minutes);
  }

  Future<void> setKeepScreenOn(bool enabled) async {
    state = state.copyWith(keepScreenOn: enabled);
    await _source.setKeepScreenOn(enabled);
    if (enabled) {
      await WakelockPlus.enable();
    } else {
      await WakelockPlus.disable();
    }
  }

  Future<void> setCanvasColor(Color color) async {
    state = state.copyWith(canvasColor: color);
    await _source.setCanvasColor(color);
  }

  Future<void> setTextColor(Color color) async {
    state = state.copyWith(textColor: color);
    await _source.setTextColor(color);
  }

  Future<void> setHighlightColor(Color color) async {
    state = state.copyWith(highlightColor: color);
    await _source.setHighlightColor(color);
  }
}

final appSettingsProvider =
    StateNotifierProvider<AppSettingsViewModel, AppSettingsState>((ref) {
      return AppSettingsViewModel(ref.watch(settingsLocalSourceProvider));
    });
