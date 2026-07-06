import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:boilerplate/domain/usecase/attendance/punch_in_out_usecase.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/domain/entity/attendance/punch_in_out_api_models.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/domain/entity/user/user.dart';
import 'package:boilerplate/domain/entity/user/user_detail.dart';
import 'package:boilerplate/core/widgets/animated_toast.dart';
import '../../../di/service_locator.dart';
import 'package:boilerplate/domain/repository/tour_plan/tour_plan_repository.dart';
import 'package:boilerplate/data/network/apis/user/lib/domain/entity/tour_plan/tour_plan_api_models.dart';
import 'package:boilerplate/domain/entity/tour_plan/tour_plan.dart';
import 'package:intl/intl.dart';

/// Positive decimal km while typing (e.g. 123.123). Rejects invalid partial input
/// instead of clearing the field (FilteringTextInputFormatter.allow + 2 decimals did that).
final RegExp _punchKmInputPattern = RegExp(r'^\d*\.?\d{0,3}$');

TextInputFormatter _punchKmInputFormatter() {
  return TextInputFormatter.withFunction((oldValue, newValue) {
    final String text = newValue.text;
    if (text.isEmpty) return newValue;
    if (_punchKmInputPattern.hasMatch(text)) return newValue;
    return oldValue;
  });
}

class PunchHomeScreen extends StatefulWidget {
  const PunchHomeScreen({super.key});

  // Static reference to allow external hard refreshes
  static _PunchHomeScreenState? _currentInstance;
  static Future<void> refreshCurrent() async {
    await _currentInstance?._hardRefresh();
  }

  // Static method to refresh summary data (Monthly Status and Planned vs Visited)
  static Future<void> refreshSummaryData() async {
    if (_currentInstance != null && _currentInstance!.mounted) {
      await _currentInstance!._refreshSummaryData();
    }
  }

  // Static method to punch out programmatically (e.g., on logout)
  static Future<bool> punchOutIfNeeded() async {
    if (_currentInstance == null || !_currentInstance!._punchedIn) {
      return false; // Not punched in, nothing to do
    }
    return await _currentInstance!._punchOutProgrammatically();
  }

  @override
  State<PunchHomeScreen> createState() => _PunchHomeScreenState();
}

