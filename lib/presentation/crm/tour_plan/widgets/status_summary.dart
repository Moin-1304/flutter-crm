import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

enum TourPlanStatus {
  planned,
  pending,
  approved,
  leaveDays,
  notEntered,
}

class MonthlyStatusSummary extends StatefulWidget {
  const MonthlyStatusSummary({
    super.key,
    required this.counts,
    this.onFilterChanged,
    this.initiallyExpanded = true,
    this.title = 'Monthly Status Summary',
    this.periodLabel = 'This Month',
    this.onPeriodChanged,
  });

  final Map<TourPlanStatus, int> counts;
  final ValueChanged<Set<TourPlanStatus>>? onFilterChanged;
  final bool initiallyExpanded;
  final String title;
  final String periodLabel;
  final ValueChanged<String>? onPeriodChanged; // e.g. this_month, last_month, this_week

  @override
  State<MonthlyStatusSummary> createState() => _MonthlyStatusSummaryState();
}

class _MonthlyStatusSummaryState extends State<MonthlyStatusSummary> {
  bool _expanded = true;
  final Set<TourPlanStatus> _selected = <TourPlanStatus>{};

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.black.withOpacity(.06)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final bool compact = constraints.maxWidth < 410;
                final Widget controls = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PopupMenuButton<String>(
                      onSelected: (v) => widget.onPeriodChanged?.call(v),
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'this_month', child: Text('This Month')),
                        PopupMenuItem(value: 'last_month', child: Text('Last Month')),
                        PopupMenuItem(value: 'this_week', child: Text('This Week')),
                      ],
                      offset: const Offset(0, 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: _PeriodPill(label: widget.periodLabel),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => setState(() => _expanded = !_expanded),
                      child: Text(
                        _expanded ? 'Hide' : 'Show',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: _expanded ? Colors.green : colorScheme.primary,
                        ),
                      ),
                    ),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.title,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Align(alignment: Alignment.centerRight, child: controls),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.title,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    controls,
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            if (_expanded) const Divider(height: 20),
            AnimatedCrossFade(
              crossFadeState: _expanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 250),
              firstChild: _LinearSummary(
                counts: widget.counts,
                onToggle: (status) {
                  setState(() {
                    if (_selected.contains(status)) {
                      _selected.remove(status);
                    } else {
                      _selected.add(status);
                    }
                  });
                  widget.onFilterChanged?.call(_selected);
                },
                selected: _selected,
              ),
              secondChild: const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipCloud extends StatelessWidget {
  const _ChipCloud({
    required this.counts,
    required this.selected,
    required this.onToggle,
  });

  final Map<TourPlanStatus, int> counts;
  final Set<TourPlanStatus> selected;
  final ValueChanged<TourPlanStatus> onToggle;

  @override
  Widget build(BuildContext context) {
    final Map<TourPlanStatus, _StatusMeta> meta = _statusMeta(Theme.of(context).colorScheme);
    final List<TourPlanStatus> order = [
      TourPlanStatus.planned,
      TourPlanStatus.pending,
      TourPlanStatus.approved,
      TourPlanStatus.leaveDays,
      TourPlanStatus.notEntered,
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final TourPlanStatus s in order)
          FilterChip(
            label: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${counts[s] ?? 0}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: meta[s]!.color)),
                const SizedBox(width: 8),
                Text(meta[s]!.label,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            selected: selected.contains(s),
            onSelected: (_) => onToggle(s),
            backgroundColor: meta[s]!.color.withOpacity(.08),
            selectedColor: meta[s]!.color.withOpacity(.18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            side: BorderSide(color: meta[s]!.color.withOpacity(.25)),
            showCheckmark: false,
            avatar: CircleAvatar(
              radius: 10,
              backgroundColor: meta[s]!.color.withOpacity(.2),
              child: Icon(meta[s]!.icon, size: 14, color: meta[s]!.color),
            ),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }

  static Map<TourPlanStatus, _StatusMeta> _statusMeta(ColorScheme scheme) {
    return {
      TourPlanStatus.planned: _StatusMeta('Planned', const Color(0xFF2B78FF), Icons.event_note),
      TourPlanStatus.pending: _StatusMeta('Pending', const Color(0xFFFFA41C), Icons.hourglass_bottom),
      TourPlanStatus.approved: _StatusMeta('Approved', const Color(0xFF2DBE64), Icons.check_circle),
      TourPlanStatus.leaveDays: _StatusMeta('LeaveDays', const Color(0xFFFF6A21), Icons.beach_access),
      TourPlanStatus.notEntered: _StatusMeta('Not Entered', const Color(0xFFB635FF), Icons.edit_off),
    };
  }
}

class _StatusMeta {
  const _StatusMeta(this.label, this.color, this.icon);
  final String label;
  final Color color;
  final IconData icon;
}

/// Donut summary with left legend and a right circular progress made of segments
class _DonutSummary extends StatelessWidget {
  const _DonutSummary({
    required this.counts,
    required this.selected,
    required this.onToggle,
  });

  final Map<TourPlanStatus, int> counts;
  final Set<TourPlanStatus> selected;
  final ValueChanged<TourPlanStatus> onToggle;

  @override
  Widget build(BuildContext context) {
    final Map<TourPlanStatus, _StatusMeta> meta = _ChipCloud._statusMeta(Theme.of(context).colorScheme);
    final List<TourPlanStatus> order = [
      TourPlanStatus.planned,
      TourPlanStatus.pending,
      TourPlanStatus.approved,
      TourPlanStatus.leaveDays,
      TourPlanStatus.notEntered,
    ];

    final List<_Segment> segments = [
      for (final s in order)
        if ((counts[s] ?? 0) > 0)
          _Segment(value: (counts[s] ?? 0).toDouble(), color: meta[s]!.color, label: meta[s]!.label),
    ];

    final int total = counts.values.fold(0, (a, b) => a + b);

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isCompact = constraints.maxWidth < 420;
        final double donutSize = math.min(200, math.max(140, constraints.maxWidth * (isCompact ? 0.58 : 0.40)));
        final Widget donut = SizedBox(
          width: donutSize,
          height: donutSize,
          child: _DonutChart(
            segments: segments,
            backgroundColor: Theme.of(context).dividerColor.withOpacity(.15),
            thickness: 40,
            center: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('$total', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                Text('Total', style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.black54)),
              ],
            ),
          ),
        );

        final Widget legend = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final s in order)
              _LegendRow(
                color: meta[s]!.color,
                label: meta[s]!.label,
                valueText: '${counts[s] ?? 0}',
                percentText: total > 0 ? '${(((counts[s] ?? 0) / total) * 100).round()}%' : null,
                selected: selected.contains(s),
                onTap: () => onToggle(s),
              ),
          ],
        );

        if (isCompact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: donut),
              const SizedBox(height: 12),
              legend,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            donut,
            const SizedBox(width: 12),
            Expanded(child: legend),
          ],
        );
      },
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({required this.color, required this.label, required this.valueText, this.percentText, this.selected = false, this.onTap});
  final Color color;
  final String label;
  final String valueText;
  final String? percentText;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final TextStyle? base = Theme.of(context).textTheme.bodyMedium;
    final TextStyle? labelStyle = selected ? Theme.of(context).textTheme.titleMedium : base;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(child: Text(label, style: labelStyle)),
            if (percentText != null) ...[
              Text(percentText!, style: base?.copyWith(color: Colors.black54)),
              const SizedBox(width: 10),
            ],
            Text(valueText, style: base),
          ],
        ),
      ),
    );
  }
}

