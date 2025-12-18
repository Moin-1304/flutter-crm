import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class _MonthYearPickerSheet extends StatefulWidget {
  const _MonthYearPickerSheet({required this.initial});
  final DateTime initial;

  @override
  State<_MonthYearPickerSheet> createState() => _MonthYearPickerSheetState();
}

class _MonthYearPickerSheetState extends State<_MonthYearPickerSheet> {
  late DateTime _cursor;
  
  static const Color tealGreen = Color(0xFF4db1b3);

  @override
  void initState() {
    super.initState();
    _cursor = DateTime(widget.initial.year, widget.initial.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => setState(() => _cursor = DateTime(_cursor.year - 1, _cursor.month, 1)),
                  icon: Icon(Icons.chevron_left, color: tealGreen),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      '${_cursor.year}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _cursor = DateTime(_cursor.year + 1, _cursor.month, 1)),
                  icon: Icon(Icons.chevron_right, color: tealGreen),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final isTablet = constraints.maxWidth >= 600;
                final isSmallMobile = constraints.maxWidth < 400;
                // Adjust aspect ratio based on screen size to prevent text overlap
                final childAspectRatio = isTablet ? 3.2 : (isSmallMobile ? 2.5 : 2.8);
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: childAspectRatio,
                  ),
                  itemCount: 12,
                  itemBuilder: (context, i) {
                    final DateTime d = DateTime(_cursor.year, i + 1, 1);
                    final bool selected = d.year == widget.initial.year && d.month == widget.initial.month;
                    return OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(d),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 8 : (isSmallMobile ? 2 : 4),
                          vertical: isTablet ? 12 : (isSmallMobile ? 8 : 10),
                        ),
                        side: BorderSide(
                          color: selected ? tealGreen.withOpacity(0.3) : Theme.of(context).dividerColor.withOpacity(.3),
                          width: selected ? 1.5 : 1,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        backgroundColor: selected ? tealGreen.withOpacity(0.1) : Colors.white,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            DateFormat.MMM().format(d),
                            style: TextStyle(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                              color: selected ? tealGreen : tealGreen.withOpacity(0.7),
                            ),
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.visible,
                            maxLines: 1,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Calendar day decoration similar to colored filled circles in the design.
class CalendarDayDecoration {
  const CalendarDayDecoration({
    required this.backgroundColor,
    this.textColor = Colors.white,
    this.borderColor,
  });

  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
}

/// Legend item shown below the calendar.
class CalendarLegendItem {
  const CalendarLegendItem({
    required this.label,
    required this.color,
    required this.count,
  });

  final String label;
  final Color color;
  final int count;
}

/// A polished month calendar with header, summary line, day decorations and legend.
class MonthCalendar extends StatefulWidget {
  const MonthCalendar({
    super.key,
    this.visibleMonth,
    this.width,
    this.dayNameStyle,
    this.dateTextStyle,
    this.onDateTap,
    this.cellSpacing = 8,
    this.cellCornerRadius = 12,
    this.showOutsideDays = true,
    this.headerBuilder,
    this.onMonthChanged,
    this.summaryText,
    this.dayDecorations = const <DateTime, CalendarDayDecoration>{},
    this.legendItems = const <CalendarLegendItem>[],
    this.selectedDate,
  });

  /// The month that should be visible initially. Only the year and month are used.
  final DateTime? visibleMonth;

  /// Optional fixed width for the calendar. Height auto-calculates.
  final double? width;

  /// Text style for weekday names.
  final TextStyle? dayNameStyle;

  /// Text style for dates.
  final TextStyle? dateTextStyle;

  /// Callback when a date is tapped.
  final ValueChanged<DateTime>? onDateTap;

  /// Gap between cells horizontally and vertically.
  final double cellSpacing;

  /// Corner radius for date cells.
  final double cellCornerRadius;

  /// Whether to render trailing/leading dates from adjacent months.
  final bool showOutsideDays;

  /// Optional custom header (e.g., month/year and controls).
  final Widget Function(BuildContext context, DateTime firstOfMonth)? headerBuilder;

  /// Called when the month is changed via the header arrows.
  final ValueChanged<DateTime>? onMonthChanged;

  /// Optional secondary line under the header (e.g. "Days: 30 | Holidays: 8").
  final String? summaryText;

  /// Per-day decorations (filled circles etc.). Only the Y/M/D parts are used.
  final Map<DateTime, CalendarDayDecoration> dayDecorations;

  /// Legend chips rendered under the grid.
  final List<CalendarLegendItem> legendItems;

  /// Optional selected date to highlight in the grid.
  final DateTime? selectedDate;

  static const int _daysPerWeek = 7;

  @override
  State<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends State<MonthCalendar> {
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _visibleMonth = DateTime(
      (widget.visibleMonth ?? now).year,
      (widget.visibleMonth ?? now).month,
      1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now();
    final DateTime firstOfMonth = _visibleMonth;
    final DateTime firstDayToShow = _firstDayInCalendar(firstOfMonth);
    final DateTime lastOfMonth = DateTime(firstOfMonth.year, firstOfMonth.month + 1, 0);
    final int totalDays = lastOfMonth.day;

    // Number of calendar cells to cover the whole month grid including lead/trail days.
    final int leading = firstOfMonth.weekday % 7; // Sunday=0
    final int rows = ((leading + totalDays) / MonthCalendar._daysPerWeek).ceil();
    final int cellCount = rows * MonthCalendar._daysPerWeek;

    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    final Widget header = widget.headerBuilder?.call(context, firstOfMonth) ?? _DefaultHeader(
      date: firstOfMonth,
      summaryText: widget.summaryText,
      onPrev: () => _navigateMonth(-1),
      onNext: () => _navigateMonth(1),
      onPickMonth: (picked) => _setMonth(picked),
    );

    final Widget weekdayHeader = _WeekdayHeader(
      style: widget.dayNameStyle ?? Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700, fontSize: 14),
      spacing: widget.cellSpacing,
    );

    final GridView grid = GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: MonthCalendar._daysPerWeek,
        crossAxisSpacing: widget.cellSpacing,
        mainAxisSpacing: widget.cellSpacing,
      ),
      itemCount: cellCount,
      itemBuilder: (context, index) {
        final DateTime day = DateTime(firstDayToShow.year, firstDayToShow.month, firstDayToShow.day + index);
        final bool isOutside = day.month != firstOfMonth.month;
        if (isOutside && !widget.showOutsideDays) {
          return const SizedBox.shrink();
        }

        final bool isToday = _isSameDate(day, now);
        final TextStyle baseStyle = (widget.dateTextStyle ?? Theme.of(context).textTheme.bodyMedium!.copyWith(fontSize: 16, fontWeight: FontWeight.w600));

        final CalendarDayDecoration? deco = _decorationForDate(widget.dayDecorations, day);
        final bool isDecorated = deco != null && !isOutside;

        final TextStyle effectiveDateStyle = baseStyle.copyWith(
          color: isDecorated
              ? (deco.textColor)
              : isOutside
                  ? baseStyle.color!.withOpacity(.38)
                  : baseStyle.color,
          fontWeight: isToday && !isDecorated ? FontWeight.w600 : FontWeight.w500,
        );

        final bool isCurrentMonthDay = day.month == firstOfMonth.month && day.year == firstOfMonth.year;
        final bool isCurrentDate = _isSameDate(day, now);
        final bool isSelected = widget.selectedDate != null && _isSameDate(day, widget.selectedDate!);
        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(widget.cellCornerRadius),
            onTap: widget.onDateTap == null ? null : () => widget.onDateTap!(day),
            child: Container(
              alignment: Alignment.center,
              padding: const EdgeInsets.all(2),
              decoration: isCurrentMonthDay && (isCurrentDate || isSelected)
                    ? BoxDecoration(
                       border: Border.all(color: const Color(0xFF4db1b3), width: 2),
                       borderRadius: BorderRadius.circular(widget.cellCornerRadius),
                      )
                  : null,
              child: isDecorated
                  ? _FilledDotDay(
                      label: '${day.day}',
                      background: deco.backgroundColor,
                      textStyle: effectiveDateStyle,
                    )
                  : Text(
                      '${day.day}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: effectiveDateStyle,
                    ),
            ),
          ),
        );
      },
    );

