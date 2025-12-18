class CalendarViewData {
  final DateTime planDate;
  final int plannedCount;
  final int weekend;
  final int isHoliday;
  final dynamic plannedCalls;
  final bool isWeekend;
  final bool isHolidayDay;

  CalendarViewData({
    required this.planDate,
    required this.plannedCount,
    required this.weekend,
    required this.isHoliday,
    this.plannedCalls,
    required this.isWeekend,
    required this.isHolidayDay,
  });

  factory CalendarViewData.fromJson(Map<String, dynamic> json) {
    // Support both camelCase and PascalCase keys from API
    final dynamic planDateRaw = json['planDate'] ?? json['PlanDate'];
    // planned count may come as plannedCount/PlannedCount/Planned
    final int plannedCountRaw = (json['plannedCount'] ?? json['PlannedCount'] ?? json['Planned'] ?? 0) as int;
    final int weekendRaw = (json['weekend'] ?? json['Weekend'] ?? 0) as int;
    final int isHolidayRaw = (json['isHoliday'] ?? json['IsHoliday'] ?? 0) as int;
    final dynamic plannedCallsRaw = json['plannedCalls'] ?? json['PlannedCalls'];
    final bool isWeekendRaw = (json['isWeekend'] ?? json['IsWeekend'] ?? false) as bool;
    final bool isHolidayDayRaw = (json['isHolidayDay'] ?? json['IsHolidayDay'] ?? false) as bool;

    return CalendarViewData(
      planDate: planDateRaw is String ? DateTime.parse(planDateRaw) : (planDateRaw as DateTime),
      plannedCount: plannedCountRaw,
      weekend: weekendRaw,
      isHoliday: isHolidayRaw,
      plannedCalls: plannedCallsRaw,
      isWeekend: isWeekendRaw,
      isHolidayDay: isHolidayDayRaw,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'planDate': planDate.toIso8601String(),
      'plannedCount': plannedCount,
      'weekend': weekend,
      'isHoliday': isHoliday,
      'plannedCalls': plannedCalls,
      'isWeekend': isWeekend,
      'isHolidayDay': isHolidayDay,
    };
  }

  @override
  String toString() {
    return 'CalendarViewData(planDate: $planDate, plannedCount: $plannedCount, weekend: $weekend, isHoliday: $isHoliday, plannedCalls: $plannedCalls, isWeekend: $isWeekend, isHolidayDay: $isHolidayDay)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarViewData &&
        other.planDate == planDate &&
        other.plannedCount == plannedCount &&
        other.weekend == weekend &&
        other.isHoliday == isHoliday &&
        other.plannedCalls == plannedCalls &&
        other.isWeekend == isWeekend &&
        other.isHolidayDay == isHolidayDay;
  }

  @override
  int get hashCode {
    return planDate.hashCode ^
        plannedCount.hashCode ^
        weekend.hashCode ^
        isHoliday.hashCode ^
        plannedCalls.hashCode ^
        isWeekend.hashCode ^
        isHolidayDay.hashCode;
  }
}

class CalendarViewRequest {
  final int month;
  final int year;
  final int? userId;
  final int managerId;
  final int employeeId;
  final int selectedEmployeeId;

  CalendarViewRequest({
    required this.month,
    required this.year,
    this.userId,
    required this.managerId,
    required this.employeeId,
    this.selectedEmployeeId = 0,
  });

  Map<String, dynamic> toJson() {
    // API expects PascalCase keys
    return {
      'Month': month,
      'Year': year,
      'UserId': userId,
      'ManagerId': managerId,
      'EmployeeId': employeeId,
      'SelectedEmployeeId': selectedEmployeeId,
    };
  }
}