/// Linear progress summary with rows: left label, right count, and a themed bar
class _LinearSummary extends StatelessWidget {
  const _LinearSummary({
    required this.counts,
    required this.selected,
    required this.onToggle,
  });

  final Map<TourPlanStatus, int> counts;
  final Set<TourPlanStatus> selected;
  final ValueChanged<TourPlanStatus> onToggle;

  @override
  Widget build(BuildContext context) {
    final Map<TourPlanStatus, _StatusMeta> meta = _ChipCloud._statusMeta(Theme.of(context).colorScheme);
    final List<TourPlanStatus> order = [
      TourPlanStatus.planned,
      TourPlanStatus.pending,
      TourPlanStatus.approved,
      TourPlanStatus.leaveDays,
      TourPlanStatus.notEntered,
    ];

    final int total = counts.values.fold(0, (a, b) => a + b);

    return Column(
      children: [
        for (final s in order)
          _LinearRow(
            color: meta[s]!.color,
            label: meta[s]!.label,
            count: counts[s] ?? 0,
            total: total,
            selected: selected.contains(s),
            onTap: () => onToggle(s),
          ),
      ],
    );
  }
}

class _LinearRow extends StatelessWidget {
  const _LinearRow({
    required this.color,
    required this.label,
    required this.count,
    required this.total,
    this.selected = false,
    this.onTap,
  });

