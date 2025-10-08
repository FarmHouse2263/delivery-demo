import 'dart:io';
import 'dart:developer';
import 'package:delivery1/page/MapPickerPage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserRegister extends StatefulWidget {
  const UserRegister({super.key});

  @override
  State<UserRegister> createState() => _UserRegisterState();
}

class _UserRegisterState extends State<UserRegister> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameCtl = TextEditingController();
  final TextEditingController phoneCtl = TextEditingController();
  final TextEditingController emailCtl = TextEditingController();
  final TextEditingController passwordCtl = TextEditingController();

  //ตัวแปรที่อยู่และ GPS
  final TextEditingController addressCtl = TextEditingController();
  final TextEditingController gpsCtl = TextEditingController();

  XFile? image; //เก็บไฟล์รูปที่เลือก
  final ImagePicker picker = ImagePicker(); // ใช้ลือกภาพจากแกลเลอรี่หรือกล้อง
  bool _isLoading = false;
  bool _obscurePassword = true;

  String? selectedRole; // เก็บ role ของ user

  /// สมัครสมาชิก
  Future<void> registerUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      DocumentReference docRef = FirebaseFirestore.instance
          .collection('users')
          .doc();
      String uid = docRef.id;

      await docRef.set({
        'user_id': uid,
        'name': nameCtl.text.trim(),
        'phone_number': phoneCtl.text.trim(),
        'email': emailCtl.text.trim(),
        'password': passwordCtl.text.trim(),
        'profile_path': image?.path ?? '',

        // เพิ่มฟิลด์ใหม่
        'address': addressCtl.text.trim(),
        'gps': gpsCtl.text.trim(),

        'role': selectedRole ?? '',
        'created_at': Timestamp.now(),
        'updated_at': Timestamp.now(),
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('ลงทะเบียนสำเร็จ')));

      Navigator.pop(context);
    } catch (e) {
      log('Error: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// แสดง Dialog เลือก Camera/Gallery
  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // เลือกรูปจากแกลเลอรี่
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blue),
              title: const Text('เลือกจากแกลเลอรี่'),
              onTap: () async {
                Navigator.pop(context);
                image = await picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  log('เลือกไฟล์: ${image!.path}');
                  setState(() {});
                } else {
                  log('No Image');
                }
              },
            ),

            // เลือกถ่ายรูปใหม่
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.blue),
              title: const Text('ถ่ายรูป'),
              onTap: () async {
                Navigator.pop(context);
                image = await picker.pickImage(source: ImageSource.camera);
                if (image != null) {
                  log('เลือกไฟล์: ${image!.path}');
                  setState(() {});
                } else {
                  log('No Image');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    required String? Function(String?) validator,
    Widget? suffixIcon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          hintText: label,
          prefixIcon: Icon(icon, color: Colors.blue),
          suffixIcon: suffixIcon,
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.blue, width: 1),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.red, width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'สมัครสมาชิก',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 30),

              // Profile Image Section
              GestureDetector(
                onTap: _showImagePickerOptions,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        shape: BoxShape.circle,
                      ),
                      child: image != null
                          ? ClipOval(
                              child: Image.file(
                                File(image!.path),
                                width: 120,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Icon(
                              Icons.camera_alt,
                              size: 50,
                              color: Colors.blue[200],
                            ),
                    ),
                  ],
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
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 30),
              // Form Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildInputField(
                        controller: nameCtl,
                        label: 'ชื่อ-นามสกุล',
                        icon: Icons.person_outline,
                        validator: (v) => v!.isEmpty ? 'กรุณากรอกชื่อ' : null,
                      ),
                      _buildInputField(
                        controller: phoneCtl,
                        label: 'เบอร์โทรศัพท์',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            v!.isEmpty ? 'กรุณากรอกเบอร์โทร' : null,
                      ),
                      _buildInputField(
                        controller: emailCtl,
                        label: 'อีเมล',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                        validator: (v) =>
                            v!.isEmpty ? 'กรุณากรอกที่อยู่อีเมล' : null,
                      ),
                      _buildInputField(
                        controller: passwordCtl,
                        label: 'รหัสผ่าน',
                        icon: Icons.lock_outline,
                        obscureText: _obscurePassword,
                        validator: (v) =>
                            v!.length < 6 ? 'รหัสผ่านอย่างน้อย 6 ตัว' : null,
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setState(() {
                              _obscurePassword = !_obscurePassword;
                            });
                          },
                        ),
                      ),

                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        child: DropdownButtonFormField<String>(
                          value: selectedRole,
                          decoration: InputDecoration(
                            hintText: 'เลือก Role',
                            prefixIcon: const Icon(
                              Icons.roller_shades,
                              color: Colors.blue,
                            ),
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 1,
                              ),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: Colors.red,
                                width: 1,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Sender',
                              child: Text('Sender'),
                            ),
                            DropdownMenuItem(
                              value: 'Receiver',
                              child: Text('Receiver'),
                            ),
                          ],
                          onChanged: (value) {
                            setState(() {
                              selectedRole = value;
                            });
                          },
                          validator: (value) =>
                              value == null ? 'กรุณาเลือก Role' : null,
                        ),
                      ),

                      _buildInputField(
                        controller: addressCtl,
                        label: 'ที่อยู่',
                        icon: Icons.home_outlined,
                        validator: (v) =>
                            v!.isEmpty ? 'กรุณากรอกที่อยู่' : null,
                      ),

                      _buildInputField(
                        controller: gpsCtl,
                        label: 'พิกัด GPS (ละติจูด, ลองจิจูด)',
                        icon: Icons.location_on_outlined,
                        validator: (v) =>
                            v!.isEmpty ? 'กรุณากรอกพิกัด GPS' : null,
                      ),

                      TextFormField(
                        controller: gpsCtl,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: "พิกัด GPS",
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.map),
                            onPressed: () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const MapPickerPage(),
                                ),
                              );
                              if (result != null) {
                                gpsCtl.text =
                                    "${result.latitude}, ${result.longitude}";
                              }
                            },
                          ),
                        ),
                        validator: (v) => v!.isEmpty ? 'กรุณาเลือกพิกัด' : null,
                      ),

                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
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
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2.5,
                                  ),
                                )
                              : const Text(
                                  'เข้าสู่ระบบ',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: RichText(
                          text: TextSpan(
                            text: 'มีบัญชีอยู่แล้ว? ',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                            children: const [
                              TextSpan(
                                text: 'สมัครสมาชิก',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
