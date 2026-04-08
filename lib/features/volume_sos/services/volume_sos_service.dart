import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../services/sos_service.dart';
import 'volume_sos_prefs.dart';

/// Manages Volume SOS state and bridges native → Flutter SOS trigger.
///
/// Uses its OWN dedicated channel 'com.nirbhaya/volume_sos' — completely
/// separate from WhisperService's 'com.nirbhaya/whisper' channel.
/// Two MethodChannels on the same name = only one handler wins. Keep them apart.
class VolumeSosService extends ChangeNotifier {
  static final VolumeSosService _instance = VolumeSosService._internal();
  factory VolumeSosService() => _instance;

  VolumeSosService._internal() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  // Dedicated channel — NOT shared with WhisperService
  static const _channel = MethodChannel('com.nirbhaya/volume_sos');
  final SOSService _sosService = SOSService();

  bool _isEnabled = false;
  DateTime? _lastTrigger;
  static const _cooldown = Duration(seconds: 15);

  bool get isEnabled => _isEnabled;

  // ── Init ──────────────────────────────────────────────────────────────

  Future<void> init() async {
    _isEnabled = await VolumeSosPrefs.isEnabled();
    await _syncToNative();
    notifyListeners();
  }

  // ── Public API ────────────────────────────────────────────────────────

  Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    await VolumeSosPrefs.setEnabled(value);
    await _syncToNative();
    notifyListeners();
  }

  // ── Native bridge ─────────────────────────────────────────────────────

  Future<void> _syncToNative() async {
    try {
      await _channel.invokeMethod('setVolumeSosEnabled', {'enabled': _isEnabled});
      debugPrint('[VolumeSosService] synced enabled=$_isEnabled to native');
    } catch (e) {
      debugPrint('[VolumeSosService] syncToNative error: $e');
    }
  }

  Future<void> requestBatteryExemption() async {
    try {
      await _channel.invokeMethod('requestBatteryOptimizationExemption');
    } catch (e) {
      debugPrint('[VolumeSosService] batteryExemption error: $e');
    }
  }

  /// Receives the volume SOS trigger from native.
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onVolumeSosDetected') return;

    if (!_isEnabled) {
      debugPrint('[VolumeSosService] disabled — ignoring trigger');
      return;
    }

    final now = DateTime.now();
    if (_lastTrigger != null && now.difference(_lastTrigger!) < _cooldown) {
      debugPrint('[VolumeSosService] cooldown active — ignoring trigger');
      return;
    }
    _lastTrigger = now;

    debugPrint('[VolumeSosService] Volume SOS confirmed — triggering SOS');
    try {
      final contacts = await _sosService.getEmergencyContacts().first;
      final userName = await _sosService.getUserName();
      if (contacts.isNotEmpty) {
        await _sosService.triggerSOSAlert(contacts: contacts, userName: userName);
      } else {
        debugPrint('[VolumeSosService] No emergency contacts configured');
      }
    } catch (e) {
      debugPrint('[VolumeSosService] SOS trigger error: $e');
    }
    notifyListeners();
  }
}
