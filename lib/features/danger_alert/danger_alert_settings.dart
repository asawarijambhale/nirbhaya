import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/danger_prediction_service.dart';

/// Settings card for the Danger Alert feature — embedded in SettingsScreen.
class DangerAlertSettings extends StatelessWidget {
  const DangerAlertSettings({super.key});

  static const _royalBlue = Color(0xFF101D68);

  @override
  Widget build(BuildContext context) {
    return Consumer<DangerPredictionService>(
      builder: (context, svc, _) {
        return Card(
          elevation: 5,
          shadowColor: _royalBlue.withOpacity(0.3),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header + toggle
                Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: _royalBlue),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Predictive Danger Alerts',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Switch(
                      value: svc.isEnabled,
                      onChanged: (val) => svc.setEnabled(val),
                      activeColor: Colors.white,
                      activeTrackColor: _royalBlue,
                      inactiveTrackColor: Colors.grey[300],
                    ),
                  ],
                ),

                // Risk level indicator
                Padding(
                  padding: const EdgeInsets.only(left: 34, bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.circle,
                          size: 10, color: _riskColor(svc.riskLevel)),
                      const SizedBox(width: 6),
                      Text(
                        svc.isEnabled
                            ? 'Risk: ${_riskLabel(svc.riskLevel)}'
                            : 'Monitoring off',
                        style: TextStyle(
                          fontSize: 12,
                          color: svc.isEnabled
                              ? _riskColor(svc.riskLevel)
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(),
                const SizedBox(height: 4),
                Text(
                  'Monitors time, location, and light level to predict unsafe areas. '
                  'Alerts you when risk is HIGH.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),

                // ── Debug Test Buttons ───────────────────────────────────
                if (svc.isEnabled) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'Test risk levels:',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _debugBtn('SAFE', Colors.green, () => svc.forceRiskLevel(RiskLevel.safe)),
                      const SizedBox(width: 6),
                      _debugBtn('MODERATE', Colors.orange, () => svc.forceRiskLevel(RiskLevel.moderate)),
                      const SizedBox(width: 6),
                      _debugBtn('HIGH', Colors.red, () => svc.forceRiskLevel(RiskLevel.high)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _riskColor(RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return Colors.red;
      case RiskLevel.moderate:
        return Colors.orange;
      case RiskLevel.safe:
        return Colors.green;
    }
  }

  String _riskLabel(RiskLevel level) {
    switch (level) {
      case RiskLevel.high:
        return 'HIGH ⚠️';
      case RiskLevel.moderate:
        return 'MODERATE';
      case RiskLevel.safe:
        return 'SAFE ✅';
    }
  }

  Widget _debugBtn(String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(color: color),
          padding: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 11)),
      ),
    );
  }
}
