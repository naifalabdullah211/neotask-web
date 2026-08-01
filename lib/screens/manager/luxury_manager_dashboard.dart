import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../../models/manager_digest_model.dart';
import '../../models/meeting_model.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/digest_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/poll_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/task_stats.dart';
import '../../widgets/daily_digest_card.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/task_kanban_board.dart';
import '../designer/designer_task_view_screen.dart';
import 'quick_add_task_sheet.dart';
import 'task_review_detail_screen.dart';

enum _LuxuryRange { day, week, month }

class LuxuryManagerDashboard extends StatefulWidget {
  const LuxuryManagerDashboard({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  State<LuxuryManagerDashboard> createState() => _LuxuryManagerDashboardState();
}

class _LuxuryManagerDashboardState extends State<LuxuryManagerDashboard> {
  _LuxuryRange _range = _LuxuryRange.week;
  DateTime _anchor = DateTime.now();
  bool _kanban = false;
  bool _digestScheduled = false;

  List<AppTask> _rangeTasks(TaskProvider provider) {
    final tasks = switch (_range) {
      _LuxuryRange.day => provider.tasksForDay(_anchor),
      _LuxuryRange.week => provider.tasksForWeek(_anchor),
      _LuxuryRange.month => provider.tasksForMonth(_anchor),
    };
    return tasks.where((task) => !task.isPersonal).toList();
  }

  void _shiftRange(int direction) {
    setState(() {
      _anchor = switch (_range) {
        _LuxuryRange.day => _anchor.add(Duration(days: direction)),
        _LuxuryRange.week => _anchor.add(Duration(days: 7 * direction)),
        _LuxuryRange.month => DateTime(
          _anchor.year,
          _anchor.month + direction,
          1,
        ),
      };
    });
  }

  String get _rangeLabel {
    final formatter = intl.DateFormat('yyyy/MM/dd');
    return switch (_range) {
      _LuxuryRange.day => formatter.format(_anchor),
      _LuxuryRange.week => () {
        final start = _anchor.subtract(Duration(days: _anchor.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${formatter.format(start)} — ${formatter.format(end)}';
      }(),
      _LuxuryRange.month =>
        '${_arabicMonths[_anchor.month - 1]} ${_anchor.year}',
    };
  }

  void _scheduleDigest(String managerUid) {
    if (_digestScheduled) return;
    _digestScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final taskProvider = context.read<TaskProvider>();
      final activeEmployees = FirestoreService.getAllEmployees()
          .where((user) => user.accountStatus == AccountStatus.active)
          .toList();
      final goalProvider = context.read<GoalProvider>();
      final allGoals = goalProvider.allGoals;
      final goalProgress = <String, ({int total, int completed})>{
        for (final goal in allGoals)
          goal.goalId: goalProvider.progressForGoal(goal.goalId),
      };
      context.read<DigestProvider>().maybeGenerateTodayDigest(
        managerUid: managerUid,
        allTasks: taskProvider.teamTasks,
        allPolls: context.read<PollProvider>().allPolls,
        activeEmployees: activeEmployees,
        allGoals: allGoals,
        goalProgress: goalProgress,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final manager = context.watch<AuthProvider>().currentUser!;
    final digest = context.watch<DigestProvider>();
    final meetings = context.watch<MeetingProvider>().upcoming.toList()
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
    final employees = FirestoreService.getAllEmployees()
        .where((user) => user.accountStatus == AccountStatus.active)
        .toList();
    final tasks = _rangeTasks(provider);
    final stats = provider.statsForRange(tasks);
    final completion = stats.total == 0
        ? 0
        : ((stats.completed / stats.total) * 100).round();

    if (!widget.readOnly) {
      _scheduleDigest(manager.uid);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 960;
        return ColoredBox(
          color: Colors.white,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _Hero(
                  managerName: manager.name,
                  completion: completion,
                  desktop: desktop,
                  readOnly: widget.readOnly,
                ),
                Transform.translate(
                  offset: Offset(0, desktop ? -38 : 0),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      desktop ? 30 : 0,
                      desktop ? 0 : 12,
                      desktop ? 30 : 0,
                      desktop ? 0 : 18,
                    ),
                    child: _DashboardSurface(
                      desktop: desktop,
                      stats: stats,
                      tasks: tasks,
                      managerUid: manager.uid,
                      employees: employees,
                      meetings: meetings,
                      digest: digest.todayDigest,
                      isGeneratingDigest: digest.isGenerating,
                      range: _range,
                      rangeLabel: _rangeLabel,
                      kanban: _kanban,
                      onRangeChanged: (value) => setState(() => _range = value),
                      onShiftRange: _shiftRange,
                      onViewChanged: (value) => setState(() => _kanban = value),
                      readOnly: widget.readOnly,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.managerName,
    required this.completion,
    required this.desktop,
    required this.readOnly,
  });

  final String managerName;
  final int completion;
  final bool desktop;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final nameParts = managerName.trim().split(RegExp(r'\s+'));
    final firstName = nameParts.isEmpty ? managerName : nameParts.first;
    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'صباح الخير' : 'مساء الخير';
    final date =
        '${_weekdays[now.weekday - 1]} ${now.day} '
        '${_arabicMonths[now.month - 1]} ${now.year}';

    final welcome = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting، $firstName',
          style: TextStyle(
            color: Colors.white,
            fontSize: desktop ? 44 : 34,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          date,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.76),
            fontSize: desktop ? 18 : 15,
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: desktop ? 520 : double.infinity,
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    'نسبة إنجاز الفترة',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '$completion%',
                    style: const TextStyle(
                      color: _LuxuryColors.mint,
                      fontSize: 40,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  minHeight: 6,
                  value: completion / 100,
                  color: _LuxuryColors.mint,
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    final action = readOnly
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _LuxuryColors.gold.withValues(alpha: 0.72),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.visibility_outlined, color: _LuxuryColors.gold),
                SizedBox(width: 9),
                Text(
                  'وضع المتابعة · عرض فقط',
                  style: TextStyle(
                    color: _LuxuryColors.gold,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          )
        : SizedBox(
      width: desktop ? 240 : double.infinity,
      height: 60,
      child: OutlinedButton.icon(
        onPressed: () => QuickAddTaskSheet.show(context),
        icon: const Icon(Icons.add, size: 30),
        label: const Text(
          'مهمة جديدة',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _LuxuryColors.gold,
          side: const BorderSide(color: _LuxuryColors.gold, width: 2),
          backgroundColor: _LuxuryColors.deepNavy.withValues(alpha: 0.12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: desktop ? 275 : 310),
      padding: EdgeInsets.fromLTRB(
        desktop ? 62 : 18,
        desktop ? 34 : 24,
        desktop ? 62 : 18,
        desktop ? 68 : 58,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
          colors: [Color(0xFF071C38), Color(0xFF0A2B58), Color(0xFF071E3D)],
        ),
      ),
      child: desktop
          ? Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [welcome, action],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [welcome, const SizedBox(height: 22), action],
            ),
    );
  }
}

class _DashboardSurface extends StatelessWidget {
  const _DashboardSurface({
    required this.desktop,
    required this.stats,
    required this.tasks,
    required this.managerUid,
    required this.employees,
    required this.meetings,
    required this.digest,
    required this.isGeneratingDigest,
    required this.range,
    required this.rangeLabel,
    required this.kanban,
    required this.onRangeChanged,
    required this.onShiftRange,
    required this.onViewChanged,
    required this.readOnly,
  });

  final bool desktop;
  final TaskStats stats;
  final List<AppTask> tasks;
  final String managerUid;
  final List<AppUser> employees;
  final List<MeetingItem> meetings;
  final ManagerDigest? digest;
  final bool isGeneratingDigest;
  final _LuxuryRange range;
  final String rangeLabel;
  final bool kanban;
  final ValueChanged<_LuxuryRange> onRangeChanged;
  final ValueChanged<int> onShiftRange;
  final ValueChanged<bool> onViewChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _MetricData(
        'قيد الانتظار',
        stats.pendingDisplay,
        Icons.schedule_outlined,
        _LuxuryColors.navy,
      ),
      _MetricData(
        'مكتملة',
        stats.completed,
        Icons.check_circle_outline,
        _LuxuryColors.mint,
      ),
      _MetricData(
        'الإجمالي',
        stats.total,
        Icons.assignment_outlined,
        _LuxuryColors.navy,
      ),
      _MetricData(
        'متأخرة',
        stats.overdue,
        Icons.access_time,
        _LuxuryColors.coral,
      ),
      _MetricData(
        'مرفوضة',
        stats.rejected,
        Icons.block_outlined,
        const Color(0xFF343940),
      ),
      _MetricData(
        'بانتظار المراجعة',
        stats.submitted,
        Icons.description_outlined,
        _LuxuryColors.gold,
      ),
    ];

    final content = desktop
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 330,
                child: Column(
                  children: [
                    _TeamPulse(employees: employees, tasks: tasks),
                    const SizedBox(height: 14),
                    _UpcomingPanel(meetings: meetings),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: _ExecutionPanel(
                  tasks: tasks,
                  managerUid: managerUid,
                  desktop: true,
                  range: range,
                  rangeLabel: rangeLabel,
                  kanban: kanban,
                  onRangeChanged: onRangeChanged,
                  onShiftRange: onShiftRange,
                  onViewChanged: onViewChanged,
                  readOnly: readOnly,
                ),
              ),
            ],
          )
        : Column(
            children: [
              _ExecutionPanel(
                tasks: tasks,
                managerUid: managerUid,
                desktop: false,
                range: range,
                rangeLabel: rangeLabel,
                kanban: kanban,
                onRangeChanged: onRangeChanged,
                onShiftRange: onShiftRange,
                onViewChanged: onViewChanged,
                readOnly: readOnly,
              ),
              const SizedBox(height: 14),
              _TeamPulse(employees: employees, tasks: tasks),
              const SizedBox(height: 14),
              _UpcomingPanel(meetings: meetings),
            ],
          );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(desktop ? 24 : 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(desktop ? 24 : 0),
        border: desktop
            ? Border.all(color: const Color(0x0D082A55))
            : null,
        boxShadow: desktop
            ? const [
                BoxShadow(
                  color: Color(0x24122643),
                  blurRadius: 38,
                  offset: Offset(0, 18),
                ),
              ]
            : null,
      ),
      child: Column(
        children: [
          desktop
              ? Row(
                  children: [
                    for (var i = 0; i < metrics.length; i++) ...[
                      Expanded(child: _Metric(data: metrics[i])),
                      if (i < metrics.length - 1)
                        const SizedBox(
                          height: 64,
                          child: VerticalDivider(width: 1),
                        ),
                    ],
                  ],
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - 1) / 2;
                    return Wrap(
                      children: [
                        for (final metric in metrics)
                          SizedBox(
                            width: width,
                            child: _Metric(data: metric),
                          ),
                      ],
                    );
                  },
                ),
          SizedBox(height: desktop ? 30 : 22),
          content,
          if (digest != null || isGeneratingDigest) ...[
            const SizedBox(height: 18),
            DailyDigestCard(digest: digest, isGenerating: isGeneratingDigest),
          ],
        ],
      ),
    );
  }
}

class _MetricData {
  const _MetricData(this.label, this.value, this.icon, this.color);

