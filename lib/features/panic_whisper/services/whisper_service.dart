import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../services/sos_service.dart';
import 'whisper_prefs.dart';

/// Bridges Flutter ↔ Android WhisperForegroundService via MethodChannel.
///
/// The native service detects the keyword and notifies Flutter.
/// Flutter then triggers the unified SOS flow from `SOSService` so every SOS
/// feature uses the same SMS format and police-details behavior.
class WhisperService extends ChangeNotifier {
  static final WhisperService _instance = WhisperService._internal();
  factory WhisperService() => _instance;
  WhisperService._internal() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const _channel = MethodChannel('com.nirbhaya/whisper');
  final SOSService _sosService = SOSService();

  bool _isEnabled = false;
  // Cooldown: mirror of native cooldown to prevent duplicate Flutter triggers
  DateTime? _lastTrigger;
  static const _cooldown = Duration(seconds: 15);

  bool get isEnabled => _isEnabled;
  bool get isListening => _isEnabled;

  // ── Init ──────────────────────────────────────────────────────────────

  Future<void> init() async {
    _isEnabled = await WhisperPrefs.isEnabled();
    if (_isEnabled) {
      final codeword = await WhisperPrefs.getCodeword();
      if (codeword.isNotEmpty) await _startNativeService(codeword);
    }
    notifyListeners();
  }

  // ── Public API ────────────────────────────────────────────────────────

  Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    await WhisperPrefs.setEnabled(value);
    if (value) {
      final codeword = await WhisperPrefs.getCodeword();
      await _startNativeService(codeword);
    } else {
      await _stopNativeService();
    }
    notifyListeners();
  }

  Future<void> updateCodeword(String codeword) async {
    await WhisperPrefs.saveCodeword(codeword);
    try {
      await _channel.invokeMethod('updateCodeword', {'codeword': codeword});
    } catch (e) {
      debugPrint('[WhisperService] updateCodeword error: $e');
    }
  }

  // ── Native bridge ─────────────────────────────────────────────────────

  Future<void> _startNativeService(String codeword) async {
    try {
      // Fetch contacts and pass as comma-separated numbers to native
      final contacts = await _sosService.getEmergencyContacts().first;
      final phones = contacts.map((c) => c.phoneNumber).join(',');

      await _channel.invokeMethod('startService', {
        'codeword': codeword,
        'contacts': phones,
      });
      debugPrint('[WhisperService] Native service started');
    } catch (e) {
      debugPrint('[WhisperService] startService error: $e');
    }
  }

  Future<void> _stopNativeService() async {
    try {
      await _channel.invokeMethod('stopService');
      debugPrint('[WhisperService] Native service stopped');
    } catch (e) {
      debugPrint('[WhisperService] stopService error: $e');
    }
  }

  /// Called by native when keyword is detected.
  /// Triggers the same SOS pipeline used by the SOS screen.
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method != 'onKeywordDetected') return;

    // Dart-side cooldown guard (prevents duplicate if Flutter is foreground)
    final now = DateTime.now();
    if (_lastTrigger != null && now.difference(_lastTrigger!) < _cooldown) {
      debugPrint('[WhisperService] Ignored due to cooldown');
      return;
    }
    _lastTrigger = now;

    debugPrint('[WhisperService] Keyword detected — triggering unified SOS flow');
    try {
      final contacts = await _sosService.getEmergencyContacts().first;
      final userName = await _sosService.getUserName();
      if (contacts.isNotEmpty) {
        await _sosService.triggerSOSAlert(
          contacts: contacts,
          userName: userName,
        );
      } else {
        debugPrint('[WhisperService] No emergency contacts configured');
      }
    } catch (e) {
      debugPrint('[WhisperService] unified SOS trigger error: $e');
    }
    notifyListeners();
  }
}
