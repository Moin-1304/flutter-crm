import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:boilerplate/domain/entity/dcr/unified_dcr_item.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

const Color tealGreen = Color(0xFF4db1b3);

/// Base reusable DCR Map View screen that can be used by different map view implementations
class BaseDcrMapViewScreen extends StatefulWidget {
  final List<UnifiedDcrItem> dcrItems;
  final String title;
  final String? dateRangeText;
  final double markerColor;
  final String emptyStateTitle;
  final String emptyStateMessage;
  final bool alwaysShowMap; // If true, always show map even with no data

  const BaseDcrMapViewScreen({
    super.key,
    required this.dcrItems,
    required this.title,
    this.dateRangeText,
    this.markerColor = BitmapDescriptor.hueCyan,
    this.emptyStateTitle = 'No DCR Data Found',
    this.emptyStateMessage = 'No DCR visits with location data available',
    this.alwaysShowMap = false, // Default to false for backward compatibility
  });

  @override
  State<BaseDcrMapViewScreen> createState() => _BaseDcrMapViewScreenState();
}

class _BaseDcrMapViewScreenState extends State<BaseDcrMapViewScreen> {
  GoogleMapController? _mapController;
  final Set<Marker> _markers = {};
  bool _isLoading = true;
  LatLng? _center;

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  void _initializeMap() {
    // Filter DCR items that have valid coordinates
    final validDcrs = widget.dcrItems
        .where((item) =>
            item.customerLatitude != null &&
            item.customerLongitude != null &&
            item.customerLatitude != 0.0 &&
            item.customerLongitude != 0.0)
        .toList();

    if (validDcrs.isEmpty) {
      setState(() {
        _isLoading = false;
        _center = const LatLng(7.8731, 80.7718); // Default to Sri Lanka center
      });
      return;
    }

    // Create markers for each DCR visit
    final markers = <Marker>{};
    double totalLat = 0;
    double totalLng = 0;
    int count = 0;

    for (int i = 0; i < validDcrs.length; i++) {
      final item = validDcrs[i];
      final lat = item.customerLatitude!;
      final lng = item.customerLongitude!;

      totalLat += lat;
      totalLng += lng;
      count++;

      // Format DCR time - enhanced for managers to see DCR time clearly
      String dcrTimeFormatted = _formatDcrTimeWithTime(item.dcrDate);

      // Build info window snippet with DCR time prominently displayed
      String snippet = 'DCR Time: $dcrTimeFormatted';
      if (item.employeeName.isNotEmpty) {
        snippet += '\nEmployee: ${item.employeeName}';
      }
      if (item.designation.isNotEmpty) {
        snippet += '\n${item.designation}';
      }

      markers.add(
        Marker(
          markerId: MarkerId('dcr_${item.id}'),
          position: LatLng(lat, lng),
          infoWindow: InfoWindow(
            title: item.customerName,
            snippet: snippet,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(widget.markerColor),
        ),
      );
    }

    // Calculate center point
    final centerLat = totalLat / count;
    final centerLng = totalLng / count;

    setState(() {
      _markers.addAll(markers);
      _center = LatLng(centerLat, centerLng);
      _isLoading = false;
    });

    // Animate camera to show all markers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mapController != null && _markers.isNotEmpty) {
        _fitMarkers();
      }
    });
  }

  /// Format DCR time with time prominently displayed for managers
  /// Shows the time when DCR was entered (last entered DCR visits)
  String _formatDcrTimeWithTime(String dcrDate) {
    try {
      // Try parsing with time first (ISO format: yyyy-MM-ddTHH:mm:ss)
      if (dcrDate.contains('T') && dcrDate.length >= 19) {
      final dateTime = DateFormat('yyyy-MM-ddTHH:mm:ss').parse(dcrDate);
        // Check if it's a valid date (not the default null date)
        if (dateTime.year > 1900) {
      // Format: "Jan 13, 2026 at 10:30 AM" for better readability
      return DateFormat('MMM dd, yyyy \'at\' hh:mm a').format(dateTime);
        }
      }
    } catch (e) {
      // Continue to next format
    }
    
      try {
      // Try parsing with milliseconds (ISO format: yyyy-MM-ddTHH:mm:ss.SSS)
      if (dcrDate.contains('T') && dcrDate.contains('.')) {
        final dateTime = DateFormat('yyyy-MM-ddTHH:mm:ss.SSS').parse(dcrDate);
        if (dateTime.year > 1900) {
        return DateFormat('MMM dd, yyyy \'at\' hh:mm a').format(dateTime);
        }
      }
      } catch (e2) {
      // Continue to next format
    }
    
        try {
      // Try parsing date only (yyyy-MM-dd)
      if (dcrDate.length >= 10 && !dcrDate.contains('T')) {
          final dateTime = DateFormat('yyyy-MM-dd').parse(dcrDate);
        if (dateTime.year > 1900) {
          return DateFormat('MMM dd, yyyy').format(dateTime);
        }
      }
    } catch (e3) {
      // Fallback to original string
    }
    
    // Fallback to original string if all parsing fails
    return dcrDate;
  }

  void _fitMarkers() {
    if (_markers.isEmpty || _mapController == null) return;

    double minLat = double.infinity;
    double maxLat = -double.infinity;
    double minLng = double.infinity;
    double maxLng = -double.infinity;

    for (final marker in _markers) {
      final lat = marker.position.latitude;
      final lng = marker.position.longitude;
      minLat = minLat < lat ? minLat : lat;
      maxLat = maxLat > lat ? maxLat : lat;
      minLng = minLng < lng ? minLng : lng;
      maxLng = maxLng > lng ? maxLng : lng;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 100),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: GoogleFonts.inter(
            fontSize: isTablet ? 20 : 18,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
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
            color: Colors.grey.withOpacity(0.2),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
                )
              : Stack(
                  children: [
                // Always show the map
                    GoogleMap(
                      onMapCreated: (GoogleMapController controller) {
                        _mapController = controller;
                    if (_markers.isNotEmpty) {
                        _fitMarkers();
                    }
                      },
                      initialCameraPosition: CameraPosition(
                        target: _center ?? const LatLng(7.8731, 80.7718),
                        zoom: 10,
                      ),
                      markers: _markers,
                      myLocationEnabled: false,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: true,
                      mapToolbarEnabled: false,
                    ),
                // Info card showing total DCRs (only show if there are markers or alwaysShowMap is true)
                if (_markers.isNotEmpty || widget.alwaysShowMap)
                    Positioned(
                      top: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.location_on,
                                  color: tealGreen,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${_markers.length} Visit${_markers.length != 1 ? 's' : ''}',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[800],
                                  ),
                                ),
                              ],
                            ),
                            if (widget.dateRangeText != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                widget.dateRangeText!,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                // Show empty state overlay if no markers and alwaysShowMap is true
                if (_markers.isEmpty && widget.alwaysShowMap)
                  Center(
                    child: Container(
                      margin: const EdgeInsets.all(32),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.map_outlined,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.emptyStateTitle,
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey[700],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            widget.emptyStateMessage,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.grey[500],
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

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}
