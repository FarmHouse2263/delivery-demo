import 'dart:convert';
import 'dart:typed_data';
import 'package:delivery1/page/LandingPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SelectReceiverPage extends StatefulWidget {
  const SelectReceiverPage({super.key});

  @override
  State<SelectReceiverPage> createState() => _SelectReceiverPageState();
}

class _SelectReceiverPageState extends State<SelectReceiverPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ออกจากระบบ'),
        content: const Text('คุณต้องการออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ปิด dialog
              // ไปยังหน้าล็อกอิน
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const LandingPage()),
                (route) => false,
              );
            },
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  Uint8List? _decodeProfile(dynamic profileData) {
    if (profileData == null) return null;

    try {
      // กรณีเป็น Object { imageBase64: "..." }
      if (profileData is Map && profileData['imageBase64'] != null) {
        final base64Str = profileData['imageBase64'].toString().replaceAll(RegExp(r'\s+'), '');
        return base64Decode(base64Str);
      }
      // กรณีเป็น String base64
      else if (profileData is String && profileData.isNotEmpty) {
        final cleaned = profileData.replaceAll(RegExp(r'\s+'), '');
        return base64Decode(cleaned);
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'เลือกผู้รับสินค้า',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: _logout,
          ),
        ],
      ),
      backgroundColor: Colors.grey[100],
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('users')
            .where('role', isEqualTo: 'Receiver')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'ยังไม่มีข้อมูลผู้รับสินค้า',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            );
          }

          final receivers = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: receivers.length,
            itemBuilder: (context, index) {
              final receiver = receivers[index].data() as Map<String, dynamic>;

              final name = receiver['name'] ?? '-';
              final phone = receiver['phone_number'] ?? '-';
              final address = receiver['address'] ?? '-';
              final password = receiver['password'] ?? '-';
              final gps = receiver['gps'] ?? '-';
              final profileBytes = _decodeProfile(receiver['profile_image']);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 3,
                child: ListTile(
                  leading: profileBytes != null
                      ? CircleAvatar(
                          backgroundImage: MemoryImage(profileBytes),
                        )
                      : const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📞 $phone'),
                      Text('📍 $address'),
                      Text('🗺️ $gps'),
                      Text('🔑 $password'),
                    ],
                  ),
                  onTap: () {
                    Navigator.pop(context, {
                      'name': name,
                      'phone_number': phone,
                      'address': address,
                      'gps': gps,
                      'profileBytes': profileBytes,
                      'password': password,
                    });
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
