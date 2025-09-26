import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserRegister extends StatefulWidget {
  const UserRegister({super.key});

  @override
  State<UserRegister> createState() => _UserRegisterState();
}

class _UserRegisterState extends State<UserRegister> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController phoneCtl = TextEditingController();
  final TextEditingController emailCtl = TextEditingController();
  final TextEditingController passwordCtl = TextEditingController();
  final TextEditingController nameCtl = TextEditingController();

  File? _profileImage;
  bool _isLoading = false;
  bool _obscurePassword = true;

  final ImagePicker _picker = ImagePicker();

  Future<void> pickImage() async {
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<String> uploadProfileImage(String uid) async {
    if (_profileImage == null) return '';
    final ref = FirebaseStorage.instance
        .ref()
        .child('user_profile')
        .child('$uid.jpg');
    await ref.putFile(_profileImage!);
    return await ref.getDownloadURL();
  }

  Future<void> registerUser() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    // สร้าง document ใหม่ใน collection 'users'
    DocumentReference docRef =
        FirebaseFirestore.instance.collection('users').doc();

    String uid = docRef.id;

    // อัปโหลดรูปโปรไฟล์
    String profileUrl = await uploadProfileImage(uid);

    // บันทึกข้อมูลผู้ใช้
    await docRef.set({
      'user_id': uid,
      'phone_number': phoneCtl.text.trim(),
      'name': nameCtl.text.trim(),
      'email': emailCtl.text.trim(),
      'profile_image': profileUrl,
      'password': passwordCtl.text.trim(), // ต้องเป็น .text
      'role': 'user',
      'created_at': Timestamp.now(),
      'updated_at': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ลงทะเบียนสำเร็จ')),
    );

    Navigator.pop(context);
  } catch (e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
  } finally {
    setState(() => _isLoading = false);
  }
}


  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String? Function(String?) validator,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    Widget? suffixIcon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
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
        validator: validator,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: Colors.blue),
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
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        title: const Text('สมัครสมาชิกผู้ใช้'),
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

                // Profile Image Picker
                GestureDetector(
                  onTap: pickImage,
                  child: CircleAvatar(
                    radius: 45,
                    backgroundColor: Colors.blue[100],
                    backgroundImage:
                        _profileImage != null ? FileImage(_profileImage!) : null,
                    child: _profileImage == null
                        ? const Icon(Icons.add_a_photo, size: 40, color: Colors.blue)
                        : null,
                  ),
                ),
                const SizedBox(height: 20),

                const Text(
                  'สร้างบัญชีผู้ใช้ใหม่',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'กรอกข้อมูลเพื่อสมัครสมาชิกผู้ใช้ระบบ',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 30),

                _buildInputField(
                  controller: nameCtl,
                  label: 'ชื่อ-นามสกุล',
                  icon: Icons.person,
                  validator: (v) => v!.isEmpty ? 'กรุณากรอกชื่อ' : null,
                ),

                _buildInputField(
                  controller: phoneCtl,
                  label: 'เบอร์โทรศัพท์',
                  icon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'กรุณากรอกเบอร์โทร' : null,
                ),

                _buildInputField(
                  controller: emailCtl,
                  label: 'อีเมล',
                  icon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty ? 'กรุณากรอกอีเมล' : null,
                ),

                _buildInputField(
                  controller: passwordCtl,
                  label: 'รหัสผ่าน',
                  icon: Icons.lock,
                  obscureText: _obscurePassword,
                  validator: (v) =>
                      v!.length < 6 ? 'รหัสผ่านอย่างน้อย 6 ตัว' : null,
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
                ),

                const SizedBox(height: 10),

                Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blue.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : registerUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
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
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'มีบัญชีอยู่แล้ว? ',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text(
                        'เข้าสู่ระบบ',
                        style: TextStyle(
                          color: Colors.blue,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
