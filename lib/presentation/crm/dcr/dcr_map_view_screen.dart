import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:boilerplate/domain/entity/dcr/unified_dcr_item.dart';
import 'package:boilerplate/presentation/crm/dcr/base_dcr_map_view_screen.dart';

/// Sales Rep Map View screen showing DCR visits on a map
class DcrMapViewScreen extends StatelessWidget {
  final List<UnifiedDcrItem> dcrItems;
  
  const DcrMapViewScreen({
    super.key,
    required this.dcrItems,
  });

  @override
  Widget build(BuildContext context) {
    return BaseDcrMapViewScreen(
      dcrItems: dcrItems,
      title: 'Sales Rep Map View',
      markerColor: BitmapDescriptor.hueCyan,
      emptyStateTitle: 'No DCR Data Found',
      emptyStateMessage: 'No DCR visits with location data available',
      alwaysShowMap: true, // Always show map even if no data
    );
  }
}
