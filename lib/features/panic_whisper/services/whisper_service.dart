import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../services/sos_service.dart';
import 'whisper_prefs.dart';

/// Singleton that bridges Flutter ↔ Android WhisperForegroundService.
///
/// On Android the actual listening runs inside a native foreground service
/// (WhisperForegroundService.kt) so it survives screen-off and app backgrounding.
/// This Dart class:
///   1. Sends start/stop/updateCodeword commands to the native service.
///   2. Receives "onKeywordDetected" callbacks from the native service.
///   3. Calls SOSService.triggerSOSAlert() silently when the keyword fires.
class WhisperService extends ChangeNotifier {
  static final WhisperService _instance = WhisperService._internal();
  factory WhisperService() => _instance;
  WhisperService._internal() {
    // Listen for keyword-detected events coming from the native service
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const _channel = MethodChannel('com.nirbhaya/whisper');
  final SOSService _sosService = SOSService();

  bool _isEnabled = false;
  String _lastDetected = '';

  bool get isEnabled => _isEnabled;
  bool get isListening => _isEnabled; // native service is running when enabled
  String get lastDetected => _lastDetected;

  // ── Init ──────────────────────────────────────────────────────────────────

  /// Restore saved state on app start.
  Future<void> init() async {
    _isEnabled = await WhisperPrefs.isEnabled();
    if (_isEnabled) {
      final codeword = await WhisperPrefs.getCodeword();
      if (codeword.isNotEmpty) {
        await _startNativeService(codeword);
      }
    }
    notifyListeners();
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Enable or disable the whisper detection system.
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

  /// Save a new codeword and push it to the running native service.
  Future<void> updateCodeword(String codeword) async {
    await WhisperPrefs.saveCodeword(codeword);
    try {
      await _channel.invokeMethod('updateCodeword', {'codeword': codeword});
    } catch (e) {
      debugPrint('[WhisperService] updateCodeword error: $e');
    }
  }

  // ── Native bridge ─────────────────────────────────────────────────────────

  Future<void> _startNativeService(String codeword) async {
    try {
      await _channel.invokeMethod('startService', {'codeword': codeword});
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

  /// Handles method calls coming FROM native → Flutter.
  Future<dynamic> _handleNativeCall(MethodCall call) async {
    if (call.method == 'onKeywordDetected') {
      debugPrint('[WhisperService] Keyword detected — triggering silent SOS');
      _lastDetected = 'codeword detected';
      notifyListeners();
      await _triggerSilentSOS();
    }
  }

  // ── Silent SOS ────────────────────────────────────────────────────────────

  Future<void> _triggerSilentSOS() async {
    try {
      final contacts = await _sosService.getEmergencyContacts().first;
      final userName = await _sosService.getUserName();

      if (contacts.isEmpty) {
        debugPrint('[WhisperService] No emergency contacts — SOS skipped');
        return;
      }

      // Log event to Firestore
      await FirebaseFirestore.instance.collection('emergency_alerts').add({
        'userId': FirebaseAuth.instance.currentUser?.uid,
        'trigger': 'panic_whisper',
        'timestamp': FieldValue.serverTimestamp(),
        'type': 'whisper_sos',
      });

      await _sosService.triggerSOSAlert(
        contacts: contacts,
        userName: userName,
      );

      debugPrint('[WhisperService] Silent SOS triggered successfully');
    } catch (e) {
      debugPrint('[WhisperService] Error triggering SOS: $e');
    }
  }
}
