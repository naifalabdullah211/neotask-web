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
import '../../widgets/project_plan_timeline_workspace.dart';
import '../designer/designer_task_view_screen.dart';
import 'quick_add_task_sheet.dart';
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

    void openTask(AppTask task) {
      final isDesigner = context.read<AuthProvider>().isDesigner;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => isDesigner
              ? DesignerTaskViewScreen(task: task)
              : TaskReviewDetailScreen(task: task),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'خطة العمل',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (!widget.readOnly)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: MediaQuery.sizeOf(context).width < 620
                  ? IconButton.filled(
                      tooltip: 'مهمة جديدة',
                      onPressed: () => QuickAddTaskSheet.show(context),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.mintAccent,
                        foregroundColor: AppColors.navy,
                      ),
                      icon: const Icon(Icons.add_rounded),
                    )
                  : FilledButton.icon(
                      onPressed: () => QuickAddTaskSheet.show(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.mintAccent,
                        foregroundColor: AppColors.navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'مهمة جديدة',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
            ),
          ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(54),
          child: ColoredBox(
            color: Colors.white,
            child: Align(
              alignment: AlignmentDirectional.center,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: AppColors.mintAccent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicatorWeight: 3,
                  labelColor: AppColors.deepBlue,
                  unselectedLabelColor: AppColors.textSecondary,
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                  tabs: const [
                    Tab(text: 'الخط الزمني'),
                    Tab(text: 'عبء العمل'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          ProjectPlanMetricsBar(
            taskCount: tasks.length,
            weightedProgress: weightedProgress,
            blockedCount: blocked,
            criticalCount: critical.length,
            overdueCount: overdue,
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                ProjectPlanTimelineWorkspace(
                  tasks: tasks,
                  criticalTaskIds: critical,
                  readOnly: widget.readOnly,
                  onEditTask: (task) =>
                      _showPlanningEditor(context, task, tasks),
                  onOpenTask: openTask,
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
