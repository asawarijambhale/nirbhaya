import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../theme/app_theme.dart';
import '../features/auth/auth_service.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController          = TextEditingController();
  final _guardianController      = TextEditingController();
  final _guardianPhoneController = TextEditingController();
  final _addressController       = TextEditingController();

  DateTime? _dob;
  File?     _image;
  bool      _saving = false;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _image = File(picked.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final phone = await AuthService.getPhone() ?? '';
      // Use phone as doc ID (sanitized)
      final docId = phone.replaceAll(RegExp(r'[^\w]'), '_');

      String? photoUrl;
      if (_image != null) {
        final ref = FirebaseStorage.instance.ref().child('profile/$docId.jpg');
        await ref.putFile(_image!);
        photoUrl = await ref.getDownloadURL();
      }

      await FirebaseFirestore.instance.collection('users').doc(docId).set({
        'name':             _nameController.text.trim(),
        'phone':            phone,
        'guardianName':     _guardianController.text.trim(),
        'guardianPhone':    _guardianPhoneController.text.trim(),
        'dob':              _dob,
        'homeAddress':      _addressController.text.trim(),
        'photoUrl':         photoUrl,
        'profileCompleted': true,
        'createdAt':        FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Complete Your Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Avatar picker
              Center(
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 56,
                        backgroundColor: AppColors.primary.withOpacity(0.1),
                        backgroundImage: _image != null ? FileImage(_image!) : null,
                        child: _image == null
                            ? const Icon(Icons.person, size: 50, color: AppColors.primary)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 28),

              _field(_nameController,       'Full Name',       Icons.person_outline,   required: true),
              const SizedBox(height: 14),
              _field(_guardianController,   'Guardian Name',   Icons.people_outline),
              const SizedBox(height: 14),
              _field(_guardianPhoneController, 'Guardian Phone', Icons.phone_outlined,
                  keyboardType: TextInputType.phone),
              const SizedBox(height: 14),
              _field(_addressController,    'Home Address',    Icons.home_outlined),
              const SizedBox(height: 14),

              // DOB picker
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime(2000),
                    firstDate: DateTime(1950),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _dob = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Date of Birth',
                    prefixIcon: const Icon(Icons.calendar_today_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  child: Text(
                    _dob == null
                        ? 'Select date'
                        : '${_dob!.day}/${_dob!.month}/${_dob!.year}',
                    style: TextStyle(
                      color: _dob == null ? AppColors.textLight : AppColors.textDark,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save & Continue'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? '$label is required' : null
          : null,
    );
  }
}
