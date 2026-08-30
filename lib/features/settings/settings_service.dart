import 'package:flutter/foundation.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light-weight app settings backed by SharedPreferences (non sensitive)
/// and FlutterSecureStorage (sensitive, e.g. OpenRouter key).
///
/// On platforms where the secure storage secret service is unavailable
/// (e.g. some Linux desktops without libsecret/D-Bus), it falls back to
/// SharedPreferences so the app keeps working.
class SettingsService {
  static const _appSettingsKey = 'app_settings_v1';
  static const _themeKey = 'theme_mode';
  static const _apiKeyKey = 'openrouter_api_key';
  static const _apiKeyFallbackKey = 'openrouter_api_key_fallback';

  static const _storage = FlutterSecureStorage();

  Future<String?> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey);
  }

  Future<AppSettings> getAppSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_appSettingsKey);
    if (raw != null) {
      try {
        return AppSettings.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        // Fall back to defaults if a partially written value is corrupted.
      }
    }
    final legacyTheme = prefs.getString(_themeKey);
    return AppSettings(
      themeMode: switch (legacyTheme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
    );
  }

  Future<void> setAppSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appSettingsKey, jsonEncode(settings.toJson()));
    await prefs.setString(_themeKey, settings.themeMode.name);
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode);
  }

  Future<String?> getApiKey() async {
    if (!kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS)) {
      try {
        return await _storage.read(key: _apiKeyKey);
      } catch (_) {
        // fall through to fallback
      }
    }
    return _readFallback();
  }

  Future<void> setApiKey(String value) async {
    final secure =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.macOS);
    if (secure) {
      try {
        if (value.isEmpty) {
          await _storage.delete(key: _apiKeyKey);
        } else {
          await _storage.write(key: _apiKeyKey, value: value);
        }
        return;
      } catch (_) {
        // fall through to fallback
      }
    }
    await _writeFallback(value);
  }

  Future<bool> hasApiKey() async {
    final key = await getApiKey();
    return key != null && key.isNotEmpty;
  }

  Future<String?> _readFallback() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_apiKeyFallbackKey);
  }

  Future<void> _writeFallback(String value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value.isEmpty) {
      await prefs.remove(_apiKeyFallbackKey);
    } else {
      await prefs.setString(_apiKeyFallbackKey, value);
    }
  }
}

enum DateFormatPreference { locale, dayMonthYear, monthDayYear }

enum HourFormatPreference { locale, h12, h24 }

class AppSettings {
  const AppSettings({
    this.languageCode = 'es',
    this.themeMode = ThemeMode.system,
    this.dateFormat = DateFormatPreference.locale,
    this.hourFormat = HourFormatPreference.locale,
    this.weekStartsMonday = true,
  });

  final String languageCode;
  final ThemeMode themeMode;
  final DateFormatPreference dateFormat;
  final HourFormatPreference hourFormat;
  final bool weekStartsMonday;

  AppSettings copyWith({
    String? languageCode,
    ThemeMode? themeMode,
    DateFormatPreference? dateFormat,
    HourFormatPreference? hourFormat,
    bool? weekStartsMonday,
  }) {
    return AppSettings(
      languageCode: languageCode ?? this.languageCode,
      themeMode: themeMode ?? this.themeMode,
      dateFormat: dateFormat ?? this.dateFormat,
      hourFormat: hourFormat ?? this.hourFormat,
      weekStartsMonday: weekStartsMonday ?? this.weekStartsMonday,
    );
  }

  Map<String, dynamic> toJson() => {
    'languageCode': languageCode,
    'themeMode': themeMode.name,
    'dateFormat': dateFormat.name,
    'hourFormat': hourFormat.name,
    'weekStartsMonday': weekStartsMonday,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      languageCode: json['languageCode'] == 'en' ? 'en' : 'es',
      themeMode: _themeMode(json['themeMode'] as String?),
      dateFormat: _dateFormat(json['dateFormat'] as String?),
      hourFormat: _hourFormat(json['hourFormat'] as String?),
      weekStartsMonday: json['weekStartsMonday'] as bool? ?? true,
    );
  }

  static ThemeMode _themeMode(String? value) => switch (value) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  static DateFormatPreference _dateFormat(String? value) =>
      DateFormatPreference.values.firstWhere(
        (item) => item.name == value,
        orElse: () => DateFormatPreference.locale,
      );

  static HourFormatPreference _hourFormat(String? value) =>
      HourFormatPreference.values.firstWhere(
        (item) => item.name == value,
        orElse: () => HourFormatPreference.locale,
      );
}
