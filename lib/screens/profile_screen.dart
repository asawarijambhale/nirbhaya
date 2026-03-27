import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'edit_profile_screen.dart';
import '../features/auth/auth_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const royalBlue = Color(0xFF101D68);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          "My Profile",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 22,
          ),
        ),
        centerTitle: true,
        backgroundColor: royalBlue,
        elevation: 0,
      ),
      body: FutureBuilder<String?>(
        future: uid != null && uid.trim().isNotEmpty
            ? Future.value(uid)
            : AuthService.getCurrentUserDocId(),
        builder: (context, docIdSnap) {
          if (docIdSnap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final docId = docIdSnap.data;
          if (docId == null || docId.trim().isEmpty) {
            return const Center(child: Text("Please login again."));
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(docId)
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              var data = snapshot.data!.data() as Map<String, dynamic>?;

              if (data == null) {
                return const Center(child: Text("No Profile Data Found"));
              }

              return Column(
                children: [
              // 🔥 Profile Header
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Color(0xFF101D68),
                      Color(0xFF2A3BB3),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(40),
                    bottomRight: Radius.circular(40),
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(vertical: 30, horizontal: 20),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 55,
                      backgroundImage: data['photoUrl'] != null
                          ? NetworkImage(data['photoUrl'])
                          : null,
                      child: data['photoUrl'] == null
                          ? const Icon(Icons.person,
                              size: 60, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      data['name'] ?? "No Name",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      data['email'] ?? "",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 🔥 Info Section
              Expanded(
                child: ListView(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    _buildInfoCard(Icons.phone, "Phone",
                        data['phone'] ?? "Not Added"),
                    _buildInfoCard(Icons.person, "Guardian Name",
                        data['guardianName'] ?? "Not Added"),
                    _buildInfoCard(Icons.phone_android,
                        "Guardian Phone",
                        data['guardianPhone'] ?? "Not Added"),
                    _buildInfoCard(Icons.cake, "Date of Birth",
                        data['dob'] != null
                            ? (data['dob'] as Timestamp)
                                .toDate()
                                .toString()
                                .split(" ")[0]
                            : "Not Added"),
                    _buildInfoCard(Icons.home, "Home Address",
                        data['homeAddress'] ?? "Not Added"),
                    _buildInfoCard(Icons.work, "Work/College Address",
                        data['workAddress'] ?? "Not Added"),

                    const SizedBox(height: 15),

                    // 🔴 Logout Button
                    ElevatedButton.icon(
                      onPressed: () async {
                        await FirebaseAuth.instance.signOut();
                        Navigator.pushReplacementNamed(
                            context, '/login');
                      },
                      icon: const Icon(Icons.logout),
                      label: const Text("Logout"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: royalBlue,
                        foregroundColor: Colors.white,
                        minimumSize:
                            const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(15),
                        ),
                      ),
                    ),
                    // ✏️ Edit Profile Button
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditProfileScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text("Edit Profile"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: royalBlue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
              );
            },
          );
        },
      ),
    );
  }

  // 🔹 Reusable Card
  Widget _buildInfoCard(
      IconData icon, String title, String subtitle) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              const Color(0xFF101D68).withOpacity(0.1),
          child: Icon(icon,
              color: const Color(0xFF101D68)),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(subtitle),
      ),
    );
  }
}
