import 'package:flutter/material.dart';
import 'package:boilerplate/core/widgets/month_calendar.dart';
import 'package:boilerplate/presentation/crm/tour_plan/widgets/status_summary.dart';
import 'package:boilerplate/presentation/crm/tour_plan/store/tour_plan_store.dart';
import 'package:boilerplate/presentation/user/store/user_store.dart';
import 'package:boilerplate/di/service_locator.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:boilerplate/domain/entity/tour_plan/tour_plan.dart' as domain;
import 'package:boilerplate/presentation/crm/tour_plan/tour_plan_entry_screen.dart';
import 'package:boilerplate/domain/repository/tour_plan/tour_plan_repository.dart';
import 'package:boilerplate/core/stores/error/error_store.dart';
import 'package:boilerplate/data/repository/tour_plan/tour_plan_repository_impl.dart';
import 'package:boilerplate/presentation/crm/tour_plan/mock/mock_tour_plan.dart';
import 'package:boilerplate/domain/repository/common/common_repository.dart';
import 'package:boilerplate/domain/entity/common/common_api_models.dart';
import 'package:boilerplate/data/network/apis/user/lib/domain/entity/tour_plan/calendar_view_data.dart';
import 'package:boilerplate/data/network/apis/user/lib/domain/entity/tour_plan/tour_plan_api_models.dart';

import '../../../data/sharedpref/shared_preference_helper.dart';

const String kFilterClearToken = '__CLEAR__';

class TourPlanListScreen extends StatefulWidget {
  const TourPlanListScreen({super.key});

  @override
  State<TourPlanListScreen> createState() => _TourPlanListScreenState();
}

class _TourPlanListScreenState extends State<TourPlanListScreen> {
  final Set<TourPlanStatus> _filters = <TourPlanStatus>{};
  String? _customer;
  String? _employee;
  String? _status; // Draft/Pending/Approved/Rejected
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime? _selectedDay;
  late final TourPlanStore _store;
  late final UserDetailStore _userDetailStore;
  final bool _isManager = false; // TODO: wire with real role/permission
  List<domain.TourPlanEntry> _allEntries = <domain.TourPlanEntry>[];
  
  // Customer options loaded from API
  List<String> _customerOptions = [];
  final Map<String, int> _customerNameToId = {};
  
  // Status options loaded from API
  List<String> _statusOptions = [];
  final Map<String, int> _statusNameToId = {};
  
  // Employee options loaded from API
  List<String> _employeeOptions = [];
  final Map<String, int> _employeeNameToId = {};
  
  int _dataVersion = 0;

