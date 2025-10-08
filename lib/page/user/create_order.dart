import 'dart:typed_data';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

class CreateOrder extends StatefulWidget {
  final String senderName;
  final String senderId;

  const CreateOrder({
    super.key,
    required this.senderId,
    required this.senderName,
  });

  @override
  State<CreateOrder> createState() => _CreateOrderState();
}

class _CreateOrderState extends State<CreateOrder> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker picker = ImagePicker();

  Uint8List? orderImageBytes; // เก็บรูปเป็น bytes ทันที
  final TextEditingController _recipientNameController = TextEditingController();
  final TextEditingController _recipientPhoneController = TextEditingController();
  final TextEditingController _recipientAddressController = TextEditingController();
  final TextEditingController _itemController = TextEditingController();

  String _recipientGps = '';
  List<String> items = [];

  @override
  void initState() {
    super.initState();
    _initFirebase();
  }

  /// 🔹 Initial Firebase + App Check + Sign-in
  Future<void> _initFirebase() async {
    await Firebase.initializeApp();

    // App Check แบบ Debug
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );

    // Sign-in anonymous
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  /// 🔍 ค้นหาผู้รับจากเบอร์โทร
  Future<void> _searchRecipient() async {
    final phone = _recipientPhoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกเบอร์โทรผู้รับ')),
      );
      return;
    }

    try {
      final query = await _firestore
          .collection('users')
          .where('phone_number', isEqualTo: phone)
          .where('role', isEqualTo: 'Receiver')
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data() as Map<String, dynamic>;
        setState(() {
          _recipientNameController.text = data['name'] ?? '';
          _recipientAddressController.text = data['address'] ?? '';
          _recipientGps = data['gps'] ?? '';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ดึงข้อมูลผู้รับสำเร็จ')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ไม่พบข้อมูลผู้รับจากหมายเลขนี้')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  /// ➕ เพิ่มสินค้า
  void _addItem() {
    if (_itemController.text.isNotEmpty) {
      setState(() {
        items.add(_itemController.text.trim());
        _itemController.clear();
      });
    }
  }

  /// 📷 เลือกรูป
  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.orange),
              title: const Text('เลือกจากแกลเลอรี่'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await picker.pickImage(source: ImageSource.gallery);
                if (picked != null) {
                  orderImageBytes = await picked.readAsBytes(); // แปลงทันที
                  setState(() {});
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.orange),
              title: const Text('ถ่ายรูป'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await picker.pickImage(source: ImageSource.camera);
                if (picked != null) {
                  orderImageBytes = await picked.readAsBytes(); // แปลงทันที
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// ☁️ แปลงรูปเป็น Base64 สำหรับ Firestore
  Future<Map<String, dynamic>?> _uploadImageToFirestore() async {
    if (orderImageBytes == null) return null;

    try {
      final base64Image = base64Encode(orderImageBytes!);
      final imageData = {
        'imageBase64': base64Image,
        'uploadedAt': FieldValue.serverTimestamp(),
      };
      return imageData;
    } catch (e) {
      log('❌ แปลงรูปเป็น Base64 ไม่สำเร็จ: $e');
      return null;
    }
  }

  /// 📝 สร้างออเดอร์
  Future<void> _createOrder() async {
    if (_recipientNameController.text.isEmpty ||
        _recipientPhoneController.text.isEmpty ||
        _recipientAddressController.text.isEmpty ||
        _recipientGps.isEmpty ||
        items.isEmpty ||
        orderImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกข้อมูลครบทุกช่องและอัปโหลดรูป')),
      );
      return;
    }

    try {
      final imageData = await _uploadImageToFirestore();
      if (imageData == null) return;

      await _firestore.collection('orders').add({
        'senderId': widget.senderId,
        'senderName': widget.senderName,
        'recipientName': _recipientNameController.text.trim(),
        'recipientPhone': _recipientPhoneController.text.trim(),
        'recipientAddress': _recipientAddressController.text.trim(),
        'recipientGps': _recipientGps,
        'items': items,
        'status': 'รอไรเดอร์มารับสินค้า',
        'orderImage': imageData, // Base64
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ สร้างรายการส่งสำเร็จ')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ เกิดข้อผิดพลาด: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สร้างรายการส่งสินค้า'),
        backgroundColor: Colors.blue[700],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ข้อมูลผู้รับ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _recipientPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'เบอร์โทรผู้รับ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searchRecipient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Icon(Icons.search, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recipientNameController,
              decoration: InputDecoration(
                labelText: 'ชื่อผู้รับ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recipientAddressController,
              decoration: InputDecoration(
                labelText: 'ที่อยู่ผู้รับ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            const Text('รายการสินค้า', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemController,
                    decoration: InputDecoration(
                      labelText: 'สินค้า',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...items.map(
              (e) => ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.green),
                title: Text(e),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      items.remove(e);
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: _showImagePicker,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('รูปประกอบสถานะ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: orderImageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(orderImageBytes!, fit: BoxFit.cover),
                          )
                        : const Center(
                            child: Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _createOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('สร้างรายการส่ง', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
