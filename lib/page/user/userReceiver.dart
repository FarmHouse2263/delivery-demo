import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class Userreceiver extends StatefulWidget {
  final String userEmail;

  const Userreceiver({super.key, required this.userEmail});

  @override
  State<Userreceiver> createState() => _UserRegisterState();
}

class _UserRegisterState extends State<Userreceiver> {
  String? profilePath;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  Future<void> fetchUserProfile() async {
    try {
      // ดึงข้อมูลผู้ใช้จาก Firestore โดย filter ด้วย email
      QuerySnapshot userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: widget.userEmail)
          .get();

      if (userSnap.docs.isNotEmpty) {
        var userData = userSnap.docs.first.data() as Map<String, dynamic>;
        setState(() {
          profilePath = userData['profile_path'] ?? null;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching profile: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Receiver"), backgroundColor: Colors.blue),
      body: Center(
        child: isLoading
            ? const CircularProgressIndicator()
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // แสดงรูปผู้ใช้
                  if (profilePath != null && profilePath!.isNotEmpty)
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: FileImage(File(profilePath!)),
                    )
                  else
                    const CircleAvatar(
                      radius: 50,
                      child: Icon(Icons.person, size: 50),
                    ),
                  const SizedBox(height: 20),
                  Text(
                    "สวัสดี, ${widget.userEmail}",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "คุณเข้าสู่ระบบเรียบร้อยแล้ว",
                    style: TextStyle(fontSize: 16),
                  ),
                ],
              ),
      ),
    );
  }
}
