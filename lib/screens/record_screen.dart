import 'dart:async';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/sos_service.dart';

class RecordScreen extends StatefulWidget {
  const RecordScreen({super.key});

  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen>
    with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;

  bool _isListening = false;
  String _recognizedText = "";
  Timer? _timer;
  int _seconds = 0;

  final Color royalBlue = const Color(0xFF101D68);
final SOSService _sosService = SOSService();
  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
  }

  // 🎤 Start / Stop Recording
  Future<void> _recordAudio() async {
    var status = await Permission.microphone.request();
    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Microphone permission denied")),
      );
      return;
    }
    Future<void> _triggerVoiceSOS() async {
  try {
    final contacts = await _sosService.getEmergencyContacts().first;
    final userName = await _sosService.getUserName();

    if (contacts.isEmpty) {
      print("No emergency contacts found");
      return;
    }

    await _sosService.triggerSOSAlert(
      contacts: contacts,
      userName: userName,
    );

    print("🚨 SOS Triggered from Voice");
  } catch (e) {
    print("Voice SOS Error: $e");
  }
}

    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() {
          _isListening = true;
          _recognizedText = "";
          _seconds = 0;
        });

        _startTimer();

       _speech.listen(
  listenMode: stt.ListenMode.dictation,
  partialResults: true,
  cancelOnError: false,
  onResult: (result) async {
  setState(() {
    _recognizedText = result.recognizedWords;
  });

  final text = result.recognizedWords.toLowerCase();

  if (_isListening &&
      (text.contains("help") ||
       text.contains("save me") ||
       text.contains("emergency"))) {

    await _stopRecording();
    await _saveToFirebase();

    // 🔥 Trigger SOS directly (NO navigation)
    await _triggerVoiceSOS();
  }
},
);
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _seconds++;
      });
    });
  }

  Future<void> _stopRecording() async {
    _timer?.cancel();
    await _speech.stop();

    setState(() {
      _isListening = false;
    });

    await _saveToFirebase();
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  // ☁ Save to Firebase
  Future<void> _saveToFirebase() async {
    if (_recognizedText.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection("recordings").add({
      "userId": user?.uid ?? "anonymous",
      "text": _recognizedText,
      "timestamp": FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Recording saved successfully")),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final circleSize = size.width * 0.55; // Responsive circle

    return Scaffold(
      backgroundColor: royalBlue,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: size.height * 0.04),

            const Text(
              "Voice Recorder",
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const Spacer(),

            // 🎙 Animated Mic Button
            GestureDetector(
              onTap: _recordAudio,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _isListening
                      ? const LinearGradient(
                          colors: [Colors.white, Colors.white70],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFF3F51B5), Color(0xFF1A237E)],
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.3),
                      blurRadius: 25,
                      spreadRadius: _isListening ? 8 : 2,
                    )
                  ],
                ),
                child: Icon(
                  Icons.mic,
                  size: circleSize * 0.35,
                  color: _isListening ? royalBlue : Colors.white,
                ),
              ),
            ),

            SizedBox(height: size.height * 0.04),

            // ⏱ Timer
            Text(
              _formatTime(_seconds),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            SizedBox(height: size.height * 0.03),

            // 📝 Recognized Text Box
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 25),
              padding: const EdgeInsets.all(16),
              height: size.height * 0.18,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _recognizedText.isEmpty
                      ? "Tap mic and start speaking..."
                      : _recognizedText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),

            const Spacer(),

            // 🔴 Stop Button
            if (_isListening)
              Padding(
                padding: const EdgeInsets.only(bottom: 40),
                child: ElevatedButton(
                  onPressed: _stopRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: royalBlue,
                    padding: EdgeInsets.symmetric(
                        horizontal: size.width * 0.15, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    "Stop Recording",
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              )
            else
              SizedBox(height: size.height * 0.05),
          ],
        ),
      ),
    );
  }
}