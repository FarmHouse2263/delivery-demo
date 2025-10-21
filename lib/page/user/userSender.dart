import 'dart:convert';
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

  // 🟦 กำหนดสีสถานะไว้ที่ด้านบน
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
  backgroundColor: Colors.blue[700],

  // ✅ เพิ่มปุ่มดูแผนที่ด้านขวา
  actions: [
    IconButton(
      icon: const Icon(Icons.map_outlined),
      tooltip: 'ดูแผนที่',
      onPressed: () {
        // ตรวจสอบสถานะของรายการล่าสุด
        _firestore
            .collection('orders')
            .where('senderId', isEqualTo: widget.senderId)
            .orderBy('createdAt', descending: true)
            .limit(1) // เอารายการล่าสุด
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
                    'ยังไม่สามารถเปิดแผนที่ได้ เนื่องจากยังไม่มีไรเดอร์รับงาน'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => MapPage(),
              ),
            );
          }
        });
      },
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

              Widget imageWidget = const Icon(
                Icons.inventory_2_outlined,
                size: 70,
                color: Colors.grey,
              );

              if (data['orderImage'] != null &&
                  data['orderImage']['imageBase64'] != null) {
                try {
                  final imageBytes = base64Decode(
                    data['orderImage']['imageBase64'],
                  );
                  imageWidget = ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      imageBytes,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    ),
                  );
                } catch (_) {}
              }

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
                      imageWidget,
                      const SizedBox(height: 12),
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
                      const SizedBox(height: 10),

                      // ✅ ปุ่มดูแผนที่ (กดได้เฉพาะเมื่อไรเดอร์รับงานแล้ว)
                      // ElevatedButton.icon(
                      //   icon: const Icon(Icons.map_outlined),
                      //   label: const Text('ดูแผนที่'),
                      //   style: ElevatedButton.styleFrom(
                      //     backgroundColor: Colors.blue[700],
                      //     foregroundColor: Colors.white,
                      //   ),
                      //   onPressed: () {
                      //     if (status == 'รอไรเดอร์มารับสินค้า') {
                      //       ScaffoldMessenger.of(context).showSnackBar(
                      //         const SnackBar(
                      //           content: Text(
                      //               'ยังไม่สามารถเปิดแผนที่ได้ เนื่องจากยังไม่มีไรเดอร์รับงาน'),
                      //           backgroundColor: Colors.orange,
                      //           behavior: SnackBarBehavior.floating,
                      //         ),
                      //       );
                      //     } else {
                      //       Navigator.push(
                      //         context,
                      //         MaterialPageRoute(
                      //           builder: (context) => MapPage(),
                      //         ),
                      //       );
                      //     }
                      //   },
                      // ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.blue[700],
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
