import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:boilerplate/presentation/crm/tour_plan/store/tour_plan_store.dart';
import 'package:boilerplate/di/service_locator.dart';

import '../../../domain/entity/tour_plan/calendar_view_data.dart';

class TourPlanCalendarViewScreen extends StatefulWidget {
  const TourPlanCalendarViewScreen({super.key});

  @override
  State<TourPlanCalendarViewScreen> createState() => _TourPlanCalendarViewScreenState();
}

class _TourPlanCalendarViewScreenState extends State<TourPlanCalendarViewScreen> {
  late final TourPlanStore _store;
  DateTime _currentMonth = DateTime.now();
  int _userId = 0;
  int _managerId = 0;
  int _employeeId = 0;

  @override
  void initState() {
    super.initState();
    _store = getIt<TourPlanStore>();
    _loadCalendarData();
  }

  void _loadCalendarData() {
    _store.loadCalendarViewData(
      month: _currentMonth.month,
      year: _currentMonth.year,
      userId: _userId,
      managerId: _managerId,
      employeeId: _employeeId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tour Plan Calendar View'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadCalendarData,
          ),
        ],
      ),
      body: Column(
        children: [
          // Month selector
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
                      _loadCalendarData();
                    });
                  },
                  icon: const Icon(Icons.chevron_left),
                  label: const Text('Previous'),
                ),
                Text(
                  '${_currentMonth.month.toString().padLeft(2, '0')}/${_currentMonth.year}',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
                      _loadCalendarData();
                    });
                  },
                  label: const Text('Next'),
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),
          
          // Calendar data display
          Expanded(
            child: Observer(
              builder: (_) {
                if (_store.calendarLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (_store.calendarViewData.isEmpty) {
                  return const Center(
                    child: Text('No calendar data available'),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _store.calendarViewData.length,
                  itemBuilder: (context, index) {
                    final data = _store.calendarViewData[index];
                    return _buildCalendarDayCard(data);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarDayCard(CalendarViewData data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Date column
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.planDate.day.toString(),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getMonthName(data.planDate.month),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  _getWeekdayName(data.planDate.weekday),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(width: 16),
            
            // Status indicators
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildStatusChip(
                        'Planned',
                        data.plannedCount,
                        Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      if (data.isWeekend)
                        _buildStatusChip(
                          'Weekend',
                          1,
                          Colors.orange,
                        ),
                      const SizedBox(width: 8),
                      if (data.isHolidayDay)
                        _buildStatusChip(
                          'Holiday',
                          1,
                          Colors.red,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Planned Calls: ${data.plannedCount}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return months[month - 1];
  }

  String _getWeekdayName(int weekday) {
    const weekdays = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];
    return weekdays[weekday - 1];
  }
}