  final Color color;
  final String label;
  final int count;
  final int total;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double ratio = total > 0 ? count / total : 0.0;

    final Color trackColor = Theme.of(context).dividerColor.withOpacity(.25);
    final Color fillColor = selected ? color : color.withOpacity(.85);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: fillColor, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: selected ? textTheme.titleMedium : textTheme.bodyMedium,
                  ),
                ),
                Text(
                  '$count',
                  style: textTheme.bodyMedium?.copyWith(color: scheme.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) {
                final double width = constraints.maxWidth;
                final double barWidth = width * ratio;
                return Stack(
                  children: [
                    Container(
                      height: 8,
                      decoration: BoxDecoration(
                        color: trackColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      width: barWidth,
                      height: 8,
                      decoration: BoxDecoration(
                        color: fillColor,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Segment {
  const _Segment({required this.value, required this.color, required this.label});
  final double value;
  final Color color;
  final String label;
}

class _DonutChart extends StatelessWidget {
  const _DonutChart({
    required this.segments,
    this.backgroundColor,
    this.thickness = 14,
    this.center,
  });

  final List<_Segment> segments;
  final Color? backgroundColor;
  final double thickness;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Summary donut chart',
      child: CustomPaint(
        painter: _DonutPainter(segments: segments, backgroundColor: backgroundColor, thickness: thickness),
        child: Center(child: center),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments, required this.backgroundColor, required this.thickness});
  final List<_Segment> segments;
  final Color? backgroundColor;
  final double thickness;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double startAngle = -math.pi / 2; // start at top
    final double radius = math.min(size.width, size.height) / 2;
    final double innerRadius = radius - thickness; // kept for potential shadow/future use

    final Paint bgPaint = Paint()
      ..color = (backgroundColor ?? Colors.black12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    // draw background circle
    canvas.drawArc(Rect.fromCircle(center: rect.center, radius: radius - thickness / 2), 0, 2 * math.pi, false, bgPaint);

    final double total = segments.fold(0.0, (p, s) => p + s.value);
    if (total <= 0) return;

    final int n = segments.length;
    final double gapSweep = n > 1 ? (3 * math.pi / 180) : 0; // 3 degrees gaps
    final double available = 2 * math.pi - n * gapSweep;

    double current = startAngle;
    for (final _Segment s in segments) {
      final double sweep = (s.value / total) * available;
      final Paint p = Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: rect.center, radius: radius - thickness / 2), current, sweep, false, p);

      current += sweep + gapSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.segments != segments ||
        oldDelegate.backgroundColor != backgroundColor ||
        oldDelegate.thickness != thickness;
  }
}

class _PeriodPill extends StatelessWidget {
  const _PeriodPill({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.3)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith()),
          const SizedBox(width: 6),
          const Icon(Icons.expand_more, size: 16),
        ],
      ),
    );
  }
}

/// Simple category breakdown card matching the provided screenshot style
class CategorySlice {
  const CategorySlice({required this.label, required this.percent, required this.color, this.active = true});
  final String label;
  final double percent; // 0..100
  final Color color;
  final bool active; // if false, render in greyed style
}

class CategoryBreakdownCard extends StatelessWidget {
  const CategoryBreakdownCard({super.key, required this.slices, this.backgroundGradient});

  final List<CategorySlice> slices;
  final Gradient? backgroundGradient;

  @override
  Widget build(BuildContext context) {
    final List<_Segment> segments = [
      for (final s in slices)
        _Segment(value: s.percent, color: s.active ? s.color : Colors.grey.withOpacity(.35), label: s.label),
    ];
    final Gradient gradient = backgroundGradient ?? const LinearGradient(
      colors: [Color(0xFFF8F2FF), Color(0xFFFFFFFF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(18),
        ),
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final bool compact = constraints.maxWidth < 420;
            final double size = math.min(180, math.max(130, constraints.maxWidth * (compact ? 0.52 : 0.36)));
            final Widget donut = SizedBox(
              width: size,
              height: size,
              child: _DonutChart(
                segments: segments,
                backgroundColor: Colors.white.withOpacity(.8),
                thickness: 20,
              ),
            );
            final Widget legend = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in slices)
                  _OutlinedLegendRow(
                    color: s.color,
                    label: s.label,
                    percent: s.percent,
                    active: s.active,
                  ),
              ],
            );

            if (compact) {
              return Column(
                children: [
                  donut,
                  const SizedBox(height: 12),
                  legend,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                donut,
                const SizedBox(width: 16),
                Expanded(child: legend),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OutlinedLegendRow extends StatelessWidget {
  const _OutlinedLegendRow({required this.color, required this.label, required this.percent, this.active = true});
  final Color color;
  final String label;
  final double percent;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Color textColor = active ? color : Colors.black45;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: active ? color : Colors.black26, width: 2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
          Text(
            '${percent.toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}


/// Public chart card that renders overall status distribution as a donut with legend
class StatusDonutCard extends StatelessWidget {
  const StatusDonutCard({super.key, required this.counts, this.title = 'Status Breakdown', this.trailing});

  final Map<TourPlanStatus, int> counts;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final isMobile = MediaQuery.of(context).size.width < 600;
    final isSmallMobile = MediaQuery.of(context).size.width < 400;
    
    final Map<TourPlanStatus, _StatusMeta> meta = _ChipCloud._statusMeta(Theme.of(context).colorScheme);
    final List<TourPlanStatus> order = [
      TourPlanStatus.planned,
      TourPlanStatus.pending,
      TourPlanStatus.approved,
      TourPlanStatus.leaveDays,
      TourPlanStatus.notEntered,
    ];

    final int total = counts.values.fold(0, (a, b) => a + b);

    final Widget chartAndLegend = LayoutBuilder(
      builder: (context, constraints) {
        // Ensure all 5 rings are visible by sizing to fit ring stack.
        final double ringThickness = isSmallMobile ? 6 : (isTablet ? 10 : 8);
        final double ringGap = isSmallMobile ? 4 : (isTablet ? 8 : 6);
        final int ringCount = order.length; // 5
        final double spacing = ringThickness + ringGap;
        final double requiredDiameter = 2 * (((ringCount - 1) * spacing) + ringThickness / 2 + 1);
        
        // Responsive sizing
        final bool isCompact = constraints.maxWidth < 500 || isSmallMobile;
        double defaultSize;
        if (isSmallMobile) {
          defaultSize = constraints.maxWidth * 0.45;
        } else if (isMobile) {
          defaultSize = constraints.maxWidth * 0.35;
        } else {
          defaultSize = constraints.maxWidth * 0.40;
        }
        
        final double chartSize = math.max(requiredDiameter, math.min(isTablet ? 320 : 280, math.max(isSmallMobile ? 120 : 140, defaultSize)));

        final Widget chart = SizedBox(
          width: chartSize,
          height: chartSize,
          child: _ConcentricRingsChart(
            values: [
              for (final s in order) (counts[s] ?? 0).toDouble(),
            ],
            colors: [
              meta[TourPlanStatus.planned]!.color,
              meta[TourPlanStatus.pending]!.color,
              meta[TourPlanStatus.approved]!.color,
              meta[TourPlanStatus.leaveDays]!.color,
              meta[TourPlanStatus.notEntered]!.color,
            ],
            ringThickness: ringThickness,
            ringGap: ringGap,
            sweepDegrees: 360, // full circle
            startDegrees: -90, // start at top
            backgroundRingCount: 5,
            backgroundColor: Theme.of(context).dividerColor.withOpacity(.10),
            center: null,
          ),
        );

        final Widget legend = _LegendTwoColumn(
          items: [
            for (final s in order)
              _LegendItem(
                color: meta[s]!.color,
                label: meta[s]!.label,
                count: counts[s] ?? 0,
                percent: total > 0 ? ((counts[s] ?? 0) / total * 100).round() : 0,
              ),
          ],
          isTablet: isTablet,
          isSmallMobile: isSmallMobile,
        );

        // Stack vertically on very small screens
        if (isSmallMobile || constraints.maxWidth < 350) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              chart,
              SizedBox(height: isTablet ? 20 : 16),
              legend,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            chart,
            SizedBox(width: isTablet ? 20 : (isMobile ? 12 : 16)),
            Expanded(child: legend),
          ],
        );
      },
    );

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isTablet ? 20 : 18),
        side: BorderSide(color: Colors.black.withOpacity(0.06)),
      ),
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 20 : (isMobile ? 16 : 18)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title.isNotEmpty || trailing != null)
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: isTablet ? 18 : 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            if (title.isNotEmpty || trailing != null) SizedBox(height: isTablet ? 16 : 12),
            chartAndLegend,
          ],
        ),
      ),
    );
  }
}

