import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:math' as _m;

class MapPickerScreen extends StatefulWidget {
  const MapPickerScreen({super.key, required this.initial, this.title, this.limitTo1KmDefault = false});
  final LatLng initial;
  final String? title;
  final bool limitTo1KmDefault;

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  GoogleMapController? _controller;
  LatLng? _selected;
  bool _limitTo1Km = false;
  late LatLng _limitCenter;
  static const double _radiusMeters = 1000.0;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
    _limitCenter = widget.initial;
    _limitTo1Km = widget.limitTo1KmDefault;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const Color tealGreen = Color(0xFF4db1b3);
    final LatLng center = _selected ?? widget.initial;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: tealGreen,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          widget.title ?? 'Pick location',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop<LatLng>(context, _selected),
            child: const Text('USE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(target: center, zoom: 15),
              onMapCreated: (c) => _controller = c,
              onTap: (pos) {
                if (_limitTo1Km && _distanceMeters(_limitCenter, pos) > _radiusMeters) {
                  _showSnack('Please pick within 1 km');
                  return;
                }
                setState(() => _selected = pos);
              },
              myLocationEnabled: false,
              zoomControlsEnabled: true,
              circles: _limitTo1Km
                  ? {
                      Circle(
                        circleId: const CircleId('limit'),
                        center: _limitCenter,
                        radius: _radiusMeters,
                        strokeColor: tealGreen.withOpacity(.7),
                        strokeWidth: 2,
                        fillColor: tealGreen.withOpacity(.12),
                      ),
                    }
                  : const <Circle>{},
              markers: {
                Marker(
                  markerId: const MarkerId('sel'),
                  position: _selected ?? center,
                  draggable: true,
                  onDragEnd: (pos) {
                    if (_limitTo1Km && _distanceMeters(_limitCenter, pos) > _radiusMeters) {
                      _showSnack('Please keep marker within 1 km');
                      return;
                    }
                    setState(() => _selected = pos);
                  },
                  infoWindow: const InfoWindow(title: 'Selected'),
                ),
              },
            ),
          ),
          Container(
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Lat: ${(_selected ?? center).latitude.toStringAsFixed(6)}\nLng: ${(_selected ?? center).longitude.toStringAsFixed(6)}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
                  ),
                ),
                Row(children: [
                  Switch(
                    value: _limitTo1Km,
                    onChanged: (v) {
                      setState(() {
                        _limitTo1Km = v;
                        _limitCenter = _selected ?? center;
                      });
                    },
                    activeColor: tealGreen,
                    activeTrackColor: tealGreen.withOpacity(.3),
                  ),
                  Text('1 km limit', style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700)),
                  const SizedBox(width: 12),
                ]),
                FilledButton(
                  onPressed: () => Navigator.pop<LatLng>(context, _selected),
                  style: FilledButton.styleFrom(
                    backgroundColor: tealGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 2,
                  ),
                  child: const Text('Use this', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _distanceMeters(LatLng a, LatLng b) {
    const double R = 6371000; // meters
    final double dLat = _degToRad(b.latitude - a.latitude);
    final double dLon = _degToRad(b.longitude - a.longitude);
    final double lat1 = _degToRad(a.latitude);
    final double lat2 = _degToRad(b.latitude);
    final double h =
        _hav(dLat) + Math.cos(lat1) * Math.cos(lat2) * _hav(dLon);
    return 2 * R * Math.asin(Math.min(1.0, Math.sqrt(h)));
  }

  double _degToRad(double d) => d * (3.141592653589793 / 180.0);
  double _hav(double x) => Math.pow(Math.sin(x / 2), 2).toDouble();

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

// Lightweight math helpers without importing dart:math at top-level
class Math {
  static double sin(num x) => _m.sin(x);
  static double cos(num x) => _m.cos(x);
  static double asin(num x) => _m.asin(x);
  static double sqrt(num x) => _m.sqrt(x);
  static double min(num a, num b) => a < b ? a.toDouble() : b.toDouble();
  static double pow(num x, num exponent) => _m.pow(x, exponent).toDouble();
}


