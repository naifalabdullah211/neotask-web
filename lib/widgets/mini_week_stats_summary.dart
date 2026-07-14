import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Compact "screen filler" widget shown below the employee's task list
/// whenever there aren't enough tasks to occupy the screen — per explicit
/// request: "لا تترك أكثر من 40% من الشاشة فارغة بدون عنصر بصري" (don't
/// leave more than 40% of the screen empty without a visual element).
///
/// Shows completed/pending counts for the CURRENT calendar week. Reuses
/// [dashboardMetricColors]/[dashboardMetricLabelsAr] as the single source
/// of truth for the "completed"/"pending" color+label pair, matching the
/// manager dashboard's stat cards instead of inventing new colors.
class MiniWeekStatsSummary extends StatelessWidget {
  const MiniWeekStatsSummary({
    super.key,
    required this.completedThisWeek,
    required this.pendingThisWeek,
  });

  final int completedThisWeek;
  final int pendingThisWeek;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'ملخص هذا الأسبوع',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _StatBlock(
                    value: completedThisWeek,
                    label: dashboardMetricLabelsAr[DashboardMetric.completed]!,
                    color: dashboardMetricColors[DashboardMetric.completed]!,
                    icon: Icons.check_circle_outline,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _StatBlock(
                    value: pendingThisWeek,
                    label: dashboardMetricLabelsAr[DashboardMetric.pending]!,
                    color: dashboardMetricColors[DashboardMetric.pending]!,
                    icon: Icons.hourglass_bottom_outlined,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({
    required this.value,
    required this.label,
    required this.color,
    required this.icon,
  });

  final int value;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