    final Widget legend = widget.legendItems.isEmpty
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final List<Widget> chips = [
                  for (int i = 0; i < widget.legendItems.length; i++) ...[
                    _LegendChip(item: widget.legendItems[i]),
                    if (i != widget.legendItems.length - 1) const SizedBox(width: 8),
                  ],
                ];
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 2),
                        ...chips,
                        const SizedBox(width: 2),
                      ],
                    ),
                  ),
                );
              },
            ),
          );

    final Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        const SizedBox(height: 8),
        weekdayHeader,
        const SizedBox(height: 4),
        grid,
        legend,
      ],
    );

    if (widget.width != null) {
      return SizedBox(width: widget.width, child: content);
    }
    return content;
  }

  void _navigateMonth(int delta) {
    setState(() {
      _visibleMonth = DateTime(_visibleMonth.year, _visibleMonth.month + delta, 1);
    });
    widget.onMonthChanged?.call(_visibleMonth);
  }

  void _setMonth(DateTime picked) {
    setState(() {
      _visibleMonth = DateTime(picked.year, picked.month, 1);
    });
    widget.onMonthChanged?.call(_visibleMonth);
  }

  static DateTime _firstDayInCalendar(DateTime firstOfMonth) {
    // We want the Sunday on or before the first of the month.
    final int weekday = firstOfMonth.weekday % 7; // Mon=1..Sun=7 -> 0..6
    return DateTime(firstOfMonth.year, firstOfMonth.month, firstOfMonth.day - weekday);
  }

  static bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  CalendarDayDecoration? _decorationForDate(Map<DateTime, CalendarDayDecoration> map, DateTime day) {
    for (final entry in map.entries) {
      if (_isSameDate(entry.key, day)) return entry.value;
    }
    return null;
  }
}

