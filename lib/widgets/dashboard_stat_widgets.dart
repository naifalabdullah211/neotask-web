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
        borderRadius: BorderRadius.circular(AppRadius.lg - 2),
        border: Border.all(color: color.withValues(alpha: 0.18)),
        boxShadow: AppElevation.lowShadow,
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
              borderRadius: BorderRadius.circular(AppRadius.sm + 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: AppIconSize.md + 2, color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '$value',
            style: AppTextStyles.statValue.copyWith(fontSize: 26, height: 1),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.sectionLabel.copyWith(fontSize: 11),
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
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppElevation.mediumShadow,
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
                    // Small decorative accent bar radius — below the
                    // smallest named token ([AppRadius.sm]=8), kept as a
                    // literal since a named token for a 4px "bar cap"
                    // radius would add no reuse value.
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
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
                          padding: const EdgeInsets.only(top: AppSpacing.sm),
                          child: Text(
                            bars[i].label,
                            style: AppTextStyles.sectionLabel.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
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
                          borderRadius: BorderRadius.circular(AppRadius.sm),
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
                          // Legend color-dot radius — tiny decorative
                          // value, same rationale as above.
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm - 2),
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
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.pill),
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
      duration: AppMotion.medium,
      curve: AppMotion.standard,
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.pill),
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
        borderRadius: BorderRadius.circular(AppRadius.pill),
        child: InkWell(
          onTap: selected ? null : onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
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
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxl + 12),
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
                size: AppIconSize.xl + 12,
                color: AppColors.deepBlue,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(title, style: AppTextStyles.cardTitle.copyWith(fontSize: 15)),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              onAddTask != null
                  ? 'يمكنك إضافة مهمة جديدة الآن أو تصفّح فترة أخرى'
                  : 'يمكنك تصفّح فترة أخرى',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySecondary.copyWith(fontSize: 12.5),
            ),
            if (onAddTask != null) ...[
              const SizedBox(height: AppSpacing.lg + 2),
              // NOTE: `mintAccent` is intentionally kept here (not the
              // theme's default deepBlue ElevatedButton fill) — it is the
              // app's documented third accent hue reserved for quick-add
              // task actions (see AppColors.mintAccent doc comment) and
              // this CTA is exactly that action, just reached from an
              // empty state instead of the FAB. Colour is preserved
              // per the branding-preservation requirement; only the
              // padding/radius/icon size below are now tokenized to match
              // every other button in the app.
              ElevatedButton.icon(
                onPressed: onAddTask,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mintAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl,
                    vertical: AppSpacing.md,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                icon: const Icon(Icons.add, size: AppIconSize.sm + 2),
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
