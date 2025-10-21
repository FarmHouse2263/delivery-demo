import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  GoogleMapController? mapController;
  Map<String, Marker> markers = {}; // เก็บ Marker ของ Rider & Recipient
  LatLng initialPosition = const LatLng(13.7563, 100.5018); // กรุงเทพฯ

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  /// โหลดข้อมูล order ทั้งหมดจาก Firestore
  /// โหลดข้อมูล order ทั้งหมดจาก Firestore
  Future<void> _loadOrders() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('orders')
          .get();

      Map<String, Marker> loadedMarkers = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>?; // ✅ null-safe
        if (data == null) continue;

        final status = data['status'] as String? ?? '';

        // ถ้า order ส่งสินค้าแล้ว ให้ข้าม ไม่สร้าง Marker ของ Rider และ Recipient
        if (status == 'ส่งสินค้าแล้ว') continue;

        // 🔹 ผู้รับ
        final recipientGps = data['recipientGps'] as String?;
        final recipientName =
            data['recipientName'] as String? ?? 'ไม่ทราบชื่อผู้รับ';
        if (recipientGps != null && recipientGps.contains(',')) {
          final parts = recipientGps.split(',');
          final lat = double.tryParse(parts[0].trim());
          final lng = double.tryParse(parts[1].trim());
          if (lat != null && lng != null) {
            loadedMarkers['recipient_${doc.id}'] = Marker(
              markerId: MarkerId('recipient_${doc.id}'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: '📦 ผู้รับ: $recipientName',
                snippet: data['recipientAddress'] as String? ?? '',
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueBlue,
              ),
            );
          }
        }

        // 🔹 ไรเดอร์
        final riderGps = data['riderGps'] as String?;
        final riderId = data['riderId'] as String? ?? doc.id;
        final riderName = data['riderName'] as String? ?? 'ไม่ทราบชื่อไรเดอร์';
        if (riderGps != null && riderGps.contains(',')) {
          final parts = riderGps.split(',');
          final lat = double.tryParse(parts[0].trim());
          final lng = double.tryParse(parts[1].trim());
          if (lat != null && lng != null) {
            loadedMarkers['rider_$riderId'] = Marker(
              markerId: MarkerId('rider_$riderId'),
              position: LatLng(lat, lng),
              infoWindow: InfoWindow(
                title: '🛵 ไรเดอร์: $riderName',
                snippet: status,
              ),
              icon: BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueOrange,
              ),
            );
          }
        }
      }

      setState(() {
        markers = loadedMarkers;
      });
    } catch (e) {
      debugPrint("โหลดข้อมูล order ผิดพลาด: $e");
    }
  }

  /// ฟังก์ชันเลื่อนไปยังตำแหน่งที่เลือก
  void _goToLocation(double lat, double lng) {
    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: LatLng(lat, lng), zoom: 15),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text(
          'แผนที่แสดงผู้รับและไรเดอร์',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
            style: IconButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: (controller) => mapController = controller,
            initialCameraPosition: CameraPosition(
              target: initialPosition,
              zoom: 12,
            ),
            markers: markers.values.toSet(),
          ),

          // 🔹 ปุ่มเลื่อนไปยัง Rider แต่ละคน
          Positioned(
            bottom: 20,
            left: 10,
            right: 10,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                final orders = snapshot.data!.docs;

                // Map ของ riderId -> latest order (ไม่เอา status ส่งสินค้าแล้ว)
                // Map ของ riderId -> latest order (ไม่เอา order ที่ส่งสินค้าแล้ว)
                Map<String, Map<String, dynamic>> riderMap = {};
                for (var doc in orders) {
                  final data = doc.data() as Map<String, dynamic>?;
                  if (data == null) continue;
                  final riderId = data['riderId'] as String?;
                  final status = data['status'] as String? ?? '';
                  if (riderId != null && status != 'ส่งสินค้าแล้ว')
                    riderMap[riderId] = data;
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: riderMap.entries.map((entry) {
                      final data = entry.value;
                      final name =
                          data['riderName'] as String? ?? 'ไม่ทราบชื่อ';
                      final gps = data['riderGps'] as String?;
                      if (gps == null || !gps.contains(','))
                        return const SizedBox();
                      final parts = gps.split(',');
                      final lat = double.tryParse(parts[0].trim());
                      final lng = double.tryParse(parts[1].trim());
                      if (lat == null || lng == null) return const SizedBox();

                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.location_pin),
                          label: Text(name),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => _goToLocation(lat, lng),
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
