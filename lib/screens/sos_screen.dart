import 'dart:async';
import 'package:flutter/material.dart';
import '../services/sos_service.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  final SOSService _sosService = SOSService();
  List<Map<String, String>> contacts = [];
  
  int countdown = 10;
  Timer? timer;
  bool isTimerActive = false;

  final TextEditingController nameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  // ================= ADD CONTACT =================
  void _addContact() {
    if (nameController.text.isEmpty || phoneController.text.isEmpty) return;

    setState(() {
      contacts.add({
        "name": nameController.text,
        "phone": phoneController.text,
      });
    });

    nameController.clear();
    phoneController.clear();
    Navigator.pop(context);
  }

  // ================= MAIN SOS FUNCTION =================


Future<void> _sendSOS() async {
  if (contacts.isEmpty) {
    _showMessage("Add at least one contact");
    return;
  }

  try {
    final userName = await _sosService.getUserName();
    final emergencyContacts = contacts
        .where((c) => (c['name'] ?? '').isNotEmpty && (c['phone'] ?? '').isNotEmpty)
        .map(
          (c) => EmergencyContact(
            id: '${c['name']}_${c['phone']}',
            name: c['name']!,
            phoneNumber: c['phone']!,
          ),
        )
        .toList();

    if (emergencyContacts.isEmpty) {
      _showMessage("Add at least one valid contact");
      return;
    }

    await _sosService.triggerSOSAlert(
      contacts: emergencyContacts,
      userName: userName,
    );

    _showMessage("🚨 Emergency SMS sent successfully!");
  } catch (e) {
    _showMessage("Failed to trigger SOS: $e");
  }
}
  // ================= START TIMER =================
  void _startTimer() {
    if (contacts.isEmpty) {
      _showMessage("Please add at least one contact");
      return;
    }

    setState(() {
      isTimerActive = true;
      countdown = 10;
    });

    timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (countdown > 0) {
        setState(() => countdown--);
      } else {
        timer.cancel();
        _triggerSOS();
      }
    });
  }

  void _triggerSOS() async {
  setState(() {
    isTimerActive = false;
    countdown = 10;
  });

  await _sendSOS();
}

  void _cancelTimer() {
    timer?.cancel();
    setState(() {
      isTimerActive = false;
    });
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  // ================= ADD CONTACT DIALOG =================
  void _showAddContactDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Add Emergency Contact"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Name"),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: "Phone Number"),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: _addContact, child: const Text("Save"))
        ],
      ),
    );
  }

  @override
  void dispose() {
    timer?.cancel();
    nameController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Real SOS 🚨"),
        backgroundColor: Colors.red,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showAddContactDialog,
          )
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 20),

          Expanded(
            child: contacts.isEmpty
                ? const Center(child: Text("No Contacts Added"))
                : ListView.builder(
                    itemCount: contacts.length,
                    itemBuilder: (_, index) {
                      var c = contacts[index];
                      return ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(c["name"]!),
                        subtitle: Text(c["phone"]!),
                      );
                    },
                  ),
          ),

          GestureDetector(
            onTap: () {
              if (!isTimerActive) _startTimer();
            },
            child: Container(
              height: 150,
              width: 150,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: Center(
                child: Text(
                  isTimerActive ? "$countdown" : "SOS",
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          if (isTimerActive)
            ElevatedButton(
              onPressed: _cancelTimer,
              child: const Text("Cancel"),
            ),

          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
