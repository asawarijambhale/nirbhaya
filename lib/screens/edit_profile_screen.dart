import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() =>
      _EditProfileScreenState();
}

class _EditProfileScreenState
    extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController =
      TextEditingController();
  final TextEditingController phoneController =
      TextEditingController();
  final TextEditingController guardianNameController =
      TextEditingController();
  final TextEditingController guardianPhoneController =
      TextEditingController();
  final TextEditingController homeAddressController =
      TextEditingController();
  final TextEditingController workAddressController =
      TextEditingController();

  final uid =
      FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (doc.exists) {
      var data = doc.data()!;
      nameController.text = data['name'] ?? '';
      phoneController.text = data['phone'] ?? '';
      guardianNameController.text =
          data['guardianName'] ?? '';
      guardianPhoneController.text =
          data['guardianPhone'] ?? '';
      homeAddressController.text =
          data['homeAddress'] ?? '';
      workAddressController.text =
          data['workAddress'] ?? '';
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate())
      return;

    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .update({
      'name': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'guardianName':
          guardianNameController.text.trim(),
      'guardianPhone':
          guardianPhoneController.text.trim(),
      'homeAddress':
          homeAddressController.text.trim(),
      'workAddress':
          workAddressController.text.trim(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
          content:
              Text("Profile Updated Successfully")),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    const royalBlue = Color(0xFF101D68);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Profile"),
        backgroundColor: royalBlue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildField("Name", nameController),
              _buildField("Phone", phoneController),
              _buildField("Guardian Name",
                  guardianNameController),
              _buildField("Guardian Phone",
                  guardianPhoneController),
              _buildField("Home Address",
                  homeAddressController),
              _buildField("Work/College Address",
                  workAddressController),

              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _updateProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: royalBlue,
                  minimumSize:
                      const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                ),
                child: const Text(
                  "Save Changes",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(
      String label, TextEditingController controller) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        validator: (value) =>
            value!.isEmpty ? "Required" : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}