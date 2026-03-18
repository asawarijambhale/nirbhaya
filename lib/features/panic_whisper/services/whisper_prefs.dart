import 'package:shared_preferences/shared_preferences.dart';

/// Handles local persistence for Panic Whisper Detection settings.
class WhisperPrefs {
  static const _keyCodeword = 'panic_codeword';
  static const _keyEnabled = 'panic_whisper_enabled';

  /// Save the panic codeword locally.
  static Future<void> saveCodeword(String codeword) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyCodeword, codeword.trim().toLowerCase());
  }

  /// Retrieve the saved panic codeword. Returns empty string if not set.
  static Future<String> getCodeword() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyCodeword) ?? '';
  }

  /// Save the enabled/disabled toggle state.
  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
  }

  /// Retrieve the enabled state. Defaults to false.
  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }
}
