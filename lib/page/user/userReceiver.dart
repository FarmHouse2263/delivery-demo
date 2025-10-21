import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class UserReceiver extends StatefulWidget {
  final String recipientPhone; // เบอร์โทรผู้ใช้ที่ login
  final String? recipientName; // ชื่อผู้ใช้

  const UserReceiver({
    super.key,
    required this.recipientPhone,
    required this.recipientName,
  });

  @override
  State<UserReceiver> createState() => _UserReceiverState();
}

class _UserReceiverState extends State<UserReceiver> {
  String? profileUrl;
  bool isLoading = true;
  GoogleMapController? mapController;
  Set<Marker> markers = {};

  LatLng? recipientLatLng;
  Map<String, Marker> riderMarkers = {}; // รักษา Marker ของ Rider แต่ละคน

  @override
  void initState() {
    super.initState();
    fetchUserProfile();
  }

  Future<void> fetchUserProfile() async {
    try {
      QuerySnapshot userSnap = await FirebaseFirestore.instance
          .collection('users')
          .where(
            'phone_number',
            isEqualTo:
                widget.recipientPhone.replaceAll(RegExp(r'\D'), '').trim(),
          )
          .get();

      if (userSnap.docs.isNotEmpty) {
        var userData = userSnap.docs.first.data() as Map<String, dynamic>;
        String? profilePath = userData['profile_path'];
        String? downloadUrl;

        if (profilePath != null && profilePath.isNotEmpty) {
          downloadUrl =
              await FirebaseStorage.instance.ref(profilePath).getDownloadURL();
        }

        setState(() {
          profileUrl = downloadUrl;
          isLoading = false;
        });
      } else {
        log("ไม่มีข้อมูลผู้ใช้เบอร์นี้");
        setState(() => isLoading = false);
      }
    } catch (e) {
      log("Error fetching profile: $e");
      setState(() => isLoading = false);
    }
  }

  LatLng? parseLatLng(String? gps) {
    if (gps == null || gps.isEmpty) return null;
    try {
      var parts = gps.split(',');
      if (parts.length != 2) return null;
      double? lat = double.tryParse(parts[0].trim());
      double? lng = double.tryParse(parts[1].trim());
      if (lat != null && lng != null) return LatLng(lat, lng);
    } catch (e) {
      log("Error parsing GPS: $e");
    }
    return null;
  }

  void moveCamera(LatLng target) {
    if (mapController != null) {
      mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 16),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String displayName = widget.recipientName ?? 'ผู้ใช้';

    return Scaffold(
      appBar: AppBar(
        foregroundColor: Colors.white,
        title: const Text("แผนที่ผู้รับ", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('recipientPhone',
                      isEqualTo: widget.recipientPhone.trim())
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final orders = snapshot.data!.docs;
                markers.clear(); // ล้าง Marker ก่อนอัปเดต
                riderMarkers.clear();

                LatLng initialPosition = const LatLng(13.7563, 100.5018);
                bool addedRecipientMarker = false;

                for (var order in orders) {
                  var data = order.data() as Map<String, dynamic>? ?? {};
                  if (data.isEmpty) continue;

                  // เพิ่ม Marker ผู้รับแค่ครั้งเดียว
                  if (!addedRecipientMarker && data['recipientGps'] != null) {
                    recipientLatLng = parseLatLng(data['recipientGps']);
                    if (recipientLatLng != null) {
                      markers.add(
                        Marker(
                          markerId: const MarkerId('recipient'),
                          position: recipientLatLng!,
                          infoWindow: InfoWindow(
                            title: data['recipientName'] ?? 'ผู้รับ',
                            snippet: 'เบอร์: ${data['recipientPhone']}',
                          ),
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueBlue),
                        ),
                      );
                      initialPosition = recipientLatLng!;
                      addedRecipientMarker = true;
                    }
                  }

                  // เพิ่ม Marker Rider ของ order ตัวเอง (status รับหรือกำลังส่ง)
                  if ((data['status'] == "ไรเดอร์รับสินค้าแล้ว" ||
                          data['status'] == "ไรเดอร์รับสินค้าแล้วและกำลังเดินทางไปส่ง") &&
                      data['riderGps'] != null &&
                      data['riderId'] != null) {
                    String riderId = data['riderId'];
                    LatLng? riderPos = parseLatLng(data['riderGps']);
                    if (riderPos != null) {
                      riderMarkers[riderId] = Marker(
                        markerId: MarkerId('rider_$riderId'),
                        position: riderPos,
                        infoWindow: InfoWindow(
                          title: data['riderName'] ?? 'ไรเดอร์',
                          snippet: 'สถานะ: ${data['status']}',
                        ),
                        icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueOrange),
                      );
                    }
                  }
                }

                // รวม Marker ผู้รับ + Rider
                markers.addAll(riderMarkers.values);

                return Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition:
                          CameraPosition(target: initialPosition, zoom: 14),
                      markers: markers,
                      onMapCreated: (controller) => mapController = controller,
                    ),

                    // แถบชื่อและปุ่มดูไรเดอร์
                    Positioned(
                      top: 10,
                      left: 10,
                      right: 10,
                      child: Card(
                        elevation: 5,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 25,
                                    backgroundColor: Colors.grey[200],
                                    backgroundImage: profileUrl != null
                                        ? NetworkImage(profileUrl!)
                                        : null,
                                    child: profileUrl == null
                                        ? const Icon(Icons.person)
                                        : null,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      "สวัสดี $displayName",
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              if (riderMarkers.isNotEmpty) ...[
                                const Divider(),
                                const Text(
                                  "ดูตำแหน่งไรเดอร์:",
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Wrap(
                                  children: riderMarkers.entries
                                      .map(
                                        (e) => Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: ElevatedButton.icon(
                                            onPressed: () => moveCamera(
                                                e.value.position),
                                            icon: const Icon(
                                                Icons.delivery_dining),
                                            label: Text(
                                                e.key.substring(0, 6)), // แสดง ID สั้นๆ
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
