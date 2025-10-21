import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery1/page/rider/rider_order_map.dart';
import 'package:location/location.dart';
import 'dart:developer';

class HomePageRider extends StatefulWidget {
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
  State<HomePageRider> createState() => _HomePageRiderState();
}

class _HomePageRiderState extends State<HomePageRider>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    log('Rider ${widget.riderId} - ${widget.riderName} logged in');
  }

  Future<void> _acceptOrder(Map<String, dynamic> order, String orderId) async {
    try {
      // ตรวจสอบว่ามีงานที่ยังไม่เสร็จอยู่ไหม
      final existingOrder = await _firestore
          .collection('orders')
          .where('riderId', isEqualTo: widget.riderId)
          .where(
            'status',
            whereIn: [
              'ไรเดอร์รับงาน',
              'ไรเดอร์รับสินค้าแล้วและกำลังเดินทางไปส่ง',
            ],
          )
          .get();

      if (existingOrder.docs.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('คุณยังมีงานอยู่ ไม่สามารถรับงานใหม่ได้'),
          ),
        );
        return;
      }

      // 🔹 ดึงตำแหน่งปัจจุบันของไรเดอร์
      Location location = Location();
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return;
      }

      PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != PermissionStatus.granted) return;
      }

      LocationData locData = await location.getLocation();
      String riderGps =
          '${locData.latitude?.toStringAsFixed(6)},${locData.longitude?.toStringAsFixed(6)}';

      // อัปเดตสถานะและ Rider ข้อมูลลง Firestore
      log('Order $orderId accepted by rider ${widget.riderId}');
      await _firestore.collection('orders').doc(orderId).update({
        'status': 'ไรเดอร์รับงาน',
        'riderId': widget.riderId,
        'riderName': widget.riderName,
        'riderEmail': widget.riderEmail,
        'riderGps': riderGps,
        'acceptedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('รับงานสำเร็จ!')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    }
  }

  Widget _buildOrderList(List<String> statuses) {
    Query query = _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true);

    if (statuses.contains('รอไรเดอร์มารับสินค้า')) {
      // แสดงงานที่ยังไม่มี Rider
      query = query.where('status', isEqualTo: 'รอไรเดอร์มารับสินค้า');
      // .where('riderId', isEqualTo: ''); // Rider ยังไม่รับ
    } else {
      // แสดงงานของ Rider คนนี้
      query = query
          .where('status', whereIn: statuses)
          .where('riderId', isEqualTo: widget.riderId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('ยังไม่มีงานในหมวดนี้'));
        }

        final orders = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          final rider = data['riderId'] as String?;
          if (statuses.contains('รอไรเดอร์มารับสินค้า')) {
            // กรองงานที่ยังไม่มี Rider รับ
            return status == 'รอไรเดอร์มารับสินค้า' &&
                (rider == null || rider == '');
          } else {
            // งานของ Rider คนนี้
            return statuses.contains(status) && rider == widget.riderId;
          }
        }).toList();

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: orders.length,
          itemBuilder: (context, index) {
            final order = orders[index].data() as Map<String, dynamic>;
            final orderId = orders[index].id;

            final recipient = order['recipientName'] ?? '-';
            final address = order['recipientAddress'] ?? '-';
            final phone = order['recipientPhone'] ?? '-';
            final items = (order['items'] as List?)?.join(', ') ?? '-';
            final price = order['price']?.toString() ?? '0';
            final createdAt = (order['createdAt'] as Timestamp?)?.toDate();

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 6),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ราคา + วันที่สร้าง
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '฿$price',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      if (createdAt != null)
                        Text(
                          '🕒 ${createdAt.toLocal()}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('📦 สินค้า: $items'),
                  Text('👤 ผู้รับ: $recipient'),
                  Text('📍 ที่อยู่: $address'),
                  Text('📞 โทร: $phone'),
                  const SizedBox(height: 12),

                  // ปุ่ม
                  if (order['status'] == 'รอไรเดอร์มารับสินค้า')
                    ElevatedButton(
                      onPressed: () => _acceptOrder(order, orderId),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                      child: const Text(
                        'รับงานนี้',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => RiderMapPage(
                              orderId: orderId,
                              riderId: widget.riderId,
                              riderName: widget.riderName,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.map, color: Colors.white),
                      label: const Text(
                        'ดูแผนที่ / ถ่ายรูป',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 16,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text(
          'จัดการงานไรเดอร์',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.orange,
        bottom: TabBar(
          labelColor: Colors.white,
          controller: _tabController,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(text: '🕒 งานรอรับ'),
            Tab(text: '🚚 งานที่รับแล้ว'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOrderList(['รอไรเดอร์มารับสินค้า']),
          _buildOrderList([
            'ไรเดอร์รับงาน',
            'ไรเดอร์รับสินค้าแล้วและกำลังเดินทางไปส่ง',
          ]),
        ],
      ),
    );
  }
}
