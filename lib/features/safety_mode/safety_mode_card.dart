import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'safety_mode_manager.dart';

/// Read-only status card showing the current hybrid safety mode.
/// Placed at the top of SettingsScreen so users always know what's active.
class SafetyModeCard extends StatelessWidget {
  const SafetyModeCard({super.key});

  static const _royalBlue = Color(0xFF101D68);

  @override
  Widget build(BuildContext context) {
    return Consumer<SafetyModeManager>(
      builder: (context, mgr, _) {
        final mode = mgr.currentMode;
        final inFg = mgr.appInForeground;

        return Card(
          elevation: 5,
          shadowColor: _royalBlue.withOpacity(0.3),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
          margin: const EdgeInsets.symmetric(vertical: 10),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.security, color: _royalBlue),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Hybrid Safety Mode',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                    ),
                    _StatusDot(mode: mode),
                  ],
                ),
                const SizedBox(height: 10),

                // Current mode row
                _ModeRow(
                  icon: Icons.remove_red_eye,
                  label: 'Eye Gesture SOS',
                  active: mode == SafetyMode.eyeGesture,
                  note: inFg ? 'Foreground' : 'Paused (background)',
                ),
                const SizedBox(height: 6),
                _ModeRow(
                  icon: Icons.mic,
                  label: 'Panic Whisper',
                  active: mode == SafetyMode.whisper,
                  note: inFg ? 'Standby' : 'Background active',
                ),

                const Divider(height: 20),
                Text(
                  'Switches automatically: Eye detection when screen is ON, '
                  'Voice detection when phone is locked or app is in background.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusDot extends StatelessWidget {
  final SafetyMode mode;
  const _StatusDot({required this.mode});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (mode) {
      case SafetyMode.eyeGesture:
        color = Colors.blue;
        break;
      case SafetyMode.whisper:
        color = Colors.green;
        break;
      case SafetyMode.none:
        color = Colors.grey;
        break;
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _ModeRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final String note;
  const _ModeRow({
    required this.icon,
    required this.label,
    required this.active,
    required this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon,
            size: 16,
            color: active ? const Color(0xFF101D68) : Colors.grey[400]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              color: active ? const Color(0xFF101D68) : Colors.grey[500],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: active
                ? const Color(0xFF101D68).withOpacity(0.1)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            active ? '● ACTIVE' : note,
            style: TextStyle(
              fontSize: 10,
              color: active ? const Color(0xFF101D68) : Colors.grey[500],
              fontWeight: active ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }
}
