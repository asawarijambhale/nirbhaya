import 'package:flutter/material.dart';
import '../features/panic_whisper/panic_whisper_settings.dart';
import '../features/danger_alert/danger_alert_settings.dart';
import '../features/eye_gesture_sos/eye_gesture_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _enableCameraLocation = true;
  bool _enableDecoyMode = false;
  bool _addSosContact = true;
  bool _enableNotifications = true;
  bool _enableCamMicAccess = false;

  @override
  Widget build(BuildContext context) {
    const royalBlue = Color(0xFF101D68);

    return Scaffold(
      backgroundColor: const Color(0xFFEFF3FF),
      appBar: AppBar(
        title: const Text("Settings ⚙️"),
        backgroundColor: royalBlue,
        centerTitle: true,
        elevation: 6,
        shadowColor: royalBlue.withOpacity(0.6),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _buildSettingCard(
              "Enable Camera Location",
              _enableCameraLocation,
              (val) => setState(() => _enableCameraLocation = val),
              royalBlue,
            ),
            _buildSettingCard(
              "Enable Decoy App Mode",
              _enableDecoyMode,
              (val) => setState(() => _enableDecoyMode = val),
              royalBlue,
            ),
            _buildSettingCard(
              "Add SOS Contact",
              _addSosContact,
              (val) => setState(() => _addSosContact = val),
              royalBlue,
            ),
            _buildSettingCard(
              "Enable Notifications",
              _enableNotifications,
              (val) => setState(() => _enableNotifications = val),
              royalBlue,
            ),
            _buildSettingCard(
              "Enable Camera & Microphone Access",
              _enableCamMicAccess,
              (val) => setState(() => _enableCamMicAccess = val),
              royalBlue,
            ),

            // ── Panic Whisper Detection ──────────────────────────────────
            const PanicWhisperSettings(),

            // ── Predictive Danger Alerts ─────────────────────────────────
            const DangerAlertSettings(),

            // ── Eye Gesture SOS ───────────────────────────────────────────
            const EyeGestureSettings(),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingCard(
    String label,
    bool value,
    Function(bool) onChanged,
    Color royalBlue,
  ) {
    return Card(
      elevation: 5,
      shadowColor: royalBlue.withOpacity(0.3),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        title: Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        trailing: Switch(
          activeColor: Colors.white,
          activeTrackColor: royalBlue,
          inactiveTrackColor: Colors.grey[300],
          value: value,
          onChanged: (val) => onChanged(val),
        ),
      ),
    );
  }
}
