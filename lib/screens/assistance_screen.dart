import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AssistanceScreen extends StatelessWidget {
  const AssistanceScreen({super.key});

  final String helpUrl = 'https://www.safewomen.gov.in/';

  Future<void> _launchURL() async {
    Uri url = Uri.parse(helpUrl);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchURL();
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Assistance"),
        centerTitle: true,
        backgroundColor: const Color(0xFF101D68),
        foregroundColor: Colors.white,
        elevation: 6,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.support_agent, size: 100, color: Color(0xFF101D68)),
              const SizedBox(height: 20),
              const Text(
                "Redirecting to Women Safety Help Page...",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _launchURL,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF101D68),
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                icon: const Icon(Icons.open_in_new, color: Colors.white),
                label: const Text(
                  "Open Now",
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
