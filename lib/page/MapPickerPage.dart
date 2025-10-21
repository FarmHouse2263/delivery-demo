import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  GoogleMapController? mapController;
  LatLng? selectedPosition;

  @override
  void initState() {
    super.initState();
    _setCurrentLocation(); // โหลดพิกัดปัจจุบันอัตโนมัติ
  }

  Future<void> _setCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) return;

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    setState(() {
      selectedPosition = LatLng(position.latitude, position.longitude);
    });

    mapController?.animateCamera(
      CameraUpdate.newLatLngZoom(selectedPosition!, 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("เลือกตำแหน่งบนแผนที่")),
      body: GoogleMap(
        onMapCreated: (controller) => mapController = controller,
        initialCameraPosition: const CameraPosition(
          target: LatLng(13.7563, 100.5018), // Bangkok default
          zoom: 14,
        ),
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        markers: selectedPosition != null
            ? {
                Marker(
                  markerId: const MarkerId("selected"),
                  position: selectedPosition!,
                  infoWindow: const InfoWindow(title: "ตำแหน่งที่เลือก"),
                  icon: BitmapDescriptor.defaultMarkerWithHue(
                      BitmapDescriptor.hueAzure),
                ),
              }
            : {},
        onTap: (pos) {
          setState(() {
            selectedPosition = pos;
          });
        },
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // ปุ่มยืนยันตำแหน่ง
          FloatingActionButton(
            heroTag: "confirm",
            onPressed: () {
              if (selectedPosition != null) {
                Navigator.pop(context, selectedPosition);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("โปรดเลือกตำแหน่งก่อน")),
                );
              }
            },
            child: const Icon(Icons.check),
          ),
          const SizedBox(height: 10),
          // ปุ่มไปยังตำแหน่งปัจจุบัน
          FloatingActionButton(
            heroTag: "current",
            onPressed: _setCurrentLocation,
            backgroundColor: Colors.green,
            child: const Icon(Icons.my_location),
          ),
        ],
      ),
    );
  }
}
