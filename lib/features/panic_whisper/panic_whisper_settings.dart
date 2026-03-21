import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'services/whisper_prefs.dart';
import 'services/whisper_service.dart';

/// Settings UI for the Panic Whisper Detection feature.
/// Embedded inside SettingsScreen — not a standalone route.
class PanicWhisperSettings extends StatefulWidget {
  const PanicWhisperSettings({super.key});

  @override
  State<PanicWhisperSettings> createState() => _PanicWhisperSettingsState();
}

class _PanicWhisperSettingsState extends State<PanicWhisperSettings> {
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _whisperService = WhisperService();

  bool _isEnabled = false;
  bool _isSaving = false;
  String _savedCodeword = '';

  static const _royalBlue = Color(0xFF101D68);

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final codeword = await WhisperPrefs.getCodeword();
    final enabled = await WhisperPrefs.isEnabled();
    setState(() {
      _savedCodeword = codeword;
      _controller.text = codeword;
      _isEnabled = enabled;
    });
  }

  Future<void> _saveCodeword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    // Request microphone permission before saving
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      setState(() => _isSaving = false);
      _showSnack('Microphone permission is required for whisper detection.');
      return;
    }

    await WhisperPrefs.saveCodeword(_controller.text.trim());
    setState(() {
      _savedCodeword = _controller.text.trim().toLowerCase();
      _isSaving = false;
    });

    // Push new codeword to native service if running
    await _whisperService.updateCodeword(_controller.text.trim());

    _showSnack('Codeword saved successfully.');
  }

  Future<void> _toggleEnabled(bool value) async {
    if (value && _savedCodeword.isEmpty) {
      _showSnack('Please set a codeword first.');
      return;
    }

    if (value) {
      // Request microphone permission
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        _showSnack('Microphone permission is required.');
        return;
      }
      // Request fine location
      final locStatus = await Permission.location.request();
      if (!locStatus.isGranted) {
        _showSnack('Location permission is required for SOS.');
        return;
      }
      // Request background location (must be asked AFTER fine location)
      final bgLocStatus = await Permission.locationAlways.request();
      if (!bgLocStatus.isGranted) {
        _showSnack(
          'Background location denied. SOS may show "Location unavailable" '
          'when screen is locked. Grant in Settings → App → Permissions.',
        );
        // Don't block — allow enabling with degraded location
      }
    }

    await _whisperService.setEnabled(value);
    setState(() => _isEnabled = value);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
            // Header row with toggle
            Row(
              children: [
                const Icon(Icons.mic, color: _royalBlue),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Panic Whisper Detection',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                Switch(
                  value: _isEnabled,
                  onChanged: _toggleEnabled,
                  activeColor: Colors.white,
                  activeTrackColor: _royalBlue,
                  inactiveTrackColor: Colors.grey[300],
                ),
              ],
            ),

            // Status indicator
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
                    _isEnabled ? 'Listening for codeword...' : 'Detection off',
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

            // Codeword input
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Panic Codeword',
                    style: TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _controller,
                    decoration: InputDecoration(
                      hintText: 'e.g. black banana',
                      prefixIcon: const Icon(Icons.vpn_key_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: _royalBlue, width: 2),
                      ),
                    ),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) {
                        return 'Codeword cannot be empty';
                      }
                      if (val.trim().length < 3) {
                        return 'Codeword must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveCodeword,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.save),
                      label: Text(_isSaving ? 'Saving...' : 'Save Codeword'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _royalBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Current codeword display
            if (_savedCodeword.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _royalBlue.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Active codeword: "$_savedCodeword"',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            // Info note
            Text(
              'When enabled, the app listens in the background. '
              'Whispering your codeword will silently trigger SOS.',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