  @override
  void initState() {
    super.initState();
    // Ensure registration in hot-reload scenarios then resolve
    if (!getIt.isRegistered<TourPlanRepository>()) {
      getIt.registerSingleton<TourPlanRepository>(TourPlanRepositoryImpl(
        sharedPreferenceHelper: getIt<SharedPreferenceHelper>(),
      ));
    }
    if (!getIt.isRegistered<TourPlanStore>()) {
      getIt.registerSingleton<TourPlanStore>(
        TourPlanStore(
          getIt<TourPlanRepository>(),
          getIt<ErrorStore>(),
        ),
      );
    }
    _store = getIt<TourPlanStore>();
    _userDetailStore = getIt<UserDetailStore>();
    _store.month = _month;
    // Use mock constant data for now
    _allEntries = mockTourPlanEntriesForMonth(_month);
    _applyFilters();
    // Load initial data from API
    _refreshAll();
    _getTourPlanStatusList();
    _loadMappedCustomersByEmployeeId(); // Load customer list using API
    _getEmployeeList();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime demoMonth = _month;
    // Colors matching the screenshot style
    const Color green = Color(0xFF2DBE64);
    const Color yellow = Color(0xFFFFA41C);
    const Color blue = Color(0xFF2B78FF);
    const Color orange = Color(0xFFFF6A21);

    final Map<DateTime, CalendarDayDecoration> decorations = _buildDayDecorations(_store.entries);

    final List<CalendarLegendItem> legend = const <CalendarLegendItem>[
      CalendarLegendItem(label: 'Approved', color: green, count: 1),
      CalendarLegendItem(label: 'Sent', color: Colors.redAccent, count: 1),
      CalendarLegendItem(label: 'Planned', color: blue, count: 1),
      CalendarLegendItem(label: 'Draft/Ped..', color: yellow, count: 1),
    ];
    return RefreshIndicator(
      onRefresh: _onPullToRefresh,
      edgeOffset: 12,
      displacement: 36,
      child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Enhanced Filters Section - Same as DCR Deviation UI
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                children: [
                    // Section Title
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Filter Settings',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Responsive Filters Layout
                    LayoutBuilder(
                      builder: (context, constraints) {
                        // Determine if we should use single row or wrap layout
                        // Use single row only for very wide screens (tablets and larger)
                        final bool useSingleRow = constraints.maxWidth > 800;
                        
                        if (useSingleRow) {
                          // Single row layout for larger screens
                          return Row(
                            children: [
                              // Customer Filter
                              Expanded(
                                child: _EnhancedActionPill(
                                  icon: Icons.person_outline,
                                  label: _customer ?? 'Customer',
                                  isActive: _customer != null,
                                  onTap: () async {
                                    if (_customerOptions.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('⚠ No customers available. Please try again.'),
                                          backgroundColor: Colors.orange,
                                          duration: const Duration(seconds: 3),
                                          behavior: SnackBarBehavior.floating,
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        ),
                                      );
                                      return;
                                    }
                                    
                                    print('TourPlanListScreen: Customer filter tapped - options count: ${_customerOptions.length}');
                                    final String? selected = await _pickFromList(
                                      context,
                                      title: 'Select Customer',
                                      options: _customerOptions,
                                      selected: _customer,
                                      searchable: true,
                                    );
                                    if (selected != null) {
                                      setState(() {
                                        _customer = selected == kFilterClearToken ? null : selected;
                                        _dataVersion++;
                                      });
                                      // Force hard refresh - reload data with updated filter
                                      await Future.wait([
                                        _loadCalendarViewData(),
                                        _loadCalendarItemListData(),
                                      ]);
                                      // Apply filters after data is loaded
                                      if (mounted) {
                                        setState(() {
                                          _applyFilters();
                                        });
                                      }
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              
                              // Status Filter
                              Expanded(
                                child: _EnhancedActionPill(
                                  icon: Icons.verified_outlined,
                                  label: _status ?? 'Status',
                                  isActive: _status != null,
                                  onTap: () async {
                                    final statusOptions = _statusOptions.isNotEmpty 
                                        ? _statusOptions 
                                        : const ['Draft','Pending','Approved','Rejected'];
                                    
                                    final value = await _pickFromList(
                                      context, 
                                      title: 'Select Status', 
                                      options: statusOptions, 
                                      selected: _status
                                    );
                                    if (value != null) {
                                      setState(() {
                                        _status = value == kFilterClearToken ? null : value;
                                        _dataVersion++;
                                      });
                                      // Force hard refresh - reload data with updated filter
                                      await Future.wait([
                                        _loadCalendarViewData(),
                                        _loadCalendarItemListData(),
                                      ]);
                                      // Apply filters after data is loaded
                                      if (mounted) {
                                        setState(() {
                                          _applyFilters();
                                        });
                                      }
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              
                              // Employee Filter (only for managers)
                              if (_isManager) ...[
                                Expanded(
                                  child: _EnhancedActionPill(
                                    icon: Icons.badge_outlined,
                                    label: _employee ?? 'Employee',
                                    isActive: _employee != null,
                                    onTap: () async {
                                      final employeeOptions = _employeeOptions.isNotEmpty 
                                          ? _employeeOptions 
                                          : const ['John Manager','Sam','Alex','Priya'];
                                      
                                      print('TourPlanListScreen: Employee filter tapped - options count: ${employeeOptions.length}');
                                      final selected = await _pickFromList(
                                        context,
                                        title: 'Select Employee', 
                                        options: employeeOptions, 
                                        selected: _employee,
                                        searchable: true,
                                      );
                                      if (selected != null) {
                                        setState(() {
                                          _employee = selected == kFilterClearToken ? null : selected;
                                          _dataVersion++;
                                        });
                                        // Force hard refresh - reload data with updated filter
                                        await Future.wait([
                                          _loadCalendarViewData(),
                                          _loadCalendarItemListData(),
                                          _loadTourPlanEmployeeListSummary(),
                                        ]);
                                        // Apply filters after data is loaded
                                        if (mounted) {
                                          setState(() {
                                            _applyFilters();
                                          });
                                        }
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 12),
                              ],
                              
                              // Clear Filters Button
                              _ClearFiltersButton(
                                onPressed: _clearAllFilters,
                                isActive: _hasActiveFilters(),
                              ),
                            ],
                          );
                        } else {
                          // Wrap layout for smaller screens (mobile)
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // First row: Customer and Status
                              Row(
                                children: [
                                  Expanded(
                                    flex: 1,
                                    child: _EnhancedActionPill(
                                      icon: Icons.person_outline,
                                      label: _customer ?? 'Customer',
                                      isActive: _customer != null,
                                      onTap: () async {
                                        if (_customerOptions.isEmpty) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('⚠ No customers available. Please try again.'),
                                              backgroundColor: Colors.orange,
                                              duration: const Duration(seconds: 3),
                                              behavior: SnackBarBehavior.floating,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                            ),
                                          );
                                          return;
                                        }
                                        
                                        print('TourPlanListScreen: Customer filter tapped (desktop) - options count: ${_customerOptions.length}');
                                        final String? selected = await _pickFromList(
                                          context,
                                          title: 'Select Customer',
                                          options: _customerOptions,
                                          selected: _customer,
                                          searchable: true,
                                        );
                                        if (selected != null) {
                                          setState(() {
                                            _customer = selected == kFilterClearToken ? null : selected;
                                            _dataVersion++;
                                          });
                                          // Force hard refresh - reload data with updated filter
                                          await Future.wait([
                                            _loadCalendarViewData(),
                                            _loadCalendarItemListData(),
                                          ]);
                                          // Apply filters after data is loaded
                                          if (mounted) {
                                            setState(() {
                                              _applyFilters();
                                            });
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    flex: 1,
                                    child: _EnhancedActionPill(
                                      icon: Icons.verified_outlined,
                                      label: _status ?? 'Status',
                                      isActive: _status != null,
                                      onTap: () async {
                                        final statusOptions = _statusOptions.isNotEmpty 
                                            ? _statusOptions 
                                            : const ['Draft','Pending','Approved','Rejected'];
                                        
                                        final value = await _pickFromList(
                                          context, 
                                          title: 'Select Status', 
                                          options: statusOptions, 
                                          selected: _status
                                        );
                                        if (value != null) {
                                          setState(() {
                                            _status = value == kFilterClearToken ? null : value;
                                            _dataVersion++;
                                          });
                                          // Force hard refresh - reload data with updated filter
                                          await Future.wait([
                                            _loadCalendarViewData(),
                                            _loadCalendarItemListData(),
                                          ]);
                                          // Apply filters after data is loaded
                                          if (mounted) {
                                            setState(() {
                                              _applyFilters();
                                            });
                                          }
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              
                              // Second row: Employee (if manager) and Clear button
                              Row(
                                children: [
                                  if (_isManager) ...[
                                    Expanded(
                                      flex: 2,
                                      child: _EnhancedActionPill(
                                        icon: Icons.badge_outlined,
                                        label: _employee ?? 'Employee',
                                        isActive: _employee != null,
                                        onTap: () async {
                                          final employeeOptions = _employeeOptions.isNotEmpty 
                                              ? _employeeOptions 
                                              : const ['John Manager','Sam','Alex','Priya'];
                                          
                                          print('TourPlanListScreen: Employee filter tapped (desktop) - options count: ${employeeOptions.length}');
                                          final selected = await _pickFromList(
                                            context,
                                            title: 'Select Employee', 
                                            options: employeeOptions, 
                                            selected: _employee,
                                            searchable: true,
                                          );
                                          if (selected != null) {
                                            setState(() {
                                              _employee = selected == kFilterClearToken ? null : selected;
                                              _dataVersion++;
                                            });
                                            // Force hard refresh - reload data with updated filter
                                            await Future.wait([
                                              _loadCalendarViewData(),
                                              _loadCalendarItemListData(),
                                              _loadTourPlanEmployeeListSummary(),
                                            ]);
                                            // Apply filters after data is loaded
                                            if (mounted) {
                                              setState(() {
                                                _applyFilters();
                                              });
                                            }
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                  ],
                                  Expanded(
                                    flex: 1,
                                    child: _ClearFiltersButton(
                                      onPressed: _clearAllFilters,
                                      isActive: _hasActiveFilters(),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              Observer(builder: (_) {
                // Use API calendar item list data for counts
                final counts = _buildMonthlyCountsFromApi(_store.calendarItemListData);
                return StatusDonutCard(
                  counts: counts,
                  title: 'Monthly Status Summary',
                );
              }),

              const SizedBox(height: 12),

              // Calendar
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double calendarWidth = constraints.maxWidth;
                      return Observer(builder: (_) {
                        // Use API calendar view data instead of mock entries
                        final Map<DateTime, CalendarDayDecoration> reactiveDecorations = _buildApiDayDecorations(_store.calendarViewData);
                        return Stack(
                          children: [
                            MonthCalendar(
                              key: ValueKey('list-month-cal-$_dataVersion-${_employee}-${_customer}-${_status}'),
                              width: calendarWidth,
                              visibleMonth: demoMonth,
                              selectedDate: _selectedDay,
                              cellSpacing: 10,
                              cellCornerRadius: 12,
                              onDateTap: (d) => setState(() => _selectedDay = d),
                          onMonthChanged: (m) async {
                                setState(() {
                                  _month = DateTime(m.year, m.month, 1);
                                  _selectedDay = null;
                                  _store.month = _month;
                                  _dataVersion++;
                                });
                                // Load calendar and list data for new month
                                await Future.wait([
                                  _loadCalendarViewData(),
                                  _loadCalendarItemListData(),
                                  _loadTourPlanEmployeeListSummary(),
                                ]);
                                // Apply filters after data is loaded
                                if (mounted) {
                                  setState(() {
                                    _applyFilters();
                                  });
                                }
                              },
                              summaryText: _daysAndHolidaysLabel(_month),
                              dayDecorations: reactiveDecorations,
                              legendItems: legend,
                            ),
                            // Calendar loading overlay
                            if (_store.calendarLoading)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircularProgressIndicator(),
                                        SizedBox(height: 8),
                                        Text('Loading calendar...'),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      });
                    },
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Observer(builder: (_) {
                final DateTime? selected = _selectedDay;
                // Use API calendar item list data instead of mock entries
                final apiItems = selected != null 
                    ? _store.calendarItemListData.where((e) => _isSameDate(e.planDate, selected)).toList()
                    : <TourPlanItem>[];
                if (apiItems.isEmpty && !_store.calendarItemListDataLoading) {
                  if (selected != null) {
                    return const Center(child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('No plans for the selected day.'),
                    ));
                  }
                  return const SizedBox.shrink();
                }
                if (selected == null) return const SizedBox.shrink();
                return _DayPlansCard(
                  date: selected,
                  entries: apiItems.map((item) => domain.TourPlanEntry(
                    id: item.id.toString(),
                    date: item.planDate,
                    cluster: item.cluster ?? '',
                    customer: item.customerName ?? 'Customer ${item.customerId}',
                    employeeId: item.employeeId.toString(),
                    employeeName: item.employeeName ?? '',
                    status: _parseStatusFromApi(item.status),
                    callDetails: domain.TourPlanCallDetails(
                      purposes: [],
                      productsToDiscuss: item.productsToDiscuss,
                      samplesToDistribute: item.samplesToDistribute,
                      remarks: item.remarks,
                    ),
                  )).toList(),
                  onEdit: (entry) async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TourPlanEntryScreen(entry: entry),
                      ),
                    );
                    _applyFilters();
                  },
                );
              }),
            ],
          ),
      ),
      ),
    ));
  }

  Future<void> _onPullToRefresh() async {
    // Reload calendar data and re-apply filters for the current month
    await _refreshAll();
    // Apply filters after data is loaded
    if (mounted) {
      setState(() {
        _applyFilters();
      });
    }
  }

  Map<DateTime, CalendarDayDecoration> _buildApiDayDecorations(List<CalendarViewData> apiData) {
    final Map<DateTime, CalendarDayDecoration> map = <DateTime, CalendarDayDecoration>{};
    for (final d in apiData) {
      // Priority: Holiday > Weekend > Status-derived > Planned
      Color? color;
      if (d.isHolidayDay == true) {
        color = Colors.purple; // Leave/Holiday
      } else if (d.isWeekend == true) {
        color = Colors.grey; // Weekend
      } else {
        // Determine color from plannedCalls' statuses if available
        final Object? calls = d.plannedCalls;
        if (calls is List && calls.isNotEmpty) {
          bool hasApproved = false;
          bool hasSentBackOrRejected = false;
          bool hasPending = false;

          for (final c in calls) {
            if (c is Map) {
              final int statusId = (c['statusId'] is int)
                  ? c['statusId'] as int
                  : int.tryParse('${c['statusId']}') ?? 0;
              // Map status ids: 5=Approved, 1=Pending, 4=Sent Back, 3=Rejected
              if (statusId == 5) hasApproved = true;
              if (statusId == 4 || statusId == 3) hasSentBackOrRejected = true;
              if (statusId == 1 || statusId == 2) hasPending = true; // include Submitted as pending-like
            }
          }

          if (hasApproved) {
            color = const Color(0xFF2DBE64); // Approved
          } else if (hasSentBackOrRejected) {
            color = Colors.redAccent; // Sent Back / Rejected
          } else if (hasPending) {
            color = const Color(0xFFFFA41C); // Pending
          }
        }

        // If still no color but plannedCount > 0, mark as Planned
        color ??= (d.plannedCount > 0) ? const Color(0xFF2B78FF) : null;
      }

      if (color != null) {
        map[DateTime(d.planDate.year, d.planDate.month, d.planDate.day)] =
            CalendarDayDecoration(backgroundColor: color);
      }
    }
    return map;
  }

  Map<DateTime, CalendarDayDecoration> _buildDayDecorations(List<domain.TourPlanEntry> entries) {
    final Map<String, Color> dayColor = <String, Color>{};
    for (final e in entries) {
      final String key = '${e.date.year}-${e.date.month}-${e.date.day}';
      final Color next = () {
        switch (e.status) {
          case domain.TourPlanEntryStatus.approved:
            return const Color(0xFF2DBE64);
          case domain.TourPlanEntryStatus.pending:
          case domain.TourPlanEntryStatus.sentBack:
            return const Color(0xFFFFA41C);
          case domain.TourPlanEntryStatus.draft:
          case domain.TourPlanEntryStatus.rejected:
          default:
            return const Color(0xFFFFA41C);
        }
      }();
      // precedence: approved > pending > others
      if (dayColor[key] == null || next == const Color(0xFF2DBE64)) {
        dayColor[key] = next;
      }
    }
    final Map<DateTime, CalendarDayDecoration> map = <DateTime, CalendarDayDecoration>{};
    dayColor.forEach((key, color) {
      final parts = key.split('-').map(int.parse).toList();
      final d = DateTime(parts[0], parts[1], parts[2]);
      map[d] = CalendarDayDecoration(backgroundColor: color);
    });
    return map;
  }

  Map<TourPlanStatus, int> _buildMonthlyCountsFromApi(List<TourPlanItem> items) {
    int planned = items.length;
    int pending = items.where((e) => e.status == 1 || e.status == 2 || e.status == 4).length;
    int approved = items.where((e) => e.status == 5).length;
    int leaveDays = 0; // not tracked
    int notEntered = items.where((e) => e.status == 0 || e.status == 3).length;
    return {
      TourPlanStatus.planned: planned,
      TourPlanStatus.pending: pending,
      TourPlanStatus.approved: approved,
      TourPlanStatus.leaveDays: leaveDays,
      TourPlanStatus.notEntered: notEntered,
    };
  }

  Map<TourPlanStatus, int> _buildMonthlyCounts(List<domain.TourPlanEntry> entries) {
    int planned = entries.length;
    int pending = entries.where((e) => e.status == domain.TourPlanEntryStatus.pending || e.status == domain.TourPlanEntryStatus.sentBack).length;
    int approved = entries.where((e) => e.status == domain.TourPlanEntryStatus.approved).length;
    int leaveDays = 0; // not tracked in demo
    int notEntered = entries.where((e) => e.status == domain.TourPlanEntryStatus.draft || e.status == domain.TourPlanEntryStatus.rejected).length;
    return {
      TourPlanStatus.planned: planned,
      TourPlanStatus.pending: pending,
      TourPlanStatus.approved: approved,
      TourPlanStatus.leaveDays: leaveDays,
      TourPlanStatus.notEntered: notEntered,
    };
  }

  domain.TourPlanEntryStatus _parseStatusFromApi(int status) {
    switch (status) {
      case 0:
        return domain.TourPlanEntryStatus.draft;
      case 1:
      case 2:
        return domain.TourPlanEntryStatus.pending;
      case 4:
        return domain.TourPlanEntryStatus.sentBack;
      case 5:
        return domain.TourPlanEntryStatus.approved;
      case 3:
        return domain.TourPlanEntryStatus.rejected;
      default:
        return domain.TourPlanEntryStatus.draft;
    }
  }

  domain.TourPlanEntryStatus? _parseStatus(String? label) {
    switch (label) {
      case 'Draft':
        return domain.TourPlanEntryStatus.draft;
      case 'Pending':
        return domain.TourPlanEntryStatus.pending;
      case 'Approved':
        return domain.TourPlanEntryStatus.approved;
      case 'Rejected':
        return domain.TourPlanEntryStatus.rejected;
    }
    return null;
  }

  bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  String _daysAndHolidaysLabel(DateTime date) {
    final int days = _daysInMonth(date);
    final int holidays = _countWeekendDays(date);
    return 'Days: $days  |  Holidays: $holidays';
  }

  int _daysInMonth(DateTime date) {
    final DateTime first = DateTime(date.year, date.month, 1);
    final DateTime next = DateTime(date.year, date.month + 1, 1);
    return next.difference(first).inDays;
  }

  int _countWeekendDays(DateTime date) {
    final int total = _daysInMonth(date);
    int weekends = 0;
    for (int d = 1; d <= total; d++) {
      final int weekday = DateTime(date.year, date.month, d).weekday; // 1=Mon..7=Sun
      if (weekday == DateTime.saturday || weekday == DateTime.sunday) weekends++;
    }
    return weekends;
  }

  void _applyFilters() {
    // Filters are applied via API (server-side filtering), so this method
    // mainly handles local filtering of mock data if still in use
    // For API-based data, filtering is done server-side
    final domain.TourPlanEntryStatus? status = _parseStatus(_status);
    final List<domain.TourPlanEntry> filtered = _allEntries.where((e) {
      final bool byCustomer = _customer == null || e.customer == _customer;
      final bool byEmployee = _employee == null || e.employeeName == _employee || e.employeeId == _employee;
      final bool byStatus = status == null || e.status == status;
      return byCustomer && byEmployee && byStatus;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    _store.entries = filtered;
  }

  void _clearAllFilters() async {
    setState(() {
      _customer = null;
      _employee = null;
      _status = null;
      _filters.clear();
      _dataVersion++;
    });
    // Force hard refresh - reload calendar view and list data without filters
    await Future.wait([
      _loadCalendarViewData(),
      _loadCalendarItemListData(),
      _loadTourPlanEmployeeListSummary(),
    ]);
    // Apply filters after data is loaded
    if (mounted) {
      setState(() {
        _applyFilters();
      });
    }
  }

  bool _hasActiveFilters() {
    return _customer != null || _employee != null || _status != null;
  }

  Future<void> _refreshAll() async {
    try {
      await Future.wait([
        _loadCalendarViewData(),
        _loadCalendarItemListData(),
        _loadTourPlanEmployeeListSummary(),
      ]);
      if (mounted) {
        setState(() {
          _dataVersion++;
        });
      }
    } catch (e) {
      print('TourPlanListScreen: Error refreshing data: $e');
    }
  }

  Future<void> _loadCalendarViewData() async {
    try {
      final int? userId = _userDetailStore.userDetail?.userId;
      final managerId = _userDetailStore.userDetail?.id ?? 0;
      
      // Determine EmployeeId and SelectedEmployeeId based on filters
      final int? filteredEmployeeId = (_employee != null && _employee!.isNotEmpty && _employeeNameToId.containsKey(_employee))
          ? _employeeNameToId[_employee!]
          : null;
      
      // Get user's employeeId - ensure it's not null/0
      final int? userEmployeeId = _userDetailStore.userDetail?.employeeId;
      if (userEmployeeId == null || userEmployeeId == 0) {
        print('TourPlanListScreen: EmployeeId not available from user store, cannot load calendar view data');
        return;
      }
      
      // Use filtered employeeId if available, otherwise use user's employeeId
      final int finalEmployeeId = filteredEmployeeId ?? userEmployeeId;
      final int finalSelectedEmployeeId = filteredEmployeeId ?? userEmployeeId;
      
      print('TourPlanListScreen: Calendar View - EmployeeId: $finalEmployeeId, SelectedEmployeeId: $finalSelectedEmployeeId');
      
      final request = CalendarViewRequest(
        month: _month.month,
        year: _month.year,
        userId: userId,
        managerId: managerId,
        employeeId: finalEmployeeId,
        selectedEmployeeId: finalSelectedEmployeeId,
      );
      
      await _store.loadCalendarViewData(
        month: request.month,
        year: request.year,
        userId: request.userId,
        managerId: request.managerId,
        employeeId: request.employeeId,
        selectedEmployeeId: request.selectedEmployeeId,
      );
      
      if (mounted) {
        setState(() {
          _dataVersion++;
        });
      }
    } catch (e) {
      print('TourPlanListScreen: Error loading calendar view data: $e');
    }
  }

  Future<void> _loadCalendarItemListData() async {
    try {
      final userId = _userDetailStore.userDetail?.id;
      final employeeId = _userDetailStore.userDetail?.employeeId;
      
      if (userId == null || employeeId == null || employeeId == 0) {
        print('TourPlanListScreen: userId or employeeId is null/invalid, skipping load');
        return;
      }
      
      // Determine EmployeeId and SelectedEmployeeId based on filters
      final int? filteredEmployeeId = (_employee != null && _employee!.isNotEmpty && _employeeNameToId.containsKey(_employee))
          ? _employeeNameToId[_employee!]
          : null;
      
      // Use filtered employeeId if available, otherwise use user's employeeId
      final int finalEmployeeId = filteredEmployeeId ?? employeeId;
      final int finalSelectedEmployeeId = filteredEmployeeId ?? employeeId;
      
      // Get customerId and status from filters
      final int? customerId = (_customer != null && _customer!.isNotEmpty && _customerNameToId.containsKey(_customer))
          ? _customerNameToId[_customer!]
          : null;
      final int? status = (_status != null && _statusNameToId.containsKey(_status))
          ? _statusNameToId[_status!]
          : null;
      
      print('TourPlanListScreen: Loading calendar item list data - EmployeeId: $finalEmployeeId, SelectedEmployeeId: $finalSelectedEmployeeId, CustomerId: $customerId, Status: $status');
      
      await _store.loadCalendarItemListData(
        searchText: null,
        pageNumber: 1,
        pageSize: 1000,
        employeeId: finalEmployeeId,
        month: _month.month,
        userId: userId,
        bizunit: 1,
        year: _month.year,
        selectedEmployeeId: finalSelectedEmployeeId,
        customerId: customerId,
        status: status,
        sortOrder: 0,
        sortDir: 0,
        sortField: null,
      );
      
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      print('TourPlanListScreen: Error loading calendar item list data: $e');
    }
  }

  Future<void> _loadTourPlanEmployeeListSummary() async {
    try {
      final int? userEmployeeId = _userDetailStore.userDetail?.employeeId;
      if (userEmployeeId == null || userEmployeeId == 0) {
        print('TourPlanListScreen: EmployeeId not available, skipping employee list summary');
        return;
      }
      
      // Use filtered employeeId if available, otherwise use user's employeeId
      final int? filteredEmployeeId = (_employee != null && _employeeNameToId.containsKey(_employee))
          ? _employeeNameToId[_employee!]
          : null;
      final int finalEmployeeId = filteredEmployeeId ?? userEmployeeId;
      
      await _store.loadTourPlanEmployeeListSummary(
        employeeId: finalEmployeeId,
        month: _month.month,
        year: _month.year,
      );
    } catch (e) {
      print('TourPlanListScreen: Error loading employee list summary: $e');
    }
  }

  Future<void> _getTourPlanStatusList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final repo = getIt<CommonRepository>();
        final List<CommonDropdownItem> items = await repo.getTourPlanStatusList();
        final names = items.map((e) => e.text.trim()).where((s) => s.isNotEmpty).toSet();
        if (names.isNotEmpty && mounted) {
          setState(() {
            _statusOptions = {..._statusOptions, ...names}.toList();
            for (final item in items) {
              final String key = item.text.trim();
              if (key.isNotEmpty) _statusNameToId[key] = item.id;
            }
          });
        }
      }
    } catch (e) {
      print('TourPlanListScreen: Error loading tour plan status list: $e');
    }
  }

  Future<void> _loadMappedCustomersByEmployeeId() async {
    try {
      final int? employeeId = _userDetailStore.userDetail?.employeeId;
      if (employeeId == null || employeeId == 0) {
        print('TourPlanListScreen: Employee ID is null or 0, skipping customer load');
        return;
      }

      if (getIt.isRegistered<TourPlanRepository>()) {
        final repo = getIt<TourPlanRepository>();
        final request = GetMappedCustomersByEmployeeIdRequest(
          searchText: null,
          pageNumber: 0,
          pageSize: 0,
          sortOrder: 0,
          sortDir: 0,
          sortField: null,
          employeeId: null,
          clusterId: null,
          customerId: null,
          month: null,
          tourPlanId: null,
          userId: null,
          bizunit: null,
          filterExpression: null,
          monthNumber: null,
          year: null,
          id: employeeId, // Pass employeeId as Id
          action: null,
          comment: null,
          status: null,
          tourPlanAcceptId: null,
          remarks: null,
          selectedEmployeeId: null,
          date: null,
        );

        final response = await repo.getMappedCustomersByEmployeeId(request);
        
        if (response.customers.isNotEmpty) {
          final names = response.customers
              .map((e) => e.customerName.trim())
              .where((s) => s.isNotEmpty)
              .toSet();
          
          if (names.isNotEmpty) {
            setState(() {
              _customerOptions = names.toList()..sort();
              _customerNameToId.clear();
              for (final customer in response.customers) {
                final String key = customer.customerName.trim();
                if (key.isNotEmpty) {
                  _customerNameToId[key] = customer.customerId;
                }
              }
            });
            print('TourPlanListScreen: Loaded ${_customerOptions.length} customers for employee $employeeId');
          }
        } else {
          print('TourPlanListScreen: No customers found for employee $employeeId');
        }
      }
    } catch (e) {
      print('TourPlanListScreen: Error loading mapped customers by employee ID: $e');
    }
  }

  Future<void> _getEmployeeList({int? employeeId}) async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        final int? finalEmployeeId = employeeId ?? _userDetailStore.userDetail?.employeeId;
        final List<CommonDropdownItem> items = await commonRepo.getEmployeeList(employeeId: finalEmployeeId);
        final names = items.map((e) => (e.employeeName.isNotEmpty ? e.employeeName : e.text).trim()).where((s) => s.isNotEmpty).toSet();
        
        if (names.isNotEmpty && mounted) {
          setState(() {
            _employeeOptions = {..._employeeOptions, ...names}.toList();
            String? selectedEmployeeName;
            for (final item in items) {
              final String key = (item.employeeName.isNotEmpty ? item.employeeName : item.text).trim();
              if (key.isNotEmpty) {
                _employeeNameToId[key] = item.id;
                if (finalEmployeeId != null && item.id == finalEmployeeId) {
                  selectedEmployeeName = key;
                }
              }
            }
            if (selectedEmployeeName != null) {
              _employee = selectedEmployeeName;
              print('TourPlanListScreen: Auto-selected employee: $selectedEmployeeName (ID: $finalEmployeeId)');
            }
          });
        }
      }
    } catch (e) {
      print('TourPlanListScreen: Error getting employee list: $e');
    }
  }

  int _getEmployeeIdForApi() {
    if (_employee != null && _employeeNameToId.containsKey(_employee)) {
      return _employeeNameToId[_employee!]!;
    }
    final userEmployeeId = _userDetailStore.userDetail?.employeeId;
    return userEmployeeId ?? 0;
  }



  Future<void> _getTourPlanEmployeeList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        
        final employees = await commonRepo.getTourPlanEmployeeList();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${employees.length} tour plan employees'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Error getting tour plan employee list: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _getEmployeesReportingTo(int id) async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        
        final employees = await commonRepo.getEmployeesReportingTo(id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${employees.length} employees reporting to ID: $id'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Error getting employees reporting to: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _getClusterList(int countryId, int employeeId) async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        
        final clusters = await commonRepo.getClusterList(countryId, employeeId);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${clusters.length} clusters for country: $countryId'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Error getting cluster list: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Future<void> _getTypeOfWorkList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        
        final types = await commonRepo.getTypeOfWorkList();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${types.length} types of work'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Error getting type of work list: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }



  Future<void> _getExpenseTypeList() async {
    try {
      if (getIt.isRegistered<CommonRepository>()) {
        final commonRepo = getIt<CommonRepository>();
        
        final types = await commonRepo.getExpenseTypeList();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Found ${types.length} expense types'),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Error getting expense type list: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }
}

class TourPlanManagerReviewList extends StatefulWidget {
  const TourPlanManagerReviewList({super.key});

  @override
  State<TourPlanManagerReviewList> createState() => _TourPlanManagerReviewListState();
}

class _TourPlanManagerReviewListState extends State<TourPlanManagerReviewList> {
  final Set<String> _selectedIds = <String>{};
  final TourPlanStore _store = getIt<TourPlanStore>();
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month, 1);
  String? _employee;
  DateTime? _pickedDate;
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _store.month = _month;
    // load mock data initially for the current month
    _store.entries = mockTourPlanEntriesForMonth(_month);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Select plans to review', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              LayoutBuilder(builder: (context, constraints) {
                final bool stacked = constraints.maxWidth < 580;
                final buttons = [
                  Expanded(child: _ActionBtn(label: 'Approve', icon: Icons.check_circle, color: Colors.green, onTap: _approve)),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionBtn(label: 'Send Back', icon: Icons.undo, color: Colors.orange, onTap: () => _commentThen('Send Back'))),
                  const SizedBox(width: 8),
                  Expanded(child: _ActionBtn(label: 'Reject', icon: Icons.cancel, color: Colors.redAccent, onTap: () => _commentThen('Reject'))),
                ];
                if (stacked) {
                  return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(children: [buttons[0], buttons[1], buttons[2]]),
                    const SizedBox(height: 8),
                    Row(children: [buttons[3]]),
                  ]);
                }
                return Row(children: buttons);
              }),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                _FilterPill(
                  icon: Icons.calendar_today,
                  label: _pickedDate == null
                      ? '${_month.month.toString().padLeft(2, '0')}-${_month.year}'
                      : '${_pickedDate!.day.toString().padLeft(2, '0')}-${_pickedDate!.month.toString().padLeft(2, '0')}-${_pickedDate!.year}',
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _pickedDate ?? _month,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035, 12, 31),
                      helpText: 'Pick a date',
                    );
                    if (picked != null) {
                      setState(() {
                        _pickedDate = picked;
                        _month = DateTime(picked.year, picked.month, 1);
                        _selectedDay = picked;
                      });
                      _store.month = _month;
                      // load mock data for the picked month
                      _store.entries = mockTourPlanEntriesForMonth(_month);
                    }
                  },
                ),
                _FilterPill(
                  icon: Icons.badge_outlined,
                  label: _employee ?? 'Employee',
                  onTap: () async {
                    final value = await _pickFromList(context, title: 'Select Employee', options: const ['Sam','Alex','Priya'], selected: _employee, searchable: true);
                    if (value != null) {
                      setState(() => _employee = value);
                      _store.loadMonth(employeeId: _employee);
                    }
                  },
                ),
              ]),
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final double calendarWidth = constraints.maxWidth;
                      return Observer(builder: (_) {
                        final Map<DateTime, CalendarDayDecoration> reactiveDecorations = _buildDayDecorations(_store.entries);
                        return MonthCalendar(
                          width: calendarWidth,
                          visibleMonth: _month,
                          selectedDate: _selectedDay,
                          cellSpacing: 10,
                          cellCornerRadius: 12,
                          onDateTap: (d) => setState(() => _selectedDay = d),
                          onMonthChanged: (m) => setState(() {
                                _month = DateTime(m.year, m.month, 1);
                                _selectedDay = null;
                                _store.month = _month;
                                _store.entries = mockTourPlanEntriesForMonth(_month);
                              }),
                          dayDecorations: reactiveDecorations,
                          legendItems: const [],
                        );
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Observer(builder: (_) {
            final DateTime? day = _selectedDay;
            final items = day == null
                ? _store.entries
                : _store.entries.where((e) => _isSameDate(e.date, day)).toList();
            if (items.isEmpty) {
              return const Center(child: Text('No plans found for this month.'));
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final e = items[index];
                final bool sel = _selectedIds.contains(e.id);
                return GestureDetector(
                  onTap: () => _showPlanDetails(e),
                  child: Container(
                    decoration: BoxDecoration(
                      color: _statusColor(e.status).withOpacity(.06),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _statusColor(e.status).withOpacity(.20)),
                    ),
                    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          value: sel,
                          onChanged: (_) => setState(() => sel ? _selectedIds.remove(e.id) : _selectedIds.add(e.id)),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Expanded(
                                  child: Text(
                                    '${e.customer} • ${e.date.day.toString().padLeft(2, '0')}-${e.date.month.toString().padLeft(2, '0')}-${e.date.year}',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                Icon(_statusIcon(e.status), color: _statusColor(e.status)),
                              ]),
                              const SizedBox(height: 6),
                              Wrap(spacing: 10, runSpacing: 6, children: [
                                _Chip(text: 'Employee: ${e.employeeName}'),
                                _Chip(text: 'Status: ${e.status.name}'),
                                _Chip(text: 'Cluster: ${e.cluster}'),
                              ]),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ],
    );
  }

  void _approve() {
    if (_selectedIds.isEmpty) return;
    _store.approve(_selectedIds.toList());
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Success: Approved ${_selectedIds.length} plan(s)'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    setState(() => _selectedIds.clear());
  }

  Future<void> _commentThen(String action) async {
    if (_selectedIds.isEmpty) return;
    final controller = TextEditingController();
    final String? comment = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action - Comment'),
        content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(hintText: 'Type your comment')), 
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: const Text('Submit')),
        ],
      ),
    );
    if (comment == null) return;
    if (action == 'Send Back') {
      await _store.sendBack(_selectedIds.toList(), comment);
    } else if (action == 'Reject') {
      await _store.reject(_selectedIds.toList(), comment);
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Success: $action ${_selectedIds.length} plan(s) with comment'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    setState(() => _selectedIds.clear());
  }

  Map<DateTime, CalendarDayDecoration> _buildDayDecorations(List<domain.TourPlanEntry> entries) {
    final Map<String, Color> dayColor = <String, Color>{};
    for (final e in entries) {
      final String key = '${e.date.year}-${e.date.month}-${e.date.day}';
      final Color next = _statusColor(e.status);
      if (dayColor[key] == null || next == const Color(0xFF2DBE64)) {
        dayColor[key] = next;
      }
    }
    final Map<DateTime, CalendarDayDecoration> map = <DateTime, CalendarDayDecoration>{};
    dayColor.forEach((key, color) {
      final parts = key.split('-').map(int.parse).toList();
      final d = DateTime(parts[0], parts[1], parts[2]);
      map[d] = CalendarDayDecoration(backgroundColor: color);
    });
    return map;
  }

  bool _isSameDate(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _showPlanDetails(domain.TourPlanEntry e) async {
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Plan Details',
                        style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                    ),
                    Icon(_statusIcon(e.status), color: _statusColor(e.status)),
                  ],
                ),
                const SizedBox(height: 12),
                _detailRow('Date', '${e.date.day.toString().padLeft(2, '0')}-${e.date.month.toString().padLeft(2, '0')}-${e.date.year}'),
                _detailRow('Employee', e.employeeName),
                _detailRow('Customer', e.customer),
                _detailRow('Cluster', e.cluster),
                _detailRow('Status', e.status.name),
                if ((e.callDetails.purposes).isNotEmpty)
                  _detailRow('Purpose', e.callDetails.purposes.join(', ')),
                if ((e.callDetails.productsToDiscuss ?? '').isNotEmpty)
                  _detailRow('Products', e.callDetails.productsToDiscuss ?? ''),
                if ((e.callDetails.samplesToDistribute ?? '').isNotEmpty)
                  _detailRow('Samples', e.callDetails.samplesToDistribute ?? ''),
                if ((e.callDetails.remarks ?? '').isNotEmpty)
                  _detailRow('Remarks', e.callDetails.remarks ?? ''),
                const SizedBox(height: 16),
                // Delete button - only show for non-approved plans
                if (e.status != domain.TourPlanEntryStatus.approved)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(ctx).pop(); // Close bottom sheet
                      _deleteTourPlan(e);
                    },
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: BorderSide(color: Colors.red.withOpacity(0.6)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Delete tour plan
  Future<void> _deleteTourPlan(domain.TourPlanEntry entry) async {
    // Show confirmation dialog
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Tour Plan'),
        content: const Text('Are you sure you want to delete this tour plan? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    
    if (confirmed != true) return;
    
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Convert entry ID (string) to int for API call
      final int tourPlanId = int.tryParse(entry.id) ?? 0;
      if (tourPlanId == 0) {
        throw Exception('Invalid tour plan ID: ${entry.id}');
      }
      
      final response = await _store.deleteTourPlan(tourPlanId);
      
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        if (response.status) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Success: ${response.message.isNotEmpty ? response.message : "Tour plan deleted successfully"}'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          
          // Refresh data after deletion - reload mock data for current month
          if (mounted) {
            setState(() {
              _store.entries = mockTourPlanEntriesForMonth(_month);
              _selectedIds.removeWhere((id) => id == entry.id);
            });
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✗ ${response.message.isNotEmpty ? response.message : "Failed to delete tour plan"}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✗ Error deleting tour plan: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.black54))),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.label, required this.icon, required this.color, required this.onTap});
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 18),
      label: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(.6)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.icon, required this.label, this.onTap, this.onLongPress});
  final IconData icon; final String label; final VoidCallback? onTap; final VoidCallback? onLongPress;
  @override
  Widget build(BuildContext context) {
    final Color border = Theme.of(context).dividerColor.withOpacity(.25);
    return Material(
      color: Colors.white,
      shape: StadiumBorder(side: BorderSide(color: border)),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        customBorder: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              const SizedBox(width: 8),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _pickFromList(BuildContext context, {required String title, required List<String> options, String? selected, bool searchable = false}) async {
  // If searchable is true or options list is large, use searchable version
  // Always use searchable if searchable=true is explicitly passed
  final bool useSearch = searchable || (options.length > 10);
  
  print('TourPlanListScreen: _pickFromList - searchable: $searchable, options.length: ${options.length}, useSearch: $useSearch');
  
  if (useSearch) {
    print('TourPlanListScreen: Using searchable list for: $title');
    return _pickFromListSearchable(context, title: title, options: options, selected: selected);
  }
  
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx))
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemBuilder: (c, i) => ListTile(
                title: Text(options[i]),
                trailing: options[i] == selected ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () => Navigator.pop(ctx, options[i]),
              ),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemCount: options.length,
            ),
          ),
        ],
      ),
    ),
  );
}

