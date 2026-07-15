import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/task_urgency_indicator.dart';
import '../../widgets/mini_week_stats_summary.dart';
import '../../widgets/date_nav_arrow_button.dart';
import '../../widgets/favorite_star_button.dart';
import '../../widgets/task_kanban_board.dart';
import 'task_detail_screen.dart';

/// Below this task count, the list alone will not fill a typical mobile
/// screen — per explicit request "لا تترك أكثر من 40% من الشاشة فارغة
/// بدون عنصر بصري" (don't leave more than 40% of the screen empty without
/// a visual element), the mini weekly stat summary is appended below the
/// list (or shown alone, in the empty case) once the count drops to/below
/// this threshold. Heuristic, not a measured layout percentage — each
/// task Card is ~96px tall vs. a ~700px usable list area on a typical
/// phone, so 3 cards (~288px) still leaves well over 40% empty.
const int _kFewTasksThreshold = 3;

enum _EmpRangeMode { day, week, month }

/// "قائمة"/"لوحة" view-mode toggle — same feature as the manager dashboard
/// (see manager_dashboard_tab.dart), but VIEW-ONLY here: the employee can
/// switch to Kanban to see the same status-grouped board, but cards are
/// not draggable (per explicit requirement #6 — "الموظف العادي عرض فقط،
/// بدون Drag & Drop"). Persisted separately from the manager's preference
/// (distinct SharedPreferences key) since each role's choice is
/// independent.
enum _EmpViewMode { list, kanban }

const _kEmpViewModePrefKey = 'employee_tasks_view_mode';

class EmployeeTasksTab extends StatefulWidget {
  final String employeeUid;
  const EmployeeTasksTab({super.key, required this.employeeUid});

  @override
  State<EmployeeTasksTab> createState() => _EmployeeTasksTabState();
}

class _EmployeeTasksTabState extends State<EmployeeTasksTab> {
  _EmpRangeMode _mode = _EmpRangeMode.day;
  DateTime _anchor = DateTime.now();
  _EmpViewMode _viewMode = _EmpViewMode.list;

  @override
  void initState() {
    super.initState();
    _loadViewModePreference();
  }

