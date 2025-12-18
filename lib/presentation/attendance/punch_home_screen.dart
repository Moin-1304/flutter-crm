import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:boilerplate/domain/usecase/attendance/punch_in_out_usecase.dart';
import 'package:boilerplate/data/sharedpref/shared_preference_helper.dart';
import 'package:boilerplate/domain/entity/attendance/punch_in_out_api_models.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/core/widgets/animated_toast.dart';
import '../../../di/service_locator.dart';

class PunchHomeScreen extends StatefulWidget {
  const PunchHomeScreen({super.key});

  // Static reference to allow external hard refreshes
  static _PunchHomeScreenState? _currentInstance;
  static Future<void> refreshCurrent() async {
    await _currentInstance?._hardRefresh();
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

class _PunchHomeScreenState extends State<PunchHomeScreen> {
  bool _punchedIn = false;
  DateTime? _punchedInSince;
  final List<_LogEntry> _todayLog = <_LogEntry>[];

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

  // Theme color matching login screen
  final Color tealGreen = const Color(0xFF4db1b3);

  // Demo geofence for office reach (replace with your coordinates)
  static const double _officeLat = 18.5204;
  static const double _officeLng = 73.8567;
  static const double _officeRadiusMeters = 300;

  GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    PunchHomeScreen._currentInstance = this;
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
    
    // Listen for user details changes to reload punch records when ready
    _userDetailStore.addListener(_onUserDetailsChanged);
  }

  void _onUserDetailsChanged() {
    // When user details are loaded, reload punch records immediately
    if (_userDetailStore.userDetail != null) {
      _loadTodayPunchRecords();
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
                      _buildActivityCard(),
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
                    : GoogleMap(
                        onMapCreated: (GoogleMapController controller) {
                          _mapController = controller;
                        },
                        initialCameraPosition: CameraPosition(
                          target:
                              LatLng(_position!.latitude, _position!.longitude),
                          zoom: 14.4746,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('current_location'),
                            position: LatLng(
                                _position!.latitude, _position!.longitude),
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
                      ),
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

  Widget _buildActivityCard() {
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
                  "Today's Activity",
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
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[900],
                            letterSpacing: 0.1,
                          ),
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



  void _togglePunch() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      // Get user data from shared preferences
      final user = await _sharedPreferenceHelper.getUser();
      if (user == null) {
        setState(() {
          _isLoading = false;
        });
        _showToast('User not found. Please login again.', isError: true);
        return;
      }

      // Get employee ID from user detail store
      final userDetail = _userDetailStore.userDetail;
      if (userDetail == null) {
        setState(() {
          _isLoading = false;
        });
        _showToast('User details not loaded. Please refresh the app.', isError: true);
        return;
      }

      final isPunchIn = !_punchedIn;
      
      // Call API to save punch in/out
      final result = await _punchInOutUseCase.savePunchInOut(
        userId: user.userId,
        employeeId: userDetail.employeeId, // Get from user detail store
        sbuId: user.sbuId,
        createdBy: user.createdBy,
        status: 1, // Active status
        bizUnit: 1, // Default business unit
        isPunchIn: isPunchIn,
      );

      if (result.isSuccess) {
        setState(() {
          _punchedIn = !_punchedIn;
          final DateTime now = DateTime.now();
          if (_punchedIn) {
            _punchedInSince = now;
            _todayLog.insert(0, _LogEntry(_LogType.inn, now));
            _showToast('Punch In successful!');
          } else {
            _todayLog.insert(0, _LogEntry(_LogType.out, now));
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
        _showToast(result.error ?? 'Failed to save punch record', isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showToast('Error: ${e.toString()}', isError: true);
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
      
      // Call API to save punch out
      final result = await _punchInOutUseCase.savePunchInOut(
        userId: user.userId,
        employeeId: userDetail.employeeId,
        sbuId: user.sbuId,
        createdBy: user.createdBy,
        status: 1, // Active status
        bizUnit: 1, // Default business unit
        isPunchIn: false, // Punch out
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
      await _loadLocation();
    }
    if (mounted) setState(() {});
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

            if (isInByActivity || log.checkInStatus == 1) {
              _todayLog.add(_LogEntry(_LogType.inn, log.checkDateTime));
            } else if (isOutByActivity || log.checkOutStatus == 1) {
              _todayLog.add(_LogEntry(_LogType.out, log.checkDateTime));
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
              // Fallback to our derived list
              if (_todayLog.isNotEmpty) {
                _punchedIn = _todayLog.first.type == _LogType.inn;
                _punchedInSince = _punchedIn ? _todayLog.first.time : null;
              } else {
                _punchedIn = false;
                _punchedInSince = null;
              }
            }
          } else {
            _punchedIn = false;
            _punchedInSince = null;
          }
        });
      }
    } catch (e) {
      // Handle error silently for loading records
    }
  }

  Future<void> _loadLocation() async {
    try {
      final Position pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
      final List<geocoding.Placemark> marks = await geocoding.placemarkFromCoordinates(pos.latitude, pos.longitude);
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
    } catch (_) {}
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
  _LogEntry(this.type, this.time);
  final _LogType type;
  final DateTime time;
}
