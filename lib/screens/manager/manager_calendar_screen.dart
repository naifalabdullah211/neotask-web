import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/task_urgency_indicator.dart';
import 'manager_create_task_screen.dart';
import 'task_review_detail_screen.dart';
import '../designer/designer_task_view_screen.dart';

enum _MgrRangeMode { day, week, month }

/// Manager-facing task calendar ("التقويم") — shows every employee's tasks
/// for a day/week/month window (unlike the employee's ICS import screen,
/// which is a personal read-only iPhone-calendar sync). Reuses
/// TaskProvider.tasksForDay/Week/Month with employeeUid == null to include
/// ALL employees' tasks, and displays each task's assignee name.
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

  List<AppTask> _tasksForRange(TaskProvider provider) {
    switch (_mode) {
      case _MgrRangeMode.day:
        return provider.tasksForDay(_anchor);
      case _MgrRangeMode.week:
        return provider.tasksForWeek(_anchor);
      case _MgrRangeMode.month:
        return provider.tasksForMonth(_anchor);
    }
  }

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
        final weekday = _anchor.weekday;
        final start = _anchor.subtract(Duration(days: weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${df.format(start)} - ${df.format(end)}';
      case _MgrRangeMode.month:
        return '${_anchor.year}/${_anchor.month.toString().padLeft(2, '0')}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final tasks = _tasksForRange(provider)
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

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
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () => _shift(1),
                  ),
                  Text(
                    _rangeLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () => _shift(-1),
                  ),
                ],
              ),
            ),
            Expanded(
              child: tasks.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد مهام في هذه الفترة',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final t = tasks[index];
                        final employee = FirestoreService.getUser(t.assignedTo);
                        return Card(
                          child: ListTile(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => widget.readOnly
                                    ? DesignerTaskViewScreen(task: t)
                                    : TaskReviewDetailScreen(task: t),
                              ),
                            ),
                            leading: TaskUrgencyDot(task: t),
                            title: Text(
                              t.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${employee?.name ?? "-"} · ${t.category} · '
                              '${intl.DateFormat('yyyy/MM/dd').format(t.dueDate)}',
                            ),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                StatusChip(statusName: t.status.name),
                                const SizedBox(height: 4),
                                PriorityBadge(
                                  priorityName: t.priority.name,
                                  compact: true,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
