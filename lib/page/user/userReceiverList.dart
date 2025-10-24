import 'dart:convert';
import 'dart:developer';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery1/page/LandingPage.dart';
import 'package:delivery1/page/user/map_Receiver.dart';
import 'package:flutter/material.dart';

class Userreceiverlist extends StatefulWidget {
  final String recipientPhone; // เบอร์โทรผู้ใช้ที่ login
  final String? recipientName; // ชื่อผู้ใช้
  const Userreceiverlist({
    super.key,
    required this.recipientPhone,
    this.recipientName,
  });

  @override
  State<Userreceiverlist> createState() => _UserreceiverlistState();
}

class _UserreceiverlistState extends State<Userreceiverlist> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ออกจากระบบ'),
        content: Text('คูณต้องการออกจากระบบใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ปิด dialog
              // ลบข้อมูล session / token ที่เก็บไว้ถ้ามี

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

  final Map<String, dynamic> _statusColorsMap = {
    'รอไรเดอร์มารับสินค้า': Colors.orange,
    'ไรเดอร์รับงาน': Colors.blue,
    'ไรเดอร์รับสินค้าแล้วและกำลังเดินทางไปส่ง': Colors.purple,
    'ส่งสินค้าแล้ว': Colors.green,
    'ยกเลิก': Colors.red,
  };

  // ฟังก์ชันเพื่อดึงข้อมูลคำสั่งซื้อของผู้รับของที่ล็อกอินอยู่
  Stream<QuerySnapshot> _getReceiverOrdersStream() {
    return _firestore
        .collection('orders')
        .where('recipientPhone', isEqualTo: widget.recipientPhone)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'พัสดุของฉัน',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.blue[700],
        foregroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          IconButton(
            onPressed: () {
              log('recipientPhoneL ${widget.recipientPhone}');
              log('recipientNameL ${widget.recipientName}');
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MapReceiver(
                    recipientPhone: widget.recipientPhone,
                    recipientName: widget.recipientName,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.map_outlined),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: _logout,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getReceiverOrdersStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 100,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'ยังไม่มีพัสดุ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'พัสดุของคุณจะแสดงที่นี่',
                    style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                  ),
                ],
              ),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index].data() as Map<String, dynamic>;
              final items = List<String>.from(order['items'] ?? []);
              final status = order['status'] ?? '-';
              final statusColor = _statusColorsMap[status] ?? Colors.grey;
              final senderName = order['senderName'] ?? '-';
              final orderImage = order['orderImage'];
              final statusImage = order['statusImageBase64'];

              // สร้าง widget สำหรับ status image
              Widget statusImageWidget = Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.image_outlined,
                  size: 30,
                  color: Colors.grey[400],
                ),
              );

              if (statusImage != null && statusImage.isNotEmpty) {
                try {
                  final statusImageBytes = base64Decode(statusImage);
                  statusImageWidget = Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(7),
                      child: Image.memory(statusImageBytes, fit: BoxFit.cover),
                    ),
                  );
                } catch (e) {
                  debugPrint('แสดง statusImage ไม่ได้: $e');
                }
              }

              // สร้าง widget สำหรับ order image
              Widget orderImageWidget = Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.inventory_2_outlined,
                  size: 40,
                  color: Colors.grey[400],
                ),
              );

              if (orderImage != null) {
                try {
                  String? base64String;
                  if (orderImage is Map && orderImage['imageBase64'] != null) {
                    base64String = orderImage['imageBase64'];
                  } else if (orderImage is String && orderImage.isNotEmpty) {
                    base64String = orderImage;
                  }

                  if (base64String != null && base64String.isNotEmpty) {
                    final imageBytes = base64Decode(base64String);
                    orderImageWidget = Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!, width: 1),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.memory(imageBytes, fit: BoxFit.cover),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('แสดง orderImage ไม่ได้: $e');
                }
              }

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey[200]!, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with status
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              status,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Order Image
                          orderImageWidget,
                          const SizedBox(width: 12),

                          // Info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'จาก:',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        senderName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'รายการสินค้า',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  items.join(", "),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[800],
                                    height: 1.4,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Footer with status image
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(12),
                          bottomRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'หลักฐานการส่ง',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
                          statusImageWidget,
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
