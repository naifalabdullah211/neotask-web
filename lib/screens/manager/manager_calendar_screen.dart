import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/task_urgency_indicator.dart';
import '../../widgets/date_nav_arrow_button.dart';
import 'manager_create_task_screen.dart';
import 'task_review_detail_screen.dart';
import '../designer/designer_task_view_screen.dart';

enum _MgrRangeMode { day, week, month }

/// Saturday-start weekday order used ONLY by this screen's week/month
/// *grids* (Gulf/Arabic business-week convention: السبت..الجمعة). This is
/// intentionally independent of `TaskProvider.tasksForWeek`'s Monday-start
/// (ISO-8601) range math — that method is still used unchanged elsewhere
/// (dashboard, reports, employee tasks tab) and must not be touched here.
/// This screen instead calls `tasksForDay` once per day of the
/// Saturday-start week, sidestepping the convention mismatch entirely.
const List<String> _weekdayFullNamesSat = [
  'السبت',
  'الأحد',
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
];

/// Single-letter weekday initials for the monthly grid's tight header row
/// (7 columns leave ~50px per column on a phone). Matches the common
/// Gulf-calendar disambiguation convention: الأربعاء uses "ر" (not "أ",
/// already taken by الأحد) since الأحد and الأربعاء both start with أ.
const List<String> _weekdayInitialsSat = ['س', 'ح', 'ن', 'ث', 'ر', 'خ', 'ج'];

/// Returns the 7 dates (Saturday..Friday) of the Saturday-start week that
/// contains [anchor], each truncated to a plain date (no time-of-day).
List<DateTime> _weekDaysStartingSaturday(DateTime anchor) {
  final date = DateTime(anchor.year, anchor.month, anchor.day);
  // Dart's `%` on int always returns a non-negative result when the
  // divisor is positive, so this maps weekday(Sat=6..Fri=5) -> 0..6
  // without needing an extra `+ 7` guard.
  final daysSinceSaturday = (date.weekday - 6) % 7;
  final saturday = date.subtract(Duration(days: daysSinceSaturday));
  return List.generate(7, (i) => saturday.add(Duration(days: i)));
}

bool _isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Colour representing the single most urgent task in [tasks] ("worst
/// wins": any overdue task paints the whole day-cell badge red, else any
/// due-soon task paints it amber, else green). Returns null for an empty
/// list (no badge shown). Reuses `taskUrgency`'s existing classification
/// (task_urgency_indicator.dart) so this stays consistent with the
/// red/amber/green language used elsewhere in the app instead of
/// inventing a new colour scheme.
Color? _worstUrgencyColor(List<AppTask> tasks) {
  if (tasks.isEmpty) return null;
  if (tasks.any((t) => taskUrgency(t) == TaskUrgency.overdue)) {
    return AppColors.overdue;
  }
  if (tasks.any((t) => taskUrgency(t) == TaskUrgency.dueSoon)) {
    return AppColors.statusPending;
  }
  return AppColors.statusApproved;
}

/// SHARED task card — identical visuals to the previous single ListView
/// so the (unchanged) daily view and the new "day detail" screen (opened
/// by tapping a cell in the monthly grid) render tasks identically.
Widget _taskCard(BuildContext context, AppTask t, {required bool readOnly}) {
  final employee = FirestoreService.getUser(t.assignedTo);
  return Card(
    child: ListTile(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => readOnly
              ? DesignerTaskViewScreen(task: t)
              : TaskReviewDetailScreen(task: t),
        ),
      ),
      leading: TaskUrgencyDot(task: t),
      title: Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              StatusChip(statusName: t.status.name),
              PriorityBadge(priorityName: t.priority.name, compact: true),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${employee?.name ?? "-"} · ${t.category} · '
            '${intl.DateFormat('yyyy/MM/dd').format(t.dueDate)}',
          ),
        ],
      ),
    ),
  );
}

/// Manager-facing task calendar ("التقويم") — a genuine TEMPORAL overview
/// of when tasks are distributed across days/weeks/months, deliberately
/// distinct from the manager dashboard ("المهام"), which gives a STATUS
/// overview (each task's current state). Three modes:
///  - Day: today's task list (unchanged from the original implementation).
///  - Week: a horizontal 7-column grid (one column per weekday), each
///    showing that day's task count + abbreviated titles.
///  - Month: a classic calendar grid (rows × 7 columns), each day cell
///    showing the day number + a single colour-coded count badge; tapping
///    a cell opens a detailed task list for that specific day.
class ManagerCalendarScreen extends StatefulWidget {
  const ManagerCalendarScreen({super.key, this.readOnly = false});