  final String label;
  final int value;
  final IconData icon;
  final Color color;
}

class _Metric extends StatelessWidget {
  const _Metric({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(data.icon, color: data.color, size: 30),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label,
                style: const TextStyle(color: Color(0xFF2D3440), fontSize: 14),
              ),
              Text(
                '${data.value}',
                style: TextStyle(
                  color: data.color,
                  fontSize: 34,
                  height: 1.05,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExecutionPanel extends StatelessWidget {
  const _ExecutionPanel({
    required this.tasks,
    required this.managerUid,
    required this.desktop,
    required this.range,
    required this.rangeLabel,
    required this.kanban,
    required this.onRangeChanged,
    required this.onShiftRange,
    required this.onViewChanged,
    required this.readOnly,
  });

  final List<AppTask> tasks;
  final String managerUid;
  final bool desktop;
  final _LuxuryRange range;
  final String rangeLabel;
  final bool kanban;
  final ValueChanged<_LuxuryRange> onRangeChanged;
  final ValueChanged<int> onShiftRange;
  final ValueChanged<bool> onViewChanged;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      padding: EdgeInsets.all(desktop ? 20 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              const Text(
                'مسار التنفيذ',
                style: TextStyle(
                  color: _LuxuryColors.navy,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _DashboardControls(
                range: range,
                rangeLabel: rangeLabel,
                kanban: kanban,
                onRangeChanged: onRangeChanged,
                onShiftRange: onShiftRange,
                onViewChanged: onViewChanged,
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 8),
          if (kanban)
            SizedBox(
              height: desktop ? 520 : 650,
              child: TaskKanbanBoard(
                tasks: tasks,
                canDrag: !readOnly,
                onTapTask: (task) => _openTask(
                  context,
                  task,
                  readOnly: readOnly,
                ),
                onStatusChanged: readOnly
                    ? null
                    : (task, status) {
                        context.read<TaskProvider>().updateStatus(
                          task.taskId,
                          status,
                          managerUid,
                        );
                      },
              ),
            )
          else if (tasks.isEmpty)
            _EmptyTasks(
              onAdd: readOnly ? null : () => QuickAddTaskSheet.show(context),
            )
          else if (desktop)
            _DesktopTaskTable(tasks: tasks, readOnly: readOnly)
          else
            Column(
              children: [
                for (final task in tasks.take(8))
                  _MobileTaskCard(task: task, readOnly: readOnly),
              ],
            ),
        ],
      ),
    );
  }
}

class _DashboardControls extends StatelessWidget {
  const _DashboardControls({
    required this.range,
    required this.rangeLabel,
    required this.kanban,
    required this.onRangeChanged,
    required this.onShiftRange,
    required this.onViewChanged,
  });

  final _LuxuryRange range;
  final String rangeLabel;
  final bool kanban;
  final ValueChanged<_LuxuryRange> onRangeChanged;
  final ValueChanged<int> onShiftRange;
  final ValueChanged<bool> onViewChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SegmentedButton<_LuxuryRange>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: _LuxuryRange.day, label: Text('يومي')),
            ButtonSegment(value: _LuxuryRange.week, label: Text('أسبوعي')),
            ButtonSegment(value: _LuxuryRange.month, label: Text('شهري')),
          ],
          selected: {range},
          onSelectionChanged: (values) => onRangeChanged(values.first),
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            textStyle: WidgetStatePropertyAll(
              TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        IconButton(
          tooltip: 'الفترة السابقة',
          visualDensity: VisualDensity.compact,
          onPressed: () => onShiftRange(-1),
          icon: const Icon(Icons.chevron_right),
        ),
        Text(
          rangeLabel,
          style: const TextStyle(fontSize: 12, color: _LuxuryColors.muted),
        ),
        IconButton(
          tooltip: 'الفترة التالية',
          visualDensity: VisualDensity.compact,
          onPressed: () => onShiftRange(1),
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton.filledTonal(
          tooltip: kanban ? 'عرض القائمة' : 'عرض اللوحة',
          visualDensity: VisualDensity.compact,
          onPressed: () => onViewChanged(!kanban),
          icon: Icon(
            kanban ? Icons.view_list_outlined : Icons.view_kanban_outlined,
          ),
        ),
      ],
    );
  }
}

class _DesktopTaskTable extends StatelessWidget {
  const _DesktopTaskTable({required this.tasks, required this.readOnly});

