import 'dart:async';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/sos_service.dart';

enum EyeGestureState {
  idle,       // disabled or paused (background)
  monitoring, // waiting for inactivity — camera OFF
  active,     // camera ON, blink detection running
}

class EyeGestureService extends ChangeNotifier {
  static const _prefKey            = 'eye_sos_enabled';
  static const _inactivityThreshold = Duration(seconds: 15);

  // ── Blink detection constants ─────────────────────────────────────────────
  // Two eyes must both be below this probability to count as a blink.
  static const _blinkThreshold    = 0.4;
  // Max gap between consecutive blinks to count as part of the same pattern.
  static const _maxBlinkGap       = Duration(milliseconds: 800);
  // Total window within which all 3 blinks must occur.
  static const _blinkWindow       = Duration(seconds: 3);
  static const _requiredBlinks    = 3;

  // ── SOS lock ──────────────────────────────────────────────────────────────
  // Once SOS fires, block any further trigger for this duration.
  static const _sosCooldown       = Duration(seconds: 60);

  // ── Camera auto-off ───────────────────────────────────────────────────────
  static const _autoDeactivate    = Duration(seconds: 60);

  // ── State ─────────────────────────────────────────────────────────────────
  bool _isEnabled          = false;
  EyeGestureState _state   = EyeGestureState.idle;
  DateTime _lastInteraction = DateTime.now();

  // ── SOS lock ──────────────────────────────────────────────────────────────
  bool _sosTriggered       = false;
  DateTime? _lastSosTrigger;

  // ── Camera / ML ───────────────────────────────────────────────────────────
  CameraController? _cameraController;
  FaceDetector?     _faceDetector;
  bool _isProcessingFrame  = false;
  bool _cameraReady        = false;

  // ── Blink state machine ───────────────────────────────────────────────────
  int      _blinkCount          = 0;
  DateTime? _firstBlinkTime;    // time of the first blink in current sequence
  DateTime? _lastBlinkTime;     // time of the most recent blink
  bool     _wasBlinking         = false;

  // ── Timers ────────────────────────────────────────────────────────────────
  Timer? _inactivityTimer;
  Timer? _autoDeactivateTimer;
  Timer? _sosResetTimer;

