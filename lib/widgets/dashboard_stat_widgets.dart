import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';

/// SHARED, single-implementation versions of the manager dashboard's stat
/// card / completion chart / time-range segmented control / empty state,
/// extracted out of manager_dashboard_tab.dart so BOTH the main dashboard
/// AND the new per-employee stats feature
/// (manager_employees_tab.dart's mini summary row + the employee stats
/// detail page) render from the exact same widget classes — not visually
/// similar copies that could silently drift apart over time. This file
/// intentionally contains ONLY presentation widgets; all NUMBER
/// computation still lives in `lib/utils/task_stats.dart`
/// (computeTaskStats/computeOnTimeStats), per the single-source-of-truth
/// requirement.

/// Public time-range mode, shared by the main dashboard and the employee
/// stats detail page's own "يومي/أسبوعي/شهري" filter.
enum TimeRangeMode { day, week, month }

/// One dashboard stat card (icon chip + value + Arabic label), colored
/// from the shared [dashboardMetricColors]/[dashboardMetricIcons] maps.
/// Used at ORIGINAL size on both the main dashboard and the employee
/// detail page (per explicit requirement: same design, same size).
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.metric, required this.value});

  final DashboardMetric metric;
  final int value;

  static const double boxWidth = 108;

  @override
  Widget build(BuildContext context) {
    final color = dashboardMetricColors[metric]!;
    final label = dashboardMetricLabelsAr[metric]!;
    final icon = dashboardMetricIcons[metric]!;
    return Container(
      width: boxWidth,
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.10),
            color.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 22, color: Colors.white),
          ),
          const SizedBox(height: 12),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarSpec {
  _BarSpec(this.metric, this.value)
    : label = dashboardMetricLabelsAr[metric]!,
      color = dashboardMetricColors[metric]!;
  final DashboardMetric metric;
  final int value;
  final String label;
  final Color color;
}

/// "المنجز مقابل المتأخر" completed/overdue/pending bar chart — identical
/// design used by the main dashboard AND (scoped to one employee) the new
/// employee stats detail page.
class CompletionChartCard extends StatelessWidget {
  const CompletionChartCard({
    super.key,
    required this.completed,
    required this.overdue,
    required this.pending,
  });

  final int completed;
  final int overdue;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final maxVal = [
      completed,
      overdue,
      pending,
    ].fold<int>(1, (m, v) => v > m ? v : m);
    final maxY = (maxVal * 1.35).ceilToDouble();

    final bars = <_BarSpec>[
      _BarSpec(DashboardMetric.completed, completed),
      _BarSpec(DashboardMetric.overdue, overdue),
      _BarSpec(DashboardMetric.pending, pending),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7E9EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'المنجز مقابل المتأخر',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            height: 260,
            width: double.infinity,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                alignment: BarChartAlignment.spaceEvenly,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY / 4).clamp(1, double.infinity),
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: const Color(0xFFEEF0F4), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= bars.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            bars[i].label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < bars.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: bars[i].value.toDouble(),
                          color: bars[i].color,
                          width: 50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Forced ltr so this legend row's visual order matches the
          // chart's own left-to-right bar order regardless of ambient
          // RTL Directionality — see original doc comment history in
          // manager_dashboard_tab.dart for the color-mismatch this fixes.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final b in bars)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: b.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${b.value}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: b.color,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Unified pill-shaped navy segmented control for يومي/أسبوعي/شهري —
/// shared by the main dashboard and the employee stats detail page's own
/// time filter.
class TimeRangeSegmented extends StatelessWidget {
  const TimeRangeSegmented({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final TimeRangeMode mode;
  final ValueChanged<TimeRangeMode> onChanged;

  static const _options = [
    (TimeRangeMode.day, 'يومي'),
    (TimeRangeMode.week, 'أسبوعي'),
    (TimeRangeMode.month, 'شهري'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          for (final (value, label) in _options)
            Expanded(
              child: _TimeRangeSegmentButton(
                label: label,
                selected: mode == value,
                onTap: () => onChanged(value),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimeRangeSegmentButton extends StatelessWidget {
  const _TimeRangeSegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: selected ? null : onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? AppColors.navy : Colors.white70,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Designed empty state (icon + title + subtitle), reused wherever a
/// filtered task list is empty. [onAddTask] is optional — the employee
/// stats detail page has no task-creation entry point of its own, so it
/// omits the CTA button entirely rather than duplicating quick-add logic.
class NoTasksEmptyState extends StatelessWidget {
  const NoTasksEmptyState({super.key, required this.title, this.onAddTask});

  final String title;
  final VoidCallback? onAddTask;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.deepBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_available_outlined,
                size: 44,
                color: AppColors.deepBlue,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              onAddTask != null
                  ? 'يمكنك إضافة مهمة جديدة الآن أو تصفّح فترة أخرى'
                  : 'يمكنك تصفّح فترة أخرى',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textSecondary,
              ),
            ),
            if (onAddTask != null) ...[
              const SizedBox(height: 18),
              ElevatedButton.icon(
                onPressed: onAddTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mintAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.add, size: 18),
                label: const Text(
                  'إضافة مهمة جديدة',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
