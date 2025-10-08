import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'create_order.dart';

class UserSender extends StatefulWidget {
  final String senderId;
  final String senderName;

  const UserSender({
    super.key,
    required this.senderId,
    required this.senderName,
  });

  @override
  State<UserSender> createState() => _UserSenderState();
}

class _UserSenderState extends State<UserSender> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // สีตามสถานะ
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
      appBar: AppBar(
        title: Text(
          'ผู้ส่งสินค้า: ${widget.senderName}',
          style: const TextStyle(color: Colors.white),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue[700],
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => Navigator.pop(context),
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
            return const Center(child: Text('ยังไม่มีรายการส่งสินค้า'));
          }

          final orders = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              final items = List<String>.from(order['items']);
              final createdAt = (order['createdAt'] as Timestamp?)?.toDate();
              final status = order['status'] as String;
              final statusColor = statusColorMap[status] ?? Colors.grey;

              // 🔹 แปลง Base64 เป็น Image
              Widget orderImageWidget = const SizedBox();
              if (order['orderImage'] != null && order['orderImage']['imageBase64'] != null) {
                try {
                  final imageBytes = base64Decode(order['orderImage']['imageBase64']);
                  orderImageWidget = Image.memory(
                    imageBytes,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                  );
                } catch (e) {
                  orderImageWidget = const Icon(Icons.broken_image, size: 80, color: Colors.grey);
                }
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 4,
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: orderImageWidget,
                  ),
                  title: Text('ผู้รับ: ${order['recipientName']}'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('📦 สินค้า: ${items.join(', ')}'),
                      Text('📞 โทร: ${order['recipientPhone']}'),
                      Text('📍 ที่อยู่: ${order['recipientAddress']}'),
                      if (createdAt != null)
                        Text('🕐 วันที่สร้าง: ${createdAt.toLocal()}'),
                    ],
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: statusColor),
                    ),
                    child: Text(
                      status,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  onTap: () {
                    // 👉 ไปหน้าแผนที่/รายละเอียดเพิ่มเติมในอนาคต
                  },
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
