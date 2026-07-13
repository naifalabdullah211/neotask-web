import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/task_urgency_indicator.dart';
import 'designer_task_view_screen.dart';

enum _RangeMode { day, week, month }

/// Read-only dashboard tab for the `designer` observer role. Mirrors
/// ManagerDashboardTab's day/week/month stat-card layout exactly (per the
/// "1-a" full-read-access answer — the designer must see the same
/// aggregate tracking view the manager sees), but every task tap routes to
/// [DesignerTaskViewScreen] (no action buttons) instead of
/// TaskReviewDetailScreen, and taps are enabled for EVERY status (not just
/// `submitted`, unlike the manager's review-only shortcut) since there is
/// no write action gated behind the tap here — it is purely informational.
class DesignerDashboardTab extends StatefulWidget {
  const DesignerDashboardTab({super.key});

  @override
  State<DesignerDashboardTab> createState() => _DesignerDashboardTabState();
}

class _DesignerDashboardTabState extends State<DesignerDashboardTab> {
  _RangeMode _mode = _RangeMode.day;
  DateTime _anchor = DateTime.now();

  List<AppTask> _tasksForRange(TaskProvider provider) {
    switch (_mode) {
      case _RangeMode.day:
        return provider.tasksForDay(_anchor);
      case _RangeMode.week:
        return provider.tasksForWeek(_anchor);
      case _RangeMode.month:
        return provider.tasksForMonth(_anchor);
    }
  }

  void _shift(int direction) {
    setState(() {
      switch (_mode) {
        case _RangeMode.day:
          _anchor = _anchor.add(Duration(days: direction));
          break;
        case _RangeMode.week:
          _anchor = _anchor.add(Duration(days: 7 * direction));
          break;
        case _RangeMode.month:
          _anchor = DateTime(_anchor.year, _anchor.month + direction, 1);
          break;
      }
    });
  }

  String get _rangeLabel {
    final df = intl.DateFormat('yyyy/MM/dd');
    switch (_mode) {
      case _RangeMode.day:
        return df.format(_anchor);
      case _RangeMode.week:
        final weekday = _anchor.weekday;
        final start = _anchor.subtract(Duration(days: weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${df.format(start)} - ${df.format(end)}';
      case _RangeMode.month:
        return '${_arabicMonths[_anchor.month - 1]} ${_anchor.year}';
    }
  }

  static const _arabicMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  String _modeLabel(_RangeMode m) {
    switch (m) {
      case _RangeMode.day:
        return 'يومي';
      case _RangeMode.week:
        return 'أسبوعي';
      case _RangeMode.month:
        return 'شهري';
    }
  }

  IconData get _modeIcon {
    switch (_mode) {
      case _RangeMode.day:
        return Icons.today_outlined;
      case _RangeMode.week:
        return Icons.view_week_outlined;
      case _RangeMode.month:
        return Icons.calendar_month_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final rangeTasks = _tasksForRange(provider);
    final stats = provider.statsForRange(rangeTasks);

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Eye-catching gradient card combining the range-mode DROPDOWN
          // (replaces the previous 3-way SegmentedButton per user request)
          // with the day/week/month date navigator.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.deepBlue.withValues(alpha: 0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<_RangeMode>(
                      value: _mode,
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      icon: const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                      ),
                      selectedItemBuilder: (context) => _RangeMode.values
                          .map(
                            (m) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_modeIcon, size: 16, color: Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  _modeLabel(m),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                      items: _RangeMode.values
                          .map(
                            (m) => DropdownMenuItem(
                              value: m,
                              child: Text(
                                _modeLabel(m),
                                style: const TextStyle(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _mode = v);
                      },
                    ),
                  ),
                ),
                Row(
                  children: [
                    _NavArrowButton(
                      icon: Icons.chevron_right,
                      onTap: () => _shift(1),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _rangeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 4),
                    _NavArrowButton(
                      icon: Icons.chevron_left,
                      onTap: () => _shift(-1),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Fixed-size boxes via Wrap — NOT a GridView. A GridView.count
          // divides the FULL available width into N stretched columns, so
          // on a wide desktop browser window each colored frame becomes a
          // huge square while the icon/number/label inside stay tiny (the
          // exact "كبرت الاطار و صغرت الكلام" bug the user reported). Wrap
          // instead sizes each card to its own fixed width regardless of
          // viewport size, keeping the frame small and letting text/icon
          // size be set proportionally to that fixed box.
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatCard(
                label: 'الإجمالي',
                value: stats['total']!,
                color: AppColors.deepBlue,
                icon: Icons.assignment_outlined,
              ),
              _StatCard(
                label: 'مكتملة',
                value: stats['approved']!,
                color: AppColors.statusApproved,
                icon: Icons.check_circle_outline,
              ),
              _StatCard(
                label: 'قيد الانتظار',
                value: stats['pending']!,
                color: AppColors.statusPending,
                icon: Icons.hourglass_empty,
              ),
              _StatCard(
                label: 'بانتظار المراجعة',
                value: stats['submitted']!,
                color: AppColors.statusSubmitted,
                icon: Icons.rate_review_outlined,
              ),
              _StatCard(
                label: 'مرفوضة',
                value: stats['rejected']!,
                color: AppColors.statusRejected,
                icon: Icons.cancel_outlined,
              ),
              _StatCard(
                label: 'متأخرة',
                value: stats['overdue']!,
                color: Colors.orange.shade800,
                icon: Icons.warning_amber_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Container(
                width: 8,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.purple,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'المهام (${rangeTasks.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (rangeTasks.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'لا توجد مهام في هذه الفترة',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...rangeTasks.map((t) => _TaskCard(task: t)),
        ],
      ),
    );
  }
}

/// Compact circular chevron button used for the day/week/month navigator,
/// styled to sit on the dark gradient header (white translucent circle).
class _NavArrowButton extends StatelessWidget {
  const _NavArrowButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}

/// Eye-catching task row: a colored left accent stripe (matches the task's
/// status color) + soft-tinted background, replacing the previous plain
/// [Card]/[ListTile] row.
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final AppTask task;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(task.status.name);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DesignerTaskViewScreen(task: task),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: const BorderRadius.horizontal(
                        left: Radius.circular(14),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          TaskUrgencyDot(task: task),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${task.category} · ${intl.DateFormat('yyyy/MM/dd').format(task.dueDate)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              StatusChip(statusName: task.status.name),
                              const SizedBox(height: 4),
                              PriorityBadge(
                                priorityName: task.priority.name,
                                compact: true,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final IconData icon;

  const _StatCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  // Fixed footprint (independent of screen/viewport width) — this is what
  // keeps the colored frame small on a wide desktop browser instead of
  // stretching to fill a GridView column.
  static const double _boxWidth = 104;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _boxWidth,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.14),
            color.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
