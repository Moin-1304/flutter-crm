import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

const Color tealGreen = Color(0xFF4db1b3);

/// A screen that shows the current location on a map and allows the user to confirm it.
/// The map is read-only (no dragging markers or picking other locations).
class LocationPickerMapScreen extends StatefulWidget {
  final Position initialPosition;

  const LocationPickerMapScreen({
    super.key,
    required this.initialPosition,
  });

  @override
  State<LocationPickerMapScreen> createState() => _LocationPickerMapScreenState();
}

class _LocationPickerMapScreenState extends State<LocationPickerMapScreen> {
  late LatLng _currentLatLng;
  final Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _currentLatLng = LatLng(
      widget.initialPosition.latitude,
      widget.initialPosition.longitude,
    );
    _markers.add(
      Marker(
        markerId: const MarkerId('current_location'),
        position: _currentLatLng,
        infoWindow: const InfoWindow(title: 'Current Location'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueCyan),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Confirm Location',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.withOpacity(0.1),
          ),
        ),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _currentLatLng,
              zoom: 16,
            ),
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapToolbarEnabled: false,
            // Disable interactions that might lead to changing location
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            scrollGesturesEnabled: true,
            zoomGesturesEnabled: true,
          ),
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: tealGreen.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.location_on, color: tealGreen, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Detected Current Location',
                                    style: GoogleFonts.inter(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.grey[900],
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'This location will be saved with your DCR.',
                                    style: GoogleFonts.inter(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _coordItem('Latitude', _currentLatLng.latitude),
                              Container(width: 1, height: 20, color: Colors.grey[300]),
                              _coordItem('Longitude', _currentLatLng.longitude),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop(widget.initialPosition);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: tealGreen,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: tealGreen.withOpacity(0.3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        'Use This Location',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _coordItem(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Colors.grey[500],
            letterSpacing: 0.5,
          ),
        ),
        Text(
          value.toStringAsFixed(6),
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[800],
            fontFeatures: [ui.FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }
}