class _DefaultHeader extends StatelessWidget {
  const _DefaultHeader({required this.date, required this.onPrev, required this.onNext, this.summaryText, this.onPickMonth});
  final DateTime date;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final String? summaryText;
  final ValueChanged<DateTime>? onPickMonth;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final String month = DateFormat.yMMMM().format(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: onPrev,
            ),
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(24),
                onTap: () => _openMonthPicker(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    month,
                    textAlign: TextAlign.center,
                  style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 18),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: onNext,
            ),
          ],
        ),
        if (summaryText != null) ...[
          Text(
            summaryText!,
            textAlign: TextAlign.center,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurface.withOpacity(.6),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
        const SizedBox(height: 8),
        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant.withOpacity(.6)),
      ],
    );
  }

  Future<void> _openMonthPicker(BuildContext context) async {
    final DateTime? picked = await showModalBottomSheet<DateTime>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => _MonthYearPickerSheet(initial: date),
    );
    if (picked != null) {
      onPickMonth?.call(picked);
    }
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader({required this.style, required this.spacing});
  final TextStyle? style;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    final List<String> days = DateFormat.E().dateSymbols.STANDALONESHORTWEEKDAYS;
    // Ensure order starts from Sun..Sat per the screenshot.
    final List<String> ordered = <String>[days[0], days[1], days[2], days[3], days[4], days[5], days[6]];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double cellWidth = (constraints.maxWidth - (spacing * 6)) / 7;
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(7, (i) {
            return SizedBox(
              width: cellWidth,
              child: Text(
                ordered[i],
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            );
          }),
        );
      },
    );
  }
}

class _FilledDotDay extends StatelessWidget {
  const _FilledDotDay({required this.label, required this.background, required this.textStyle});
  final String label;
  final Color background;
  final TextStyle textStyle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(label, style: textStyle.copyWith(fontWeight: FontWeight.w800, color: Colors.white, fontSize: 16)),
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  const _LegendChip({required this.item});
  final CalendarLegendItem item;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return IntrinsicWidth(
      child: Container(
        constraints: const BoxConstraints(minWidth: 100, maxWidth: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: colorScheme.outlineVariant.withOpacity(.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.07),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: item.color,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              '${item.count} calls',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