Future<String?> _pickFromListSearchable(BuildContext context, {required String title, required List<String> options, String? selected}) async {
  print('TourPlanListScreen: _pickFromListSearchable called - title: $title, options: ${options.length}');
  return showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (ctx) {
      print('TourPlanListScreen: Building searchable bottom sheet for: $title');
      return _SearchableListBottomSheet(
        title: title,
        options: options,
        selected: selected,
      );
    },
  );
}

class _SearchableListBottomSheet extends StatefulWidget {
  final String title;
  final List<String> options;
  final String? selected;

  const _SearchableListBottomSheet({
    required this.title,
    required this.options,
    this.selected,
  });

  @override
  State<_SearchableListBottomSheet> createState() => _SearchableListBottomSheetState();
}

class _SearchableListBottomSheetState extends State<_SearchableListBottomSheet> {
  late List<String> _filteredOptions;
  late TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
    _searchController = TextEditingController();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredOptions = widget.options;
      } else {
        _filteredOptions = widget.options.where((option) =>
          option.toLowerCase().contains(query)
        ).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, child) {
                  return TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: value.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  );
                },
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: _filteredOptions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        'No results found',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      itemBuilder: (c, i) => ListTile(
                        title: Text(_filteredOptions[i]),
                        trailing: _filteredOptions[i] == widget.selected
                            ? const Icon(Icons.check, color: Colors.green)
                            : null,
                        onTap: () => Navigator.pop(context, _filteredOptions[i]),
                      ),
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemCount: _filteredOptions.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<Set<String>?> _pickMultipleFromList(BuildContext context, {required String title, required List<String> options, required Set<String> initiallySelected}) async {
  final Set<String> temp = {...initiallySelected};
  return showModalBottomSheet<Set<String>>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                TextButton(onPressed: () => Navigator.pop(ctx, <String>{}), child: const Text('Clear')),
                const SizedBox(width: 4),
                FilledButton(onPressed: () => Navigator.pop(ctx, temp), child: const Text('Apply')),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              itemCount: options.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final opt = options[i];
                final selected = temp.contains(opt);
                return ListTile(
                  onTap: () {
                    if (selected) {
                      temp.remove(opt);
                    } else {
                      temp.add(opt);
                    }
                    (context as Element).markNeedsBuild();
                  },
                  leading: Checkbox(value: selected, onChanged: (_) {
                    if (selected) {
                      temp.remove(opt);
                    } else {
                      temp.add(opt);
                    }
                    (context as Element).markNeedsBuild();
                  }),
                  title: Text(opt),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _DayPlansCard extends StatelessWidget {
  const _DayPlansCard({required this.date, required this.entries, required this.onEdit});
  final DateTime date;
  final List<domain.TourPlanEntry> entries;
  final void Function(domain.TourPlanEntry entry) onEdit;
  @override
  Widget build(BuildContext context) {
    final String label = '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Expanded(child: Text('Planned Calls on $label', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
            ]),
            const SizedBox(height: 12),
            ...entries.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _PlanRow(index: e.key + 1, entry: e.value, onEdit: () => onEdit(e.value)),
                )),
          ],
        ),
      ),
    );
  }
}

