import 'dart:typed_data';
import 'dart:convert';
import 'dart:developer';
import 'package:delivery1/page/user/SelectReceiverPage.dart';
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

  Uint8List? orderImageBytes;
  Uint8List? recipientProfileBytes;
  String? recipientProfileUrl;

  final TextEditingController _recipientNameController =
      TextEditingController();
  final TextEditingController _recipientPhoneController =
      TextEditingController();
  final TextEditingController _recipientPasswordController =
      TextEditingController();
  final TextEditingController _recipientAddressController =
      TextEditingController();
  final TextEditingController _itemController = TextEditingController();
  final TextEditingController _recipientGpsController = TextEditingController();

  String _recipientGps = '';
  List<String> items = [];

  @override
  void initState() {
    super.initState();
    _initFirebase();
  }

  Future<void> _initFirebase() async {
    await Firebase.initializeApp();
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  Future<void> _searchRecipient() async {
    final phone = _recipientPhoneController.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกเบอร์โทรผู้รับ')));
      return;
    }

    try {
      final query = await _firestore
          .collection('users')
          .where('phone_number', isEqualTo: phone)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data() as Map<String, dynamic>;
        log('🔹 Raw profile_image: ${data['profile_image']}');

        setState(() {
          _recipientNameController.text = data['name'] ?? '';
          _recipientPasswordController.text = data['password'] ?? '';
          _recipientAddressController.text = data['address'] ?? '';
          _recipientGps = data['gps'] ?? '';
          _recipientGpsController.text = _recipientGps;

          recipientProfileBytes = null;
          recipientProfileUrl = null;

          final profileData = data['profile_image'];
          if (profileData != null) {
            try {
              if (profileData is Map && profileData['imageBase64'] != null) {
                final base64Str = profileData['imageBase64']
                    .toString()
                    .replaceAll(RegExp(r'\s+'), '');
                recipientProfileBytes = base64Decode(base64Str);
              } else if (profileData is String && profileData.isNotEmpty) {
                final cleaned = profileData.replaceAll(RegExp(r'\s+'), '');
                recipientProfileBytes = base64Decode(cleaned);
              }
            } catch (e) {
              log('❌ Decode Base64 fail: $e');
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ แสดงข้อมูลผู้รับสำเร็จ')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('❌ ไม่พบข้อมูลผู้รับจากหมายเลขนี้')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  void _addItem() {
    if (_itemController.text.isNotEmpty) {
      setState(() {
        items.add(_itemController.text.trim());
        _itemController.clear();
      });
    }
  }

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
                final picked = await picker.pickImage(
                  source: ImageSource.gallery,
                );
                if (picked != null) {
                  orderImageBytes = await picked.readAsBytes();
                  setState(() {});
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.orange),
              title: const Text('ถ่ายรูป'),
              onTap: () async {
                Navigator.pop(context);
                final picked = await picker.pickImage(
                  source: ImageSource.camera,
                );
                if (picked != null) {
                  orderImageBytes = await picked.readAsBytes();
                  setState(() {});
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createOrder() async {
    if (_recipientNameController.text.isEmpty ||
        _recipientPhoneController.text.isEmpty ||
        _recipientAddressController.text.isEmpty ||
        _recipientGps.isEmpty ||
        items.isEmpty ||
        orderImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกข้อมูลครบทุกช่องและอัปโหลดรูปสินค้า'),
        ),
      );
      return;
    }

    try {
      final base64OrderImage = base64Encode(orderImageBytes!);
      await _firestore.collection('orders').add({
        'senderId': widget.senderId,
        'senderName': widget.senderName,
        'recipientName': _recipientNameController.text.trim(),
        'recipientPhone': _recipientPhoneController.text.trim(),
        'recipientAddress': _recipientAddressController.text.trim(),
        'recipientGps': _recipientGps,
        'recipientPassword': _recipientPasswordController.text.trim(),
        'profile_image': recipientProfileBytes != null
            ? base64Encode(recipientProfileBytes!)
            : recipientProfileUrl ?? null,
        'items': items,
        'status': 'รอไรเดอร์มารับสินค้า',
        'orderImage': base64OrderImage,
        'createdAt': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('✅ สร้างรายการส่งสำเร็จ')));
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('❌ เกิดข้อผิดพลาด: $e')));
    }
  }

  Future<void> _selectReceiver() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SelectReceiverPage()),
    );

    if (result != null) {
      setState(() {
        _recipientNameController.text = result['name'] ?? '';
        _recipientPhoneController.text = result['phone_number'] ?? '';
        _recipientAddressController.text = result['address'] ?? '';
        _recipientGps = result['gps'] ?? '';
        _recipientGpsController.text = _recipientGps;
        _recipientPasswordController.text = result['password'] ?? '';

        recipientProfileBytes = result['profileBytes'];
        recipientProfileUrl = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'สร้างรายการส่งสินค้า',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ข้อมูลผู้รับ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _recipientPhoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'เบอร์โทรผู้รับ',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _searchRecipient,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.search, color: Colors.white),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _selectReceiver,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Icon(Icons.list, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Center(
              child: recipientProfileBytes != null
                  ? CircleAvatar(
                      radius: 50,
                      backgroundImage: MemoryImage(recipientProfileBytes!),
                    )
                  : (recipientProfileUrl != null
                        ? CircleAvatar(
                            radius: 50,
                            backgroundImage: NetworkImage(recipientProfileUrl!),
                          )
                        : const CircleAvatar(
                            radius: 50,
                            child: Icon(Icons.person, size: 40),
                          )),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recipientNameController,
              decoration: InputDecoration(
                labelText: 'ชื่อผู้รับ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recipientPasswordController,
              decoration: InputDecoration(
                labelText: 'รหัสผ่านผู้รับ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recipientAddressController,
              decoration: InputDecoration(
                labelText: 'ที่อยู่ผู้รับ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _recipientGpsController,
              readOnly: true,
              decoration: InputDecoration(
                labelText: 'พิกัด GPS',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'รายการสินค้า',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _itemController,
                    decoration: InputDecoration(
                      labelText: 'สินค้า',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _addItem,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    padding: const EdgeInsets.all(16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                  const Text(
                    'รูปสินค้า',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
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
                            child: Image.memory(
                              orderImageBytes!,
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Center(
                            child: Icon(
                              Icons.camera_alt,
                              size: 50,
                              color: Colors.grey,
                            ),
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
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'สร้างรายการส่ง',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
