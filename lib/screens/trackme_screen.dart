import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:share_plus/share_plus.dart';

class TrackMeScreen extends StatefulWidget {
  const TrackMeScreen({super.key});

  @override
  State<TrackMeScreen> createState() => _TrackMeScreenState();
}

class _TrackMeScreenState extends State<TrackMeScreen> {
//  GoogleMapController? _mapController;
  LatLng? _currentPosition;
  Location location = Location();

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  // 🔐 Get Current Location
  Future<void> _getCurrentLocation() async {
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

    final locData = await location.getLocation();

    setState(() {
      _currentPosition =
          LatLng(locData.latitude!, locData.longitude!);
    });
  }

  void _onMapCreated(GoogleMapController controller) {
//    _mapController = controller;
  }

  // 📤 Share Live Location
  Future<void> _shareLiveLocation() async {
    await _getCurrentLocation();

    if (_currentPosition == null) return;

    final lat = _currentPosition!.latitude;
    final lng = _currentPosition!.longitude;

    final googleMapsUrl =
        "https://www.google.com/maps/search/?api=1&query=$lat,$lng";

    Share.share("🚨 Emergency! This is my live location:\n$googleMapsUrl");
  }

  Set<Marker> _createMarkers() {
    if (_currentPosition == null) return {};

    return {
      Marker(
        markerId: const MarkerId("current"),
        position: _currentPosition!,
        infoWindow:
            const InfoWindow(title: "You are here"),
        icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure),
      )
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101D68),
      body: Stack(
        children: [
          // 🗺 Map
          if (_currentPosition != null)
            GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(
                target: _currentPosition!,
                zoom: 16,
              ),
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              markers: _createMarkers(),
            )
          else
            const Center(
              child: CircularProgressIndicator(
                  color: Colors.white),
            ),

          // 📍 Share Button
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: ElevatedButton.icon(
              onPressed: _shareLiveLocation,
              icon: const Icon(Icons.share,
                  color: Colors.white),
              label: const Text(
                "Share Live Location",
                style: TextStyle(fontSize: 16),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding:
                    const EdgeInsets.symmetric(
                        vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}