import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light-weight app settings backed by SharedPreferences (non sensitive)
/// and FlutterSecureStorage (sensitive, e.g. OpenRouter key).
///
/// On platforms where the secure storage secret service is unavailable
/// (e.g. some Linux desktops without libsecret/D-Bus), it falls back to
/// SharedPreferences so the app keeps working.
class SettingsService {
  static const _themeKey = 'theme_mode';
  static const _apiKeyKey = 'openrouter_api_key';
  static const _apiKeyFallbackKey = 'openrouter_api_key_fallback';

  static const _storage = FlutterSecureStorage();

  Future<String?> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_themeKey);
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
