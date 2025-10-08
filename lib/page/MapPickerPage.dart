// หน้าแสดง Map
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
class MapPickerPage extends StatefulWidget {
  const MapPickerPage({super.key});

  @override
  State<MapPickerPage> createState() => _MapPickerPageState();
}

class _MapPickerPageState extends State<MapPickerPage> {
  LatLng? selectedPosition;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("เลือกตำแหน่งบนแผนที่")),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(13.7563, 100.5018), // Bangkok default
          zoom: 14,
        ),
        onTap: (LatLng pos) {
          setState(() {
            selectedPosition = pos;
          });
        },
        markers: selectedPosition != null
            ? {
                Marker(
                  markerId: const MarkerId("selected"),
                  position: selectedPosition!,
                ),
              }
            : {},
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (selectedPosition != null) {
            Navigator.pop(context, selectedPosition);
          }
        },
        child: const Icon(Icons.check),
      ),
    );
  }
}
