import 'package:flutter/material.dart';
import '../services/gallery_service.dart';

class PinScreen extends StatefulWidget {
  @override
  _PinScreenState createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {

  final TextEditingController pinController = TextEditingController();

  final String correctPin = "1234";

  void checkPin() {

    String enteredPin = pinController.text;

    if (enteredPin == correctPin) {

      Navigator.pushReplacementNamed(context, '/home');

    } else {

      openSystemGallery(); // open phone gallery
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
