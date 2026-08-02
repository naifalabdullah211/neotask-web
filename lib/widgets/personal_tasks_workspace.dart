import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:intl/intl.dart' as intl;

import '../models/task_model.dart';
import '../theme/app_theme.dart';
import 'neo_selection_field.dart';
import 'neo_workspace_chrome.dart';
import 'status_chip.dart';

enum _PersonalTaskFilter { all, today, upcoming, completed }

class PersonalTasksMetricsBar extends StatelessWidget {
  const PersonalTasksMetricsBar({super.key, required this.tasks});

  final List<AppTask> tasks;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    bool sameDay(DateTime date) =>
        date.year == now.year && date.month == now.month && date.day == now.day;
    final completed = tasks
        .where((task) => task.primaryStatus == PrimaryTaskStatus.completed)
        .length;
    final active = tasks.length - completed;
    final today = tasks
        .where(
          (task) =>
              sameDay(task.dueDate) &&
              task.primaryStatus != PrimaryTaskStatus.completed,
        )
        .length;
    final overdue = tasks.where((task) => task.isOverdue).length;

    return NeoWorkspaceMetricsBar(
      items: [
        NeoWorkspaceMetric(
          label: 'مهام نشطة',
          value: '$active',
          icon: Icons.checklist_rtl_rounded,
          color: const Color(0xFF1F6FD2),
        ),
        NeoWorkspaceMetric(
          label: 'مستحقة اليوم',
          value: '$today',
          icon: Icons.today_outlined,
          color: AppColors.mintAccent,
        ),
        NeoWorkspaceMetric(
          label: 'مكتملة',
          value: '$completed',
          icon: Icons.task_alt_rounded,
          color: AppColors.gold,
        ),
        NeoWorkspaceMetric(
          label: 'متأخرة',
          value: '$overdue',
          icon: Icons.schedule_rounded,
          color: AppColors.overdue,
        ),
      ],
    );
  }
}

class PersonalTasksWorkspace extends StatefulWidget {
  const PersonalTasksWorkspace({
    super.key,
    required this.tasks,
    required this.readOnly,
    required this.onToggleDone,
    required this.onOpen,
    required this.onDelete,
  });

  final List<AppTask> tasks;
  final bool readOnly;
  final Future<void> Function(AppTask task, bool completed) onToggleDone;
  final ValueChanged<AppTask> onOpen;
  final ValueChanged<AppTask> onDelete;

  @override
  State<PersonalTasksWorkspace> createState() =>
      _PersonalTasksWorkspaceState();
}

class _PersonalTasksWorkspaceState extends State<PersonalTasksWorkspace> {
  String? _selectedTaskId;
  _PersonalTaskFilter _filter = _PersonalTaskFilter.all;

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  List<AppTask> get _visibleTasks {
    final now = DateTime.now();
    final tasks = switch (_filter) {
      _PersonalTaskFilter.all => widget.tasks,
      _PersonalTaskFilter.today => widget.tasks
          .where((task) => _sameDay(task.dueDate, now))
          .toList(),
      _PersonalTaskFilter.upcoming => widget.tasks
          .where(
            (task) =>
                task.primaryStatus != PrimaryTaskStatus.completed &&
                task.dueDate.isAfter(DateTime(now.year, now.month, now.day)),
          )
          .toList(),
      _PersonalTaskFilter.completed => widget.tasks
          .where((task) => task.primaryStatus == PrimaryTaskStatus.completed)
          .toList(),
    };
    return List<AppTask>.of(tasks)
      ..sort((a, b) {
        final aDone = a.primaryStatus == PrimaryTaskStatus.completed;
        final bDone = b.primaryStatus == PrimaryTaskStatus.completed;
        if (aDone != bDone) return aDone ? 1 : -1;
        return a.dueDate.compareTo(b.dueDate);
      });
  }

  AppTask? get _selectedTask {
    final tasks = _visibleTasks;
    if (tasks.isEmpty) return null;
    for (final task in tasks) {
      if (task.taskId == _selectedTaskId) return task;
    }
    return tasks.first;
  }

