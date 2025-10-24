import 'dart:convert';
import 'package:delivery1/page/LandingPage.dart';
import 'package:delivery1/page/user/SelectReceiverPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_order.dart';
import 'map_sender.dart';

class UserSender extends StatefulWidget {
  final String senderId;
  final String senderName;
  final String senderEmail;

  const UserSender({
    super.key,
    required this.senderId,
    required this.senderName,
    required this.senderEmail,
  });

  @override
  State<UserSender> createState() => _UserSenderState();
}

class _UserSenderState extends State<UserSender> {
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

  // สีของสถานะ
  final Map<String, Color> statusColorMap = {
    'รอไรเดอร์มารับสินค้า': Colors.orange,
    'ไรเดอร์รับงาน': Colors.blue,
    'ไรเดอร์รับสินค้าแล้ว': Colors.purple,
    'ส่งแล้ว': Colors.green,
    'ยกเลิก': Colors.red,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        foregroundColor: Colors.white,
        elevation: 2,
        title: Text(
          'รายการส่งของ: ${widget.senderName}',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        actions: [
          IconButton(
            icon: const Icon(Icons.map_outlined),
            tooltip: 'ดูแผนที่',
            onPressed: () {
              _firestore
                  .collection('orders')
                  .where('senderId', isEqualTo: widget.senderId)
                  .orderBy('createdAt', descending: true)
                  .limit(1)
                  .get()
                  .then((snapshot) {
                    if (snapshot.docs.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ยังไม่มีรายการส่งสินค้า'),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    final data =
                        snapshot.docs.first.data() as Map<String, dynamic>;
                    final status = data['status'] as String;

                    if (status == 'รอไรเดอร์มารับสินค้า') {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'ยังไม่มีไรเดอร์รับงาน ไม่สามารถเปิดแผนที่ได้',
                          ),
                          backgroundColor: Colors.orange,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MapPage()),
                      );
                    }
                  });
            },
          ),

          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: _logout,
          ),
        ],

      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('orders')
            .where('senderId', isEqualTo: widget.senderId)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'ยังไม่มีรายการส่งสินค้า',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final data = order.data() as Map<String, dynamic>;
              final items = List<String>.from(data['items']);
              final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
              final status = data['status'] as String;
              final statusColor = statusColorMap[status] ?? Colors.grey;

              // ---------- โหลดรูปสินค้า ----------
              Widget orderImageWidget = const Icon(
                Icons.inventory_2_outlined,
                size: 70,
                color: Colors.grey,
              );

              final orderImage = data['orderImage'];
              if (orderImage != null) {
                try {
                  String? base64String;

                  if (orderImage is Map && orderImage['imageBase64'] != null) {
                    base64String = orderImage['imageBase64'];
                  } else if (orderImage is String) {
                    if (orderImage.contains('{')) {
                      final decoded = jsonDecode(orderImage);
                      base64String = decoded['imageBase64'];
                    } else {
                      base64String = orderImage;
                    }
                  }

                  if (base64String != null && base64String.isNotEmpty) {
                    final imageBytes = base64Decode(base64String);
                    orderImageWidget = ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        imageBytes,
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('❌ ไม่สามารถแสดงรูป orderImage ได้: $e');
                }
              }

              // ---------- โหลดรูปสถานะจากไรเดอร์ ----------
              Widget? statusImageWidget;
              final statusImage = data['statusImageBase64'];
              if (statusImage != null) {
                try {
                  String? base64Status;

                  if (statusImage is Map &&
                      statusImage['imageBase64'] != null) {
                    base64Status = statusImage['imageBase64'];
                  } else if (statusImage is String) {
                    if (statusImage.contains('{')) {
                      final decoded = jsonDecode(statusImage);
                      base64Status = decoded['imageBase64'];
                    } else {
                      base64Status = statusImage;
                    }
                  }

                  if (base64Status != null && base64Status.isNotEmpty) {
                    final imageBytes = base64Decode(base64Status);
                    statusImageWidget = ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(
                        imageBytes,
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('❌ ไม่สามารถแสดงรูปสถานะได้: $e');
                }
              }

              // ---------- สร้าง UI ----------
              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      orderImageWidget,
                      const SizedBox(height: 10),

                      Text(
                        'ผู้รับ: ${data['recipientName']}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: statusColor),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),

                      if (statusImageWidget != null) ...[
                        const SizedBox(height: 12),
                        const Text(
                          '📸 รูปประกอบสถานะ',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        statusImageWidget,
                      ],

                      const SizedBox(height: 12),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('📦 สินค้า: ${items.join(', ')}'),
                          Text('📞 โทร: ${data['recipientPhone']}'),
                          Text(
                            '📍 ที่อยู่: ${data['recipientAddress']}',
                            softWrap: true,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (createdAt != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                '🕐 วันที่สร้าง: ${createdAt.toLocal().toString().substring(0, 19)}',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blue,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'สร้างรายการส่ง',
          style: TextStyle(color: Colors.white),
        ),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => CreateOrder(
                senderId: widget.senderId,
                senderName: widget.senderName,
              ),
            ),
          );
        },
      ),
    );
  }
}
