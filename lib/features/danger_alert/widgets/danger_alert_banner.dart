import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/danger_prediction_service.dart';

/// Wraps any child widget and overlays a warning banner when risk is HIGH.
class DangerAlertBanner extends StatefulWidget {
  final Widget child;
  const DangerAlertBanner({super.key, required this.child});

  @override
  State<DangerAlertBanner> createState() => _DangerAlertBannerState();
}

class _DangerAlertBannerState extends State<DangerAlertBanner> {
  bool _dismissed = false;
  RiskLevel? _lastLevel;

  @override
  Widget build(BuildContext context) {
    return Consumer<DangerPredictionService>(
      builder: (context, svc, _) {
        // Reset dismissed flag when risk level changes
        if (svc.riskLevel != _lastLevel) {
          _lastLevel = svc.riskLevel;
          _dismissed = false;
        }

        final showBanner =
            svc.isEnabled && svc.riskLevel == RiskLevel.high && !_dismissed;

        return Stack(
          children: [
            widget.child,
            if (showBanner)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    color: Colors.red.shade700,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: SafeArea(
                      bottom: false,
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Colors.white, size: 22),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              '⚠️ This area may be unsafe. Stay alert or move to a safer place.',
                              style: TextStyle(
                                  color: Colors.white, fontSize: 13),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close,
                                color: Colors.white, size: 18),
                            onPressed: () => setState(() => _dismissed = true),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