  /// True when reached from the read-only `designer` role's drawer: hides
  /// the "مهمة جديدة" FAB and routes taps to the read-only
  /// DesignerTaskViewScreen instead of TaskReviewDetailScreen (which has
  /// live approve/reject/edit-request buttons a designer must never see).
  final bool readOnly;

  @override
  State<ManagerCalendarScreen> createState() => _ManagerCalendarScreenState();
}

class _ManagerCalendarScreenState extends State<ManagerCalendarScreen> {
  _MgrRangeMode _mode = _MgrRangeMode.day;
  DateTime _anchor = DateTime.now();

  void _shift(int direction) {
    setState(() {
      switch (_mode) {
        case _MgrRangeMode.day:
          _anchor = _anchor.add(Duration(days: direction));
          break;
        case _MgrRangeMode.week:
          _anchor = _anchor.add(Duration(days: 7 * direction));
          break;
        case _MgrRangeMode.month:
          _anchor = DateTime(_anchor.year, _anchor.month + direction, 1);
          break;
      }
    });
  }

  String get _rangeLabel {
    final df = intl.DateFormat('yyyy/MM/dd');
    switch (_mode) {
      case _MgrRangeMode.day:
        return df.format(_anchor);
      case _MgrRangeMode.week:
        final days = _weekDaysStartingSaturday(_anchor);
        return '${df.format(days.first)} - ${df.format(days.last)}';
      case _MgrRangeMode.month:
        return '${_anchor.year}/${_anchor.month.toString().padLeft(2, '0')}';
    }
  }

  /// Arabic period noun used to build tooltip labels ('اليوم التالي',
  /// 'الأسبوع السابق', ...) matching the currently-selected range mode.
  String get _periodLabel {
    switch (_mode) {
      case _MgrRangeMode.day:
        return 'اليوم';
      case _MgrRangeMode.week:
        return 'الأسبوع';
      case _MgrRangeMode.month:
        return 'الشهر';
    }
  }