/// Chart card that shows per-category stacked bars across statuses
class StatusByCategoryCard extends StatelessWidget {
  const StatusByCategoryCard({super.key, required this.data, this.title = 'Category Status', this.compactLegend = false});

  /// Map of category name -> map of status counts
  final Map<String, Map<TourPlanStatus, int>> data;
  final String title;
  final bool compactLegend;

  @override
  Widget build(BuildContext context) {
    final Map<TourPlanStatus, _StatusMeta> meta = _ChipCloud._statusMeta(Theme.of(context).colorScheme);
    final List<TourPlanStatus> order = [
      TourPlanStatus.planned,
      TourPlanStatus.pending,
      TourPlanStatus.approved,
      TourPlanStatus.leaveDays,
      TourPlanStatus.notEntered,
    ];

    final Widget legend = Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        for (final s in order)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 10, height: 10, decoration: BoxDecoration(color: meta[s]!.color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text(meta[s]!.label, style: Theme.of(context).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
      ],
    );

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleLarge)),
              ],
            ),
            const SizedBox(height: 12),
            if (!compactLegend) legend,
            if (!compactLegend) const SizedBox(height: 8),
            ...data.entries.map((e) {
              final String category = e.key;
              final Map<TourPlanStatus, int> counts = e.value;
              final int total = counts.values.fold(0, (a, b) => a + b);
              return _CategoryStackedBar(
                label: category,
                total: total,
                segments: [
                  for (final s in order)
                    _BarSegment(color: meta[s]!.color, count: counts[s] ?? 0),
                ],
              );
            }),
            if (compactLegend) const SizedBox(height: 8),
            if (compactLegend) legend,
          ],
        ),
      ),
    );
  }
}

