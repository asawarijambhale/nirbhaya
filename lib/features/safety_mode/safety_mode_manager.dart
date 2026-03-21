import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../eye_gesture_sos/services/eye_gesture_service.dart';
import '../panic_whisper/services/whisper_service.dart';

/// Describes which safety subsystem is currently active.
enum SafetyMode {
  eyeGesture,  // foreground — camera blink detection
  whisper,     // background / locked — native voice keyword
  none,        // both disabled (user hasn't enabled either)
}

/// Coordinates automatic switching between Eye Gesture SOS (foreground)
/// and Panic Whisper Detection (background/locked) based on app lifecycle.
///
/// Rules:
///   • App resumed (foreground)  → eye detection ON  | whisper paused
///   • App paused  (background)  → eye detection OFF | whisper ON
///   • App detached              → eye detection OFF | whisper ON
///
/// Both services must be individually enabled by the user in Settings.
/// SafetyModeManager only switches the ACTIVE one — it never enables a
/// service the user has not turned on.
class SafetyModeManager extends ChangeNotifier
    with WidgetsBindingObserver {
  final EyeGestureService eyeService;
  final WhisperService whisperService;

  SafetyMode _currentMode = SafetyMode.none;
  bool _appInForeground = true;

  SafetyMode get currentMode => _currentMode;
  bool get appInForeground => _appInForeground;

  SafetyModeManager({
    required this.eyeService,
    required this.whisperService,
  }) {
    WidgetsBinding.instance.addObserver(this);
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _onForeground();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _onBackground();
        break;
      case AppLifecycleState.inactive:
        // Brief inactive (e.g. notification shade) — don't switch yet
        break;
    }
  }

  // ── Mode Switching ────────────────────────────────────────────────────────

  Future<void> _onForeground() async {
    if (_appInForeground) return;
    _appInForeground = true;
    debugPrint('[SafetyMode] App → FOREGROUND');

    if (eyeService.isEnabled) {
      // Resume eye monitoring
      eyeService.resumeForForeground();
      _currentMode = SafetyMode.eyeGesture;
      debugPrint('[SafetyMode] Mode → EYE GESTURE');
    } else if (whisperService.isEnabled) {
      _currentMode = SafetyMode.whisper;
    } else {
      _currentMode = SafetyMode.none;
    }
    notifyListeners();
  }

  Future<void> _onBackground() async {
    if (!_appInForeground) return;
    _appInForeground = false;
    debugPrint('[SafetyMode] App → BACKGROUND');

    // Always pause eye detection — camera cannot run in background
    if (eyeService.isEnabled) {
      eyeService.pauseForBackground();
      debugPrint('[SafetyMode] Eye detection PAUSED');
    }

    // Whisper service is a native foreground service — it keeps running
    if (whisperService.isEnabled) {
      _currentMode = SafetyMode.whisper;
      debugPrint('[SafetyMode] Mode → WHISPER');
    } else {
      _currentMode = SafetyMode.none;
    }
    notifyListeners();
  }

  /// Call once at startup to set initial mode.
  void evaluateInitialMode() {
    _appInForeground = true;
    if (eyeService.isEnabled) {
      _currentMode = SafetyMode.eyeGesture;
    } else if (whisperService.isEnabled) {
      _currentMode = SafetyMode.whisper;
    } else {
      _currentMode = SafetyMode.none;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