class _PlanRow extends StatelessWidget {
  const _PlanRow({required this.index, required this.entry, required this.onEdit});
  final int index;
  final domain.TourPlanEntry entry;
  final VoidCallback onEdit;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF6F7FA), borderRadius: BorderRadius.circular(12)),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          CircleAvatar(radius: 16, child: Text('$index')),
          const SizedBox(width: 12),
          Expanded(child: Text('${entry.customer} • ${entry.callDetails.purposes.isNotEmpty ? entry.callDetails.purposes.join(', ') : 'No purpose'}')),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: _statusColor(entry.status).withOpacity(.15), borderRadius: BorderRadius.circular(20)),
            child: Text(_statusText(entry.status)),
          ),
          const SizedBox(width: 8),
          TextButton(
            onPressed: entry.status == domain.TourPlanEntryStatus.approved ? null : onEdit,
            child: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Color _statusColor(domain.TourPlanEntryStatus s) {
    switch (s) {
      case domain.TourPlanEntryStatus.approved:
        return const Color(0xFF2DBE64);
      case domain.TourPlanEntryStatus.pending:
      case domain.TourPlanEntryStatus.sentBack:
        return const Color(0xFFFFA41C);
      case domain.TourPlanEntryStatus.draft:
      case domain.TourPlanEntryStatus.rejected:
      default:
        return const Color(0xFFFFA41C);
    }
  }

  String _statusText(domain.TourPlanEntryStatus s) {
    switch (s) {
      case domain.TourPlanEntryStatus.draft:
        return 'Draft';
      case domain.TourPlanEntryStatus.pending:
        return 'Pending';
      case domain.TourPlanEntryStatus.approved:
        return 'Approved';
      case domain.TourPlanEntryStatus.sentBack:
        return 'Sent Back';
      case domain.TourPlanEntryStatus.rejected:
        return 'Rejected';
    }
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.3)),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