  void _selectTask(AppTask task, {required bool showSheet}) {
    setState(() => _selectedTaskId = task.taskId);
    if (!showSheet) return;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .82,
        child: _PersonalTaskDetailsPanel(
          task: task,
          readOnly: widget.readOnly,
          onToggleDone: (completed) => widget.onToggleDone(task, completed),
          onOpen: () {
            Navigator.pop(sheetContext);
            widget.onOpen(task);
          },
          onDelete: () {
            Navigator.pop(sheetContext);
            widget.onDelete(task);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tasks.isEmpty) {
      return const NeoWorkspaceEmptyState(
        icon: Icons.checklist_rtl_rounded,
        title: 'مساحة التركيز جاهزة',
        message: 'أضف مهمة أو تذكيرًا شخصيًا؛ ولن تظهر ضمن تقارير الفريق.',
      );
    }

    final visible = _visibleTasks;
    final selected = _selectedTask;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return _MobilePersonalTasksView(
            tasks: visible,
            filter: _filter,
            readOnly: widget.readOnly,
            onFilterChanged: (value) => setState(() => _filter = value),
            onSelect: (task) => _selectTask(task, showSheet: true),
            onToggleDone: widget.onToggleDone,
          );
        }

        final showDetails = constraints.maxWidth >= 1180;
        return Column(
          children: [
            _PersonalTasksToolbar(
              filter: _filter,
              visibleCount: visible.length,
              onFilterChanged: (value) => setState(() => _filter = value),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: visible.isEmpty || selected == null
                    ? const NeoWorkspaceEmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'لا توجد مهام ضمن هذا العرض',
                        message: 'غيّر عامل التصفية لعرض بقية مهامك الشخصية.',
                      )
                    : Row(
                        textDirection: Directionality.of(context),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          NeoWorkspacePanel(
                            width: showDetails ? 390 : 350,
                            borderEnd: true,
                            child: _PersonalTaskListPanel(
                              tasks: visible,
                              selectedTaskId: selected.taskId,
                              readOnly: widget.readOnly,
                              onSelect: (task) => _selectTask(
                                task,
                                showSheet: !showDetails,
                              ),
                              onToggleDone: widget.onToggleDone,
                            ),
                          ),
                          Expanded(
                            child: _FocusCanvas(
                              task: selected,
                              readOnly: widget.readOnly,
                              onToggleDone: (completed) =>
                                  widget.onToggleDone(selected, completed),
                              onOpen: () => widget.onOpen(selected),
                            ),
                          ),
                          if (showDetails)
                            NeoWorkspacePanel(
                              width: 320,
                              borderStart: true,
                              child: _PersonalTaskDetailsPanel(
                                task: selected,
                                readOnly: widget.readOnly,
                                onToggleDone: (completed) =>
                                    widget.onToggleDone(selected, completed),
                                onOpen: () => widget.onOpen(selected),
                                onDelete: () => widget.onDelete(selected),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PersonalTasksToolbar extends StatelessWidget {
  const _PersonalTasksToolbar({
    required this.filter,
    required this.visibleCount,
    required this.onFilterChanged,
  });

  final _PersonalTaskFilter filter;
  final int visibleCount;
  final ValueChanged<_PersonalTaskFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox(
            width: 230,
            child: NeoSelectionField<_PersonalTaskFilter>(
              label: 'عرض المهام',
              value: filter,
              options: const [
                NeoSelectionOption(
                  value: _PersonalTaskFilter.all,
                  label: 'الكل',
                  icon: Icons.checklist_rtl,
                ),
                NeoSelectionOption(
                  value: _PersonalTaskFilter.today,
                  label: 'اليوم',
                  icon: Icons.today_outlined,
                ),
                NeoSelectionOption(
                  value: _PersonalTaskFilter.upcoming,
                  label: 'القادمة',
                  icon: Icons.upcoming_outlined,
                ),
                NeoSelectionOption(
                  value: _PersonalTaskFilter.completed,
                  label: 'المكتملة',
                  icon: Icons.task_alt_outlined,
                ),
              ],
              onChanged: onFilterChanged,
            ),
          ),
          const Spacer(),
          Text(
            '$visibleCount مهمة في العرض',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PersonalTaskListPanel extends StatelessWidget {
  const _PersonalTaskListPanel({
    required this.tasks,
    required this.selectedTaskId,
    required this.readOnly,
    required this.onSelect,
    required this.onToggleDone,
  });

  final List<AppTask> tasks;
  final String selectedTaskId;
  final bool readOnly;
  final ValueChanged<AppTask> onSelect;
  final Future<void> Function(AppTask task, bool completed) onToggleDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NeoWorkspaceSectionHeader(
          title: 'قائمة التركيز',
          subtitle: 'مهامك الخاصة مرتبة حسب الاستحقاق',
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: tasks.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _PersonalTaskCard(
              task: tasks[index],
              selected: tasks[index].taskId == selectedTaskId,
              readOnly: readOnly,
              onTap: () => onSelect(tasks[index]),
              onToggleDone: (completed) =>
                  onToggleDone(tasks[index], completed),
            ),
          ),
        ),
      ],
    );
  }
}

class _PersonalTaskCard extends StatelessWidget {
  const _PersonalTaskCard({
    required this.task,
    required this.selected,
    required this.readOnly,
    required this.onTap,
    required this.onToggleDone,
  });

  final AppTask task;
  final bool selected;
  final bool readOnly;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggleDone;

  @override
  Widget build(BuildContext context) {
    final done = task.primaryStatus == PrimaryTaskStatus.completed;
    return Material(
      color: selected ? AppColors.deepBlue.withValues(alpha: .055) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: selected
              ? AppColors.deepBlue.withValues(alpha: .42)
              : task.isOverdue
              ? AppColors.overdue.withValues(alpha: .4)
              : AppColors.divider,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Checkbox(
                value: done,
                activeColor: AppColors.mintAccent,
                onChanged: readOnly
                    ? null
                    : (value) => onToggleDone(value ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: done
                            ? AppColors.textSecondary
                            : AppColors.deepBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                        decoration: done ? TextDecoration.lineThrough : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        PriorityBadge(
                          priorityName: task.priority.name,
                          compact: true,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          intl.DateFormat('yyyy/MM/dd').format(task.dueDate),
                          style: TextStyle(
                            color: task.isOverdue
                                ? AppColors.overdue
                                : AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: task.isOverdue
                                ? FontWeight.w900
                                : FontWeight.w600,
                          ),
                        ),
                        if (task.recurrenceType != RecurrenceType.none) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.repeat_rounded,
                            color: AppColors.textSecondary,
                            size: 14,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_left, color: AppColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _FocusCanvas extends StatelessWidget {
  const _FocusCanvas({
    required this.task,
    required this.readOnly,
    required this.onToggleDone,
    required this.onOpen,
  });

  final AppTask task;
  final bool readOnly;
  final ValueChanged<bool> onToggleDone;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final done = task.primaryStatus == PrimaryTaskStatus.completed;
    return ColoredBox(
      color: const Color(0xFFF8FAFD),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.divider),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.deepBlue.withValues(alpha: .05),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 74,
                    height: 74,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: (done ? AppColors.mintAccent : AppColors.gold)
                          .withValues(alpha: .12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      done ? Icons.task_alt_rounded : Icons.bolt_rounded,
                      color: done ? AppColors.mintAccent : AppColors.gold,
                      size: 36,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    task.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (task.description.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      task.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 13,
                        height: 1.55,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!readOnly)
                        FilledButton.icon(
                          onPressed: () => onToggleDone(!done),
                          style: FilledButton.styleFrom(
                            backgroundColor: done
                                ? AppColors.deepBlue
                                : AppColors.mintAccent,
                            foregroundColor: done
                                ? Colors.white
                                : AppColors.navy,
                          ),
                          icon: Icon(
                            done ? Icons.refresh_rounded : Icons.check_rounded,
                          ),
                          label: Text(done ? 'إعادة فتح المهمة' : 'إكمال المهمة'),
                        ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: onOpen,
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('فتح التفاصيل'),
                      ),
                    ],
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

class _PersonalTaskDetailsPanel extends StatelessWidget {
  const _PersonalTaskDetailsPanel({
    required this.task,
    required this.readOnly,
    required this.onToggleDone,
    required this.onOpen,
    required this.onDelete,
  });

  final AppTask task;
  final bool readOnly;
  final ValueChanged<bool> onToggleDone;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final done = task.primaryStatus == PrimaryTaskStatus.completed;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'تفاصيل المهمة',
          style: TextStyle(
            color: AppColors.deepBlue,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        _TaskDetailLine(
          icon: Icons.calendar_today_outlined,
          label: 'موعد الاستحقاق',
          value: intl.DateFormat('yyyy/MM/dd').format(task.dueDate),
          valueColor: task.isOverdue ? AppColors.overdue : null,
        ),
        _TaskDetailLine(
          icon: Icons.label_outline_rounded,
          label: 'التصنيف',
          value: task.category.isEmpty ? 'غير مصنف' : task.category,
        ),
        _TaskDetailLine(
          icon: Icons.flag_outlined,
          label: 'الأولوية',
          value: _priorityLabel(task.priority),
        ),
        _TaskDetailLine(
          icon: Icons.repeat_rounded,
          label: 'التكرار',
          value: _recurrenceLabel(task.recurrenceType),
        ),
        _TaskDetailLine(
          icon: Icons.history_rounded,
          label: 'التحديثات',
          value: '${task.activityLog.length}',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('فتح التفاصيل والتعديل'),
        ),
        if (!readOnly) ...[
          const SizedBox(height: 9),
          OutlinedButton.icon(
            onPressed: () => onToggleDone(!done),
            icon: Icon(done ? Icons.refresh_rounded : Icons.check_rounded),
            label: Text(done ? 'إعادة فتح المهمة' : 'إكمال المهمة'),
          ),
          const SizedBox(height: 9),
          TextButton.icon(
            onPressed: onDelete,
            style: TextButton.styleFrom(foregroundColor: AppColors.overdue),
            icon: const Icon(Icons.delete_outline_rounded),
            label: const Text('حذف المهمة'),
          ),
        ],
      ],
    );
  }
}

class _TaskDetailLine extends StatelessWidget {
  const _TaskDetailLine({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? AppColors.deepBlue,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
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

class _MobilePersonalTasksView extends StatelessWidget {
  const _MobilePersonalTasksView({
    required this.tasks,
    required this.filter,
    required this.readOnly,
    required this.onFilterChanged,
    required this.onSelect,
    required this.onToggleDone,
  });

  final List<AppTask> tasks;
  final _PersonalTaskFilter filter;
  final bool readOnly;
  final ValueChanged<_PersonalTaskFilter> onFilterChanged;
  final ValueChanged<AppTask> onSelect;
  final Future<void> Function(AppTask task, bool completed) onToggleDone;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PersonalTasksToolbar(
          filter: filter,
          visibleCount: tasks.length,
          onFilterChanged: onFilterChanged,
        ),
        Expanded(
          child: tasks.isEmpty
              ? const NeoWorkspaceEmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'لا توجد مهام ضمن هذا العرض',
                  message: 'غيّر عامل التصفية لعرض بقية مهامك الشخصية.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                  itemCount: tasks.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (context, index) => _PersonalTaskCard(
                    task: tasks[index],
                    selected: false,
                    readOnly: readOnly,
                    onTap: () => onSelect(tasks[index]),
                    onToggleDone: (completed) =>
                        onToggleDone(tasks[index], completed),
                  ),
                ),
        ),
      ],
    );
  }
}

String _priorityLabel(TaskPriority priority) => switch (priority) {
  TaskPriority.low => 'منخفضة',
  TaskPriority.medium => 'متوسطة',
  TaskPriority.high => 'عالية',
};

String _recurrenceLabel(RecurrenceType recurrence) => switch (recurrence) {
  RecurrenceType.none => 'بدون تكرار',
  RecurrenceType.daily => 'يومي',
  RecurrenceType.weekly => 'أسبوعي',
  RecurrenceType.monthlyFixedDate => 'شهري بتاريخ ثابت',
  RecurrenceType.monthlyWeekdayPattern => 'شهري بنمط أسبوعي',
};
