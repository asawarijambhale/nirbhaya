import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/volume_sos_prefs.dart';
import 'services/volume_sos_service.dart';

/// Settings card for Volume Button SOS (UP → DOWN → UP pattern).
/// Embedded inside SettingsScreen — not a standalone route.
class VolumeSosSettings extends StatefulWidget {
  const VolumeSosSettings({super.key});

  @override
  State<VolumeSosSettings> createState() => _VolumeSosSettingsState();
}

class _VolumeSosSettingsState extends State<VolumeSosSettings> {
  final _service = VolumeSosService();
  bool _isEnabled = false;

  static const _royalBlue = Color(0xFF101D68);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await VolumeSosPrefs.isEnabled();
    if (mounted) setState(() => _isEnabled = enabled);
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      final locStatus = await Permission.location.request();
      if (!locStatus.isGranted) {
        _snack('Location permission is required for SOS.');
        return;
      }
      final bgLoc = await Permission.locationAlways.request();
      if (!bgLoc.isGranted) {
        _snack(
          'Background location denied. SOS may show "Location unavailable" '
          'when screen is locked. Grant in Settings → App → Permissions.',
        );
      }
      // Ask user to exempt app from battery optimisation so the service
      // survives screen-off on aggressive OEMs (Moto, Xiaomi, Samsung)
      await _service.requestBatteryExemption();
    }

    await _service.setEnabled(value);
    if (mounted) setState(() => _isEnabled = value);
    _snack(value ? 'Volume SOS enabled.' : 'Volume SOS disabled.');
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 5,
      shadowColor: _royalBlue.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────
            Row(
              children: [
                const Icon(Icons.volume_up, color: _royalBlue),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Volume Button SOS',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  value: _isEnabled,
                  onChanged: _toggle,
                  activeColor: Colors.white,
                  activeTrackColor: _royalBlue,
                  inactiveTrackColor: Colors.grey[300],
                ),
              ],
            ),

            // ── Status indicator ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 34, bottom: 8),
              child: Row(
                children: [
                  Icon(
                    _isEnabled ? Icons.circle : Icons.circle_outlined,
                    size: 10,
                    color: _isEnabled ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isEnabled ? 'Monitoring volume buttons...' : 'Detection off',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isEnabled ? Colors.green : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(),
            const SizedBox(height: 8),

            // ── Pattern visual ───────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: _royalBlue.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'SOS Trigger Pattern',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _royalBlue,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _patternStep(Icons.arrow_upward, 'Vol UP', Colors.green),
                      _arrow(),
                      _patternStep(Icons.arrow_downward, 'Vol DOWN', Colors.orange),
                      _arrow(),
                      _patternStep(Icons.arrow_upward, 'Vol UP', Colors.green),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Press within 2 seconds. Any extra press cancels the trigger.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Rules ────────────────────────────────────────────────────
            _ruleRow(Icons.check_circle_outline, 'Exactly 3 presses: UP → DOWN → UP', Colors.green),
            _ruleRow(Icons.cancel_outlined, 'Extra press after pattern = cancelled', Colors.red),
            _ruleRow(Icons.timer_outlined, 'Must complete within 2 seconds', _royalBlue),
            _ruleRow(Icons.lock_outline, 'Works in background & locked screen', _royalBlue),

            const SizedBox(height: 8),
            Text(
              'Volume keys are intercepted only when this feature is enabled. '
              'Normal volume control is restored when disabled.',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _patternStep(IconData icon, String label, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _arrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Icon(Icons.arrow_forward, size: 16, color: Colors.grey),
    );
  }

  Widget _ruleRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
