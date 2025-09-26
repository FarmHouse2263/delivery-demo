import 'package:flutter/material.dart';

class HomePageRider extends StatelessWidget {
  final String riderId;
  final String riderName;
  final String riderEmail;

  const HomePageRider({
    super.key,
    required this.riderId,
    required this.riderName,
    required this.riderEmail,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Home Rider"),
        backgroundColor: Colors.orange,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "สวัสดี, $riderName",
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              "อีเมล: $riderEmail",
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Text(
              "รหัส Rider: $riderId",
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