  Future<void> _loadViewModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kEmpViewModePrefKey);
    if (saved == _EmpViewMode.kanban.name && mounted) {
      setState(() => _viewMode = _EmpViewMode.kanban);
    }
  }

  Future<void> _setViewMode(_EmpViewMode mode) async {
    setState(() => _viewMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kEmpViewModePrefKey, mode.name);
  }

  Widget _viewToggleButton(_EmpViewMode mode, IconData icon, String label) {
    final selected = _viewMode == mode;
    return Expanded(
      child: InkWell(
        onTap: selected ? null : () => _setViewMode(mode),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<AppTask> _tasksForRange(TaskProvider provider) {
    switch (_mode) {
      case _EmpRangeMode.day:
        return provider.tasksForDay(_anchor, employeeUid: widget.employeeUid);
      case _EmpRangeMode.week:
        return provider.tasksForWeek(_anchor, employeeUid: widget.employeeUid);
      case _EmpRangeMode.month:
        return provider.tasksForMonth(_anchor, employeeUid: widget.employeeUid);
    }
  }

  void _shift(int direction) {
    setState(() {
      switch (_mode) {
        case _EmpRangeMode.day:
          _anchor = _anchor.add(Duration(days: direction));
          break;
        case _EmpRangeMode.week:
          _anchor = _anchor.add(Duration(days: 7 * direction));
          break;
        case _EmpRangeMode.month:
          _anchor = DateTime(_anchor.year, _anchor.month + direction, 1);
          break;
      }
    });
  }

  String get _rangeLabel {
    final df = intl.DateFormat('yyyy/MM/dd');
    switch (_mode) {
      case _EmpRangeMode.day:
        return df.format(_anchor);
      case _EmpRangeMode.week:
        final weekday = _anchor.weekday;
        final start = _anchor.subtract(Duration(days: weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${df.format(start)} - ${df.format(end)}';
      case _EmpRangeMode.month:
        return '${_anchor.year}/${_anchor.month.toString().padLeft(2, '0')}';
    }
  }

  /// Arabic period noun used to build tooltip labels ("اليوم التالي",
  /// "الأسبوع السابق", ...) matching the currently-selected range mode.
  String get _periodLabel {
    switch (_mode) {
      case _EmpRangeMode.day:
        return 'اليوم';
      case _EmpRangeMode.week:
        return 'الأسبوع';
      case _EmpRangeMode.month:
        return 'الشهر';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final tasks = _tasksForRange(provider);
    // NEW — tasks a manager approved for reassignment TO this employee,
    // awaiting this employee's own confirmation of receipt (per the
    // manager's design answer "٦- يحتاج لتأكيد استلامها").
    final awaitingConfirmation = provider.reassignmentsAwaitingConfirmation(
      widget.employeeUid,
    );

    return SafeArea(
      child: Column(
        children: [
          if (awaitingConfirmation.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'مهام بانتظار تأكيد استلامك',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...awaitingConfirmation.map(
                    (t) => _ReassignConfirmationCard(
                      task: t,
                      employeeUid: widget.employeeUid,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFEDEFF3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _viewToggleButton(
                    _EmpViewMode.list,
                    Icons.view_list_outlined,
                    'قائمة',
                  ),
                  _viewToggleButton(
                    _EmpViewMode.kanban,
                    Icons.view_kanban_outlined,
                    'لوحة',
                  ),
                ],
              ),
            ),
          ),
          // Time filter (يومي/أسبوعي/شهري) — hidden in "لوحة" (Kanban)
          // mode, same rule as the manager dashboard: Kanban always shows
          // every current task grouped by status only, regardless of date.
          if (_viewMode == _EmpViewMode.list) ...[
            Padding(
              padding: const EdgeInsets.all(16),
              child: SegmentedButton<_EmpRangeMode>(
                segments: const [
                  ButtonSegment(value: _EmpRangeMode.day, label: Text('يومي')),
                  ButtonSegment(
                    value: _EmpRangeMode.week,
                    label: Text('أسبوعي'),
                  ),
                  ButtonSegment(
                    value: _EmpRangeMode.month,
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
          ] else
            const SizedBox(height: 16),
          Expanded(
            child: _viewMode == _EmpViewMode.kanban
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TaskKanbanBoard(
                      // View-only: no `onStatusChanged` => `canDrag` has no
                      // effect either way, but explicitly false per
                      // requirement #6 ("بدون Drag & Drop").
                      tasks: provider.tasksForEmployee(widget.employeeUid),
                      canDrag: false,
                      onTapTask: (t) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TaskDetailScreen(task: t),
                        ),
                      ),
                    ),
                  )
                : Builder(
                    builder: (context) {
                      final weeklyStats = provider.weeklyStatsForEmployee(
                        widget.employeeUid,
                        DateTime.now(),
                      );
                      final statsSummary = MiniWeekStatsSummary(
                        completedThisWeek: weeklyStats['completed']!,
                        pendingThisWeek: weeklyStats['pending']!,
                      );

                      if (tasks.isEmpty) {
                        // Fully empty range — center the empty-state message and
                        // still show the weekly stat summary underneath so the
                        // screen isn't left with a bare "no tasks" line.
                        return SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: [
                              const SizedBox(height: 24),
                              const Text(
                                'لا توجد مهام في هذه الفترة',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              statsSummary,
                            ],
                          ),
                        );
                      }

                      final showStatsBelowList =
                          tasks.length <= _kFewTasksThreshold;
                      return ListView.builder(
                        padding: const EdgeInsets.all(16),
                        // +1 extra slot for the trailing stat summary when the
                        // list is short enough to otherwise leave the screen
                        // mostly empty.
                        itemCount: tasks.length + (showStatsBelowList ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == tasks.length) {
                            return statsSummary;
                          }
                          final t = tasks[index];
                          return Card(
                            child: ListTile(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TaskDetailScreen(task: t),
                                ),
                              ),
                              leading: TaskUrgencyDot(task: t),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      t.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  FavoriteStarButton(
                                    userUid: widget.employeeUid,
                                    taskId: t.taskId,
                                    size: 20,
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      StatusChip(statusName: t.status.name),
                                      PriorityBadge(
                                        priorityName: t.priority.name,
                                        compact: true,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${t.category} · ${intl.DateFormat('yyyy/MM/dd').format(t.dueDate)}',
                                  ),
                                  if (t.status == TaskStatus.editRequested &&
                                      t.reviewNote != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'ملاحظة المدير: ${t.reviewNote}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.statusPending,
                                        ),
                                      ),
                                    ),
                                  if (t.status == TaskStatus.rejected &&
                                      t.reviewNote != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'سبب الرفض: ${t.reviewNote}',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.statusRejected,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

/// One task the manager approved for handover TO this employee, awaiting
/// this employee's explicit confirmation before `assignedTo` actually
/// changes (per answer "٦- يحتاج لتأكيد استلامها"). The original employee
/// keeps the task, unaffected, until this confirmation happens.
class _ReassignConfirmationCard extends StatefulWidget {
  const _ReassignConfirmationCard({
    required this.task,
    required this.employeeUid,
  });
  final AppTask task;
  final String employeeUid;

  @override
  State<_ReassignConfirmationCard> createState() =>
      _ReassignConfirmationCardState();
}

class _ReassignConfirmationCardState extends State<_ReassignConfirmationCard> {
  bool _busy = false;

  Future<void> _confirm() async {
    setState(() => _busy = true);
    await context.read<TaskProvider>().confirmReassignmentByNewEmployee(
      taskId: widget.task.taskId,
      newEmployeeUid: widget.employeeUid,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تأكيد استلام المهمة، وهي الآن مهمتك')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final fromEmployee = FirestoreService.getUser(t.reassignRequestedBy ?? '');
    return Card(
      color: AppColors.statusApproved.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              'وافق المدير على إسناد هذه المهمة إليك من ${fromEmployee?.name ?? 'موظف آخر'}. المهمة ستنتقل بكل تفاصيلها الحالية بعد تأكيدك.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusApproved,
                ),
                onPressed: _busy ? null : _confirm,
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('تأكيد استلام المهمة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
