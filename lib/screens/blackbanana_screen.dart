import 'dart:math';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/sos_service.dart';
class BlackBananaScreen extends StatefulWidget {
  const BlackBananaScreen({super.key});

  @override
  State<BlackBananaScreen> createState() => _BlackBananaScreenState();
}

class _BlackBananaScreenState extends State<BlackBananaScreen> {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  String spokenText = "";
  String randomPhrase = "";

  final List<String> phrases = [
    "Black Banana",
    "Silent Storm",
    "Blue Sparrow",
    "Hidden Moon",
    "Golden Tiger",
    "Broken Glass",
    "Silver Shadow",
    "Dark Mango",
    "Lucky Raven",
    "Secret Flame",
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    generateRandomPhrase();
  }

  void generateRandomPhrase() {
    final random = Random();
    setState(() {
      randomPhrase = phrases[random.nextInt(phrases.length)];
    });
  }

  void startListening() async {
    bool available = await _speech.initialize();
    if (available) {
      setState(() => _isListening = true);

      _speech.listen(
        onResult: (result) {
          setState(() {
            spokenText = result.recognizedWords;
          });

          checkMatch();
        },
      );
    }
  }

  void stopListening() {
    _speech.stop();
    setState(() => _isListening = false);
  }

  void checkMatch() async {
  if (spokenText.toLowerCase().trim() ==
      randomPhrase.toLowerCase().trim()) {

    // Save alert in Firestore
    await FirebaseFirestore.instance.collection("emergency_alerts").add({
      "userId": FirebaseAuth.instance.currentUser?.uid,
      "phrase": randomPhrase,
      "timestamp": FieldValue.serverTimestamp(),
      "type": "voice_trigger",
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("🚨 Voice SOS Triggered!")),
    );

    stopListening();
    generateRandomPhrase();

    // 🔥 TRIGGER SOS DIRECTLY (NO NAVIGATION)
    await _triggerSOSDirectly();
  }
}

Future<void> _triggerSOSDirectly() async {
  try {
    final SOSService sosService = SOSService();

    final contacts = await sosService.getEmergencyContacts().first;
    final userName = await sosService.getUserName();

    if (contacts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please add emergency contacts first"),
        ),
      );
      return;
    }

    await sosService.triggerSOSAlert(
      contacts: contacts,
      userName: userName,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("🚨 Emergency SMS Sent Successfully!"),
      ),
    );

  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Error triggering SOS: $e")),
    );
  }
}
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A1F),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            // RANDOM PHRASE DISPLAY
            Text(
              randomPhrase,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 60),

            GestureDetector(
              onTap: _isListening ? stopListening : startListening,
              child: Container(
                height: 160,
                width: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF101D68), Color(0xFF3950C6)],
                  ),
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  size: 80,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}