class _PunchHomeScreenState extends State<PunchHomeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  bool _punchedIn = false;
  DateTime? _punchedInSince;
  double? _sessionKilometerIn;
  final List<_LogEntry> _todayLog = <_LogEntry>[];
  double? _apiLastPunchOutKilometer;
  double? _apiActivePunchInKilometer;

  Timer? _clockTicker;
  DateTime _now = DateTime.now();

  Position? _position;
  String? _address;
  double? _accuracyMeters;

  // API related
  late final PunchInOutUseCase _punchInOutUseCase;
  late final SharedPreferenceHelper _sharedPreferenceHelper;
  late final UserDetailStore _userDetailStore;
  bool _isLoading = false;
  Timer? _postSaveRefresher;



  // Track current employee ID to detect user changes
  int? _currentEmployeeId;


  // Planned vs Visited Summary
  int _totalCustomers = 0;
  int _plannedCustomers = 0;
  int _visitedCustomers = 0;
  int _pendingCustomers = 0;
  int _plannedToday = 0;
  int _visitedToday = 0;
  bool _isLoadingPlannedVsVisited = false;

  // Monthly Status Summary
  int _plannedDays = 0;
  int _approvedDays = 0;
  int _pendingDays = 0;
  int _sentBackDays = 0;
  int _leaveDays = 0;
  int _notEnteredDays = 0;
  int _rejectedDays = 0;
  bool _isLoadingMonthlyStatus = false;

  // Theme color matching login screen
  final Color tealGreen = const Color(0xFF4db1b3);

  // Demo geofence for office reach (replace with your coordinates)
  static const double _officeLat = 18.5204;
  static const double _officeLng = 73.8567;
  static const double _officeRadiusMeters = 300;

  GoogleMapController? _mapController;
  /// Defer building GoogleMap until after first frame to avoid ANR.
  bool _buildMap = false;

  @override
  void initState() {
    super.initState();
    // Defer map build so the first frame paints quickly and ANR is avoided (platform view creation blocks main thread)
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _buildMap = true);
    });
    // Always update the static instance to ensure it's current
    PunchHomeScreen._currentInstance = this;
    print('✅ [PunchHomeScreen] Instance set in initState');
    _punchInOutUseCase = getIt<PunchInOutUseCase>();
    _sharedPreferenceHelper = getIt<SharedPreferenceHelper>();
    _userDetailStore = getIt<UserDetailStore>();
    
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) => setState(() => _now = DateTime.now()));
    
    // Load location and punch records in parallel
    _ensureLocationPermissions().then((ok) {
      if (ok) _loadLocation();
    });
    
    // Try to load punch records immediately, and also listen for user details
    _loadTodayPunchRecords();
    _loadPlannedVsVisitedSummary();
    _loadMonthlyStatusSummary();
    
    // Listen for user details changes to reload punch records when ready
    _userDetailStore.addListener(_onUserDetailsChanged);
    
    // Initialize current employee ID if user details are already loaded
    final userDetail = _userDetailStore.userDetail;
    if (userDetail?.employeeId != null) {
      _currentEmployeeId = userDetail!.employeeId;
    }
  }

  void _onUserDetailsChanged() {
    // When user details change (login/logout), reload all data
    final userDetail = _userDetailStore.userDetail;
    final newEmployeeId = userDetail?.employeeId;

    if (userDetail != null && newEmployeeId != null) {
      // Update current employee ID
      _currentEmployeeId = newEmployeeId;
      
      // New user logged in - reload all data with a small delay to ensure everything is ready
      Future.microtask(() {
        if (mounted && _userDetailStore.userDetail?.employeeId == newEmployeeId && _currentEmployeeId == newEmployeeId) {
          _loadTodayPunchRecords();
          _loadPlannedVsVisitedSummary();
          _loadMonthlyStatusSummary();
        }
      });
    } else {
      // User logged out - reset tracked employee ID
      _currentEmployeeId = null;
    }
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    _postSaveRefresher?.cancel();
    _userDetailStore.removeListener(_onUserDetailsChanged);
    if (PunchHomeScreen._currentInstance == this) {
      PunchHomeScreen._currentInstance = null;
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String statusText = _punchedIn
        ? 'Punched In since ${_formatTime(_punchedInSince ?? _now)}'
        : 'You are currently Punched Out';

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        // Reduce global text scale for this screen (affects all Text widgets)
        textScaleFactor: 0.85,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: _buildResponsiveLayout(context, scheme, statusText),
        ),
      ),
    );
  }

  Widget _buildResponsiveLayout(BuildContext context, ColorScheme scheme, String statusText) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;
    final safeAreaTop = mediaQuery.padding.top;
    final safeAreaBottom = mediaQuery.padding.bottom;
    final availableHeight = screenHeight - safeAreaTop - safeAreaBottom;
    final bool isLargeWidth = screenWidth >= 1024;
    final bool isMediumWidth = screenWidth >= 768;

    final double horizontalPadding = isLargeWidth
        ? 64
        : (isMediumWidth ? 40 : 20);

    return RefreshIndicator(
      onRefresh: () async => _refreshAll(withLocation: true),
      color: tealGreen,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final bool isCompactHeight = availableHeight < 700;
          final bool isVeryCompactHeight = availableHeight < 600;

          final double targetHeaderHeight = isLargeWidth
              ? math.max(availableHeight * 0.48, 420)
              : isMediumWidth
                  ? math.max(availableHeight * 0.42, 360)
                  : math.max(availableHeight * 0.35, 300);

          final double minHeaderHeight = isMediumWidth ? 320 : 240;
          final double maxHeaderHeight = isLargeWidth ? 520 : 460;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: 24 + safeAreaBottom),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Hero section (same look on all devices)
                      Container(
                        height: targetHeaderHeight,
                        constraints: BoxConstraints(
                          minHeight: minHeaderHeight,
                          maxHeight: maxHeaderHeight,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              tealGreen,
                              tealGreen.withOpacity(0.9),
                            ],
                          ),
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(40),
                            bottomRight: Radius.circular(40),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: tealGreen.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            Positioned(
                              top: -50,
                              right: -50,
                              child: Container(
                                width: 200,
                                height: 200,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.1),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: -30,
                              left: -30,
                              child: Container(
                                width: 150,
                                height: 150,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.08),
                                ),
                              ),
                            ),
                            Center(
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: isVeryCompactHeight
                                      ? 8
                                      : (isCompactHeight ? 12 : (isLargeWidth ? 32 : 20)),
                                ),
                                child: LayoutBuilder(
                                  builder: (context, innerConstraints) {
                                    final double heroAvailableHeight = innerConstraints.maxHeight;
                                    final bool needsScaling = heroAvailableHeight < 380;

                                    final bool useCompactContent =
                                        needsScaling || isCompactHeight || screenWidth < 600;

                                    return needsScaling
                                        ? FittedBox(
                                            fit: BoxFit.scaleDown,
                                            child: _buildHeroContent(
                                              scheme,
                                              statusText,
                                              isCompact: true,
                                            ),
                                          )
                                        : _buildHeroContent(
                                            scheme,
                                            statusText,
                                            isCompact: useCompactContent,
                                          );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildLocationCard(),
                      const SizedBox(height: 16),
                      _buildPunchActivityCard(),
                      const SizedBox(height: 16),
                      _buildPlannedVsVisitedSummaryCard(),
                      const SizedBox(height: 16),
                      _buildMonthlyStatusSummaryCard(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeroContent(ColorScheme scheme, String statusText, {required bool isCompact}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildClockHeader(_now, isCompact),
        SizedBox(height: isCompact ? 14 : 28),
        _buildPunchCircle(scheme, isCompact),
        SizedBox(height: isCompact ? 10 : 16),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: isCompact ? 14 : 16,
            vertical: isCompact ? 4 : 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: Text(
            statusText,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: isCompact ? 11 : 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildClockHeader(DateTime now, [bool isCompact = false]) {
    final dateStr = '${_weekday(now.weekday)}, ${_month(now.month)} ${now.day.toString().padLeft(2, '0')}';
    // Reduced font sizes for mobile devices
    final timeFontSize = isCompact ? 42.0 : 48.0;
    final dateFontSize = isCompact ? 14.0 : 16.0;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatTime(now),
          style: TextStyle(
            fontSize: timeFontSize,
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: isCompact ? -1.2 : -1.5,
            height: 1.0,
            shadows: [
              Shadow(
                color: Colors.black12,
                offset: Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
        SizedBox(height: isCompact ? 6 : 8),
        Text(
          dateStr,
          style: TextStyle(
            fontSize: dateFontSize,
            fontWeight: FontWeight.w600,
            color: Colors.white.withOpacity(0.95),
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }

  

  Widget _buildLocationCard() {
    final String addressText = _position == null
        ? 'Fetching location...'
        : (_address ?? 'Lat ${_position!.latitude.toStringAsFixed(5)}, Lng ${_position!.longitude.toStringAsFixed(5)}');
    final String accuracyText = _accuracyMeters == null
        ? 'Accuracy: --'
        : 'Accuracy: ${_accuracyMeters!.toStringAsFixed(0)} meters';

    final bool isInOfficeRange = _isInOfficeRange();
    final String officeProximityText = _position == null
        ? 'Office proximity: --'
        : (isInOfficeRange
            ? 'Within office range '
            : '${_getDistanceToOffice().toStringAsFixed(0)}m from office');

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tealGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.location_on_rounded,
                  color: tealGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Current Location',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey[900],
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Stack(
            children: [
              Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFE9ECEF),
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: kIsWeb ? Clip.none : Clip.hardEdge,
                child: _position == null
                    ? Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(tealGreen),
                        ),
                      )
                    : (!_buildMap
                        ? Container(
                            color: Colors.grey.shade200,
                            child: Center(
                              child: CircularProgressIndicator(
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(tealGreen),
                              ),
                            ),
                          )
                        : GoogleMap(
                            onMapCreated: (GoogleMapController controller) {
                              _mapController = controller;
                            },
                            initialCameraPosition: CameraPosition(
                              target: LatLng(_position!.latitude,
                                  _position!.longitude),
                              zoom: 14.4746,
                            ),
                            markers: {
                              Marker(
                                markerId: const MarkerId('current_location'),
                                position: LatLng(_position!.latitude,
                                    _position!.longitude),
                                icon: BitmapDescriptor.defaultMarker,
                                infoWindow: const InfoWindow(
                                  title: 'Your Location',
                                  snippet: 'Current position',
                                ),
                              ),
                              Marker(
                                markerId: const MarkerId('office_location'),
                                position: const LatLng(_officeLat, _officeLng),
                                icon: BitmapDescriptor.defaultMarkerWithHue(
                                    BitmapDescriptor.hueBlue),
                                infoWindow: const InfoWindow(
                                  title: 'Office',
                                  snippet: 'Central Building Office',
                                ),
                              ),
                            },
                            myLocationEnabled: true,
                            myLocationButtonEnabled: true,
                            zoomControlsEnabled: false,
                            mapToolbarEnabled: false,
                          )),
              ),
              if (kIsWeb)
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.black.withOpacity(0.04),
                          width: 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.place_rounded,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        addressText,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[800],
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.gps_fixed_rounded,
                      size: 14,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        accuracyText,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[600],
                          letterSpacing: 0.2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (isInOfficeRange ? Colors.green : Colors.orange).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          officeProximityText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isInOfficeRange ? Colors.green.shade700 : Colors.orange.shade700,
                            letterSpacing: 0.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPunchActivityCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tealGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.history_rounded,
                  color: tealGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Punch In/Out History",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey[900],
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_todayLog.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  'No activity yet',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _todayLog.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final _LogEntry entry = _todayLog[index];
                final bool isIn = entry.type == _LogType.inn;
                final Color color = isIn ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);
                final String label = isIn ? 'Punch In' : 'Punch Out';
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: color.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          isIn ? Icons.login_rounded : Icons.logout_rounded,
                          color: color,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.grey[900],
                                letterSpacing: 0.1,
                              ),
                            ),
                            if (entry.kilometer != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                entry.type == _LogType.inn
                                    ? 'Km In: ${_formatKilometer(entry.kilometer!)}'
                                    : 'Km Out: ${_formatKilometer(entry.kilometer!)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          _formatTime(entry.time),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPlannedVsVisitedSummaryCard() {
    final plannedPercentage = _totalCustomers > 0 
        ? (_plannedCustomers / _totalCustomers * 100) 
        : 0.0;
    final executionPercentage = _plannedCustomers > 0 
        ? (_visitedCustomers / _plannedCustomers * 100) 
        : 0.0;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tealGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.analytics_rounded,
                  color: tealGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Planned vs Visited Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey[900],
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_isLoadingPlannedVsVisited)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(color: tealGreen),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSummaryCard(
                    'TOTAL CUSTOMERS',
                    _totalCustomers.toString(),
                    'Total Database',
                    const Color(0xFF3498DB),
                    Colors.blue[50]!,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'PLANNED',
                    _plannedCustomers.toString(),
                    '${plannedPercentage.toStringAsFixed(2)} % of Total Base',
                    const Color(0xFF3498DB),
                    Colors.blue[50]!,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'VISITED',
                    _visitedCustomers.toString(),
                    '${executionPercentage.toStringAsFixed(2)} % Execution',
                    const Color(0xFF2ECC71),
                    Colors.green[50]!,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'PENDING',
                    _pendingCustomers.toString(),
                    'Remaining in Plan',
                    const Color(0xFFE74C3C),
                    Colors.red[50]!,
                    isRed: true,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'PLANNED',
                    _plannedToday.toString(),
                    'TODAY',
                    const Color(0xFF9B59B6),
                    Colors.purple[50]!,
                    isPurple: true,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'VISITED',
                    _visitedToday.toString(),
                    'TODAY',
                    const Color(0xFF9B59B6),
                    Colors.purple[50]!,
                    isPurple: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthlyStatusSummaryCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: tealGreen.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: tealGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Monthly Status Summary',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.grey[900],
                    letterSpacing: -0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (_isLoadingMonthlyStatus)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: CircularProgressIndicator(color: tealGreen),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildSummaryCard(
                    'PLANNED DAYS',
                    _plannedDays.toString(),
                    '',
                    const Color(0xFF3498DB),
                    Colors.blue[50]!,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'APPROVED DAYS',
                    _approvedDays.toString(),
                    '',
                    const Color(0xFF2ECC71),
                    Colors.green[50]!,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'PENDING DAYS',
                    _pendingDays.toString(),
                    '',
                    const Color(0xFFFFA41C),
                    Colors.orange[50]!,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'SENT BACK DAYS',
                    _sentBackDays.toString(),
                    '',
                    const Color(0xFFE74C3C),
                    Colors.red[50]!,
                    isRed: true,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'LEAVE DAYS',
                    _leaveDays.toString(),
                    '',
                    const Color(0xFF9B59B6),
                    Colors.purple[50]!,
                    isPurple: true,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'NOT ENTERED DAYS',
                    _notEnteredDays.toString(),
                    '',
                    Colors.grey[700]!,
                    Colors.grey[100]!,
                  ),
                  const SizedBox(width: 12),
                  _buildSummaryCard(
                    'REJECTED DAYS',
                    _rejectedDays.toString(),
                    '',
                    const Color(0xFFE74C3C),
                    Colors.red[50]!,
                    isRed: true,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, String subtitle, Color textColor, Color bgColor, {bool isRed = false, bool isPurple = false}) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: textColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.grey[700],
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: isRed ? const Color(0xFFE74C3C) : (isPurple ? const Color(0xFF9B59B6) : textColor),
              letterSpacing: -1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              letterSpacing: 0.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }


  Widget _buildStatBox(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                    letterSpacing: 0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.white,
            blurRadius: 0,
            offset: const Offset(0, -1),
            spreadRadius: 0,
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      margin: const EdgeInsets.only(bottom: 0),
      child: child,
    );
  }

  Widget _buildPunchCircle(ColorScheme scheme, [bool isCompact = false]) {
    // Enhanced modern punch circle with better visual feedback
    final circleSize = isCompact ? 170.0 : 200.0;
    final iconSize = isCompact ? 40.0 : 48.0;
    final fontSize = isCompact ? 13.0 : 15.0; // Reduced for mobile
    
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: _isLoading ? null : _togglePunch,
          borderRadius: BorderRadius.circular(100),
          child: Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: Colors.white.withOpacity(0.8),
                  blurRadius: 20,
                  offset: const Offset(-5, -5),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.white.withOpacity(0.95),
                  ],
                ),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 2,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isLoading)
                    SizedBox(
                      width: isCompact ? 36 : 40,
                      height: isCompact ? 36 : 40,
                      child: CircularProgressIndicator(
                        color: tealGreen,
                        strokeWidth: 3.5,
                        backgroundColor: tealGreen.withOpacity(0.2),
                      ),
                    )
                  else
                    Container(
                      padding: EdgeInsets.all(isCompact ? 10 : 12),
                      decoration: BoxDecoration(
                        color: tealGreen.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.touch_app_rounded,
                        color: tealGreen,
                        size: iconSize,
                      ),
                    ),
                  SizedBox(height: isCompact ? 10 : 12),
                  Text(
                    _isLoading 
                        ? 'PROCESSING...' 
                        : (_punchedIn ? 'CLOCK OUT' : 'CLOCK IN'),
                    style: TextStyle(
                      color: tealGreen,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                      fontSize: fontSize,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }



  /// Today's punch-in odometer reading for the active session.
  double? _kilometerInFromTodayLog() {
    for (final entry in _todayLog) {
      if (entry.type == _LogType.inn &&
          entry.kilometer != null &&
          entry.kilometer! > 0) {
        return entry.kilometer;
      }
    }
    return _sessionKilometerIn;
  }

  double? _activePunchInKilometer() {
    final double? fromLog = _kilometerInFromTodayLog();
    if (fromLog != null && fromLog > 0) return fromLog;
    return _sessionKilometerIn;
  }

  /// Most recent punch-out odometer reading for today (for multi-session days).
  double? _lastPunchOutKilometerToday() {
    for (final entry in _todayLog) {
      if (entry.type == _LogType.out &&
          entry.kilometer != null &&
          entry.kilometer! > 0) {
        return entry.kilometer;
      }
    }
    return null;
  }

  double? _effectiveLastPunchOutKilometer() {
    final double? fromLog = _lastPunchOutKilometerToday();
    if (fromLog != null && fromLog > 0) return fromLog;
    if (_apiLastPunchOutKilometer != null && _apiLastPunchOutKilometer! > 0) {
      return _apiLastPunchOutKilometer;
    }
    return null;
  }

  double? _effectiveActivePunchInKilometer() {
    final double? fromLog = _activePunchInKilometer();
    if (fromLog != null && fromLog > 0) return fromLog;
    if (_apiActivePunchInKilometer != null && _apiActivePunchInKilometer! > 0) {
      return _apiActivePunchInKilometer;
    }
    return null;
  }

  void _syncKilometerBaselinesFromRecords(
    List<LogDetail> logs,
    PunchInOutResponse? parentItem,
  ) {
    double? lastOut;
    double? activeIn;

    final List<LogDetail> sorted = List<LogDetail>.from(logs)
      ..sort((a, b) => b.checkDateTime.compareTo(a.checkDateTime));

    for (final log in sorted) {
      final String act = log.activity.toLowerCase();
      final bool isOut =
          act.contains('punch out') || log.checkOutStatus == 1;
      final double? kmOut = log.kilometerOut;
      if (kmOut != null && kmOut > 0 && (isOut || (log.kilometerIn ?? 0) == 0)) {
        lastOut = kmOut;
        break;
      }
    }

    if (lastOut == null) {
      for (final log in sorted) {
        final double? kmOut = log.kilometerOut;
        if (kmOut != null && kmOut > 0) {
          lastOut = kmOut;
          break;
        }
      }
    }

    if (_punchedIn) {
      for (final log in sorted) {
        final String act = log.activity.toLowerCase();
        if (act.contains('punch in') && !act.contains('punch out')) {
          final double? kmIn = log.kilometerIn;
          if (kmIn != null && kmIn > 0) {
            activeIn = kmIn;
            break;
          }
        }
      }
      if (activeIn == null) {
        for (final log in sorted) {
          final double? kmIn = log.kilometerIn;
          final double? kmOut = log.kilometerOut;
          if (kmIn != null && kmIn > 0 && (kmOut == null || kmOut == 0)) {
            activeIn = kmIn;
            break;
          }
        }
      }
      activeIn ??= _sessionKilometerIn;
    }

    if (parentItem != null) {
      if ((parentItem.kilometerOut ?? 0) > 0) {
        lastOut ??= parentItem.kilometerOut;
      }
      if (_punchedIn && (parentItem.kilometerIn ?? 0) > 0) {
        activeIn ??= parentItem.kilometerIn;
      }
    }

    _apiLastPunchOutKilometer = lastOut;
    _apiActivePunchInKilometer = activeIn;
  }

  /// Returns a user-facing message when mileage rules fail, or null if valid.
  String? _validatePunchMileage({
    required bool isPunchIn,
    required double kilometer,
    double? privateKilometers,
  }) {
    if (isPunchIn) {
      final double? lastOut = _effectiveLastPunchOutKilometer();
      if (lastOut != null && lastOut > 0 && kilometer < lastOut) {
        return _punchInTooLowMessage(lastOut);
      }
      return null;
    }

    final double? punchInKm = _effectiveActivePunchInKilometer();
    if (punchInKm != null && punchInKm > 0 && kilometer < punchInKm) {
      return _punchOutTooLowMessage(punchInKm);
    }

    final double privateKm = privateKilometers ?? 0;
    if (punchInKm != null &&
        punchInKm > 0 &&
        privateKm > (kilometer - punchInKm)) {
      return 'Private KM cannot exceed work distance (${_formatKilometer(kilometer - punchInKm)} km)';
    }

    return null;
  }

  String _friendlyPunchSaveError(String? error) {
    if (error == null || error.trim().isEmpty) {
      return 'Failed to save punch record. Please try again.';
    }
    final String cleaned =
        error.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    final String lower = cleaned.toLowerCase();
    if (lower.contains('kilometer') ||
        lower.contains('mileage') ||
        lower.contains('punch out') ||
        lower.contains('punch in') ||
        lower.contains('odometer')) {
      return cleaned;
    }
    if (lower.contains('server error')) {
      final double? lastOut = _effectiveLastPunchOutKilometer();
      final double? punchInKm = _effectiveActivePunchInKilometer();
      if (lastOut != null && lastOut > 0) {
        return '${_punchInTooLowMessage(lastOut)} Please correct the value and try again.';
      }
      if (punchInKm != null && punchInKm > 0) {
        return '${_punchOutTooLowMessage(punchInKm)} Please correct the value and try again.';
      }
      return 'Could not save punch record. Please check your kilometer readings and try again.';
    }
    return cleaned;
  }

  /// Shows a dialog to enter mileage values.
  /// For punch in: requires Kilometer In only (must be >= last punch out same day).
  /// For punch out: requires Kilometer Out and Private KM (Out must be >= punch in).
  Future<_PunchMileageInput?> _showKilometerDialog(
    BuildContext context, {
    required bool isPunchIn,
    double? punchInKilometer,
    double? lastPunchOutKilometer,
  }) async {
    final kilometerController = TextEditingController();
    final privateKmController = TextEditingController(text: '0');
    final key = GlobalKey<FormState>();
    final Color accentColor = isPunchIn ? const Color(0xFF2ECC71) : const Color(0xFFE74C3C);
    return showDialog<_PunchMileageInput?>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (ctx) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 8,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Form(
              key: key,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with icon
                  Container(
                    padding: const EdgeInsets.only(top: 28, bottom: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: accentColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            Icons.speed_rounded,
                            size: 28,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    isPunchIn ? 'Kilometer In' : 'Kilometer Out',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[900],
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isPunchIn
                        ? 'Enter your vehicle\'s starting mileage'
                        : 'Enter your vehicle\'s closing mileage',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!isPunchIn &&
                      punchInKilometer != null &&
                      punchInKilometer > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Punch in reading: ${_formatKilometer(punchInKilometer)} km',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tealGreen,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  if (isPunchIn &&
                      lastPunchOutKilometer != null &&
                      lastPunchOutKilometer > 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Last punch out: ${_formatKilometer(lastPunchOutKilometer)} km',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: tealGreen,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: kilometerController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: <TextInputFormatter>[
                      _punchKmInputFormatter(),
                    ],
                    autofocus: true,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                    ),
                    decoration: InputDecoration(
                      hintText: 'e.g. 1250.5',
                      hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
                      prefixText: 'km  ',
                      prefixStyle: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: tealGreen,
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: tealGreen, width: 2),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE74C3C)),
                      ),
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter mileage';
                      final n = double.tryParse(v.trim());
                      if (n == null || n < 0) return 'Enter a valid number (≥ 0)';
                      if (isPunchIn &&
                          lastPunchOutKilometer != null &&
                          lastPunchOutKilometer > 0 &&
                          n < lastPunchOutKilometer) {
                        return _punchInTooLowMessage(lastPunchOutKilometer);
                      }
                      if (!isPunchIn &&
                          punchInKilometer != null &&
                          punchInKilometer > 0 &&
                          n < punchInKilometer) {
                        return _punchOutTooLowMessage(punchInKilometer);
                      }
                      return null;
                    },
                  ),
                  if (!isPunchIn) ...[
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: privateKmController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: <TextInputFormatter>[
                        _punchKmInputFormatter(),
                      ],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                      ),
                      decoration: InputDecoration(
                        labelText: 'Private KM',
                        hintText: 'e.g. 10.0',
                        helperText: 'Enter personal travel before checkout, if any',
                        hintStyle: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.w500),
                        prefixText: 'km  ',
                        prefixStyle: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: tealGreen,
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: tealGreen, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE74C3C)),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Please enter Private KM';
                        final n = double.tryParse(v.trim());
                        if (n == null || n < 0) return 'Enter a valid number (≥ 0)';
                        if (punchInKilometer != null && punchInKilometer > 0) {
                          final double? kmOut =
                              double.tryParse(kilometerController.text.trim());
                          if (kmOut != null && kmOut >= punchInKilometer) {
                            final double maxPrivate = kmOut - punchInKilometer;
                            if (n > maxPrivate) {
                              return 'Cannot exceed ${_formatKilometer(maxPrivate)} km';
                            }
                          }
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(ctx).pop<_PunchMileageInput?>(null),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(color: Colors.grey[400]!),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            if (key.currentState?.validate() ?? false) {
                              final kilometerValue = double.tryParse(kilometerController.text.trim());
                              final privateKmValue = isPunchIn
                                  ? null
                                  : double.tryParse(privateKmController.text.trim());
                              Navigator.of(ctx).pop<_PunchMileageInput?>(
                                _PunchMileageInput(
                                  kilometer: kilometerValue,
                                  privateKilometers: privateKmValue,
                                ),
                              );
                            }
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: tealGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Save'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Resolves punch save identifiers to match the website payload (managers often
  /// have primarySBUId / employee profile fields that differ from login user.sbuId).
  ({
    int userId,
    int employeeId,
    int sbuId,
    int bizUnit,
    int createdBy,
    String userName,
    String sbuName,
  }) _resolvePunchSaveFields(User user, UserDetail userDetail) {
    final int sbuId = userDetail.primarySBUId ??
        (userDetail.sbuId > 0
            ? userDetail.sbuId
            : (user.sbuId > 0 ? user.sbuId : 1));
    final int bizUnit = sbuId > 0
        ? sbuId
        : (userDetail.sbuCompany > 0 ? userDetail.sbuCompany : 1);
    final int userId = (userDetail.userId ?? user.userId) > 0
        ? (userDetail.userId ?? user.userId)
        : user.userId;
    final int createdBy =
        user.userId > 0 ? user.userId : (userDetail.userId ?? user.id);
    final String userName = userDetail.employeeName.trim().isNotEmpty
        ? userDetail.employeeName.trim()
        : user.name;
    final String sbuName = userDetail.sbuName.trim();

    return (
      userId: userId,
      employeeId: userDetail.employeeId,
      sbuId: sbuId,
      bizUnit: bizUnit,
      createdBy: createdBy,
      userName: userName,
      sbuName: sbuName,
    );
  }

  void _togglePunch() async {
    if (_isLoading) return;

    try {
      // Get user data from shared preferences
      final user = await _sharedPreferenceHelper.getUser();
      if (user == null) {
        _showToast('User not found. Please login again.', isError: true);
        return;
      }

      // Get employee ID from user detail store
      final userDetail = _userDetailStore.userDetail;
      if (userDetail == null) {
        _showToast('User details not loaded. Please refresh the app.', isError: true);
        return;
      }

      final isPunchIn = !_punchedIn;

      // Refresh today's readings so mileage limits match the server before the dialog opens.
      await _loadTodayPunchRecords();

      // Show dialog to enter vehicle mileage (Kilometer In for punch in, Kilometer Out for punch out)
      final _PunchMileageInput? mileageInput =
          await _showKilometerDialog(
        context,
        isPunchIn: isPunchIn,
        punchInKilometer: isPunchIn ? null : _effectiveActivePunchInKilometer(),
        lastPunchOutKilometer:
            isPunchIn ? _effectiveLastPunchOutKilometer() : null,
      );
      if (mileageInput == null && !mounted) {
        return;
      }
      // User cancelled dialog
      if (mileageInput == null || mileageInput.kilometer == null) {
        return;
      }
      final double kilometerValue = mileageInput.kilometer!;

      final String? mileageError = _validatePunchMileage(
        isPunchIn: isPunchIn,
        kilometer: kilometerValue,
        privateKilometers: mileageInput.privateKilometers,
      );
      if (mileageError != null) {
        _showToast(mileageError, isError: true);
        return;
      }

      if (userDetail.employeeId <= 0) {
        _showToast(
          'Employee profile not loaded. Please logout and login again.',
          isError: true,
        );
        return;
      }

      setState(() => _isLoading = true);

      final punchFields = _resolvePunchSaveFields(user, userDetail);
      
      // Call API to save punch in/out with vehicle mileage
      final result = await _punchInOutUseCase.savePunchInOut(
        userId: punchFields.userId,
        employeeId: punchFields.employeeId,
        sbuId: punchFields.sbuId,
        createdBy: punchFields.createdBy,
        status: 1, // Active status
        bizUnit: punchFields.bizUnit,
        isPunchIn: isPunchIn,
        userName: punchFields.userName,
        sbuName: punchFields.sbuName,
        kilometerIn: isPunchIn ? kilometerValue : null,
        kilometerOut: isPunchIn ? null : kilometerValue,
        privateKilometers: isPunchIn ? null : mileageInput.privateKilometers,
      );

      if (result.isSuccess) {
        setState(() {
          _punchedIn = !_punchedIn;
          final DateTime now = DateTime.now();
          if (_punchedIn) {
            _punchedInSince = now;
            _sessionKilometerIn = kilometerValue;
            _todayLog.insert(0, _LogEntry(_LogType.inn, now, kilometer: kilometerValue));
            _showToast('Punch In successful!');
          } else {
            _sessionKilometerIn = null;
            _todayLog.insert(0, _LogEntry(_LogType.out, now, kilometer: kilometerValue));
            _showToast('Punch Out successful!');
          }
          _isLoading = false;
        });
        
        // Hard refresh whole screen after successful punch
        await _hardRefresh();

        // Start short auto-refresh to ensure server-side list syncs
        _startPostSaveAutoRefresh();
      } else {
        setState(() {
          _isLoading = false;
        });
        _showToast(_friendlyPunchSaveError(result.error), isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      final String errorString = e.toString();
      String errorMessage = _friendlyPunchSaveError(errorString);
      if (errorMessage == 'Failed to save punch record. Please try again.' &&
          errorString.contains('Connection error')) {
        errorMessage =
            'Connection error. Please check your internet connection and try again.';
      } else if (errorString.contains('Authentication failed')) {
        errorMessage = 'Authentication failed. Please login again.';
      }
      _showToast(errorMessage, isError: true);
    }
    
    _loadLocation();
  }

  /// Programmatically punch out (called during logout)
  /// Returns true if punch out was successful or not needed, false on error
  Future<bool> _punchOutProgrammatically() async {
    if (!_punchedIn) {
      return true; // Already punched out, nothing to do
    }

    try {
      // Get user data from shared preferences
      final user = await _sharedPreferenceHelper.getUser();
      if (user == null) {
        return false; // Can't punch out without user data
      }

      // Get employee ID from user detail store
      final userDetail = _userDetailStore.userDetail;
      if (userDetail == null) {
        return false; // Can't punch out without user details
      }
      
      if (userDetail.employeeId <= 0) {
        return false;
      }

      final punchFields = _resolvePunchSaveFields(user, userDetail);
      
      // Call API to save punch out
      final result = await _punchInOutUseCase.savePunchInOut(
        userId: punchFields.userId,
        employeeId: punchFields.employeeId,
        sbuId: punchFields.sbuId,
        createdBy: punchFields.createdBy,
        status: 1, // Active status
        bizUnit: punchFields.bizUnit,
        isPunchIn: false, // Punch out
        userName: punchFields.userName,
        sbuName: punchFields.sbuName,
        privateKilometers: 0,
      );

      if (result.isSuccess) {
        // Update state silently (no toast during logout)
        if (mounted) {
          setState(() {
            _punchedIn = false;
            _punchedInSince = null;
            _todayLog.insert(0, _LogEntry(_LogType.out, DateTime.now()));
          });
        }
        return true;
      } else {
        return false; // Failed to punch out
      }
    } catch (e) {
      return false; // Error during punch out
    }
  }

  /// Poll the server for a short period after saving to ensure the
  /// activity list reflects the latest punch event (handles eventual consistency)
  void _startPostSaveAutoRefresh() {
    _postSaveRefresher?.cancel();
    int ticks = 0;
    const int maxTicks = 5; // ~15s total
    _postSaveRefresher = Timer.periodic(const Duration(seconds: 3), (timer) async {
      ticks++;
      await _refreshAll(withLocation: false);
      if (ticks >= maxTicks) {
        timer.cancel();
      }
    });
  }

  /// Refresh all server-driven data used on this screen and update UI
  Future<void> _refreshAll({bool withLocation = false}) async {
    await _loadTodayPunchRecords();
    if (withLocation) {
      // Do not block pull-to-refresh on GPS/network geocoding delays.
      _loadLocation();
    }
    await Future.wait([
      _loadPlannedVsVisitedSummary(force: true),
      _loadMonthlyStatusSummary(force: true),
    ]);
    if (mounted) setState(() {});
  }

  /// Refresh only summary data (Monthly Status and Planned vs Visited)
  Future<void> _refreshSummaryData() async {
    if (!mounted) return;
    final List<Future<void>> refreshTasks = [
      _loadMonthlyStatusSummary(force: true),
      _loadPlannedVsVisitedSummary(force: true),
    ];
    await Future.wait(refreshTasks);
    if (mounted) {
      setState(() {});
    }
  }

  /// Load Planned vs Visited Summary from TourPlanDashboard API
  Future<void> _loadPlannedVsVisitedSummary({bool force = false}) async {
    if (!force && _isLoadingPlannedVsVisited) return;

    setState(() {
      _isLoadingPlannedVsVisited = true;
    });

    try {
      final userDetail = _userDetailStore.userDetail;
      if (userDetail?.employeeId == null || userDetail?.employeeId != _currentEmployeeId) {
        setState(() {
          _isLoadingPlannedVsVisited = false;
        });
        return;
      }

      final now = DateTime.now();
      final todayDateStr = DateFormat('yyyy-MM-dd').format(now);

      // Call TourPlanDashboard API
      final tourPlanRepo = getIt<TourPlanRepository>();
      final request = TourPlanDashboardRequest(
        userId: userDetail!.employeeId,
        bizunit: userDetail.sbuId > 0 ? userDetail.sbuId : 1,
        month: now.month,
        year: now.year,
        planDate: todayDateStr,
        pageNumber: 1,
        pageSize: 1000,
      );

      final dashboardData = await tourPlanRepo.getTourPlanDashboard(request);

      // Verify employeeId still matches before setting values
      final currentUserDetail = _userDetailStore.userDetail;
      if (mounted && currentUserDetail?.employeeId == userDetail.employeeId && _currentEmployeeId == userDetail.employeeId) {
        setState(() {
          _totalCustomers = dashboardData.totalCustomers;
          _plannedCustomers = dashboardData.plannedMonth;
          _visitedCustomers = dashboardData.visitedMonth;
          _pendingCustomers = dashboardData.pendingMonth;
          _plannedToday = dashboardData.plannedToday;
          _visitedToday = dashboardData.visitedToday;
          _isLoadingPlannedVsVisited = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingPlannedVsVisited = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingPlannedVsVisited = false;
        });
      }
    }
  }

  /// Load Monthly Status Summary
  Future<void> _loadMonthlyStatusSummary({bool force = false}) async {
    if (!force && _isLoadingMonthlyStatus) return;

    setState(() {
      _isLoadingMonthlyStatus = true;
    });

    try {
      final userDetail = _userDetailStore.userDetail;
      if (userDetail?.employeeId == null || userDetail?.employeeId != _currentEmployeeId) {
        setState(() {
          _isLoadingMonthlyStatus = false;
        });
        return;
      }

      final now = DateTime.now();
      final ud = userDetail!;

      final prefsUser = await getIt<SharedPreferenceHelper>().getUser();

      // Backend uses different keys per endpoint: TourPlanDashboard `UserId` = employee id,
      // while GetSummary `UserId` matches the logged-in app user (`User.id` from login — not employeeId).
      // Using employeeId for GetSummary returns all zeros from the API.
      final int summaryUserId = (prefsUser != null && prefsUser.id > 0)
          ? prefsUser.id
          : (ud.userId ?? ud.employeeId);
      final int bizunit = ud.sbuId > 0 ? ud.sbuId : 1;

      // Get tour plan summary using API
      final tourPlanRepo = getIt<TourPlanRepository>();
      final request = TourPlanGetSummaryRequest(
        month: now.month,
        year: now.year,
        userId: summaryUserId,
        bizunit: bizunit,
      );

      final summary = await tourPlanRepo.getTourPlanSummary(request);

      // Get tour plan entries to calculate leaveDays, notEnteredDays, and rejectedDays
      final plannedEntries = await tourPlanRepo.listMonth(
        month: now,
        employeeId: ud.employeeId.toString(),
      );

      // Calculate additional status counts from entries
      int notEntered = 0;
      int rejected = 0;
      int leave = 0;
      
      for (final entry in plannedEntries) {
        switch (entry.status) {
          case TourPlanEntryStatus.draft:
            notEntered++;
            break;
          case TourPlanEntryStatus.rejected:
            rejected++;
            break;
          // Note: leaveDays would need to be identified by a specific field or status
          // For now, we'll keep it at 0 unless the API provides it
          default:
            break;
        }
      }
      
      // Verify employeeId still matches before setting values
      final currentUserDetail = _userDetailStore.userDetail;
      if (mounted && currentUserDetail?.employeeId == ud.employeeId && _currentEmployeeId == ud.employeeId) {
        setState(() {
          _plannedDays = summary.planedDays;
          _approvedDays = summary.approvedDays;
          _pendingDays = summary.pendingDays;
          _sentBackDays = summary.sentBackDays;
          _notEnteredDays = notEntered;
          _rejectedDays = rejected;
          _leaveDays = leave; // Will be 0 unless API provides leave tracking
          _isLoadingMonthlyStatus = false;
        });
      } else if (mounted) {
        setState(() {
          _isLoadingMonthlyStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMonthlyStatus = false;
        });
      }
    }
  }


  /// Clear transient state and refetch everything (hard refresh for UI)
  Future<void> _hardRefresh() async {
    setState(() {
      _todayLog.clear();
      _punchedInSince = null;
    });
    await _refreshAll(withLocation: true);
  }

  Future<void> _loadTodayPunchRecords() async {
    try {
      final user = await _sharedPreferenceHelper.getUser();
      if (user == null) return;

      // Get employee ID from user detail store
      final userDetail = _userDetailStore.userDetail;
      if (userDetail == null) {
        // User details not loaded yet, will retry when user details are loaded
        // Check again after a short delay in case user details are loading
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted && _userDetailStore.userDetail != null) {
            _loadTodayPunchRecords();
          }
        });
        return;
      }

      final result = await _punchInOutUseCase.getTodayPunchInOutList(
        userId: user.userId,
      );

      if (result.isSuccess && result.data != null) {
        final punchRecords = result.data!;
        final hasItem = punchRecords.items.isNotEmpty;
        final logs = hasItem ? List.of(punchRecords.items.first.logDetails) : <LogDetail>[];

        logs.sort((a, b) => b.checkDateTime.compareTo(a.checkDateTime));

        setState(() {
          // Rebuild activity list regardless of presence/absence
          _todayLog.clear();
          for (final log in logs) {
            final String act = (log.activity).toLowerCase();
            final bool isInByActivity = act.contains('punch in') && !act.contains('punch out');
            final bool isOutByActivity = act.contains('punch out');

            final bool isInByFlags =
                log.checkOutStatus != 1 &&
                (log.checkInStatus == 1 ||
                    ((log.kilometerIn ?? 0) > 0 && (log.kilometerOut ?? 0) == 0));
            final bool isOutByFlags =
                log.checkOutStatus == 1 ||
                ((log.kilometerOut ?? 0) > 0 && !isInByActivity);

            if (isInByActivity || isInByFlags) {
              _todayLog.add(_LogEntry(_LogType.inn, log.checkDateTime, kilometer: log.kilometerIn));
            } else if (isOutByActivity || isOutByFlags) {
              _todayLog.add(_LogEntry(_LogType.out, log.checkDateTime, kilometer: log.kilometerOut));
            }
          }
          // Sort by time (most recent first)
          _todayLog.sort((a, b) => b.time.compareTo(a.time));

          // Determine punched-in state from the latest log entry using activity first, statuses as fallback
          if (logs.isNotEmpty) {
            final latest = logs.first;
            final String act = latest.activity.toLowerCase();
            if (act.contains('punch in') && !act.contains('punch out')) {
              _punchedIn = true;
              _punchedInSince = latest.checkDateTime;
            } else if (act.contains('punch out')) {
              _punchedIn = false;
              _punchedInSince = null;
            } else {
              // Fallback: prefer explicit checkout flag, then infer check-in from
              // checkInStatus/kilometer values observed in list responses.
              if (latest.checkOutStatus == 1 ||
                  ((latest.kilometerOut ?? 0) > 0 &&
                      (latest.kilometerIn ?? 0) == 0)) {
                _punchedIn = false;
                _punchedInSince = null;
              } else if (latest.checkInStatus == 1 ||
                  ((latest.kilometerIn ?? 0) > 0 &&
                      (latest.kilometerOut ?? 0) == 0)) {
                _punchedIn = true;
                _punchedInSince = latest.checkDateTime;
              } else {
                _punchedIn = false;
                _punchedInSince = null;
              }
            }
          } else {
            _punchedIn = false;
            _punchedInSince = null;
          }

          if (_punchedIn) {
            final double? kmIn = _kilometerInFromTodayLog();
            if (kmIn != null && kmIn > 0) {
              _sessionKilometerIn = kmIn;
            } else if (hasItem) {
              final double? apiKmIn = punchRecords.items.first.kilometerIn;
              if (apiKmIn != null && apiKmIn > 0) {
                _sessionKilometerIn = apiKmIn;
              }
            }
          } else {
            _sessionKilometerIn = null;
          }

          _syncKilometerBaselinesFromRecords(
            logs,
            hasItem ? punchRecords.items.first : null,
          );
        });
      }
    } catch (e) {
      // Handle error silently for loading records
    }
  }

  Future<void> _loadLocation() async {
    try {
      final Position pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      ).timeout(const Duration(seconds: 10));
      final List<geocoding.Placemark> marks =
          await geocoding.placemarkFromCoordinates(pos.latitude, pos.longitude)
              .timeout(const Duration(seconds: 8));
      final geocoding.Placemark? m = marks.isNotEmpty ? marks.first : null;
      final String? addr = m == null ? null : [m.name, m.street, m.locality].where((e) => (e ?? '').trim().isNotEmpty).join(', ');
      setState(() {
        _position = pos;
        _accuracyMeters = pos.accuracy;
        _address = addr;
      });
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(_position!.latitude, _position!.longitude),
              zoom: 14.4746,
            ),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      // Keep UI responsive even when location services are slow/unavailable.
      setState(() {
        _address = _address ?? 'Location unavailable';
      });
    }
  }

  Future<bool> _ensureLocationPermissions() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showToast('Location services are disabled. Please enable them.',
            isError: true);
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showToast(
              'Location permissions are denied. Please grant them in settings.',
              isError: true);
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showToast(
            'Location permissions are permanently denied. Please enable them in settings.',
            isError: true);
        return false;
      }

      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      _showToast('Error checking location permissions: ${e.toString()}',
          isError: true);
      return false;
    }
  }

  static String _formatTime(DateTime d) {
    final int hour = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final String ampm = d.hour >= 12 ? 'PM' : 'AM';
    return '${hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $ampm';
  }

  static String _punchInTooLowMessage(double minimumKm) {
    return 'Kilometer In cannot be less than your last Punch Out. Enter at least ${_formatKilometer(minimumKm)} km.';
  }

  static String _punchOutTooLowMessage(double minimumKm) {
    return 'Kilometer Out cannot be less than your Punch In. Enter at least ${_formatKilometer(minimumKm)} km.';
  }

  static String _formatKilometer(double value) {
    final String formatted = value.toStringAsFixed(2);
    if (formatted.endsWith('00')) return value.toStringAsFixed(0);
    if (formatted.endsWith('0')) return formatted.substring(0, formatted.length - 1);
    return formatted;
  }

  static String _weekday(int w) => const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][w - 1];
  static String _month(int m) => const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m - 1];

  /// Show toast message using AnimatedToast
  void _showToast(String message, {bool isError = false}) {
    if (!mounted) return;
    
    if (isError) {
      AnimatedToast.showError(context, message);
    } else {
      AnimatedToast.showSuccess(context, message);
    }
  }

  bool _isInOfficeRange() {
    if (_position == null) return false;
    final double distance = Geolocator.distanceBetween(
        _position!.latitude, _position!.longitude, _officeLat, _officeLng);
    return distance <= _officeRadiusMeters;
  }

  double _getDistanceToOffice() {
    if (_position == null) return 0.0;
    return Geolocator.distanceBetween(
        _position!.latitude, _position!.longitude, _officeLat, _officeLng);
  }
}

enum _LogType { inn, out }

class _LogEntry {
  _LogEntry(this.type, this.time, {this.kilometer});
  final _LogType type;
  final DateTime time;
  final double? kilometer;
}

class _PunchMileageInput {
  const _PunchMileageInput({
    required this.kilometer,
    required this.privateKilometers,
  });

  final double? kilometer;
  final double? privateKilometers;
}