IconData _statusIcon(domain.TourPlanEntryStatus s) {
  switch (s) {
    case domain.TourPlanEntryStatus.approved:
      return Icons.check_circle;
    case domain.TourPlanEntryStatus.pending:
      return Icons.hourglass_bottom;
    case domain.TourPlanEntryStatus.sentBack:
      return Icons.undo;
    case domain.TourPlanEntryStatus.rejected:
      return Icons.cancel;
    case domain.TourPlanEntryStatus.draft:
    default:
      return Icons.edit_note;
  }
}

Color _statusColor(domain.TourPlanEntryStatus s) {
  switch (s) {
    case domain.TourPlanEntryStatus.approved:
      return const Color(0xFF2DBE64);
    case domain.TourPlanEntryStatus.pending:
    case domain.TourPlanEntryStatus.sentBack:
      return const Color(0xFFFFA41C);
    case domain.TourPlanEntryStatus.rejected:
      return Colors.redAccent;
    case domain.TourPlanEntryStatus.draft:
    default:
      return Colors.grey;
  }
}

// Enhanced UI Components - Same as DCR Deviation UI
class _EnhancedActionPill extends StatelessWidget {
  const _EnhancedActionPill({
    required this.icon,
    required this.label,
    this.onTap,
    this.isActive = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color backgroundColor = isActive ? Colors.blue.shade50 : Colors.white;
    final Color iconColor = isActive ? Colors.blue.shade600 : theme.colorScheme.primary;
    final Color textColor = isActive ? Colors.blue.shade700 : Colors.grey.shade700;
    final Color borderColor = isActive ? Colors.blue.shade200 : Colors.grey.shade200;
    
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      elevation: isActive ? 3 : 2,
      shadowColor: isActive ? Colors.blue.withOpacity(0.2) : Colors.black.withOpacity(0.1),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontSize: 13, // Slightly smaller for better mobile fit
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down,
                size: 14,
                color: Colors.grey.shade500,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearFiltersButton extends StatelessWidget {
  const _ClearFiltersButton({
    required this.onPressed,
    this.isActive = false,
  });
  
  final VoidCallback onPressed;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isMobile = MediaQuery.of(context).size.width < 600;
    final Color backgroundColor = isActive ? Colors.red.shade50 : Colors.grey.shade100;
    final Color iconColor = isActive ? Colors.red.shade600 : Colors.grey.shade600;
    final Color textColor = isActive ? Colors.red.shade700 : Colors.grey.shade600;
    
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: isActive ? onPressed : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 10 : 12,
            vertical: isMobile ? 12 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isActive ? Border.all(color: Colors.red.shade200) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.filter_alt_off,
                size: isMobile ? 18 : 16,
                color: iconColor,
              ),
              SizedBox(width: isMobile ? 8 : 6),
              Flexible(
                child: Text(
                  'Clear',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: textColor,
                    fontSize: isMobile ? 13 : 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



