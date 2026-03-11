import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final nameController = TextEditingController();
  final guardianController = TextEditingController();
  final phoneController = TextEditingController();
  final guardianPhoneController = TextEditingController();
  final addressController = TextEditingController();
  final workController = TextEditingController();

  DateTime? selectedDate;
  File? _image;

  Future pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
      });
    }
  }

  Future<String?> uploadImage(String uid) async {
    if (_image == null) return null;

    final ref = FirebaseStorage.instance.ref().child('profile/$uid.jpg');
    await ref.putFile(_image!);
    return await ref.getDownloadURL();
  }

  Future saveProfile() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    String? photoUrl = await uploadImage(uid);

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'name': nameController.text,
      'guardianName': guardianController.text,
      'phone': phoneController.text,
      'guardianPhone': guardianPhoneController.text,
      'dob': selectedDate,
      'homeAddress': addressController.text,
      'workAddress': workController.text,
      'photoUrl': photoUrl,
      'profileCompleted': true,
    });

    Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Complete Profile")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundImage:
                      _image != null ? FileImage(_image!) : null,
                  child: _image == null
                      ? const Icon(Icons.camera_alt, size: 40)
                      : null,
                ),
              ),
              const SizedBox(height: 20),

              TextFormField(controller: nameController, decoration: const InputDecoration(labelText: "Name")),
              TextFormField(controller: guardianController, decoration: const InputDecoration(labelText: "Guardian Name")),
              TextFormField(controller: phoneController, decoration: const InputDecoration(labelText: "Phone")),
              TextFormField(controller: guardianPhoneController, decoration: const InputDecoration(labelText: "Guardian Phone")),

              const SizedBox(height: 10),

              ListTile(
                title: Text(selectedDate == null
                    ? "Select DOB"
                    : selectedDate.toString()),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2000),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) {
                    setState(() {
                      selectedDate = picked;
                    });
                  }
                },
              ),

              TextFormField(controller: addressController, decoration: const InputDecoration(labelText: "Home Address")),
              TextFormField(controller: workController, decoration: const InputDecoration(labelText: "Work/College Address")),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: saveProfile,
                child: const Text("Save Profile"),
              )
            ],
          ),
        ),
      ),
    );
  }
}