  final List<AppTask> tasks;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(flex: 35, child: Text('المهمة', style: _tableHeader)),
              Expanded(flex: 18, child: Text('المسؤول', style: _tableHeader)),
              Expanded(
                flex: 16,
                child: Text('الموعد النهائي', style: _tableHeader),
              ),
              Expanded(flex: 12, child: Text('الأولوية', style: _tableHeader)),
              Expanded(flex: 19, child: Text('الحالة', style: _tableHeader)),
            ],
          ),
        ),
        const Divider(height: 1),
        for (var i = 0; i < tasks.take(8).length; i++)
          _DesktopTaskRow(index: i + 1, task: tasks[i], readOnly: readOnly),
      ],
    );
  }
}

class _DesktopTaskRow extends StatelessWidget {
  const _DesktopTaskRow({
    required this.index,
    required this.task,
    required this.readOnly,
  });

  final int index;
  final AppTask task;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final employee = FirestoreService.getUser(task.assignedTo);
    final employeeName = employee?.name ?? 'غير محدد';
    final overdue = task.isOverdue;
    return InkWell(
      onTap: () => _openTask(context, task, readOnly: readOnly),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE9EDF1))),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 35,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 13,
                    backgroundColor: _LuxuryColors.navy,
                    child: Text(
                      '$index',
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                  ),
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
                            color: Color(0xFF173050),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          task.category,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _LuxuryColors.muted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 18,
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 17),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      employeeName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 16,
              child: Text(
                intl.DateFormat('yyyy-MM-dd').format(task.dueDate),
                style: TextStyle(
                  fontSize: 12,
                  color: overdue
                      ? _LuxuryColors.coral
                      : const Color(0xFF3F4E61),
                ),
              ),
            ),
            Expanded(
              flex: 12,
              child: Row(
                children: [
                  Icon(
                    priorityIcon(task.priority.name),
                    size: 15,
                    color: priorityColor(task.priority.name),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    priorityLabelAr(task.priority.name),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 19,
              child: Row(
                children: [
                  Container(
                    width: 17,
                    height: 17,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: overdue
                            ? _LuxuryColors.coral
                            : statusColor(task.status.name),
                        width: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      overdue ? 'متأخرة' : statusLabelAr(task.status.name),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: overdue
                            ? _LuxuryColors.coral
                            : statusColor(task.status.name),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MobileTaskCard extends StatelessWidget {
  const _MobileTaskCard({required this.task, required this.readOnly});

  final AppTask task;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final employee = FirestoreService.getUser(task.assignedTo);
    final employeeName = employee?.name ?? 'غير محدد';
    return InkWell(
      onTap: () => _openTask(context, task, readOnly: readOnly),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: _LuxuryColors.navy,
              child: const Icon(Icons.task_alt, color: Colors.white, size: 15),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF173050),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$employeeName · '
                    '${intl.DateFormat('yyyy/MM/dd').format(task.dueDate)}',
                    style: const TextStyle(
                      color: _LuxuryColors.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusChip(statusName: task.status.name, fontSize: 10),
          ],
        ),
      ),
    );
  }
}

class _TeamPulse extends StatelessWidget {
  const _TeamPulse({required this.employees, required this.tasks});

  final List<AppUser> employees;
  final List<AppTask> tasks;

  @override
  Widget build(BuildContext context) {
    var high = 0;
    var medium = 0;
    var low = 0;
    for (final employee in employees) {
      final count = tasks
          .where(
            (task) =>
                task.assignedTo == employee.uid &&
                task.primaryStatus != PrimaryTaskStatus.completed,
          )
          .length;
      if (count >= 5) {
        high++;
      } else if (count >= 2) {
        medium++;
      } else {
        low++;
      }
    }
    final total = employees.length;
    final chartTotal = total == 0 ? 1 : total;
    final chartSections = total == 0
        ? [
            PieChartSectionData(
              value: 1,
              color: const Color(0xFFE8EDF3),
              radius: 18,
              showTitle: false,
            ),
          ]
        : [
            PieChartSectionData(
              value: high / chartTotal,
              color: _LuxuryColors.coral,
              radius: 18,
              showTitle: false,
            ),
            PieChartSectionData(
              value: medium / chartTotal,
              color: _LuxuryColors.gold,
              radius: 18,
              showTitle: false,
            ),
            PieChartSectionData(
              value: low / chartTotal,
              color: _LuxuryColors.mint,
              radius: 18,
              showTitle: false,
            ),
          ];

    return _Panel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.groups_outlined, color: _LuxuryColors.navy),
              SizedBox(width: 8),
              Text(
                'نبض الفريق',
                style: TextStyle(
                  color: _LuxuryColors.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'توزيع عبء العمل',
            style: TextStyle(color: Color(0xFF3F4E61), fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              SizedBox(
                width: 132,
                height: 132,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        startDegreeOffset: -90,
                        centerSpaceRadius: 43,
                        sectionsSpace: 0,
                        sections: chartSections,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$total',
                          style: const TextStyle(
                            color: _LuxuryColors.navy,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Text('عضو', style: TextStyle(fontSize: 11)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  children: [
                    _LegendRow('مرتفع', high, _LuxuryColors.coral),
                    _LegendRow('متوسط', medium, _LuxuryColors.gold),
                    _LegendRow('منخفض', low, _LuxuryColors.mint),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow(this.label, this.value, this.color);

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
          Text('$value', style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _UpcomingPanel extends StatelessWidget {
  const _UpcomingPanel({required this.meetings});

  final List<MeetingItem> meetings;

  @override
  Widget build(BuildContext context) {
    final upcoming = meetings.take(2).toList();
    return _Panel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.calendar_month_outlined, color: _LuxuryColors.navy),
              SizedBox(width: 8),
              Text(
                'القادم',
                style: TextStyle(
                  color: _LuxuryColors.navy,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (upcoming.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 18),
              child: Text(
                'لا توجد اجتماعات قادمة',
                style: TextStyle(color: _LuxuryColors.muted),
              ),
            )
          else
            for (var i = 0; i < upcoming.length; i++) ...[
              _MeetingRow(meeting: upcoming[i], gold: i == 1),
              if (i < upcoming.length - 1) const Divider(height: 18),
            ],
        ],
      ),
    );
  }
}

class _MeetingRow extends StatelessWidget {
  const _MeetingRow({required this.meeting, required this.gold});

  final MeetingItem meeting;
  final bool gold;

  @override
  Widget build(BuildContext context) {
    final dateColor = gold ? _LuxuryColors.gold : _LuxuryColors.navy;
    return Row(
      children: [
        SizedBox(
          width: 62,
          child: Column(
            children: [
              Text(
                meeting.startTime.day.toString().padLeft(2, '0'),
                style: TextStyle(
                  color: dateColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                _arabicMonths[meeting.startTime.month - 1],
                style: TextStyle(color: dateColor, fontSize: 11),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meeting.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                intl.DateFormat('yyyy/MM/dd · HH:mm').format(meeting.startTime),
                style: const TextStyle(
                  color: _LuxuryColors.muted,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child, required this.padding});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFDCE2E8)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: child,
    );
  }
}

class _EmptyTasks extends StatelessWidget {
  const _EmptyTasks({required this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Column(
        children: [
          const Icon(Icons.task_alt, size: 42, color: _LuxuryColors.mint),
          const SizedBox(height: 12),
          const Text(
            'لا توجد مهام في هذه الفترة',
            style: TextStyle(
              color: _LuxuryColors.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (onAdd != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('إضافة مهمة'),
            ),
          ],
        ],
      ),
    );
  }
}

void _openTask(
  BuildContext context,
  AppTask task, {
  bool readOnly = false,
}) {
  Navigator.of(
    context,
  ).push(
    MaterialPageRoute(
      builder: (_) => readOnly
          ? DesignerTaskViewScreen(task: task)
          : TaskReviewDetailScreen(task: task),
    ),
  );
}

const _tableHeader = TextStyle(
  color: Color(0xFF536174),
  fontSize: 12,
  fontWeight: FontWeight.w700,
);

class _LuxuryColors {
  static const deepNavy = Color(0xFF071D3B);
  static const navy = Color(0xFF0A2A55);
  static const mint = Color(0xFF45CDA0);
  static const gold = Color(0xFFE6AD36);
  static const coral = Color(0xFFEF5A4D);
  static const muted = Color(0xFF677386);
}

const _arabicMonths = [
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

const _weekdays = [
  'الإثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
  'الجمعة',
  'السبت',
  'الأحد',
];
