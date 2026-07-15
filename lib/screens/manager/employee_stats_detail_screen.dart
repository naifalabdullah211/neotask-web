import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/task_stats.dart';
import '../../widgets/dashboard_stat_widgets.dart';
import '../../widgets/date_nav_arrow_button.dart';
import '../../widgets/task_list_tile.dart';

/// Per-employee statistics detail page (Level 2 of the employee-stats
/// feature). Opens when the manager taps an employee's name/card on the
/// "الموظفون" screen.
///
/// DATA-INTEGRITY REQUIREMENT (explicit, from the manager): every number
/// shown here MUST come from the exact same single source of truth already
/// used by the main dashboard — [TaskProvider.allTasks] filtered to this
/// employee, then classified via [computeTaskStats]/[computeOnTimeStats]
/// (lib/utils/task_stats.dart), the SAME functions the main dashboard
/// calls. This screen introduces NO independent counting logic of its own.
class EmployeeStatsDetailScreen extends StatefulWidget {
  const EmployeeStatsDetailScreen({super.key, required this.employee});

  final AppUser employee;

  @override
  State<EmployeeStatsDetailScreen> createState() =>
      _EmployeeStatsDetailScreenState();
}

class _EmployeeStatsDetailScreenState extends State<EmployeeStatsDetailScreen> {
  TimeRangeMode _mode = TimeRangeMode.day;
  DateTime _anchor = DateTime.now();

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

  List<AppTask> _tasksForRange(TaskProvider provider) {
    switch (_mode) {
      case TimeRangeMode.day:
        return provider.tasksForDay(_anchor, employeeUid: widget.employee.uid);
      case TimeRangeMode.week:
        return provider.tasksForWeek(_anchor, employeeUid: widget.employee.uid);
      case TimeRangeMode.month:
        return provider.tasksForMonth(
          _anchor,
          employeeUid: widget.employee.uid,
        );
    }
  }

  void _shift(int direction) {
    setState(() {
      switch (_mode) {
        case TimeRangeMode.day:
          _anchor = _anchor.add(Duration(days: direction));
          break;
        case TimeRangeMode.week:
          _anchor = _anchor.add(Duration(days: 7 * direction));
          break;
        case TimeRangeMode.month:
          _anchor = DateTime(_anchor.year, _anchor.month + direction, 1);
          break;
      }
    });
  }

  String get _rangeLabel {
    final df = intl.DateFormat('yyyy/MM/dd');
    switch (_mode) {
      case TimeRangeMode.day:
        return df.format(_anchor);
      case TimeRangeMode.week:
        final weekday = _anchor.weekday;
        final start = _anchor.subtract(Duration(days: weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${df.format(start)} - ${df.format(end)}';
      case TimeRangeMode.month:
        return '${_arabicMonths[_anchor.month - 1]} ${_anchor.year}';
    }
  }

  String get _emptyStateTitle {
    switch (_mode) {
      case TimeRangeMode.day:
        return 'لا توجد مهام مجدولة اليوم';
      case TimeRangeMode.week:
        return 'لا توجد مهام مجدولة هذا الأسبوع';
      case TimeRangeMode.month:
        return 'لا توجد مهام مجدولة هذا الشهر';
    }
  }

  String get _periodLabel {
    switch (_mode) {
      case TimeRangeMode.day:
        return 'اليوم';
      case TimeRangeMode.week:
        return 'الأسبوع';
      case TimeRangeMode.month:
        return 'الشهر';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final managerUid = context.read<AuthProvider>().currentUser!.uid;
    final rangeTasks = _tasksForRange(provider);
    // SINGLE SOURCE OF TRUTH: same computeTaskStats/computeOnTimeStats
    // functions the main dashboard uses, applied to this employee's
    // period-filtered tasks only.
    final stats = computeTaskStats(rangeTasks);
    final onTime = computeOnTimeStats(rangeTasks);

    return Scaffold(
      appBar: AppBar(title: Text(widget.employee.name)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.deepBlue.withValues(alpha: 0.1),
                    child: Text(
                      widget.employee.name.isNotEmpty
                          ? widget.employee.name[0]
                          : '?',
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.employee.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.employee.email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Detail-page-specific يومي/أسبوعي/شهري filter — independent
              // state from the main dashboard's own filter, per explicit
              // requirement ("فلتر زمني خاص بهذه الصفحة").
              TimeRangeSegmented(
                mode: _mode,
                onChanged: (m) => setState(() => _mode = m),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  DateNavArrowButton.next(
                    onTap: () => _shift(1),
                    periodLabel: _periodLabel,
                  ),
                  Text(
                    _rangeLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  DateNavArrowButton.previous(
                    onTap: () => _shift(-1),
                    periodLabel: _periodLabel,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    // Six full-size stat cards — identical widget/design
                    // to the main dashboard's cards (StatCard, shared).
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        StatCard(
                          metric: DashboardMetric.total,
                          value: stats.total,
                        ),
                        StatCard(
                          metric: DashboardMetric.completed,
                          value: stats.completed,
                        ),
                        StatCard(
                          metric: DashboardMetric.pending,
                          value: stats.pendingDisplay,
                        ),
                        StatCard(
                          metric: DashboardMetric.review,
                          value: stats.submitted,
                        ),
                        StatCard(
                          metric: DashboardMetric.rejected,
                          value: stats.rejected,
                        ),
                        StatCard(
                          metric: DashboardMetric.overdue,
                          value: stats.overdue,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Same "المنجز مقابل المتأخر" chart design as the main
                    // dashboard, scoped to this employee's period-filtered
                    // tasks.
                    CompletionChartCard(
                      completed: stats.completed,
                      overdue: stats.overdue,
                      pending: stats.pendingDisplay,
                    ),
                    const SizedBox(height: 20),
                    _OnTimeProminentCard(onTime: onTime),
                    const SizedBox(height: 20),
                    Text(
                      'مهام ${widget.employee.name} (${rangeTasks.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (rangeTasks.isEmpty)
                      NoTasksEmptyState(title: _emptyStateTitle)
                    else
                      ...rangeTasks.map(
                        (t) => TaskListTile(task: t, managerUid: managerUid),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prominent circular on-time-completion-percentage display — larger and
/// more emphasized than the mini row's tiny percentage number, per
/// explicit requirement ("بشكل أبرز وأكبر — بطاقة مستقلة أو مؤشر دائري").
/// Reads from the SAME [OnTimeStats] computed by [computeOnTimeStats] —
/// no independent recalculation.
class _OnTimeProminentCard extends StatelessWidget {
  const _OnTimeProminentCard({required this.onTime});

  final OnTimeStats onTime;

  @override
  Widget build(BuildContext context) {
    final percent = onTime.percent;
    final color = percent == null
        ? AppColors.textSecondary
        : onTimePercentTierColor(percent);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
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
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: percent == null ? 0 : (percent / 100).clamp(0, 1),
                  strokeWidth: 8,
                  backgroundColor: color.withValues(alpha: 0.12),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
                Text(
                  percent == null ? '—' : '${percent.round()}%',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'نسبة الإنجاز في الوقت المحدد',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  onTime.completedCount == 0
                      ? 'لا توجد بيانات كافية (لا مهام مكتملة في هذه الفترة)'
                      : '${onTime.onTimeCount} من ${onTime.completedCount} مهمة مكتملة قبل أو في تاريخ الاستحقاق',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
