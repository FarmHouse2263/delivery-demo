import 'dart:typed_data';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class RiderRegister extends StatefulWidget {
  const RiderRegister({super.key});

  @override
  State<RiderRegister> createState() => _RiderRegisterState();
}

class _RiderRegisterState extends State<RiderRegister> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController phoneCtl = TextEditingController();
  final TextEditingController emailCtl = TextEditingController();
  final TextEditingController passwordCtl = TextEditingController();
  final TextEditingController nameCtl = TextEditingController();
  final TextEditingController vehicleNumberCtl = TextEditingController();

  Uint8List? profileRiderBytes; // เก็บโปรไฟล์เป็น bytes
  Uint8List? vehicleImageBytes;  // เก็บรูปรถเป็น bytes
  final ImagePicker picker = ImagePicker();

  bool _isLoading = false;
  bool _obscurePassword = true;

  /// ฟังก์ชันเลือกหรือถ่ายรูป (ทั้ง Profile / Vehicle)
  Future<void> _pickImage({required bool isProfile}) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library, color: Colors.orange),
            title: const Text('เลือกจากแกลเลอรี่'),
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt, color: Colors.orange),
            title: const Text('ถ่ายรูป'),
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),
        ],
      ),
    );

    if (source != null) {
      final pickedFile = await picker.pickImage(source: source);
      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();
        setState(() {
          if (isProfile) {
            profileRiderBytes = bytes;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('เลือกโปรไฟล์เรียบร้อย')),
            );
          } else {
            vehicleImageBytes = bytes;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('เลือกรูปรถเรียบร้อย')),
            );
          }
        });
      }
    }
  }

  /// แปลงรูปเป็น Base64 สำหรับ Firestore
  Map<String, dynamic>? _convertImage(Uint8List? bytes) {
    if (bytes == null) return null;
    return {
      'imageBase64': base64Encode(bytes),
      'uploadedAt': FieldValue.serverTimestamp(),
    };
  }

  /// ฟังก์ชันสมัครสมาชิก
  Future<void> registerRider() async {
    if (!_formKey.currentState!.validate()) return;

    if (profileRiderBytes == null || vehicleImageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาอัปโหลดรูปโปรไฟล์และรูปรถ')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final docRef = FirebaseFirestore.instance.collection('riders').doc();
      final uid = docRef.id;

      await docRef.set({
        'rider_id': uid,
        'phone_number': phoneCtl.text.trim(),
        'name': nameCtl.text.trim(),
        'email': emailCtl.text.trim(),
        'vehicle_number': vehicleNumberCtl.text.trim(),
        'password': passwordCtl.text.trim(),
        'role': 'rider',
        'profile_rider': _convertImage(profileRiderBytes),
        'vehicle_image': _convertImage(vehicleImageBytes),
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ลงทะเบียนสำเร็จ')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เกิดข้อผิดพลาด: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData prefixIcon,
    required String? Function(String?) validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        decoration: InputDecoration(
          labelText: labelText,
          prefixIcon: Icon(prefixIcon, color: Colors.orange),
          suffixIcon: suffixIcon,
          border: const OutlineInputBorder(
            borderSide: BorderSide.none,
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          filled: true,
          fillColor: Colors.white,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        title: const Text('สมัครสมาชิก Rider'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 20),

                // Profile
                GestureDetector(
                  onTap: () => _pickImage(isProfile: true),
                  child: CircleAvatar(
                    radius: 60,
                    backgroundColor: Colors.orange[50],
                    child: profileRiderBytes != null
                        ? ClipOval(
                            child: Image.memory(
                              profileRiderBytes!,
                              width: 120,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Icon(Icons.camera_alt,
                            size: 50, color: Colors.orange[200]),
                  ),
                ),
                const SizedBox(height: 30),

                const Text(
                  'เข้าร่วมกับเรา!',
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                ),
                const SizedBox(height: 8),
                Text(
                  'สมัครเป็น Rider และเริ่มต้นหารายได้',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 40),

                _buildTextField(
                  controller: nameCtl,
                  labelText: 'ชื่อ-นามสกุล',
                  prefixIcon: Icons.person,
                  validator: (v) => v!.isEmpty ? 'กรุณากรอกชื่อ' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: phoneCtl,
                  labelText: 'เบอร์โทรศัพท์',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'กรุณากรอกเบอร์โทร' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: emailCtl,
                  labelText: 'อีเมล',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty ? 'กรุณากรอกอีเมล' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: passwordCtl,
                  labelText: 'รหัสผ่าน',
                  prefixIcon: Icons.lock,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (v) =>
                      v!.length < 6 ? 'รหัสผ่านอย่างน้อย 6 ตัว' : null,
                ),
                const SizedBox(height: 20),

                // Vehicle Image
                GestureDetector(
                  onTap: () => _pickImage(isProfile: false),
                  child: Container(
                    width: double.infinity,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.shade200),
                    ),
                    child: vehicleImageBytes != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(
                              vehicleImageBytes!,
                              width: double.infinity,
                              height: 120,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt,
                                  size: 40, color: Colors.orange[300]),
                              const SizedBox(height: 8),
                              Text(
                                'แตะเพื่ออัปโหลด',
                                style: TextStyle(
                                    color: Colors.orange[400], fontSize: 14),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: vehicleNumberCtl,
                  labelText: 'ทะเบียนรถ',
                  prefixIcon: Icons.motorcycle,
                  validator: (v) =>
                      v!.isEmpty ? 'กรุณากรอกทะเบียนรถ' : null,
                ),
                const SizedBox(height: 30),

                // Register Button
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : registerRider,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'สมัครสมาชิก',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
