import 'package:flutter/material.dart';

import 'dcr/dcr_list_screen.dart';
import 'dcr/dcr_entry_screen.dart';
import 'manager_review_screen.dart';
import 'deviation/deviation_list_screen.dart';
import 'deviation/deviation_entry_screen.dart';
import 'deviation/deviation_manager_review_screen.dart';
import 'tour_plan/tour_plan_list_screen.dart';
import 'tour_plan/tour_plan_entry_screen.dart';
import 'tour_plan/tour_plan_manager_review_screen.dart';
import 'sale_contract/sale_contract_list_screen.dart';
import 'sale_contract/sale_contract_entry_screen.dart';
import 'widgets/section_scaffold.dart';
import 'package:boilerplate/utils/routes/routes.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';

class CRMShell extends StatefulWidget {
  const CRMShell({super.key, this.initialIndex = 0, this.showBottomNav = true});

  final int initialIndex;
  final bool? showBottomNav;

  @override
  State<CRMShell> createState() => _CRMShellState();
}

class _CRMShellState extends State<CRMShell> with WidgetsBindingObserver {
  int _currentIndex = 0;
  bool _isKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentIndex = widget.initialIndex.clamp(0, _pages.length - 1);
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

  @override
  void didUpdateWidget(covariant CRMShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIndex != oldWidget.initialIndex) {
      final int next = widget.initialIndex.clamp(0, _pages.length - 1);
      if (_currentIndex != next) {
        setState(() {
          _currentIndex = next;
        });
      }
    }
  }

  List<Widget> get _pages {
    // Check if Manager Review tab should be hidden (roleCategory == 3)
    final UserDetailStore? userStore = getIt.isRegistered<UserDetailStore>() ? getIt<UserDetailStore>() : null;
    final shouldHideManagerReview = userStore?.userDetail?.roleCategory == 3;
    
    return <Widget>[
            CRMSectionScaffold(
              title: 'Daily Call Report',
              showTitle: false,
              tabs: shouldHideManagerReview
                  ? [
                      Tab(
                        child: Builder(
                          builder: (context) {
                            final isTablet = MediaQuery.of(context).size.width >= 600;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.description_outlined, size: isTablet ? 20 : 18),
                                SizedBox(width: isTablet ? 8 : 6),
                                const Text('My DCR'),
                              ],
                            );
                          },
                        ),
                      ),
                    ]
                  : [
                      Tab(
                        child: Builder(
                          builder: (context) {
                            final isTablet = MediaQuery.of(context).size.width >= 600;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.description_outlined, size: isTablet ? 20 : 18),
                                SizedBox(width: isTablet ? 8 : 6),
                                const Text('My DCR'),
                              ],
                            );
                          },
                        ),
                      ),
                      Tab(
                        child: Builder(
                          builder: (context) {
                            final isTablet = MediaQuery.of(context).size.width >= 600;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.verified_user_outlined, size: isTablet ? 20 : 18),
                                SizedBox(width: isTablet ? 8 : 6),
                                const Text('Manager Review'),
                              ],
                            );
                          },
                        ),
                      ),
                    ],
              tabViews: shouldHideManagerReview
                  ? [const DcrListScreen(key: ValueKey('dcr_v2'))]
                  : [const DcrListScreen(key: ValueKey('dcr_v2')), const ManagerReviewScreen()],
            ),
        CRMSectionScaffold(
          title: 'Deviations',
          showTitle: false,
          tabs: shouldHideManagerReview
              ? [
                  Tab(
                    child: Builder(
                      builder: (context) {
                        final isTablet = MediaQuery.of(context).size.width >= 600;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.report_gmailerrorred_outlined, size: isTablet ? 20 : 18),
                            SizedBox(width: isTablet ? 8 : 6),
                            const Text('My Deviations'),
                          ],
                        );
                      },
                    ),
                  ),
                ]
              : [
                  Tab(
                    child: Builder(
                      builder: (context) {
                        final isTablet = MediaQuery.of(context).size.width >= 600;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.report_gmailerrorred_outlined, size: isTablet ? 20 : 18),
                            SizedBox(width: isTablet ? 8 : 6),
                            const Text('My Deviations'),
                          ],
                        );
                      },
                    ),
                  ),
                  Tab(
                    child: Builder(
                      builder: (context) {
                        final isTablet = MediaQuery.of(context).size.width >= 600;
                        return Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.verified_user_outlined, size: isTablet ? 20 : 18),
                            SizedBox(width: isTablet ? 8 : 6),
                            const Text('Manager Review'),
                          ],
                        );
                      },
                    ),
                  ),
                ],
          tabViews: shouldHideManagerReview
              ? const [DeviationListScreen()]
              : const [DeviationListScreen(), DeviationManagerReviewScreen()],
        ),
        // Expenses tab removed per requirement
        CRMSectionScaffold(
          title: 'Tour Plan',
          tabs: [
            Tab(
              child: Builder(
                builder: (context) {
                  final isTablet = MediaQuery.of(context).size.width >= 600;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.route_outlined, size: isTablet ? 20 : 18),
                      SizedBox(width: isTablet ? 8 : 6),
                      const Text('My Plans'),
                    ],
                  );
                },
              ),
            ),
            Tab(
              child: Builder(
                builder: (context) {
                  final isTablet = MediaQuery.of(context).size.width >= 600;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_outlined, size: isTablet ? 20 : 18),
                      SizedBox(width: isTablet ? 8 : 6),
                      const Text('Manager Review'),
                    ],
                  );
                },
              ),
            ),
          ],
          tabViews: const [TourPlanListScreen(), TourPlanManagerReviewScreen()],
          fab: Builder(
            builder: (ctx) => FloatingActionButton.extended(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const TourPlanEntryScreen()),
              ),
              icon: const Icon(Icons.add),
              label: const Text('New Plan'),
            ),
          ),
        ),
        CRMSectionScaffold(
          title: 'Sale Contracts',
          showTitle: false,
          tabs: const [Tab(text: 'My Contracts'), Tab(text: 'Manager Review')],
          tabViews: const [SaleContractListScreen(), _SaleContractManagerReviewList()],
          fab: Builder(
            builder: (ctx) => FloatingActionButton.extended(
              onPressed: () => Navigator.of(ctx).push(
                MaterialPageRoute(builder: (_) => const SaleContractEntryScreen()),
              ),
              icon: const Icon(Icons.add),
              foregroundColor: Colors.white,
              label: const Text('New Contract'),
            ),
          ),
        ),
      ];
  }

  void _onFabPressed() {
    switch (_currentIndex) {
      case 0:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DcrEntryScreen()),
        );
        break;
      case 1:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const DeviationEntryScreen()),
        );
        break;
      case 2:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const TourPlanEntryScreen()),
        );
        break;
      case 3:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SaleContractEntryScreen()),
        );
        break;
    }
  }

  void _refreshDeviationList(BuildContext context) {
    // Use static method to refresh the current DeviationListScreen instance
    DeviationListScreen.refreshCurrentInstance();
    print('CRMShell: Triggered deviation list refresh via static method');
  }

  // Allow external controllers (like the sidebar) to switch tabs
  void setTab(int index) {
    if (index < 0 || index >= _pages.length) return;
    if (!mounted) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_currentIndex],
      ),
      bottomNavigationBar: (widget.showBottomNav == true && !_isKeyboardVisible)
          ? SafeArea(
              top: false,
              left: false,
              right: false,
              bottom: true,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6FAFF).withOpacity(.95), // light blue bg
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.08),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      )
                    ],
                  ),
                  child: NavigationBar(
                    backgroundColor: Colors.transparent,
                    indicatorColor: const Color(0xFF2B78FF).withOpacity(.12),
                    selectedIndex: _currentIndex,
                    onDestinationSelected: (index) {
                      // When shown standalone, navigate to named routes so URL/route reflects tab
                      // When embedded (showBottomNav == false), we don't reach here
                      switch (index) {
                        case 0:
                          Navigator.of(context).pushReplacementNamed(Routes.crmDcr);
                          break;
                        case 1:
                          Navigator.of(context).pushReplacementNamed(Routes.crmDeviation);
                          break;
                        case 2:
                          Navigator.of(context).pushReplacementNamed(Routes.crmTourPlan);
                          break;
                        case 3:
                          Navigator.of(context).pushReplacementNamed(Routes.crmContracts);
                          break;
                        default:
                          setState(() => _currentIndex = index);
                      }
                    },
                    // Always show labels
                    labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                    destinations: const [
                      NavigationDestination(
                        icon: Icon(Icons.assignment_outlined),
                        selectedIcon: Icon(Icons.assignment),
                        label: 'DCR',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.report_gmailerrorred_outlined),
                        selectedIcon: Icon(Icons.report_gmailerrorred),
                        label: 'Deviation',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.route_outlined),
                        selectedIcon: Icon(Icons.route),
                        label: 'Tour Plan',
                      ),
                      NavigationDestination(
                        icon: Icon(Icons.description_outlined),
                        selectedIcon: Icon(Icons.description),
                        label: 'Contracts',
                      ),
                    ],
                  ),
                ),
              ),
            )
          : null,
    );
  }
}

class _DcrManagerBottomActionBar extends StatelessWidget {
  const _DcrManagerBottomActionBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border.all(color: Colors.black.withOpacity(.06)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(.05), blurRadius: 10, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: const Icon(Icons.check),
                label: const Text('Approve (0)'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 44),
                ),
                onPressed: null, // Will be controlled by the manager review screen
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.undo),
                label: const Text('Send Back'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 44),
                ),
                onPressed: null, // Will be controlled by the manager review screen
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.cancel, color: Colors.redAccent),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  foregroundColor: Colors.red,
                  side: BorderSide(color: Colors.redAccent.withOpacity(.7)),
                ),
                onPressed: null, // Will be controlled by the manager review screen
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleContractManagerReviewList extends StatelessWidget {
  const _SaleContractManagerReviewList();
  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) => Card(
        child: ListTile(
          leading: const Icon(Icons.verified_outlined),
          title: Text('Review Contract #${index + 1}'),
          subtitle: const Text('Employee: Sarah • Status: Pending'),
          trailing: Wrap(
            spacing: 8,
            children: [
              IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), onPressed: () {}),
              IconButton(icon: const Icon(Icons.cancel, color: Colors.redAccent), onPressed: () {}),
            ],
          ),
        ),
      ),
    );
  }
}
