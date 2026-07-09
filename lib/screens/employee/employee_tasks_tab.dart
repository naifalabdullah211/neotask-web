import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';
import 'task_detail_screen.dart';

enum _EmpRangeMode { day, week, month }

class EmployeeTasksTab extends StatefulWidget {
  final String employeeUid;
  const EmployeeTasksTab({super.key, required this.employeeUid});

  @override
  State<EmployeeTasksTab> createState() => _EmployeeTasksTabState();
}

class _EmployeeTasksTabState extends State<EmployeeTasksTab> {
  _EmpRangeMode _mode = _EmpRangeMode.day;
  DateTime _anchor = DateTime.now();

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final tasks = _tasksForRange(provider);

    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: SegmentedButton<_EmpRangeMode>(
              segments: const [
                ButtonSegment(value: _EmpRangeMode.day, label: Text('يومي')),
                ButtonSegment(value: _EmpRangeMode.week, label: Text('أسبوعي')),
                ButtonSegment(value: _EmpRangeMode.month, label: Text('شهري')),
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
                      return Card(
                        child: ListTile(
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => TaskDetailScreen(task: t),
                            ),
                          ),
                          title: Text(
                            t.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
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
                          trailing: StatusChip(statusName: t.status.name),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
