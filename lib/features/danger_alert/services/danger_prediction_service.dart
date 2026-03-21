import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/risk_context.dart';

enum RiskLevel { safe, moderate, high }

class DangerPredictionService extends ChangeNotifier {
  static const _prefKey = 'danger_alert_enabled';
  static const _intervalSeconds = 15;

  bool _isEnabled = false;
  RiskLevel _riskLevel = RiskLevel.safe;
  RiskContext? _lastContext;
  Timer? _timer;

  bool get isEnabled => _isEnabled;
  RiskLevel get riskLevel => _riskLevel;
  RiskContext? get lastContext => _lastContext;

  // ── Persistence ──────────────────────────────────────────────────────────

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _isEnabled = prefs.getBool(_prefKey) ?? false;
    if (_isEnabled) _startTimer();
    notifyListeners();
  }

  Future<void> setEnabled(bool value) async {
    _isEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, value);

    if (value) {
      _startTimer();
      await _evaluate(); // immediate first check
    } else {
      _stopTimer();
      _riskLevel = RiskLevel.safe;
    }
    notifyListeners();
  }

  // ── Timer ─────────────────────────────────────────────────────────────────

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: _intervalSeconds),
      (_) => _evaluate(),
    );
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  // ── Data Collection ───────────────────────────────────────────────────────

  Future<Position?> _getLocation() async {
    try {
      final perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(const Duration(seconds: 5));
    } catch (_) {
      return null;
    }
  }

  /// Simulates crowd density: late night = low crowd (score 0–10).
  int _simulateCrowdScore(DateTime now) {
    final hour = now.hour;
    if (hour >= 22 || hour < 5) return 1; // very low crowd
    if (hour >= 5 && hour < 8) return 4;
    if (hour >= 8 && hour < 20) return 8; // busy hours
    return 3; // evening
  }

  // ── Risk Scoring ──────────────────────────────────────────────────────────

  int _calculateScore(RiskContext ctx) {
    int score = 0;
    final hour = ctx.time.hour;

    // Night time: 10 PM – 5 AM → +3
    if (hour >= 22 || hour < 5) score += 3;

    // Low ambient light → +2 (< 50 lux = dark; null = unknown → +1)
    if (ctx.lightLevel == null) {
      score += 1;
    } else if (ctx.lightLevel! < 50) {
      score += 2;
    }

    // Low crowd → +3 (score ≤ 3 means very low)
    if (ctx.crowdScore <= 3) score += 3;

    // Location unknown → +2
    if (ctx.latitude == null) score += 2;

    return score;
  }

  RiskLevel _scoreToLevel(int score) {
    if (score > 6) return RiskLevel.high;
    if (score >= 3) return RiskLevel.moderate;
    return RiskLevel.safe;
  }

  /// DEBUG ONLY — force a specific risk level to test UI without waiting for real conditions.
  void forceRiskLevel(RiskLevel level) {
    _riskLevel = level;
    notifyListeners();
  }

  // ── Main Evaluation ───────────────────────────────────────────────────────

  Future<void> _evaluate() async {
    final now = DateTime.now();
    final position = await _getLocation();
    final crowdScore = _simulateCrowdScore(now);

    // Light sensor: sensors_plus not added yet — use null (unknown)
    const double? lightLevel = null;

    final ctx = RiskContext(
      latitude: position?.latitude,
      longitude: position?.longitude,
      time: now,
      lightLevel: lightLevel,
      crowdScore: crowdScore,
    );

    final score = _calculateScore(ctx);
    final newLevel = _scoreToLevel(score);

    _lastContext = ctx;
    if (newLevel != _riskLevel) {
      _riskLevel = newLevel;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }
}
