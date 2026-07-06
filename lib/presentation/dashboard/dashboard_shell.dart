import 'package:flutter/material.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/presentation/home/store/theme/theme_store.dart';
import 'package:boilerplate/utils/routes/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:boilerplate/data/sharedpref/constants/preferences.dart';
import 'package:boilerplate/presentation/dashboard/store/menu_store.dart';
import 'package:boilerplate/presentation/login/store/login_store.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/presentation/user/store/user_validation_store.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:boilerplate/di/service_locator.dart';

import '../attendance/punch_home_screen.dart';
import '../tour_plan/tour_plan_screen.dart';
import 'package:boilerplate/presentation/crm/crm_shell.dart';
import '../crm/customer_issue/customer_issue_list_screen.dart';
import '../sales/sales_order_list.dart';
import '../sales/sales_bonus_approval_screen.dart';

class DashboardShell extends StatefulWidget {
  const DashboardShell({super.key});

  @override
  State<DashboardShell> createState() => _DashboardShellState();
}

class _DashboardShellState extends State<DashboardShell>
    with WidgetsBindingObserver {
  int _selected = 0;
  final MenuStore _menuStore = getIt<MenuStore>();
  final UserStore _userStore = getIt<UserStore>();
  final UserDetailStore _userDetailStore = getIt<UserDetailStore>();
  bool _isKeyboardVisible = false;

  // Pages are instance-scoped and non-const to avoid stale state reuse across sessions
  late final List<Widget> _pages = _initializePages();

  List<Widget> _initializePages() {
    print('🚀 [DashboardShell] Initializing pages array...');
    final pages = <Widget>[];

    try {
      print('  Adding PunchHomeScreen...');
      pages.add(PunchHomeScreen(key: UniqueKey()));
    } catch (e) {
      print('  ❌ Error adding PunchHomeScreen: $e');
    }

    try {
      print('  Adding TourPlanScreen...');
      pages.add(TourPlanScreen(key: UniqueKey()));
    } catch (e) {
      print('  ❌ Error adding TourPlanScreen: $e');
    }

    try {
      print('  Adding CRMShell (DCR)...');
      pages.add(
          CRMShell(key: UniqueKey(), initialIndex: 0, showBottomNav: false));
    } catch (e) {
      print('  ❌ Error adding CRMShell (DCR): $e');
    }

    try {
      print('  Adding CRMShell (Deviations)...');
      pages.add(
          CRMShell(key: UniqueKey(), initialIndex: 1, showBottomNav: false));
    } catch (e) {
      print('  ❌ Error adding CRMShell (Deviations): $e');
    }

    try {
      print('  Adding CustomerIssueListScreen...');
      pages.add(CustomerIssueListScreen(key: UniqueKey()));
    } catch (e) {
      print('  ❌ Error adding CustomerIssueListScreen: $e');
    }

    print('  Created ${pages.length} pages, now adding Sales...');
    try {
      print('  Attempting to create SaleOrderListScreen...');
      final salesScreen = SaleOrderListScreen(key: UniqueKey());
      print('  ✅ SaleOrderListScreen created successfully');
      pages.add(salesScreen);
      print(
          '  ✅ Successfully added SaleOrderListScreen. Total pages: ${pages.length}');
    } catch (e, stackTrace) {
      print('  ❌❌❌ ERROR creating SaleOrderListScreen: $e');
      print('  Stack trace: $stackTrace');
    }

    try {
      pages.add(SalesBonusApprovalScreen(key: UniqueKey()));
    } catch (e) {
      print('  ❌ Error adding SalesBonusApprovalScreen: $e');
    }
    print('🏁 [DashboardShell] Final pages count: ${pages.length}');
    print(
        '🏁 [DashboardShell] Pages: ${pages.map((p) => p.runtimeType.toString()).toList()}');
    return pages;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Load menu, user details, and validate user in parallel without blocking UI
    Future.wait([
      _loadMenu(),
      _loadUserDetails(),
      _validateUser(),
    ]).catchError((Object e) {
      debugPrint('DashboardShell: initial load failed: $e');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeMetrics() {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    final bottomInset = views.isNotEmpty ? views.first.viewInsets.bottom : 0.0;
    final isVisible = bottomInset > 0;
    if (mounted && isVisible != _isKeyboardVisible) {
      setState(() {
        _isKeyboardVisible = isVisible;
      });
    }
    super.didChangeMetrics();
  }

  Future<void> _loadMenu() async {
    if (_userStore.currentUser != null) {
      await _menuStore.getMenu(
        groupName: 'Dashboard',
        pageName: 'Main',
        userId: _userStore.currentUser!.id,
      );
    }
  }

  Future<void> _loadUserDetails() async {
    if (_userStore.currentUser != null) {
      try {
        print('GET USER BY ID API CALL');
        print('User ID: ${_userStore.currentUser!.id}');
        print('Auth Token: ${_userStore.currentUser!.token}');
        // Set the auth token first
        _userDetailStore.setAuthToken(_userStore.currentUser!.token);

        // Then fetch user details
        await _userDetailStore.fetchUserById(_userStore.currentUser!.id);

        print('GET USER BY ID API RESPONSE');
        if (_userDetailStore.userDetail != null) {
          final user = _userDetailStore.userDetail!;
          print('User ID: ${user.id}');
          print('First Name: ${user.firstName}');
          print('Last Name: ${user.lastName}');
          print('Email: ${user.email}');
          print('Company: ${user.company}');
          print('Service Area: ${user.serviceArea}');
          print('Divisions: ${user.divisions}');
          print('Roles: ${user.roles}');
        } else {
          print('User Detail: null');
        }
      } catch (e) {
        print('GET USER BY ID API ERROR');
        print('Error: $e');
      }
    }
  }

  Future<void> _validateUser() async {
    if (_userStore.currentUser != null) {
      try {
        if (getIt.isRegistered<UserValidationStore>()) {
          final validationStore = getIt<UserValidationStore>();
          final int? employeeId = _userDetailStore.userDetail?.employeeId;
          if (employeeId != null && employeeId > 0) {
            await validationStore.validateUser(employeeId);
          } else {
            print('User validation skipped: employeeId not available');
          }
          print('User validation result: ${validationStore.isUserValid}');
        }
      } catch (e) {
        print('User validation error: $e');
      }
    }
  }

  void _onNavSelect(int i) {
    print('Navigation selected: $i, Total pages: ${_pages.length}');
    print(
        'Pages list: ${_pages.map((p) => p.runtimeType.toString()).toList()}');

    // Hot reload can keep old state where _pages was initialized before
    // Bonus Approval page was added. Open it directly as a safe fallback.
    if (i == 6 && i >= _pages.length) {
      Navigator.of(context).maybePop();
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const SalesBonusApprovalScreen(),
        ),
      );
      return;
    }

    if (_selected != i) {
      // Ensure index is within bounds
      if (i >= 0 && i < _pages.length) {
        setState(() {
          _selected = i;
        });
        print('Current selected index: $_selected');
        
        // Refresh summary data when switching to home tab (index 0)
        if (i == 0) {
          // Use postFrameCallback to ensure the widget is fully built before refreshing
          WidgetsBinding.instance.addPostFrameCallback((_) {
            // Add a small delay to ensure everything is ready
            Future.delayed(const Duration(milliseconds: 150), () {
              print('🔄 [DashboardShell] Refreshing home screen data after tab switch...');
              PunchHomeScreen.refreshSummaryData();
            });
          });
        }
        
        // Re-validate user when switching to a different screen
        // This ensures buttons are properly enabled/disabled based on current validation
        _validateUser();
      } else {
        print(
            'ERROR: Index $i is out of bounds! Array length: ${_pages.length}');
      }
    }
  }

  // Modern teal-green color matching login screen
  static const Color tealGreen = Color(0xFF4db1b3);

  Widget _buildModernBottomNav(BuildContext context, int selected,
      ValueChanged<int> onSelect, List<NavigationDestination> destinations) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final baseBottomPadding = isTablet ? 12.0 : 10.0;
    final bottomSpacing =
        safeBottom > 0 ? baseBottomPadding + 8 : baseBottomPadding;

    // Clamp selected index to valid range for bottom nav
    final clampedSelected = selected < destinations.length ? selected : -1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: Container(
        padding: EdgeInsets.only(
          left: isTablet ? 24 : 16,
          right: isTablet ? 24 : 16,
          top: isTablet ? 12 : 10,
          // Let outer SafeArea handle system insets and only add breathing room here
          bottom: bottomSpacing,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: List.generate(destinations.length, (index) {
            final dest = destinations[index];
            final isSelected = clampedSelected == index;
            final iconWidget = isSelected
                ? (dest.selectedIcon ?? dest.icon ?? const Icon(Icons.circle))
                : (dest.icon ?? const Icon(Icons.circle));
            return Expanded(
              child: _EnhancedNavItem(
                icon: iconWidget,
                label: dest.label,
                isSelected: isSelected,
                onTap: () => onSelect(index),
                isTablet: isTablet,
                isMobile: isMobile,
              ),
            );
          }),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use a higher breakpoint so tablets (e.g., iPad Pro 11"/Surface) still get the bottom nav
    final isWide = MediaQuery.of(context).size.width >= 1200;
    final destinations = const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Home',
      ),
      NavigationDestination(
        icon: Icon(Icons.route_outlined),
        selectedIcon: Icon(Icons.route),
        label: 'Tour Plan',
      ),
      NavigationDestination(
        icon: Icon(Icons.assignment_outlined),
        selectedIcon: Icon(Icons.assignment),
        label: 'DCR',
      ),
      NavigationDestination(
        icon: Icon(Icons.report_gmailerrorred_outlined),
        selectedIcon: Icon(Icons.report_gmailerrorred),
        label: 'Deviations',
      ),
      NavigationDestination(
        icon: Icon(Icons.error_outline),
        selectedIcon: Icon(Icons.error),
        label: 'Sample Issue',
      ),
    ];

    if (isWide) {
      return _ShellScaffold(
        drawer: _SideMenu(
          selected: _selected,
          onSelect: (i) {
            Navigator.of(context).maybePop(); // close drawer if open
            _onNavSelect(i);
          },
          extended: true,
          userDetailStore: _userDetailStore,
          userStore: _userStore,
        ),
        child: _selected < _pages.length ? _pages[_selected] : _pages[0],
        userDetailStore: _userDetailStore,
      );
    }

    return _ShellScaffold(
      drawer: _SideMenu(
        selected: _selected,
        onSelect: (i) {
          Navigator.of(context).maybePop(); // close drawer if open
          _onNavSelect(i);
        },
        userDetailStore: _userDetailStore,
        userStore: _userStore,
      ),
      userDetailStore: _userDetailStore,
      bottomNav: _isKeyboardVisible || _selected >= destinations.length
          ? null
          : _buildModernBottomNav(
              context, _selected, _onNavSelect, destinations),
      child: _selected < _pages.length ? _pages[_selected] : _pages[0],
    );
  }
}

class _ShellScaffold extends StatelessWidget {
  final Widget drawer;
  final Widget child;
  final Widget? bottomNav;
  final UserDetailStore userDetailStore;
  const _ShellScaffold(
      {required this.drawer,
      required this.child,
      this.bottomNav,
      required this.userDetailStore});

  // Modern teal-green color matching login screen
  static const Color tealGreen = Color(0xFF4db1b3);

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final bool isKeyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      drawer: Drawer(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: drawer,
      ),
      appBar: _buildModernAppBar(context, isTablet, isMobile),
      body: child,
      bottomNavigationBar: bottomNav != null && !isKeyboardVisible
          ? SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true,
              child: bottomNav!,
            )
          : null,
    );
  }

  PreferredSizeWidget _buildModernAppBar(
      BuildContext context, bool isTablet, bool isMobile) {
    return AppBar(
      automaticallyImplyLeading: false,
      centerTitle: false,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: isTablet ? 80 : (isMobile ? 70 : 72),
      titleSpacing: isTablet ? 24 : 20,
      title: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16 : 12,
          vertical: isTablet ? 10 : 8,
        ),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey[200]!,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: isTablet ? 44 : 40,
              height: isTablet ? 44 : 40,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [tealGreen, tealGreen.withOpacity(0.8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: tealGreen.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: isTablet ? 24 : 22,
              ),
            ),
            SizedBox(width: isTablet ? 14 : 12),
            Flexible(
              child: ListenableBuilder(
                listenable: userDetailStore,
                builder: (context, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        userDetailStore.userDisplayName.isNotEmpty
                            ? userDetailStore.userDisplayName
                            : 'Loading...',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: Colors.grey[900],
                        ),
                      ),
                      if (isTablet) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Welcome back',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: isTablet ? 20.0 : 16.0),
          child: Builder(
            builder: (ctx) => Container(
              decoration: BoxDecoration(
                color: tealGreen.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => Scaffold.of(ctx).openDrawer(),
                  child: Padding(
                    padding: EdgeInsets.all(isTablet ? 14.0 : 12.0),
                    child: Icon(
                      Icons.menu_rounded,
                      color: tealGreen,
                      size: isTablet ? 26 : 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SideMenu extends StatelessWidget {
  final int selected;
  final bool extended;
  final ValueChanged<int> onSelect;
  final UserDetailStore userDetailStore;
  final UserStore userStore;
  const _SideMenu(
      {required this.selected,
      required this.onSelect,
      this.extended = false,
      required this.userDetailStore,
      required this.userStore});

  // Modern teal-green color matching login screen
  static const Color tealGreen = Color(0xFF4db1b3);

  @override
  Widget build(BuildContext context) {
    final ThemeStore themeStore = getIt<ThemeStore>();
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      width: extended ? (isTablet ? 320 : 280) : (isTablet ? 280 : 260),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white,
            Colors.grey[50]!,
          ],
        ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 30,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Modern header with user info
            Container(
              padding: EdgeInsets.all(isTablet ? 28 : 24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tealGreen,
                    tealGreen.withOpacity(0.85),
                  ],
                ),
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(32),
                ),
              ),
              child: ListenableBuilder(
                listenable: userDetailStore,
                builder: (context, child) {
                  return Row(
                    children: [
                      Container(
                        width: isTablet ? 56 : 52,
                        height: isTablet ? 56 : 52,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.25),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: isTablet ? 28 : 26,
                        ),
                      ),
                      SizedBox(width: isTablet ? 16 : 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userDetailStore.userDisplayName.isNotEmpty
                                  ? userDetailStore.userDisplayName
                                  : 'Loading...',
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 18 : 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: -0.3,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'View profile',
                              style: GoogleFonts.inter(
                                fontSize: isTablet ? 13 : 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withOpacity(0.9),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 16 : 12,
                  vertical: isTablet ? 20 : 16,
                ),
                children: [
                  _ModernDrawerItem(
                    icon: Icons.home_outlined,
                    selectedIcon: Icons.home,
                    label: 'Home',
                    selected: selected == 0,
                    onTap: () => onSelect(0),
                    isTablet: isTablet,
                  ),
                  SizedBox(height: isTablet ? 8 : 6),
                  _ModernDrawerItem(
                    icon: Icons.route_outlined,
                    selectedIcon: Icons.route,
                    label: 'Tour Plan',
                    selected: selected == 1,
                    onTap: () => onSelect(1),
                    isTablet: isTablet,
                  ),
                  SizedBox(height: isTablet ? 8 : 6),
                  _ModernDrawerItem(
                    icon: Icons.assignment_outlined,
                    selectedIcon: Icons.assignment,
                    label: 'DCR',
                    selected: selected == 2,
                    onTap: () => onSelect(2),
                    isTablet: isTablet,
                  ),
                  SizedBox(height: isTablet ? 8 : 6),
                  _ModernDrawerItem(
                    icon: Icons.report_gmailerrorred_outlined,
                    selectedIcon: Icons.report_gmailerrorred,
                    label: 'Deviations',
                    selected: selected == 3,
                    onTap: () => onSelect(3),
                    isTablet: isTablet,
                  ),
                  SizedBox(height: isTablet ? 8 : 6),
                  _ModernDrawerItem(
                    icon: Icons.error_outline,
                    selectedIcon: Icons.error,
                    label: 'Sample Issue',
                    selected: selected == 4,
                    onTap: () => onSelect(4),
                    isTablet: isTablet,
                  ),
                  SizedBox(height: isTablet ? 8 : 6),
                  ListenableBuilder(
                    listenable: userDetailStore,
                    builder: (context, _) {
                      final isSalesRep =
                          userDetailStore.userDetail?.roleCategory == 3 &&
                              userDetailStore.userDetail?.repType == 1;
                      final isManager =
                          (userDetailStore.userDetail?.roleCategory) != 3;
                      if (!isSalesRep && !isManager) {
                        return const SizedBox.shrink();
                      }
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isSalesRep)
                            _ModernDrawerItem(
                              icon: Icons.sell_outlined,
                              selectedIcon: Icons.sell,
                              label: 'Sales',
                              selected: selected == 5,
                              onTap: () => onSelect(5),
                              isTablet: isTablet,
                            ),
                          if (isManager) ...[
                            if (isSalesRep) SizedBox(height: isTablet ? 8 : 6),
                            _ModernDrawerItem(
                              icon: Icons.card_giftcard_outlined,
                              selectedIcon: Icons.card_giftcard,
                              label: 'Bonus Approval',
                              selected: selected == 6,
                              onTap: () => onSelect(6),
                              isTablet: isTablet,
                            ),
                          ],
                        ],
                      );
                    },
                  ),

                  //  _DrawerItem(
                  //           icon: Icons.sell,
                  //           label: 'Sales List',
                  //           selected: false,
                  //           onTap: () => {
                  //             Navigator.pushNamed(context, Routes.saleList)
                  //           },
                  //         ),
                  // const Divider(indent: 16, endIndent: 16),
                  // Padding(
                  //   padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  //   child: Text('CRM Pages', style: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700)),
                  // ),
                  // _DrawerItem(
                  //   icon: Icons.assignment_outlined,
                  //   label: 'DCR',
                  //   selected: selected == 1,
                  //   onTap: () => onSelect(1),
                  // ),
                  // _DrawerItem(
                  //   icon: Icons.report_gmailerrorred_outlined,
                  //   label: 'Deviations',
                  //   selected: selected == 2,
                  //   onTap: () => onSelect(2),
                  // ),
                  // _DrawerItem(
                  //   icon: Icons.route_outlined,
                  //   label: 'Tour Plan',
                  //   selected: selected == 0,
                  //   onTap: () => onSelect(0),
                  // ),
                  // _DrawerItem(
                  //   icon: Icons.description_outlined,
                  //   label: 'Contracts',
                  //   selected: selected == 3,
                  //   onTap: () => onSelect(3),
                  // ),
                ],
              ),
            ),
            // Footer with logout
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 20 : 16,
              ),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: _ModernDrawerItem(
                icon: Icons.logout_rounded,
                selectedIcon: Icons.logout_rounded,
                label: 'Log out',
                selected: false,
                onTap: () async {
                  // Punch out if user is punched in
                  await PunchHomeScreen.punchOutIfNeeded();
                  // Call logout to clear user data from SharedPreferences
                  await userStore.logout();
                  if (Navigator.of(context).canPop())
                    Navigator.of(context).pop();
                  Navigator.of(context).pushReplacementNamed(Routes.login);
                },
                isTablet: isTablet,
                isLogout: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernDrawerItem extends StatelessWidget {
  final IconData icon;
  final IconData? selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isTablet;
  final bool isLogout;

  static const Color tealGreen = Color(0xFF4db1b3);

  const _ModernDrawerItem({
    required this.icon,
    this.selectedIcon,
    required this.label,
    required this.onTap,
    this.selected = false,
    required this.isTablet,
    this.isLogout = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 18 : 16,
            vertical: isTablet ? 16 : 14,
          ),
          decoration: BoxDecoration(
            color: selected ? tealGreen.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            border: selected
                ? Border.all(
                    color: tealGreen.withOpacity(0.3),
                    width: 1.5,
                  )
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: selected
                      ? tealGreen
                      : (isLogout ? Colors.red[50] : Colors.grey[100]),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected && selectedIcon != null ? selectedIcon : icon,
                  color: selected
                      ? Colors.white
                      : (isLogout ? Colors.red[600] : Colors.grey[700]),
                  size: isTablet ? 24 : 22,
                ),
              ),
              SizedBox(width: isTablet ? 16 : 14),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    color: selected
                        ? tealGreen
                        : (isLogout ? Colors.red[600] : Colors.grey[900]),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.chevron_right_rounded,
                  color: tealGreen,
                  size: isTablet ? 22 : 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EnhancedNavItem extends StatelessWidget {
  final Widget icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isTablet;
  final bool isMobile;

  static const Color tealGreen = Color(0xFF4db1b3);

  const _EnhancedNavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isTablet,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        splashColor: tealGreen.withOpacity(0.1),
        highlightColor: tealGreen.withOpacity(0.05),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 12 : (isMobile ? 4 : 8),
            vertical: isTablet ? 10 : 8,
          ),
          decoration: BoxDecoration(
            color:
                isSelected ? tealGreen.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(
                    color: tealGreen.withOpacity(0.2),
                    width: 1,
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Icon with enhanced styling
              Container(
                padding: EdgeInsets.all(isTablet ? 8 : (isMobile ? 6 : 7)),
                decoration: BoxDecoration(
                  color: isSelected ? tealGreen : Colors.transparent,
                  borderRadius: BorderRadius.circular(isTablet ? 14 : 12),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: tealGreen.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: IconTheme(
                  data: IconThemeData(
                    color: isSelected ? Colors.white : Colors.grey[600],
                    size: isTablet ? 26 : (isMobile ? 22 : 24),
                  ),
                  child: icon,
                ),
              ),
              SizedBox(height: isTablet ? 6 : (isMobile ? 4 : 5)),
              // Label with better typography
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: isTablet ? 12 : (isMobile ? 10 : 11),
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isSelected ? tealGreen : Colors.grey[600],
                  letterSpacing: isSelected ? 0.3 : 0.2,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String label;
  const _PlaceholderPage({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label, style: Theme.of(context).textTheme.headlineMedium),
    );
  }
}
