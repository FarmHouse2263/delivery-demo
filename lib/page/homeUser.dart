import 'package:flutter/material.dart';

class HomePage extends StatelessWidget {
  final String userEmail;

  const HomePage({super.key, required this.userEmail});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Home"),
        backgroundColor: Colors.blue,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "สวัสดี, $userEmail",
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
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
