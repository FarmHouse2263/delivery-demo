import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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

  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> registerRider() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() => _isLoading = true);

  try {
    // สร้าง document ใหม่ใน collection 'riders'
    DocumentReference docRef =
        FirebaseFirestore.instance.collection('riders').doc();

    String uid = docRef.id;

    // บันทึกข้อมูล Rider
    await docRef.set({
      'rider_id': uid,
      'phone_number': phoneCtl.text.trim(),
      'name': nameCtl.text.trim(),
      'email': emailCtl.text.trim(),
      'profile_image': '',    // สามารถอัปโหลดได้ภายหลัง
      'vehicle_image': '',    // สามารถอัปโหลดได้ภายหลัง
      'vehicle_number': vehicleNumberCtl.text.trim(),
      'password': passwordCtl.text.trim(), // ต้องใช้ .text
      'role': 'rider',
      'created_at': Timestamp.now(),
      'updated_at': Timestamp.now(),
    });

    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('ลงทะเบียนสำเร็จ')));
    Navigator.pop(context);

  } catch (e) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
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

                // App Icon for Rider Registration
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(Icons.person_add, size: 40, color: Colors.white),
                ),

                const SizedBox(height: 30),

                const Text(
                  'เข้าร่วมกับเรา!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'สมัครเป็น Rider และเริ่มต้นหารายได้',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),

                const SizedBox(height: 40),

                // Name Field
                _buildTextField(
                  controller: nameCtl,
                  labelText: 'ชื่อ-นามสกุล',
                  prefixIcon: Icons.person,
                  validator: (v) => v!.isEmpty ? 'กรุณากรอกชื่อ' : null,
                ),

                const SizedBox(height: 20),

                // Phone Field
                _buildTextField(
                  controller: phoneCtl,
                  labelText: 'เบอร์โทรศัพท์',
                  prefixIcon: Icons.phone,
                  keyboardType: TextInputType.phone,
                  validator: (v) => v!.isEmpty ? 'กรุณากรอกเบอร์โทร' : null,
                ),

                const SizedBox(height: 20),

                // Email Field
                _buildTextField(
                  controller: emailCtl,
                  labelText: 'อีเมล',
                  prefixIcon: Icons.email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => v!.isEmpty ? 'กรุณากรอกอีเมล' : null,
                ),

                const SizedBox(height: 20),

                // Password Field
                _buildTextField(
                  controller: passwordCtl,
                  labelText: 'รหัสผ่าน',
                  prefixIcon: Icons.lock,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      color: Colors.grey,
                    ),
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (v) => v!.length < 6 ? 'รหัสผ่านอย่างน้อย 6 ตัว' : null,
                ),

                const SizedBox(height: 20),

                // Vehicle Number Field
                _buildTextField(
                  controller: vehicleNumberCtl,
                  labelText: 'ทะเบียนรถ',
                  prefixIcon: Icons.motorcycle,
                  validator: (v) => v!.isEmpty ? 'กรุณากรอกทะเบียนรถ' : null,
                ),

                const SizedBox(height: 30),

                // Register Button
                Container(
                  width: double.infinity,
                  height: 55,
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : registerRider,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
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

                // Info Section
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[200]!),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ข้อมูลที่ต้องเตรียม',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• รูปภาพโปรไฟล์และรูปรถ สามารถอัพโหลดได้ภายหลัง\n• ทะเบียนรถต้องถูกต้องและชัดเจน\n• อีเมลจะใช้สำหรับเข้าสู่ระบบ',
                        style: TextStyle(
                          color: Colors.orange[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
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