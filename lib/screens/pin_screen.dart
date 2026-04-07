import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_apps/device_apps.dart';
import '../services/gallery_service.dart';

class PinScreen extends StatefulWidget {
  @override
  _PinScreenState createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {

  final TextEditingController pinController = TextEditingController();

  final String correctPin = "1234";

  Future<void> checkPin() async {

    String enteredPin = pinController.text;

    if (enteredPin == correctPin) {

      Navigator.pushReplacementNamed(context, '/home');

    } else {
      final prefs = await SharedPreferences.getInstance();
      final decoyPackage = prefs.getString('decoy_package');
      
      if (decoyPackage != null) {
        bool installed = await DeviceApps.isAppInstalled(decoyPackage);
        if (installed) {
          DeviceApps.openApp(decoyPackage);
          return;
        }
      }

      openSystemGallery(); // fallback to gallery
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Enter PIN"),
      ),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [

              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Enter PIN",
                  border: OutlineInputBorder(),
                ),
              ),

              SizedBox(height: 20),

              ElevatedButton(
                onPressed: checkPin,
                child: Text("Unlock"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
