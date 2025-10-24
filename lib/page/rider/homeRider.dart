import 'dart:convert';
import 'dart:developer';
import 'package:delivery1/page/LandingPage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:delivery1/page/rider/rider_order_map.dart';
import 'package:location/location.dart';

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
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('คุณยังมีงานอยู่ ไม่สามารถรับงานใหม่ได้')),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        return;
      }

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Text('รับงานสำเร็จ!'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text('เกิดข้อผิดพลาด: $e')),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

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

  Widget _buildOrderList(List<String> statuses) {
    Query query = _firestore
        .collection('orders')
        .orderBy('createdAt', descending: true);

    if (statuses.contains('รอไรเดอร์มารับสินค้า')) {
      query = query.where('status', isEqualTo: 'รอไรเดอร์มารับสินค้า');
    } else {
      query = query
          .where('status', whereIn: statuses)
          .where('riderId', isEqualTo: widget.riderId);
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
                const SizedBox(height: 16),
                Text(
                  'เกิดข้อผิดพลาด',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 8),
                Text(
                  '${snapshot.error}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.orange.shade600),
                const SizedBox(height: 16),
                Text(
                  'กำลังโหลดข้อมูล...',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 80,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  'ยังไม่มีงานในหมวดนี้',
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
              ],
            ),
          );
        }

        final orders = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String?;
          final rider = data['riderId'] as String?;
          if (statuses.contains('รอไรเดอร์มารับสินค้า')) {
            return status == 'รอไรเดอร์มารับสินค้า' &&
                (rider == null || rider == '');
          } else {
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
            final status = order['status'] ?? 'ไม่ทราบสถานะ';
            final createdAt = (order['createdAt'] as Timestamp?)?.toDate();
            final orderImage = order['orderImage'];

            Widget statusImageWidget = const SizedBox.shrink();
            if (orderImage != null &&
                orderImage is String &&
                orderImage.isNotEmpty) {
              try {
                final decodedBytes = base64Decode(orderImage);
                statusImageWidget = ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    decodedBytes,
                    width: double.infinity,
                    height: 180,
                    fit: BoxFit.cover,
                  ),
                );
              } catch (e) {
                statusImageWidget = Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 48,
                      color: Colors.red.shade300,
                    ),
                  ),
                );
              }
            }

            return Card(
              elevation: 3,
              shadowColor: Colors.black.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              margin: const EdgeInsets.only(bottom: 16),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white,
                      Colors.orange.shade50.withOpacity(0.3),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // รูปภาพสถานะ
                      if (orderImage != null &&
                          orderImage is String &&
                          orderImage.isNotEmpty)
                        Column(
                          children: [
                            statusImageWidget,
                            const SizedBox(height: 16),
                          ],
                        ),

                      // หัวข้อ - ชื่อผู้รับ & เวลา
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.shade100,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: Colors.orange.shade700,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    recipient,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (createdAt != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${createdAt.day}/${createdAt.month} ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ข้อมูลสินค้า
                      _buildInfoRow(
                        Icons.inventory_2_outlined,
                        'สินค้า',
                        items,
                        Colors.blue,
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        Icons.location_on_outlined,
                        'ที่อยู่',
                        address,
                        Colors.red,
                      ),
                      const SizedBox(height: 10),
                      _buildInfoRow(
                        Icons.phone_outlined,
                        'โทรศัพท์',
                        phone,
                        Colors.green,
                      ),
                      const SizedBox(height: 16),

                      // ปุ่มดำเนินการ
                      if (order['status'] == 'รอไรเดอร์มารับสินค้า')
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _acceptOrder(order, orderId),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_outline, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'รับงานนี้',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.shade600,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.map_outlined, size: 22),
                                SizedBox(width: 8),
                                Text(
                                  'ดูแผนที่ / ถ่ายรูป',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color color) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        foregroundColor: Colors.white,
        title: const Text(
          'จัดการงานไรเดอร์',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        backgroundColor: Colors.orange.shade600,
        elevation: 0,

        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ออกจากระบบ',
            onPressed: _logout,
          ),
        ],

        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: Colors.orange.shade600,
            child: TabBar(
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.access_time_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('งานรอรับ'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.local_shipping_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('งานที่รับแล้ว'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildOrderList(['รอไรเดอร์มารับสินค้า']),
            _buildOrderList([
              'ไรเดอร์รับงาน',
              'ไรเดอร์รับสินค้าแล้วและกำลังเดินทางไปส่ง',
            ]),
          ],
        ),
      ),
    );
  }
}