class _BarSegment {
  const _BarSegment({required this.color, required this.count});
  final Color color;
  final int count;
}

class _CategoryStackedBar extends StatelessWidget {
  const _CategoryStackedBar({required this.label, required this.total, required this.segments});
  final String label;
  final int total;
  final List<_BarSegment> segments;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color track = Theme.of(context).dividerColor.withOpacity(.25);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(label, style: textTheme.titleMedium),
              ),
              Text('$total', style: textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 6),
          LayoutBuilder(
            builder: (context, constraints) {
              final int positiveTotal = segments.fold(0, (p, s) => p + s.count);
              if (positiveTotal == 0) {
                return Container(height: 10, decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(6)));
              }
              return Stack(
                children: [
                  Container(height: 10, decoration: BoxDecoration(color: track, borderRadius: BorderRadius.circular(6))),
                  Row(
                    children: [
                      for (final seg in segments)
                        if (seg.count > 0)
                          Flexible(
                            flex: seg.count,
                            child: Container(
                              height: 10,
                              decoration: BoxDecoration(color: seg.color.withOpacity(.9), borderRadius: BorderRadius.circular(6)),
                            ),
                          ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}


/// Screenshot-accurate monthly summary card with concentric arc rings
class MonthlyStatusScreenshotCard extends StatelessWidget {
  const MonthlyStatusScreenshotCard({super.key, required this.counts});

  final Map<TourPlanStatus, int> counts;

  @override
  Widget build(BuildContext context) {
    final Map<TourPlanStatus, _StatusMeta> meta = _ChipCloud._statusMeta(Theme.of(context).colorScheme);
    final List<TourPlanStatus> order = [
      TourPlanStatus.planned,
      TourPlanStatus.pending,
      TourPlanStatus.approved,
      TourPlanStatus.leaveDays,
      TourPlanStatus.notEntered,
    ];
    final int total = counts.values.fold(0, (a, b) => a + b);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Always keep a single horizontal row; make the chart compact to fit
        final bool isCompact = constraints.maxWidth < 500;
        final double chartSize = math.min(240, math.max(140, constraints.maxWidth * (isCompact ? 0.28 : 0.36)));

        final Widget chart = SizedBox(
          width: chartSize,
          height: chartSize,
          child: _ConcentricRingsChart(
            values: [
              for (final s in order) (counts[s] ?? 0).toDouble(),
            ],
            colors: [
              meta[TourPlanStatus.planned]!.color,
              meta[TourPlanStatus.pending]!.color,
              meta[TourPlanStatus.approved]!.color,
              meta[TourPlanStatus.leaveDays]!.color,
              meta[TourPlanStatus.notEntered]!.color,
            ],
            ringThickness: 10,
            ringGap: 6,
            sweepDegrees: 360, // full circle
            startDegrees: -90, // start at top
            backgroundRingCount: 5,
            backgroundColor: Theme.of(context).dividerColor.withOpacity(.10),
            center: null,
          ),
        );

        final Widget twoColumnLegend = _LegendTwoColumn(
          items: [
            for (final s in order)
              _LegendItem(
                color: meta[s]!.color,
                label: meta[s]!.label,
                count: counts[s] ?? 0,
                percent: total > 0 ? ((counts[s] ?? 0) / total * 100).round() : 0,
              ),
          ],
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            chart,
            const SizedBox(width: 16),
            Expanded(child: twoColumnLegend),
          ],
        );
      },
    );
  }
}

class _LegendItem {
  const _LegendItem({required this.color, required this.label, required this.count, required this.percent});
  final Color color;
  final String label;
  final int count;
  final int percent;
}

class _LegendTwoColumn extends StatelessWidget {
  const _LegendTwoColumn({
    required this.items,
    this.isTablet = false,
    this.isSmallMobile = false,
  });
  final List<_LegendItem> items;
  final bool isTablet;
  final bool isSmallMobile;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final it in items)
          Padding(
            padding: EdgeInsets.symmetric(vertical: isSmallMobile ? 4 : (isTablet ? 8 : 6)),
            child: Row(
              children: [
                Container(
                  width: isSmallMobile ? 8 : (isTablet ? 10 : 8),
                  height: isSmallMobile ? 8 : (isTablet ? 10 : 8),
                  decoration: BoxDecoration(
                    color: it.color,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: isSmallMobile ? 8 : (isTablet ? 10 : 8)),
                Expanded(
                  child: Text(
                    it.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: isSmallMobile ? 12 : (isTablet ? 15 : 13),
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[900],
                      letterSpacing: -0.1,
                    ),
                  ),
                ),
                SizedBox(width: isSmallMobile ? 4 : (isTablet ? 8 : 6)),
                Text(
                  '${it.percent}% ${it.count}',
                  style: GoogleFonts.inter(
                    color: it.color,
                    fontSize: isSmallMobile ? 11 : (isTablet ? 14 : 12),
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.1,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ConcentricRingsChart extends StatelessWidget {
  const _ConcentricRingsChart({
    required this.values,
    required this.colors,
    this.ringThickness = 12,
    this.ringGap = 8,
    this.sweepDegrees = 240,
    this.startDegrees = -120,
    this.backgroundRingCount = 8,
    this.backgroundColor,
    this.center,
  });

  final List<double> values; // order: outer -> inner
  final List<Color> colors; // same order as values
  final double ringThickness;
  final double ringGap;
  final double sweepDegrees;
  final double startDegrees;
  final int backgroundRingCount; // faint grey rings
  final Color? backgroundColor;
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _RingsPainter(
        values: values,
        colors: colors,
        ringThickness: ringThickness,
        ringGap: ringGap,
        sweepRadians: sweepDegrees * math.pi / 180,
        startRadians: startDegrees * math.pi / 180,
        backgroundRingCount: backgroundRingCount,
        backgroundColor: backgroundColor ?? Theme.of(context).dividerColor.withOpacity(.10),
      ),
      child: Center(child: center),
    );
  }
}

class _RingsPainter extends CustomPainter {
  _RingsPainter({
    required this.values,
    required this.colors,
    required this.ringThickness,
    required this.ringGap,
    required this.sweepRadians,
    required this.startRadians,
    required this.backgroundRingCount,
    required this.backgroundColor,
  });

  final List<double> values; // outer -> inner
  final List<Color> colors;
  final double ringThickness;
  final double ringGap;
  final double sweepRadians;
  final double startRadians;
  final int backgroundRingCount;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final double radius = math.min(size.width, size.height) / 2;

    // Background soft rings
    final double spacing = ringThickness + ringGap;
    final int rings = math.max(backgroundRingCount, values.length + 2);
    final Paint bg = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = ringThickness
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < rings; i++) {
      final double r = radius - (i * spacing) - ringThickness / 2;
      if (r <= 0) break;
      // draw faint full circle background aligned with ring thickness
      canvas.drawArc(
        Rect.fromCircle(center: rect.center, radius: r),
        -math.pi / 2, // start at top
        2 * math.pi, // full circle
        false,
        bg..color = backgroundColor.withOpacity(0.12),
      );
    }

    // Values normalized to percent of total
    final double total = values.fold(0.0, (p, v) => p + v);
    final List<double> ratios = [
      for (final v in values) total > 0 ? (v / total) : 0.0,
    ];

    // Draw colored arcs: outer -> inner
    const double minSweepRadiansForVisibility = 8 * math.pi / 180; // ensure ring is visible even if value is 0
    for (int i = 0; i < values.length; i++) {
      final double r = radius - (i * spacing) - ringThickness / 2;
      if (r <= 0) break;
      double sweep = ratios[i] * sweepRadians;
      if (values[i] <= 0) {
        sweep = minSweepRadiansForVisibility;
      } else if (sweep < minSweepRadiansForVisibility) {
        sweep = minSweepRadiansForVisibility;
      }
      final Paint p = Paint()
        ..color = colors[i]
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringThickness
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(Rect.fromCircle(center: rect.center, radius: r), startRadians, sweep, false, p);
    }
  }

  @override
  bool shouldRepaint(covariant _RingsPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.colors != colors ||
        oldDelegate.ringThickness != ringThickness ||
        oldDelegate.ringGap != ringGap ||
        oldDelegate.sweepRadians != sweepRadians ||
        oldDelegate.startRadians != startRadians ||
        oldDelegate.backgroundRingCount != backgroundRingCount ||
        oldDelegate.backgroundColor != backgroundColor;
  }
}

