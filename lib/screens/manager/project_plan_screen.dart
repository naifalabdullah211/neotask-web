import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_selection_field.dart';
import '../../utils/project_planning.dart';
import '../../widgets/neo_app_bar_tabs.dart';
import '../designer/designer_task_view_screen.dart';
import 'task_review_detail_screen.dart';

class ProjectPlanScreen extends StatefulWidget {
  const ProjectPlanScreen({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  State<ProjectPlanScreen> createState() => _ProjectPlanScreenState();
}

class _ProjectPlanScreenState extends State<ProjectPlanScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  DateTime _workloadWeek = DateTime.now();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ProjectPlanning.planningScope(
      context.watch<TaskProvider>().teamTasks,
    );
    final critical = ProjectPlanning.criticalPath(tasks);
    final blocked = tasks
        .where((task) => ProjectPlanning.isBlocked(task, tasks))
        .length;
    final overdue = tasks.where((task) => task.isOverdue).length;
    final weightedProgress = tasks.isEmpty
        ? 0
        : (tasks.fold<double>(
                    0,
                    (sum, task) =>
                        sum + task.progressPercent * task.plannedHours,
                  ) /
                  tasks.fold<double>(0, (sum, task) => sum + task.plannedHours))
              .round();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('خطة العمل'),
        bottom: NeoAppBarTabs(
          controller: _tabController,
          maxWidth: 560,
          tabs: const [
            NeoAppBarTab(
              icon: Icons.view_timeline_outlined,
              label: 'الخط الزمني',
            ),
            NeoAppBarTab(icon: Icons.groups_outlined, label: 'عبء العمل'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Metric(
                  label: 'مهام الخطة',
                  value: '${tasks.length}',
                  icon: Icons.task_alt,
                ),
                _Metric(
                  label: 'التقدم الموزون',
                  value: '$weightedProgress%',
                  icon: Icons.trending_up,
                ),
                _Metric(
                  label: 'متوقفة بتبعية',
                  value: '$blocked',
                  icon: Icons.lock_clock,
                ),
                _Metric(
                  label: 'المسار الحرج',
                  value: '${critical.length}',
                  icon: Icons.route_outlined,
                ),
                _Metric(
                  label: 'متأخرة',
                  value: '$overdue',
                  icon: Icons.warning_amber,
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _TimelineView(
                  tasks: tasks,
                  criticalTaskIds: critical,
                  readOnly: widget.readOnly,
                ),
                _WorkloadView(
                  tasks: tasks,
                  week: _workloadWeek,
                  readOnly: widget.readOnly,
                  onPrevious: () => setState(
                    () => _workloadWeek = _workloadWeek.subtract(
                      const Duration(days: 7),
                    ),
                  ),
                  onNext: () => setState(
                    () => _workloadWeek = _workloadWeek.add(
                      const Duration(days: 7),
                    ),
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

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.deepBlue),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineView extends StatelessWidget {
  const _TimelineView({
    required this.tasks,
    required this.criticalTaskIds,
    required this.readOnly,
  });

  final List<AppTask> tasks;
  final Set<String> criticalTaskIds;
  final bool readOnly;

  List<AppTask> _orderedTasks() {
    final byParent = <String?, List<AppTask>>{};
    for (final task in tasks) {
      byParent.putIfAbsent(task.parentTaskId, () => []).add(task);
    }
    for (final group in byParent.values) {
      group.sort((a, b) => a.startDate.compareTo(b.startDate));
    }
    final result = <AppTask>[];
    final visited = <String>{};
    void addBranch(AppTask task) {
      if (!visited.add(task.taskId)) return;
      result.add(task);
      for (final child in byParent[task.taskId] ?? const <AppTask>[]) {
        addBranch(child);
      }
    }

    for (final root in byParent[null] ?? const <AppTask>[]) {
      addBranch(root);
    }
    for (final task in tasks) {
      addBranch(task);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(child: Text('لا توجد مهام لعرضها في الخطة'));
    }
    final ordered = _orderedTasks();
    var minDate = tasks.first.startDate;
    var maxDate = tasks.first.dueDate;
    for (final task in tasks) {
      if (task.startDate.isBefore(minDate)) minDate = task.startDate;
      if (task.dueDate.isAfter(maxDate)) maxDate = task.dueDate;
    }
    minDate = DateTime(minDate.year, minDate.month, minDate.day);
    maxDate = DateTime(
      maxDate.year,
      maxDate.month,
      maxDate.day,
    ).add(const Duration(days: 1));
    final totalDays = math.max(1, maxDate.difference(minDate).inDays).toInt();
    final timelineWidth = math
        .min(10000.0, math.max(720.0, totalDays / 7 * 74))
        .toDouble();
    const labelWidth = 300.0;
    const rowHeight = 68.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: labelWidth + timelineWidth,
          child: Column(
            children: [
              _TimelineHeader(
                minDate: minDate,
                totalDays: totalDays,
                timelineWidth: timelineWidth,
                labelWidth: labelWidth,
              ),
              ...ordered.map(
                (task) => _TimelineRow(
                  task: task,
                  allTasks: tasks,
                  minDate: minDate,
                  totalDays: totalDays,
                  timelineWidth: timelineWidth,
                  labelWidth: labelWidth,
                  rowHeight: rowHeight,
                  critical: criticalTaskIds.contains(task.taskId),
                  readOnly: readOnly,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimelineHeader extends StatelessWidget {
  const _TimelineHeader({
    required this.minDate,
    required this.totalDays,
    required this.timelineWidth,
    required this.labelWidth,
  });

  final DateTime minDate;
  final int totalDays;
  final double timelineWidth;
  final double labelWidth;

  @override
  Widget build(BuildContext context) {
    final weeks = math.max(1, (totalDays / 7).ceil()).toInt();
    return Container(
      height: 48,
      decoration: const BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'المهمة والمسؤول',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: timelineWidth,
            child: Row(
              children: List.generate(weeks, (index) {
                final date = minDate.add(Duration(days: index * 7));
                return Expanded(
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: BorderDirectional(
                        start: BorderSide(
                          color: Colors.white.withValues(alpha: 0.13),
                        ),
                      ),
                    ),
                    child: Text(
                      intl.DateFormat('MM/dd').format(date),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.task,
    required this.allTasks,
    required this.minDate,
    required this.totalDays,
    required this.timelineWidth,
    required this.labelWidth,
    required this.rowHeight,
    required this.critical,
    required this.readOnly,
  });

  final AppTask task;
  final List<AppTask> allTasks;
  final DateTime minDate;
  final int totalDays;
  final double timelineWidth;
  final double labelWidth;
  final double rowHeight;
  final bool critical;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final assignee = FirestoreService.getUser(task.assignedTo);
    final isChild = task.parentTaskId != null;
    final blocked = ProjectPlanning.isBlocked(task, allTasks);
    final startOffset = task.startDate.difference(minDate).inHours / 24;
    final duration = math
        .max(1.0, task.dueDate.difference(task.startDate).inHours / 24 + 1)
        .toDouble();
    final left = (startOffset / totalDays * timelineWidth)
        .clamp(0.0, timelineWidth)
        .toDouble();
    final width = math
        .max(34.0, duration / totalDays * timelineWidth)
        .toDouble();

    void openDetails() {
      final isDesigner = context.read<AuthProvider>().isDesigner;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => isDesigner
              ? DesignerTaskViewScreen(task: task)
              : TaskReviewDetailScreen(task: task),
        ),
      );
    }

    return Container(
      height: rowHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: labelWidth,
            child: InkWell(
              onTap: openDetails,
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  start: isChild ? 28 : 12,
                  end: 8,
                ),
                child: Row(
                  children: [
                    if (isChild)
                      const Padding(
                        padding: EdgeInsetsDirectional.only(end: 7),
                        child: Icon(Icons.subdirectory_arrow_left, size: 18),
                      ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            assignee?.name ?? 'غير مسند',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (blocked)
                      const Tooltip(
                        message: 'بانتظار مهام سابقة',
                        child: Icon(
                          Icons.lock_clock,
                          size: 18,
                          color: AppColors.statusPending,
                        ),
                      ),
                    if (!readOnly)
                      IconButton(
                        tooltip: 'تعديل الخطة',
                        icon: const Icon(Icons.tune, size: 19),
                        onPressed: () =>
                            _showPlanningEditor(context, task, allTasks),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            width: timelineWidth,
            height: rowHeight,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Positioned(
                  left: left,
                  width: math.min(width, timelineWidth - left).toDouble(),
                  height: 30,
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: critical
                          ? AppColors.gold.withValues(alpha: 0.22)
                          : AppColors.deepBlue.withValues(alpha: 0.13),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: critical ? AppColors.gold : AppColors.deepBlue,
                        width: critical ? 2 : 1,
                      ),
                    ),
                    child: Stack(
                      children: [
                        FractionallySizedBox(
                          widthFactor: (task.progressPercent / 100)
                              .clamp(0, 1)
                              .toDouble(),
                          child: Container(
                            color: critical
                                ? AppColors.gold.withValues(alpha: 0.65)
                                : AppColors.deepBlue.withValues(alpha: 0.62),
                          ),
                        ),
                        Center(
                          child: Text(
                            '${task.progressPercent}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _WorkloadView extends StatelessWidget {
  const _WorkloadView({
    required this.tasks,
    required this.week,
    required this.readOnly,
    required this.onPrevious,
    required this.onNext,
  });

  final List<AppTask> tasks;
  final DateTime week;
  final bool readOnly;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AppUser>>(
      stream: FirestoreService.watchEmployees(),
      initialData: FirestoreService.getAllEmployees(),
      builder: (context, snapshot) =>
          _buildContent(context, snapshot.data ?? const <AppUser>[]),
    );
  }

  Widget _buildContent(BuildContext context, List<AppUser> employeeSnapshot) {
    final start = ProjectPlanning.weekStart(week);
    final end = start.add(const Duration(days: 6));
    final employees = employeeSnapshot
        .where((user) => user.accountStatus == AccountStatus.active)
        .toList();
    final capacityByEmployee = {
      for (final employee in employees)
        employee.uid: employee.weeklyCapacityHours,
    };
    final calculated = {
      for (final entry in ProjectPlanning.workloadForWeek(
        tasks,
        week,
        capacityByEmployee: capacityByEmployee,
      ))
        entry.employeeUid: entry,
    };
    final entries =
        employees
            .map(
              (employee) => (
                user: employee,
                workload:
                    calculated[employee.uid] ??
                    WorkloadEntry(
                      employeeUid: employee.uid,
                      plannedHours: 0,
                      capacityHours: employee.weeklyCapacityHours,
                    ),
              ),
            )
            .toList()
          ..sort(
            (a, b) => b.workload.utilization.compareTo(a.workload.utilization),
          );

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  onPressed: onPrevious,
                  icon: const Icon(Icons.chevron_right),
                ),
                Expanded(
                  child: Column(
                    children: [
                      const Text(
                        'أسبوع العمل',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${intl.DateFormat('yyyy/MM/dd').format(start)} — ${intl.DateFormat('yyyy/MM/dd').format(end)}',
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onNext,
                  icon: const Icon(Icons.chevron_left),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          readOnly
              ? 'الساعات توزّع على أيام مدة كل مهمة، والسعة محددة لكل موظف.'
              : 'الساعات توزّع على أيام مدة كل مهمة. عدّل سعة الموظف حسب دوامه الفعلي.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (entries.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Text('لا يوجد موظفون نشطون'),
            ),
          )
        else
          ...entries.map(
            (entry) => _WorkloadCard(
              user: entry.user,
              entry: entry.workload,
              readOnly: readOnly,
            ),
          ),
      ],
    );
  }
}

class _WorkloadCard extends StatelessWidget {
  const _WorkloadCard({
    required this.user,
    required this.entry,
    required this.readOnly,
  });

  final AppUser user;
  final WorkloadEntry entry;
  final bool readOnly;

  Future<void> _editCapacity(BuildContext context) async {
    final controller = TextEditingController(
      text: user.weeklyCapacityHours.toStringAsFixed(
        user.weeklyCapacityHours % 1 == 0 ? 0 : 1,
      ),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('السعة الأسبوعية — ${user.name}'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'ساعات العمل المتاحة أسبوعيًا',
            suffixText: 'ساعة',
            helperText: 'مثال: 20 للدوام الجزئي، 40 للدوام الكامل',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed == null || parsed <= 0 || parsed > 168) return;
              Navigator.pop(dialogContext, parsed);
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !context.mounted) return;
    try {
      await FirestoreService.updateEmployeeWeeklyCapacity(user.uid, value);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث السعة الأسبوعية')),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تحديث السعة الأسبوعية')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final utilization = entry.utilization;
    final color = utilization > 1
        ? AppColors.statusRejected
        : utilization >= .8
        ? AppColors.statusPending
        : AppColors.statusApproved;
    final label = utilization > 1
        ? 'حمل زائد'
        : utilization >= .8
        ? 'قريب من السعة'
        : 'متوازن';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.deepBlue.withValues(alpha: 0.08),
                  child: Text(user.name.isEmpty ? '؟' : user.name[0]),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        user.employeeNumber,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${entry.plannedHours.toStringAsFixed(1)} / ${entry.capacityHours.toStringAsFixed(entry.capacityHours % 1 == 0 ? 0 : 1)} س',
                  style: TextStyle(color: color, fontWeight: FontWeight.w800),
                ),
                if (!readOnly)
                  IconButton(
                    tooltip: 'تعديل السعة الأسبوعية',
                    onPressed: () => _editCapacity(context),
                    icon: const Icon(Icons.edit_calendar_outlined, size: 19),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: utilization.clamp(0, 1).toDouble(),
                minHeight: 9,
                color: color,
                backgroundColor: AppColors.divider,
              ),
            ),
            const SizedBox(height: 7),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _showPlanningEditor(
  BuildContext context,
  AppTask task,
  List<AppTask> tasks,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _PlanningEditor(task: task, tasks: tasks),
  );
}

class _PlanningEditor extends StatefulWidget {
  const _PlanningEditor({required this.task, required this.tasks});

  final AppTask task;
  final List<AppTask> tasks;

  @override
  State<_PlanningEditor> createState() => _PlanningEditorState();
}

class _PlanningEditorState extends State<_PlanningEditor> {
  late DateTime _startDate;
  late DateTime _dueDate;
  late final TextEditingController _hoursController;
  late String? _parentTaskId;
  late Set<String> _predecessors;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _startDate = widget.task.startDate;
    _dueDate = widget.task.dueDate;
    _hoursController = TextEditingController(
      text: widget.task.plannedHours.toString(),
    );
    _parentTaskId = widget.task.parentTaskId;
    _predecessors = widget.task.predecessorTaskIds.toSet();
  }

  @override
  void dispose() {
    _hoursController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool start) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? _startDate : _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startDate = picked;
        if (_dueDate.isBefore(picked)) _dueDate = picked;
      } else {
        _dueDate = picked;
      }
    });
  }

  Future<void> _save() async {
    final hours = double.tryParse(_hoursController.text.trim());
    if (hours == null || hours <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('أدخل ساعات مخططة صحيحة')));
      return;
    }
    setState(() => _saving = true);
    try {
      await context.read<TaskProvider>().updatePlanning(
        taskId: widget.task.taskId,
        managerUid: context.read<AuthProvider>().currentUser!.uid,
        startDate: _startDate,
        dueDate: _dueDate,
        plannedHours: hours,
        parentTaskId: _parentTaskId,
        predecessorTaskIds: _predecessors.toList(),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('Invalid argument(s): ', ''),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = widget.tasks
        .where((item) => item.taskId != widget.task.taskId)
        .toList();
    final safeBottom = MediaQuery.viewInsetsOf(context).bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + safeBottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.task.title,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('البداية'),
                      subtitle: Text(
                        intl.DateFormat('yyyy/MM/dd').format(_startDate),
                      ),
                      onTap: () => _pickDate(true),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('النهاية'),
                      subtitle: Text(
                        intl.DateFormat('yyyy/MM/dd').format(_dueDate),
                      ),
                      onTap: () => _pickDate(false),
                    ),
                  ),
                ],
              ),
              TextField(
                controller: _hoursController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'الساعات المخططة',
                  suffixText: 'ساعة',
                ),
              ),
              const SizedBox(height: 12),
              NeoSelectionField<String?>(
                label: 'المهمة الرئيسية',
                value: _parentTaskId,
                searchable: candidates.length > 7,
                options: [
                  const NeoSelectionOption<String?>(
                    value: null,
                    label: 'بدون مهمة رئيسية',
                    icon: Icons.remove_circle_outline_rounded,
                  ),
                  ...candidates
                      .where(
                        (item) => !ProjectPlanning.wouldCreateHierarchyCycle(
                          taskId: widget.task.taskId,
                          candidateParentId: item.taskId,
                          allTasks: widget.tasks,
                        ),
                      )
                      .map(
                        (item) => NeoSelectionOption<String?>(
                          value: item.taskId,
                          label: item.title,
                          icon: Icons.account_tree_outlined,
                        ),
                      ),
                ],
                onChanged: (value) => setState(() => _parentTaskId = value),
              ),
              const SizedBox(height: 14),
              const Text(
                'المهام السابقة',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView(
                  shrinkWrap: true,
                  children: candidates.map((item) {
                    final cyclic = ProjectPlanning.wouldCreateCycle(
                      taskId: widget.task.taskId,
                      candidatePredecessorId: item.taskId,
                      allTasks: widget.tasks,
                    );
                    return CheckboxListTile(
                      dense: true,
                      value: _predecessors.contains(item.taskId),
                      title: Text(item.title),
                      subtitle: cyclic
                          ? const Text('لا يمكن اختيارها: ستنشئ مسارًا دائريًا')
                          : null,
                      onChanged: cyclic
                          ? null
                          : (selected) => setState(() {
                              if (selected ?? false) {
                                _predecessors.add(item.taskId);
                              } else {
                                _predecessors.remove(item.taskId);
                              }
                            }),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: const Icon(Icons.save_outlined),
                label: Text(_saving ? 'جارٍ الحفظ...' : 'حفظ الخطة'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
