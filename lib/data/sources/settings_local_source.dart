import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsLocalSource {
  static const _keyThemeMode = 'theme_mode';
  static const _keyLocale = 'locale';
  static const _keyFontFamily = 'font_family';
  static const _keyFontSizeScale = 'font_size_scale';
  static const _keyBiometric = 'biometric_enabled';
  static const _keyAutoLock = 'auto_lock_minutes';
  static const _keyCanvasColor = 'canvas_color';
  static const _keyTextColor = 'text_color';
  static const _keyHighlightColor = 'highlight_color';
  static const _keyKeepScreenOn = 'keep_screen_on';

  final SharedPreferences _prefs;

  SettingsLocalSource(this._prefs);

  ThemeMode getThemeMode() {
    final index = _prefs.getInt(_keyThemeMode);
    if (index == null) return ThemeMode.system;
    return ThemeMode.values[index];
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setInt(_keyThemeMode, mode.index);

  Locale getLocale() {
    final code = _prefs.getString(_keyLocale);
    if (code == null) return const Locale('en');
    return Locale(code);
  }

  Future<void> setLocale(Locale locale) =>
      _prefs.setString(_keyLocale, locale.languageCode);

  String getFontFamily() => _prefs.getString(_keyFontFamily) ?? 'Roboto';

  Future<void> setFontFamily(String family) =>
      _prefs.setString(_keyFontFamily, family);

  double getFontSizeScale() => _prefs.getDouble(_keyFontSizeScale) ?? 1.0;

  Future<void> setFontSizeScale(double scale) =>
      _prefs.setDouble(_keyFontSizeScale, scale);

  bool getBiometricEnabled() => _prefs.getBool(_keyBiometric) ?? false;

  Future<void> setBiometricEnabled(bool enabled) =>
      _prefs.setBool(_keyBiometric, enabled);

  int getAutoLockMinutes() => _prefs.getInt(_keyAutoLock) ?? 5;

  Future<void> setAutoLockMinutes(int minutes) =>
      _prefs.setInt(_keyAutoLock, minutes);

  Color? getCanvasColor() {
    final val = _prefs.getInt(_keyCanvasColor);
    return val == null ? null : Color(val);
  }

  Future<void> setCanvasColor(Color color) =>
      _prefs.setInt(_keyCanvasColor, color.toARGB32());

  Color? getTextColor() {
    final val = _prefs.getInt(_keyTextColor);
    return val == null ? null : Color(val);
  }

  Future<void> setTextColor(Color color) =>
      _prefs.setInt(_keyTextColor, color.toARGB32());

  Color? getHighlightColor() {
    final val = _prefs.getInt(_keyHighlightColor);
    return val == null ? null : Color(val);
  }

  Future<void> setHighlightColor(Color color) =>
      _prefs.setInt(_keyHighlightColor, color.toARGB32());

  bool getKeepScreenOn() => _prefs.getBool(_keyKeepScreenOn) ?? false;

  Future<void> setKeepScreenOn(bool value) =>
      _prefs.setBool(_keyKeepScreenOn, value);
}
