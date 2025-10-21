import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:location/location.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:developer';

class RiderMapPage extends StatefulWidget {
  final String orderId;
  final String riderId;
  final String riderName;

  const RiderMapPage({
    super.key,
    required this.riderName,
    required this.orderId,
    required this.riderId,
  });

  @override
  State<RiderMapPage> createState() => _RiderMapPageState();
}

class _RiderMapPageState extends State<RiderMapPage> {
  GoogleMapController? mapController;
  LatLng? riderLatLng;
  LatLng? pickupLatLng;
  LatLng? deliveryLatLng;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String currentStatus = '';
  bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    _listenOrder();
    _updateLocationPeriodically();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  void _listenOrder() {
    _firestore.collection('orders').doc(widget.orderId).snapshots().listen((doc) {
      final data = doc.data();
      if (data == null) return;

      pickupLatLng = _parseLatLng(data['recipientGps']);
      deliveryLatLng = _parseLatLng(data['recipientGps']); // สมมติที่อยู่ผู้รับเป็น delivery
      if (data['riderGps'] != null) riderLatLng = _parseLatLng(data['riderGps']);

      final newStatus = data['status'] ?? '';
      if (newStatus != currentStatus && !_isDisposed) {
        setState(() {
          currentStatus = newStatus;
        });
      }
    });
  }

  LatLng? _parseLatLng(String? gps) {
    if (gps == null || gps.isEmpty) return null;
    final parts = gps.split(',');
    if (parts.length != 2) return null;
    final lat = double.tryParse(parts[0].trim());
    final lng = double.tryParse(parts[1].trim());
    if (lat != null && lng != null) return LatLng(lat, lng);
    return null;
  }

  Future<void> _updateLocationPeriodically() async {
    Location location = Location();
    while (!_isDisposed) {
      await Future.delayed(const Duration(seconds: 5));
      if (_isDisposed) break;

      LocationData locData = await location.getLocation();
      String gps =
          '${locData.latitude?.toStringAsFixed(6)},${locData.longitude?.toStringAsFixed(6)}';
      await _firestore.collection('orders').doc(widget.orderId).update({
        'riderGps': gps,
      });
      if (!_isDisposed) {
        setState(() {
          riderLatLng = LatLng(locData.latitude ?? 0, locData.longitude ?? 0);
        });
      }
    }
  }

  Future<bool> _checkDistance(LatLng target, {double allowedDistance = 20}) async {
    if (riderLatLng == null) return false;
    double distance = Geolocator.distanceBetween(
      riderLatLng!.latitude,
      riderLatLng!.longitude,
      target.latitude,
      target.longitude,
    );
    return distance <= allowedDistance;
  }

  Future<void> _takePhotoAndUpdateStatus(String newStatus) async {
    if ((newStatus == 'ไรเดอร์รับสินค้าแล้วและกำลังเดินทางไปส่ง' ||
            newStatus == 'ส่งสินค้าแล้ว') &&
        deliveryLatLng == null) return;

    // สำหรับ status 4 (ส่งสินค้าแล้ว) ตรวจสอบระยะก่อน
    if (newStatus == 'ส่งสินค้าแล้ว' && !(await _checkDistance(deliveryLatLng!))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('คุณยังอยู่ห่างเกิน 20 เมตร')),
      );
      return;
    }

    final picker = ImagePicker();
    final XFile? imageFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 70,
    );
    if (imageFile == null) return;

    final bytes = await File(imageFile.path).readAsBytes();
    final base64Image = base64Encode(bytes);

    await _firestore.collection('orders').doc(widget.orderId).update({
      'status': newStatus,
      'statusImageBase64': base64Image,
      'deliveredAt':
          newStatus == 'ส่งสินค้าแล้ว' ? FieldValue.serverTimestamp() : null,
    });

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('อัปเดตสถานะเรียบร้อย')));

    // ถ้า status เป็นส่งสินค้าแล้ว กลับหน้า HomePageRider
    if (newStatus == 'ส่งสินค้าแล้ว' && mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text('นำส่งสินค้า'),
        backgroundColor: Colors.orange,
      ),
      body: riderLatLng == null
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: riderLatLng!,
                zoom: 16,
              ),
              markers: {
                if (riderLatLng != null)
                  Marker(
                    markerId: const MarkerId('rider'),
                    position: riderLatLng!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                    infoWindow: InfoWindow(title: 'Rider: ${widget.riderName}'),
                  ),
                if (deliveryLatLng != null)
                  Marker(
                    markerId: const MarkerId('delivery'),
                    position: deliveryLatLng!,
                    icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
                    infoWindow: const InfoWindow(title: 'ตำแหน่งส่งสินค้า'),
                  ),
              },
              onMapCreated: (controller) => mapController = controller,
            ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (currentStatus == 'ไรเดอร์รับงาน')
            FloatingActionButton.extended(
              heroTag: 'status3',
              onPressed: () =>
                  _takePhotoAndUpdateStatus('ไรเดอร์รับสินค้าแล้วและกำลังเดินทางไปส่ง'),
              label: const Text('รับสินค้าแล้ว (ถ่ายรูป)'),
              icon: const Icon(Icons.camera_alt),
              backgroundColor: Colors.orange,
            ),
          if (currentStatus == 'ไรเดอร์รับสินค้าแล้วและกำลังเดินทางไปส่ง')
            FloatingActionButton.extended(
              heroTag: 'status4',
              onPressed: () => _takePhotoAndUpdateStatus('ส่งสินค้าแล้ว'),
              label: const Text('ส่งสินค้าแล้ว (ถ่ายรูป)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),),
              icon: const Icon(Icons.done, color: Colors.white, fontWeight: FontWeight.bold,),
              backgroundColor: Colors.orange,
            ),
        ],
      ),
    );
  }
}