  // ── Getters ───────────────────────────────────────────────────────────────
  bool get isEnabled  => _isEnabled;
  EyeGestureState get state => _state;
  bool get isActive   => _state == EyeGestureState.active;
  bool get cameraReady => _cameraReady;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_prefKey) ?? false;
    if (_isEnabled) _startMonitoring();
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);
    if (value) {
      _startMonitoring();
    } else {
      _stopMonitoring();
      await _stopCamera();
      _state = EyeGestureState.idle;
    }
    notifyListeners();
  }

  // ── Lifecycle (called by SafetyModeManager) ───────────────────────────────

  void pauseForBackground() {
    if (_state == EyeGestureState.idle) return;
    _stopMonitoring();
    _stopCamera().then((_) {
      _state = EyeGestureState.idle;
      notifyListeners();
    });
    debugPrint('[EyeGesture] ⏸ paused (background)');
  }

  void resumeForForeground() {
    if (!_isEnabled || _state != EyeGestureState.idle) return;
    _startMonitoring();
    debugPrint('[EyeGesture] ▶ resumed (foreground)');
  }

  /// Called by the UI Listener on every pointer-down event.
  void onUserInteraction() {
    _lastInteraction = DateTime.now();
    if (_state == EyeGestureState.active) {
      _stopCamera().then((_) {
        _state = EyeGestureState.monitoring;
        notifyListeners();
      });
    }
  }

  // ── Phase 1: Inactivity monitoring ───────────────────────────────────────

  void _startMonitoring() {
    _state = EyeGestureState.monitoring;
    _lastInteraction = DateTime.now();
    _inactivityTimer?.cancel();
    _inactivityTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!_isEnabled || _state != EyeGestureState.monitoring) return;
      if (DateTime.now().difference(_lastInteraction) >= _inactivityThreshold) {
        // Signal overlay to call activateCamera() on the main thread
        _state = EyeGestureState.active;
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void _stopMonitoring() {
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _autoDeactivateTimer?.cancel();
    _autoDeactivateTimer = null;
  }

  // ── Phase 2: Camera activation (must be called from main thread) ──────────

  Future<void> activateCamera() async {
    if (_cameraReady) return;
    debugPrint('[EyeGesture] 📷 activating camera...');

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _state = EyeGestureState.monitoring;
        notifyListeners();
        return;
      }

      final front = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _faceDetector ??= FaceDetector(
        options: FaceDetectorOptions(
          enableClassification: true,
          performanceMode: FaceDetectorMode.fast,
        ),
      );

      _cameraController = CameraController(
        front,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21,
      );

      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_processFrame);

      _cameraReady = true;
      _resetBlinkState();

      // Auto-off after 60 s to save battery
      _autoDeactivateTimer?.cancel();
      _autoDeactivateTimer = Timer(_autoDeactivate, () {
        if (_state == EyeGestureState.active) {
          _stopCamera().then((_) {
            _state = EyeGestureState.monitoring;
            notifyListeners();
          });
        }
      });

      debugPrint('[EyeGesture] ✅ camera active');
      notifyListeners();
    } catch (e) {
      debugPrint('[EyeGesture] ❌ camera activation failed: $e');
      _cameraReady = false;
      _state = EyeGestureState.monitoring;
      notifyListeners();
    }
  }

  Future<void> _stopCamera() async {
    _autoDeactivateTimer?.cancel();
    _cameraReady = false;
    _isProcessingFrame = false;
    _resetBlinkState();
    try {
      if (_cameraController != null) {
        if (_cameraController!.value.isStreamingImages) {
          await _cameraController!.stopImageStream();
        }
        await _cameraController!.dispose();
        _cameraController = null;
      }
    } catch (e) {
      _cameraController = null;
      debugPrint('[EyeGesture] camera stop (safe): $e');
    }
    try {
      await _faceDetector?.close();
      _faceDetector = null;
    } catch (_) {}
  }

  // ── Frame processing ──────────────────────────────────────────────────────

  Future<void> _processFrame(CameraImage image) async {
    // Single-frame guard — never process two frames concurrently
    if (_isProcessingFrame || !_cameraReady || _faceDetector == null) return;
    _isProcessingFrame = true;

    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) return;

      final faces = await _faceDetector!.processImage(inputImage);
      if (faces.isEmpty) {
        _wasBlinking = false;
        return;
      }

      final face = faces.first;
      final leftOpen  = face.leftEyeOpenProbability  ?? 1.0;
      final rightOpen = face.rightEyeOpenProbability ?? 1.0;
      final avgOpen   = (leftOpen + rightOpen) / 2.0;

      final isBlinking = avgOpen < _blinkThreshold;

      // Rising-edge detection: open → closed = one blink event
      if (isBlinking && !_wasBlinking) {
        _onBlinkDetected();
      }
      _wasBlinking = isBlinking;
    } catch (e) {
      debugPrint('[EyeGesture] frame error: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  // ── Blink state machine ───────────────────────────────────────────────────

  void _onBlinkDetected() {
    final now = DateTime.now();

    // If SOS lock is active, ignore all blinks
    if (_sosTriggered) return;

    if (_blinkCount == 0) {
      // First blink of a new sequence
      _blinkCount    = 1;
      _firstBlinkTime = now;
      _lastBlinkTime  = now;
      debugPrint('[EyeGesture] 👁 blink 1 — sequence started');
      return;
    }

    final gapFromLast  = now.difference(_lastBlinkTime!);
    final windowFromFirst = now.difference(_firstBlinkTime!);

    // Gap too large → this blink starts a fresh sequence
    if (gapFromLast > _maxBlinkGap) {
      _blinkCount     = 1;
      _firstBlinkTime = now;
      _lastBlinkTime  = now;
      debugPrint('[EyeGesture] 👁 gap too large — reset, blink 1');
      return;
    }

    // Total window exceeded → reset
    if (windowFromFirst > _blinkWindow) {
      _blinkCount     = 1;
      _firstBlinkTime = now;
      _lastBlinkTime  = now;
      debugPrint('[EyeGesture] 👁 window expired — reset, blink 1');
      return;
    }

    // Valid consecutive blink
    _blinkCount++;
    _lastBlinkTime = now;
    debugPrint('[EyeGesture] 👁 blink $_blinkCount');

    if (_blinkCount >= _requiredBlinks) {
      _resetBlinkState();
      _fireSOS();
    }
  }

  void _resetBlinkState() {
    _blinkCount     = 0;
    _firstBlinkTime = null;
    _lastBlinkTime  = null;
    _wasBlinking    = false;
  }

  // ── SOS trigger — single lock, called from exactly ONE place ─────────────

  Future<void> _fireSOS() async {
    // Double-check lock (guard against any race)
    if (_sosTriggered) {
      debugPrint('[EyeGesture] SOS lock active — ignored');
      return;
    }
    _sosTriggered = true;
    _lastSosTrigger = DateTime.now();
    debugPrint('[EyeGesture] 🚨 SOS firing...');

    // Schedule lock reset after cooldown
    _sosResetTimer?.cancel();
    _sosResetTimer = Timer(_sosCooldown, () {
      _sosTriggered = false;
      debugPrint('[EyeGesture] SOS lock released');
    });

    try {
      final sosService = SOSService();
      final contacts  = await sosService.getEmergencyContacts().first;
      final userName  = await sosService.getUserName();

      if (contacts.isEmpty) {
        debugPrint('[EyeGesture] No emergency contacts — SOS aborted');
        return;
      }

      // Single call — SOSService handles the one message internally
      await sosService.triggerSOSAlert(
        contacts: contacts,
        userName: userName,
      );
      debugPrint('[EyeGesture] ✅ SOS sent to ${contacts.length} contacts');
    } catch (e) {
      debugPrint('[EyeGesture] SOS error: $e');
    }
  }

  // ── Camera image → InputImage ─────────────────────────────────────────────

  InputImage? _toInputImage(CameraImage image) {
    try {
      final rotation = InputImageRotationValue.fromRawValue(
            _cameraController!.description.sensorOrientation,
          ) ??
          InputImageRotation.rotation0deg;

      final format = InputImageFormatValue.fromRawValue(image.format.raw);
      if (format == null) return null;

      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _stopMonitoring();
    _sosResetTimer?.cancel();
    _stopCamera();
    super.dispose();
  }
}