  void _openDayDetail(DateTime day) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _DayDetailScreen(day: day, readOnly: widget.readOnly),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Day mode — UNCHANGED behaviour (per explicit requirement): flat list
  // of today's tasks, identical to the original single-ListView screen.
  // ---------------------------------------------------------------------
  Widget _buildDayBody(TaskProvider provider) {
    final tasks = provider.tasksForDay(_anchor);
    if (tasks.isEmpty) {
      return const Center(
        child: Text(
          'لا توجد مهام في هذه الفترة',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: tasks.length,
      itemBuilder: (context, index) =>
          _taskCard(context, tasks[index], readOnly: widget.readOnly),
    );
  }

  // ---------------------------------------------------------------------
  // Week mode — horizontal 7-column grid (Saturday..Friday). Each column
  // shows that day's task count + up to 3 abbreviated titles.
  // ---------------------------------------------------------------------
  Widget _buildWeekBody(TaskProvider provider) {
    final weekDays = _weekDaysStartingSaturday(_anchor);
    final today = DateTime.now();
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(7, (i) {
          final day = weekDays[i];
          final tasks = provider.tasksForDay(day);
          final isToday = _isSameDate(day, today);
          return Expanded(
            child: _WeekDayColumn(
              day: day,
              label: _weekdayFullNamesSat[i],
              tasks: tasks,
              isToday: isToday,
            ),
          );
        }),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Month mode — classic calendar grid (rows × 7 columns). Tapping a cell
  // opens the detailed task list for that day (_DayDetailScreen).
  // ---------------------------------------------------------------------
  Widget _buildMonthBody(TaskProvider provider) {
    final monthTasks = provider.tasksForMonth(_anchor);
    final grouped = <int, List<AppTask>>{};
    for (final t in monthTasks) {
      grouped.putIfAbsent(t.dueDate.day, () => []).add(t);
    }

    final firstOfMonth = DateTime(_anchor.year, _anchor.month, 1);
    final daysInMonth = DateTime(_anchor.year, _anchor.month + 1, 0).day;
    final leadingBlanks = (firstOfMonth.weekday - 6) % 7;
    final totalCells = leadingBlanks + daysInMonth;
    final rows = (totalCells / 7).ceil();
    final gridCellCount = rows * 7;
    final today = DateTime.now();

    return Column(
      children: [
        // Weekday initials header row (السبت..الجمعة, single letters).
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: _weekdayInitialsSat
                .map(
                  (l) => Expanded(
                    child: Center(
                      child: Text(
                        l,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                childAspectRatio: 0.8,
                crossAxisSpacing: 4,
                mainAxisSpacing: 4,
              ),
              itemCount: gridCellCount,
              itemBuilder: (context, index) {
                if (index < leadingBlanks ||
                    index >= leadingBlanks + daysInMonth) {
                  return const SizedBox.shrink();
                }
                final dayNum = index - leadingBlanks + 1;
                final day = DateTime(_anchor.year, _anchor.month, dayNum);
                final dayTasks = grouped[dayNum] ?? const <AppTask>[];
                final isToday = _isSameDate(day, today);
                return _MonthDayCell(
                  dayNumber: dayNum,
                  taskCount: dayTasks.length,
                  badgeColor: _worstUrgencyColor(dayTasks),
                  isToday: isToday,
                  onTap: () => _openDayDetail(day),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('التقويم')),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        ManagerCreateTaskScreen(initialDueDate: _anchor),
                  ),
                );
              },
              icon: const Icon(Icons.add_task),
              label: const Text('مهمة جديدة'),
            ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<_MgrRangeMode>(
                segments: const [
                  ButtonSegment(value: _MgrRangeMode.day, label: Text('يومي')),
                  ButtonSegment(
                    value: _MgrRangeMode.week,
                    label: Text('أسبوعي'),
                  ),
                  ButtonSegment(
                    value: _MgrRangeMode.month,
                    label: Text('شهري'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (s) => setState(() => _mode = s.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // RTL: right arrow = next period, left arrow = previous.
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
            ),
            Expanded(
              child: switch (_mode) {
                _MgrRangeMode.day => _buildDayBody(provider),
                _MgrRangeMode.week => _buildWeekBody(provider),
                _MgrRangeMode.month => _buildMonthBody(provider),
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One column of the weekly grid: weekday name + date, a count badge, and
/// up to 3 abbreviated task titles (remainder collapsed into "+N").
class _WeekDayColumn extends StatelessWidget {
  const _WeekDayColumn({
    required this.day,
    required this.label,
    required this.tasks,
    required this.isToday,
  });

  final DateTime day;
  final String label;
  final List<AppTask> tasks;
  final bool isToday;

  static const _maxNamesShown = 3;

  @override
  Widget build(BuildContext context) {
    final badgeColor = _worstUrgencyColor(tasks);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      decoration: BoxDecoration(
        color: isToday
            ? AppColors.gold.withValues(alpha: 0.08)
            : AppColors.surface,
        border: Border.all(
          color: isToday
              ? AppColors.gold
              : AppColors.textSecondary.withValues(alpha: 0.2),
          width: isToday ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${day.day}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isToday ? AppColors.gold : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          if (badgeColor != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '${tasks.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          Expanded(
            child: tasks.isEmpty
                ? const SizedBox.shrink()
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      ...tasks
                          .take(_maxNamesShown)
                          .map(
                            (t) => Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 1.5,
                              ),
                              child: Text(
                                t.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 9.5),
                              ),
                            ),
                          ),
                      if (tasks.length > _maxNamesShown)
                        Text(
                          '+${tasks.length - _maxNamesShown}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 9.5,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
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

/// One cell of the monthly calendar grid: day number + a single
/// colour-coded count badge (colour = worst urgency among that day's
/// tasks; see `_worstUrgencyColor`). Tapping opens the day's task list.
class _MonthDayCell extends StatelessWidget {
  const _MonthDayCell({
    required this.dayNumber,
    required this.taskCount,
    required this.badgeColor,
    required this.isToday,
    required this.onTap,
  });

  final int dayNumber;
  final int taskCount;
  final Color? badgeColor;
  final bool isToday;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: isToday
              ? AppColors.gold.withValues(alpha: 0.1)
              : AppColors.surface,
          border: Border.all(
            color: isToday
                ? AppColors.gold
                : AppColors.textSecondary.withValues(alpha: 0.15),
            width: isToday ? 1.5 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '$dayNumber',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isToday ? AppColors.gold : AppColors.textPrimary,
              ),
            ),
            if (badgeColor != null)
              Positioned(
                bottom: 3,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: badgeColor,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$taskCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Detailed task list for a single day — opened by tapping a monthly-grid
/// cell. Reuses `_taskCard` so the card design exactly matches the
/// (unchanged) daily view.
class _DayDetailScreen extends StatelessWidget {
  const _DayDetailScreen({required this.day, required this.readOnly});

  final DateTime day;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final tasks = provider.tasksForDay(day);
    return Scaffold(
      appBar: AppBar(
        title: Text('مهام يوم ${intl.DateFormat('yyyy/MM/dd').format(day)}'),
      ),
      body: SafeArea(
        child: tasks.isEmpty
            ? const Center(
                child: Text(
                  'لا توجد مهام في هذا اليوم',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                itemBuilder: (context, index) =>
                    _taskCard(context, tasks[index], readOnly: readOnly),
              ),
      ),
    );
  }
}
