import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'services/eye_gesture_service.dart';

/// Settings card for Eye Gesture SOS — embedded in SettingsScreen.
class EyeGestureSettings extends StatelessWidget {
  const EyeGestureSettings({super.key});

  static const _royalBlue = Color(0xFF101D68);

  Future<bool> _requestCamera(BuildContext context) async {
    final status = await Permission.camera.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera permission is required for Eye SOS.')),
      );
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<EyeGestureService>(
      builder: (context, svc, _) {
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
                // Header + toggle
                Row(
                  children: [
                    const Icon(Icons.remove_red_eye, color: _royalBlue),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Eye Gesture SOS',
                        style: TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Switch(
                      value: svc.isEnabled,
                      onChanged: (val) async {
                        if (val) {
                          final granted = await _requestCamera(context);
                          if (!granted) return;
                        }
                        await svc.setEnabled(val);
                      },
                      activeColor: Colors.white,
                      activeTrackColor: _royalBlue,
                      inactiveTrackColor: Colors.grey[300],
                    ),
                  ],
                ),

                // Status indicator
                Padding(
                  padding: const EdgeInsets.only(left: 34, bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.circle,
                          size: 10, color: _stateColor(svc.state)),
                      const SizedBox(width: 6),
                      Text(
                        _stateLabel(svc.state),
                        style: TextStyle(
                            fontSize: 12, color: _stateColor(svc.state)),
                      ),
                    ],
                  ),
                ),

                const Divider(),
                const SizedBox(height: 4),
                Text(
                  'Silently monitors blinks after 15s of inactivity. '
                  '3 rapid blinks (within 3s) trigger SOS.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _stateColor(EyeGestureState s) {
    switch (s) {
      case EyeGestureState.active:
        return Colors.blue;
      case EyeGestureState.monitoring:
        return Colors.green;
      case EyeGestureState.idle:
        return Colors.grey;
    }
  }

  String _stateLabel(EyeGestureState s) {
    switch (s) {
      case EyeGestureState.active:
        return 'Active';
      case EyeGestureState.monitoring:
        return 'Monitoring...';
      case EyeGestureState.idle:
        return 'Disabled';
    }
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 14, color: const Color(0xFF101D68)),
      label: Text(label, style: const TextStyle(fontSize: 10)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      backgroundColor: const Color(0xFF101D68).withOpacity(0.07),
    );
  }
}
