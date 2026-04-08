import 'package:shared_preferences/shared_preferences.dart';

/// Persists Volume SOS settings locally.
class VolumeSosPrefs {
  static const _keyEnabled = 'volume_sos_enabled';

  static Future<void> setEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, value);
  }

  static Future<bool> isEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyEnabled) ?? false;
  }
}
