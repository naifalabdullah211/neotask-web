import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../models/task_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import '../utils/project_planning.dart';
import 'neo_selection_field.dart';
import 'user_avatar.dart';

/// The visual workspace used by the Work Plan screen.
///
/// It deliberately keeps the existing task model and planning calculations
/// intact. The widget only changes how that information is organised and
/// interacted with: stage/task list on the right, RTL Gantt chart in the
/// centre, and the selected task's details on the left.
class ProjectPlanTimelineWorkspace extends StatefulWidget {
  const ProjectPlanTimelineWorkspace({
    super.key,
    required this.tasks,
    required this.criticalTaskIds,
    required this.readOnly,
    required this.onEditTask,
    required this.onOpenTask,
  });

  final List<AppTask> tasks;
  final Set<String> criticalTaskIds;
  final bool readOnly;
  final ValueChanged<AppTask> onEditTask;
  final ValueChanged<AppTask> onOpenTask;

  @override
  State<ProjectPlanTimelineWorkspace> createState() =>
      _ProjectPlanTimelineWorkspaceState();
}

enum _TimelineScale { week, month }

class _ProjectPlanTimelineWorkspaceState
    extends State<ProjectPlanTimelineWorkspace> {
  String? _selectedTaskId;
  _TimelineScale _scale = _TimelineScale.week;
  final ScrollController _listScrollController = ScrollController();
  final ScrollController _chartScrollController = ScrollController();
  bool _syncingScroll = false;

  @override
  void initState() {
    super.initState();
    _listScrollController.addListener(
      () => _syncVerticalScroll(_listScrollController, _chartScrollController),
    );
    _chartScrollController.addListener(
      () => _syncVerticalScroll(_chartScrollController, _listScrollController),
    );
  }

  void _syncVerticalScroll(
    ScrollController source,
    ScrollController target,
  ) {
    if (_syncingScroll || !source.hasClients || !target.hasClients) return;
    final nextOffset = source.offset
        .clamp(0.0, target.position.maxScrollExtent)
        .toDouble();
    if ((target.offset - nextOffset).abs() < .5) return;
    _syncingScroll = true;
    target.jumpTo(nextOffset);
    _syncingScroll = false;
  }

  @override
  void dispose() {
    _listScrollController.dispose();
    _chartScrollController.dispose();
    super.dispose();
  }

  AppTask? get _selectedTask {
    final tasks = widget.tasks;
    if (tasks.isEmpty) return null;
    for (final task in tasks) {
      if (task.taskId == _selectedTaskId) return task;
    }
    return tasks.first;
  }

  void _selectTask(AppTask task, {bool showSheet = false}) {
    setState(() => _selectedTaskId = task.taskId);
    if (showSheet) {
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (context) => FractionallySizedBox(
          heightFactor: .78,
          child: _TaskDetailsPanel(
            task: task,
            allTasks: widget.tasks,
            critical: widget.criticalTaskIds.contains(task.taskId),
            readOnly: widget.readOnly,
            onEdit: () {
              Navigator.pop(context);
              widget.onEditTask(task);
            },
            onOpen: () {
              Navigator.pop(context);
              widget.onOpenTask(task);
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.tasks.isEmpty) {
      return const _PlanEmptyState();
    }

    final rows = _buildPlanRows(widget.tasks);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (width < 760) {
          return _MobilePlanView(
            rows: rows,
            tasks: widget.tasks,
            criticalTaskIds: widget.criticalTaskIds,
            onSelect: (task) => _selectTask(task, showSheet: true),
          );
        }

        final showDetails = width >= 1180;
        return Column(
          children: [
            _TimelineControls(
              tasks: widget.tasks,
              scale: _scale,
              onScaleChanged: (value) => setState(() => _scale = value),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: AppColors.divider),
                  ),
                ),
                child: Row(
                  textDirection: TextDirection.rtl,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: showDetails ? 430 : 380,
                      child: _TaskListPanel(
                        rows: rows,
                        scrollController: _listScrollController,
                        selectedTaskId: _selectedTask?.taskId,
                        criticalTaskIds: widget.criticalTaskIds,
                        onSelect: (task) => _selectTask(
                          task,
                          showSheet: !showDetails,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _TimelineChart(
                        rows: rows,
                        tasks: widget.tasks,
                        selectedTaskId: _selectedTask?.taskId,
                        criticalTaskIds: widget.criticalTaskIds,
                        scale: _scale,
                        verticalScrollController: _chartScrollController,
                        onSelect: (task) => _selectTask(
                          task,
                          showSheet: !showDetails,
                        ),
                      ),
                    ),
                    if (showDetails)
                      SizedBox(
                        width: 320,
                        child: _TaskDetailsPanel(
                          task: _selectedTask!,
                          allTasks: widget.tasks,
                          critical: widget.criticalTaskIds.contains(
                            _selectedTask!.taskId,
                          ),
                          readOnly: widget.readOnly,
                          onEdit: () => widget.onEditTask(_selectedTask!),
                          onOpen: () => widget.onOpenTask(_selectedTask!),
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

class ProjectPlanMetricsBar extends StatelessWidget {
  const ProjectPlanMetricsBar({
    super.key,
    required this.taskCount,
    required this.weightedProgress,
    required this.blockedCount,
    required this.criticalCount,
    required this.overdueCount,
  });

  final int taskCount;
  final int weightedProgress;
  final int blockedCount;
  final int criticalCount;
  final int overdueCount;

  @override
  Widget build(BuildContext context) {
    final items = [
      _MetricData(
        label: 'مهام الخطة',
        value: '$taskCount',
        icon: Icons.assignment_outlined,
        color: const Color(0xFF1F6FD2),
      ),
      _MetricData(
        label: 'التقدم الموزون',
        value: '$weightedProgress%',
        icon: Icons.donut_large_rounded,
        color: AppColors.mintAccent,
      ),
      _MetricData(
        label: 'متوقفة بتبعية',
        value: '$blockedCount',
        icon: Icons.pause_circle_outline_rounded,
        color: AppColors.textSecondary,
      ),
      _MetricData(
        label: 'المسار الحرج',
        value: '$criticalCount',
        icon: Icons.route_outlined,
        color: AppColors.gold,
      ),
      _MetricData(
        label: 'متأخرة',
        value: '$overdueCount',
        icon: Icons.schedule_rounded,
        color: AppColors.overdue,
      ),
    ];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          textDirection: TextDirection.rtl,
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _HeaderMetric(data: items[index]),
              if (index != items.length - 1)
                const SizedBox(
                  height: 42,
                  child: VerticalDivider(
                    width: 28,
                    color: AppColors.divider,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MetricData {
  const _MetricData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _HeaderMetric extends StatelessWidget {
  const _HeaderMetric({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 174,
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(data.icon, color: data.color, size: 23),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  data.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySecondary,
                ),
                Text(
                  data.value,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
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

class _TimelineControls extends StatelessWidget {
  const _TimelineControls({
    required this.tasks,
    required this.scale,
    required this.onScaleChanged,
  });

  final List<AppTask> tasks;
  final _TimelineScale scale;
  final ValueChanged<_TimelineScale> onScaleChanged;

  @override
  Widget build(BuildContext context) {
    var start = tasks.first.startDate;
    var end = tasks.first.dueDate;
    for (final task in tasks) {
      if (task.startDate.isBefore(start)) start = task.startDate;
      if (task.dueDate.isAfter(end)) end = task.dueDate;
    }
    final range =
        '${intl.DateFormat('d MMM', 'ar').format(start)} — ${intl.DateFormat('d MMM yyyy', 'ar').format(end)}';

    return Container(
      color: const Color(0xFFF9FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        textDirection: TextDirection.rtl,
        children: [
          const Text(
            'الجدول الزمني',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          if (MediaQuery.sizeOf(context).width >= 900)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 17,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Text(range, style: AppTextStyles.bodySecondary),
                ],
              ),
            ),
          if (MediaQuery.sizeOf(context).width >= 900)
            const SizedBox(width: 10),
          SizedBox(
            width: 142,
            child: NeoSelectionField<_TimelineScale>(
              label: 'المقياس',
              value: scale,
              options: const [
                NeoSelectionOption(
                  value: _TimelineScale.week,
                  label: 'أسبوعي',
                  icon: Icons.view_week_outlined,
                ),
                NeoSelectionOption(
                  value: _TimelineScale.month,
                  label: 'شهري',
                  icon: Icons.calendar_view_month_outlined,
                ),
              ],
              onChanged: onScaleChanged,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanRow {
  const _PlanRow.phase(this.label)
    : task = null,
      phase = true;

  const _PlanRow.task(this.task)
    : label = '',
      phase = false;

  final String label;
  final AppTask? task;
  final bool phase;

  double get height => phase ? 44 : 66;
}

List<_PlanRow> _buildPlanRows(List<AppTask> tasks) {
  final orderedCategories = <String>[];
  final groups = <String, List<AppTask>>{};
  final byId = {for (final task in tasks) task.taskId: task};

  String categoryFor(AppTask task) {
    var current = task;
    final visited = <String>{task.taskId};
    while (current.parentTaskId != null) {
      final parent = byId[current.parentTaskId];
      if (parent == null || !visited.add(parent.taskId)) break;
      current = parent;
    }
    final category = current.category.trim();
    return category.isEmpty ? 'مهام الخطة' : category;
  }

  for (final task in tasks) {
    final category = categoryFor(task);
    if (!groups.containsKey(category)) orderedCategories.add(category);
    groups.putIfAbsent(category, () => []).add(task);
  }

  final rows = <_PlanRow>[];
  for (var index = 0; index < orderedCategories.length; index++) {
    final category = orderedCategories[index];
    rows.add(_PlanRow.phase('${index + 1}. $category'));
    final group = groups[category]!..sort((a, b) {
      if (a.parentTaskId == b.taskId) return 1;
      if (b.parentTaskId == a.taskId) return -1;
      return a.startDate.compareTo(b.startDate);
    });
    rows.addAll(group.map(_PlanRow.task));
  }
  return rows;
}

class _TaskListPanel extends StatelessWidget {
  const _TaskListPanel({
    required this.rows,
    required this.scrollController,
    required this.selectedTaskId,
    required this.criticalTaskIds,
    required this.onSelect,
  });

  final List<_PlanRow> rows;
  final ScrollController scrollController;
  final String? selectedTaskId;
  final Set<String> criticalTaskIds;
  final ValueChanged<AppTask> onSelect;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        children: [
          const _TaskListHeader(),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              padding: EdgeInsets.zero,
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final row = rows[index];
                if (row.phase) {
                  return Container(
                    height: row.height,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    alignment: AlignmentDirectional.centerStart,
                    decoration: const BoxDecoration(
                      color: Color(0xFFFAFBFD),
                      border: Border(
                        bottom: BorderSide(color: AppColors.divider),
                      ),
                    ),
                    child: Text(
                      row.label,
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  );
                }
                final task = row.task!;
                return _TaskPlanRow(
                  task: task,
                  selected: task.taskId == selectedTaskId,
                  critical: criticalTaskIds.contains(task.taskId),
                  onTap: () => onSelect(task),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskListHeader extends StatelessWidget {
  const _TaskListHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: const Row(
        textDirection: TextDirection.rtl,
        children: [
          Expanded(
            flex: 4,
            child: Text('اسم المهمة', style: AppTextStyles.sectionLabel),
          ),
          Expanded(
            flex: 3,
            child: Text('المسؤول', style: AppTextStyles.sectionLabel),
          ),
          Expanded(
            flex: 2,
            child: Text('الحالة', style: AppTextStyles.sectionLabel),
          ),
          SizedBox(
            width: 48,
            child: Text('التقدم', style: AppTextStyles.sectionLabel),
          ),
        ],
      ),
    );
  }
}

class _TaskPlanRow extends StatelessWidget {
  const _TaskPlanRow({
    required this.task,
    required this.selected,
    required this.critical,
    required this.onTap,
  });

  final AppTask task;
  final bool selected;
  final bool critical;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final assignee = FirestoreService.getUser(task.assignedTo);
    final color = _statusColor(task);
    return Material(
      color: selected ? const Color(0xFFEAF4FF) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 66,
          padding: EdgeInsetsDirectional.only(
            start: task.parentTaskId == null ? 14 : 28,
            end: 14,
          ),
          decoration: BoxDecoration(
            border: BorderDirectional(
              bottom: const BorderSide(color: AppColors.divider),
              start: selected
                  ? const BorderSide(color: AppColors.mintAccent, width: 3)
                  : BorderSide.none,
            ),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                flex: 4,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: critical ? AppColors.gold : color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    UserAvatar(
                      name: assignee?.name ?? 'غير مسند',
                      imageUrl: assignee?.profilePhotoUrl,
                      radius: 14,
                      borderWidth: 1,
                      borderColor: AppColors.divider,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        assignee?.name ?? 'غير مسند',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 10.5),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 2,
                child: Text(
                  _statusLabel(task),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SizedBox(
                width: 48,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${task.progressPercent}%',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                      child: LinearProgressIndicator(
                        value: task.progressPercent / 100,
                        minHeight: 4,
                        backgroundColor: AppColors.divider,
                        color: color,
                      ),
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

class _TimelineChart extends StatelessWidget {
  const _TimelineChart({
    required this.rows,
    required this.tasks,
    required this.selectedTaskId,
    required this.criticalTaskIds,
    required this.scale,
    required this.verticalScrollController,
    required this.onSelect,
  });

  final List<_PlanRow> rows;
  final List<AppTask> tasks;
  final String? selectedTaskId;
  final Set<String> criticalTaskIds;
  final _TimelineScale scale;
  final ScrollController verticalScrollController;
  final ValueChanged<AppTask> onSelect;

  @override
  Widget build(BuildContext context) {
    var minDate = tasks.first.startDate;
    var maxDate = tasks.first.dueDate;
    for (final task in tasks) {
      if (task.startDate.isBefore(minDate)) minDate = task.startDate;
      if (task.dueDate.isAfter(maxDate)) maxDate = task.dueDate;
    }
    minDate = DateTime(minDate.year, minDate.month, minDate.day);
    maxDate = DateTime(maxDate.year, maxDate.month, maxDate.day).add(
      const Duration(days: 1),
    );
    final totalDays = math.max(1, maxDate.difference(minDate).inDays).toInt();
    final dayWidth = scale == _TimelineScale.week ? 25.0 : 13.0;
    final chartWidth = math.max(720.0, totalDays * dayWidth).toDouble();
    final bodyHeight = rows.fold<double>(0, (sum, row) => sum + row.height);

    return ColoredBox(
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        reverse: true,
        child: SizedBox(
          width: chartWidth,
          child: Column(
            children: [
              _TimelineDateHeader(
                minDate: minDate,
                totalDays: totalDays,
                dayWidth: dayWidth,
                scale: scale,
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: verticalScrollController,
                  child: SizedBox(
                    width: chartWidth,
                    height: bodyHeight,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _TimelineBackdropPainter(
                              rows: rows,
                              minDate: minDate,
                              totalDays: totalDays,
                              dayWidth: dayWidth,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DependencyPainter(
                              rows: rows,
                              minDate: minDate,
                              dayWidth: dayWidth,
                              chartWidth: chartWidth,
                            ),
                          ),
                        ),
                        ..._buildBars(
                          minDate: minDate,
                          dayWidth: dayWidth,
                          chartWidth: chartWidth,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildBars({
    required DateTime minDate,
    required double dayWidth,
    required double chartWidth,
  }) {
    var top = 0.0;
    final widgets = <Widget>[];
    for (final row in rows) {
      if (row.phase) {
        top += row.height;
        continue;
      }
      final task = row.task!;
      final startDays = task.startDate.difference(minDate).inHours / 24;
      final durationDays = math
          .max(1.0, task.dueDate.difference(task.startDate).inHours / 24 + 1)
          .toDouble();
      final right = math.max(0.0, startDays * dayWidth).toDouble();
      final width = math
          .min(chartWidth - right, math.max(72.0, durationDays * dayWidth))
          .toDouble();
      widgets.add(
        Positioned(
          top: top + 15,
          right: right,
          width: width,
          height: 36,
          child: _TimelineTaskBar(
            task: task,
            selected: task.taskId == selectedTaskId,
            critical: criticalTaskIds.contains(task.taskId),
            onTap: () => onSelect(task),
          ),
        ),
      );
      top += row.height;
    }
    return widgets;
  }
}

class _TimelineDateHeader extends StatelessWidget {
  const _TimelineDateHeader({
    required this.minDate,
    required this.totalDays,
    required this.dayWidth,
    required this.scale,
  });

  final DateTime minDate;
  final int totalDays;
  final double dayWidth;
  final _TimelineScale scale;

  @override
  Widget build(BuildContext context) {
    if (scale == _TimelineScale.month) {
      return _buildMonthHeader();
    }

    final weeks = math.max(1, (totalDays / 7).ceil()).toInt();
    return Container(
      height: 58,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Stack(
        children: [
          for (var week = 0; week < weeks; week++)
            Positioned(
              right: week * 7 * dayWidth,
              width: math.min(7, totalDays - week * 7) * dayWidth,
              top: 0,
              bottom: 0,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    intl.DateFormat('d MMM', 'ar').format(
                      minDate.add(Duration(days: week * 7)),
                    ),
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      for (
                        var day = 0;
                        day < math.min(7, totalDays - week * 7);
                        day++
                      )
                        SizedBox(
                          width: dayWidth,
                          child: Text(
                            _weekdayInitial(
                              minDate.add(
                                Duration(days: week * 7 + day),
                              ),
                            ),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.sectionLabel,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMonthHeader() {
    final segments = <({DateTime start, int days, int offsetDays})>[];
    var cursor = minDate;
    var offsetDays = 0;
    final end = minDate.add(Duration(days: totalDays));
    while (cursor.isBefore(end)) {
      final nextMonth = cursor.month == 12
          ? DateTime(cursor.year + 1)
          : DateTime(cursor.year, cursor.month + 1);
      final segmentEnd = nextMonth.isBefore(end) ? nextMonth : end;
      final days = segmentEnd.difference(cursor).inDays;
      segments.add((start: cursor, days: days, offsetDays: offsetDays));
      offsetDays += days;
      cursor = segmentEnd;
    }

    return Container(
      height: 58,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Stack(
        children: [
          for (final segment in segments)
            Positioned(
              right: segment.offsetDays * dayWidth,
              width: segment.days * dayWidth,
              top: 0,
              bottom: 0,
              child: Container(
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  border: Border(
                    left: BorderSide(color: AppColors.divider),
                  ),
                ),
                child: Text(
                  intl.DateFormat('MMMM yyyy', 'ar').format(segment.start),
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TimelineTaskBar extends StatelessWidget {
  const _TimelineTaskBar({
    required this.task,
    required this.selected,
    required this.critical,
    required this.onTap,
  });

  final AppTask task;
  final bool selected;
  final bool critical;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final completed = task.status == TaskStatus.approved;
    final baseColor = completed
        ? AppColors.mintAccent
        : critical
        ? AppColors.gold
        : AppColors.deepBlue;
    return Tooltip(
      message:
          '${task.title} • ${intl.DateFormat('yyyy/MM/dd').format(task.startDate)} — ${intl.DateFormat('yyyy/MM/dd').format(task.dueDate)}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          child: AnimatedContainer(
            duration: AppMotion.medium,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: baseColor.withValues(alpha: completed ? .18 : .12),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                color: selected ? AppColors.mintAccent : baseColor,
                width: selected ? 2 : 1,
              ),
              boxShadow: selected ? AppElevation.lowShadow : null,
            ),
            child: Stack(
              children: [
                FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: (task.progressPercent / 100)
                      .clamp(0, 1)
                      .toDouble(),
                  child: ColoredBox(
                    color: baseColor.withValues(alpha: completed ? .86 : .92),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          task.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: task.progressPercent >= 52
                                ? Colors.white
                                : AppColors.textPrimary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${task.progressPercent}%',
                        style: TextStyle(
                          color: task.progressPercent >= 82
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimelineBackdropPainter extends CustomPainter {
  const _TimelineBackdropPainter({
    required this.rows,
    required this.minDate,
    required this.totalDays,
    required this.dayWidth,
  });

  final List<_PlanRow> rows;
  final DateTime minDate;
  final int totalDays;
  final double dayWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    final weekLine = Paint()
      ..color = const Color(0xFFD8DEE8)
      ..strokeWidth = 1;
    for (var day = 0; day <= totalDays; day++) {
      final x = size.width - day * dayWidth;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        day % 7 == 0 ? weekLine : line,
      );
    }

    final today = DateTime.now();
    final normalizedToday = DateTime(today.year, today.month, today.day);
    final todayOffset = normalizedToday.difference(minDate).inDays;
    if (todayOffset >= 0 && todayOffset <= totalDays) {
      final x = size.width - todayOffset * dayWidth;
      final todayPaint = Paint()
        ..color = AppColors.mintAccent.withValues(alpha: .55)
        ..strokeWidth = 2;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), todayPaint);
    }

    var y = 0.0;
    for (final row in rows) {
      if (row.phase) {
        canvas.drawRect(
          Rect.fromLTWH(0, y, size.width, row.height),
          Paint()..color = const Color(0xFFFAFBFD),
        );
      }
      y += row.height;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), line);
    }
  }

  @override
  bool shouldRepaint(covariant _TimelineBackdropPainter oldDelegate) =>
      oldDelegate.rows != rows ||
      oldDelegate.minDate != minDate ||
      oldDelegate.totalDays != totalDays ||
      oldDelegate.dayWidth != dayWidth;
}

class _DependencyPainter extends CustomPainter {
  const _DependencyPainter({
    required this.rows,
    required this.minDate,
    required this.dayWidth,
    required this.chartWidth,
  });

  final List<_PlanRow> rows;
  final DateTime minDate;
  final double dayWidth;
  final double chartWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final geometry = <String, Rect>{};
    var y = 0.0;
    for (final row in rows) {
      if (!row.phase) {
        final task = row.task!;
        final startDays = task.startDate.difference(minDate).inHours / 24;
        final durationDays = math
            .max(1.0, task.dueDate.difference(task.startDate).inHours / 24 + 1)
            .toDouble();
        final right = math.max(0.0, startDays * dayWidth).toDouble();
        final width = math
            .min(chartWidth - right, math.max(72.0, durationDays * dayWidth))
            .toDouble();
        geometry[task.taskId] = Rect.fromLTWH(
          chartWidth - right - width,
          y + 15,
          width,
          36,
        );
      }
      y += row.height;
    }

    final paint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final arrowPaint = Paint()
      ..color = AppColors.gold
      ..style = PaintingStyle.fill;

    for (final row in rows) {
      final task = row.task;
      if (task == null || task.predecessorTaskIds.isEmpty) continue;
      final successor = geometry[task.taskId];
      if (successor == null) continue;
      for (final predecessorId in task.predecessorTaskIds) {
        final predecessor = geometry[predecessorId];
        if (predecessor == null) continue;

        final from = Offset(predecessor.left, predecessor.center.dy);
        final to = Offset(successor.right, successor.center.dy);
        final bendX = (from.dx + to.dx) / 2;
        final path = Path()
          ..moveTo(from.dx, from.dy)
          ..lineTo(bendX, from.dy)
          ..lineTo(bendX, to.dy)
          ..lineTo(to.dx + 5, to.dy);
        canvas.drawPath(path, paint);
        canvas.drawPath(
          Path()
            ..moveTo(to.dx, to.dy)
            ..lineTo(to.dx + 7, to.dy - 4)
            ..lineTo(to.dx + 7, to.dy + 4)
            ..close(),
          arrowPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DependencyPainter oldDelegate) =>
      oldDelegate.rows != rows ||
      oldDelegate.minDate != minDate ||
      oldDelegate.dayWidth != dayWidth ||
      oldDelegate.chartWidth != chartWidth;
}

class _TaskDetailsPanel extends StatelessWidget {
  const _TaskDetailsPanel({
    required this.task,
    required this.allTasks,
    required this.critical,
    required this.readOnly,
    required this.onEdit,
    required this.onOpen,
  });

  final AppTask task;
  final List<AppTask> allTasks;
  final bool critical;
  final bool readOnly;
  final VoidCallback onEdit;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final assignee = FirestoreService.getUser(task.assignedTo);
    final predecessors = ProjectPlanning.index(allTasks);
    final duration = math.max(
      1,
      task.dueDate.difference(task.startDate).inDays + 1,
    );
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: AppColors.divider)),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'تفاصيل المهمة',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!readOnly)
                IconButton(
                  tooltip: 'تعديل الخطة',
                  onPressed: onEdit,
                  icon: const Icon(Icons.tune_rounded, size: 20),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: critical ? AppColors.gold : _statusColor(task),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'المرحلة: ${task.category.isEmpty ? 'عام' : task.category}',
            style: AppTextStyles.bodySecondary,
          ),
          const Divider(height: 30),
          const _DetailLabel('المسؤول'),
          const SizedBox(height: 8),
          Row(
            children: [
              UserAvatar(
                name: assignee?.name ?? 'غير مسند',
                imageUrl: assignee?.profilePhotoUrl,
                radius: 22,
                borderColor: AppColors.mintAccent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignee?.name ?? 'غير مسند',
                      style: AppTextStyles.cardTitle,
                    ),
                    if ((assignee?.employeeNumber ?? '').isNotEmpty)
                      Text(
                        assignee!.employeeNumber,
                        style: AppTextStyles.bodySecondary,
                      ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          const _DetailLabel('التواريخ'),
          const SizedBox(height: 10),
          _DetailLine(
            icon: Icons.calendar_today_outlined,
            label: 'تاريخ البدء',
            value: intl.DateFormat('yyyy/MM/dd').format(task.startDate),
          ),
          _DetailLine(
            icon: Icons.event_available_outlined,
            label: 'تاريخ الانتهاء',
            value: intl.DateFormat('yyyy/MM/dd').format(task.dueDate),
          ),
          _DetailLine(
            icon: Icons.timelapse_rounded,
            label: 'المدة',
            value: '$duration ${duration == 1 ? 'يوم' : 'أيام'}',
          ),
          const Divider(height: 30),
          const _DetailLabel('التبعية'),
          const SizedBox(height: 8),
          if (task.predecessorTaskIds.isEmpty)
            const Text('لا توجد تبعيات', style: AppTextStyles.bodySecondary)
          else
            ...task.predecessorTaskIds.map(
              (id) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F7FA),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.link_rounded,
                      color: AppColors.gold,
                      size: 17,
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        predecessors[id]?.title ?? 'مهمة سابقة',
                        style: AppTextStyles.bodySecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const Divider(height: 30),
          Row(
            children: [
              const Expanded(child: _DetailLabel('التقدم')),
              Text(
                '${task.progressPercent}%',
                style: const TextStyle(
                  color: AppColors.deepBlue,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.pill),
            child: LinearProgressIndicator(
              value: task.progressPercent / 100,
              minHeight: 8,
              backgroundColor: AppColors.divider,
              color: _statusColor(task),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_statusLabel(task)} • ${task.plannedHours.toStringAsFixed(task.plannedHours % 1 == 0 ? 0 : 1)} ساعة مخططة',
            style: AppTextStyles.bodySecondary,
          ),
          if (critical) ...[
            const Divider(height: 30),
            const _CriticalPathBadge(),
          ],
          if (task.description.trim().isNotEmpty) ...[
            const Divider(height: 30),
            const _DetailLabel('وصف مختصر'),
            const SizedBox(height: 8),
            Text(task.description, style: AppTextStyles.bodySecondary),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('فتح المهمة كاملة'),
          ),
        ],
      ),
    );
  }
}

class _DetailLabel extends StatelessWidget {
  const _DetailLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      color: AppColors.textPrimary,
      fontSize: 12,
      fontWeight: FontWeight.w800,
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 9),
    child: Row(
      children: [
        Icon(icon, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: AppTextStyles.bodySecondary)),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _CriticalPathBadge extends StatelessWidget {
  const _CriticalPathBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: AppColors.gold.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(AppRadius.sm),
      border: Border.all(color: AppColors.gold.withValues(alpha: .35)),
    ),
    child: const Row(
      children: [
        Icon(Icons.route_outlined, color: AppColors.gold, size: 18),
        SizedBox(width: 8),
        Text(
          'ضمن المسار الحرج',
          style: TextStyle(
            color: AppColors.statusPending,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _MobilePlanView extends StatelessWidget {
  const _MobilePlanView({
    required this.rows,
    required this.tasks,
    required this.criticalTaskIds,
    required this.onSelect,
  });

  final List<_PlanRow> rows;
  final List<AppTask> tasks;
  final Set<String> criticalTaskIds;
  final ValueChanged<AppTask> onSelect;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      itemCount: rows.length,
      itemBuilder: (context, index) {
        final row = rows[index];
        if (row.phase) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
            child: Text(
              row.label,
              style: const TextStyle(
                color: AppColors.deepBlue,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          );
        }
        final task = row.task!;
        final assignee = FirestoreService.getUser(task.assignedTo);
        final color = _statusColor(task);
        final blocked = ProjectPlanning.isBlocked(task, tasks);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: AppElevation.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            side: const BorderSide(color: AppColors.divider),
          ),
          child: InkWell(
            onTap: () => onSelect(task),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 9,
                        height: 9,
                        decoration: BoxDecoration(
                          color: criticalTaskIds.contains(task.taskId)
                              ? AppColors.gold
                              : color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          task.title,
                          style: AppTextStyles.cardTitle,
                        ),
                      ),
                      if (blocked)
                        const Icon(
                          Icons.link_rounded,
                          color: AppColors.gold,
                          size: 19,
                        ),
                      const Icon(
                        Icons.chevron_left_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      UserAvatar(
                        name: assignee?.name ?? 'غير مسند',
                        imageUrl: assignee?.profilePhotoUrl,
                        radius: 14,
                        borderWidth: 1,
                        borderColor: AppColors.divider,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          assignee?.name ?? 'غير مسند',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySecondary,
                        ),
                      ),
                      Text(
                        '${intl.DateFormat('MM/dd').format(task.startDate)} — ${intl.DateFormat('MM/dd').format(task.dueDate)}',
                        style: AppTextStyles.bodySecondary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  Row(
                    children: [
                      Text(
                        '${task.progressPercent}%',
                        style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          child: LinearProgressIndicator(
                            value: task.progressPercent / 100,
                            minHeight: 6,
                            color: color,
                            backgroundColor: AppColors.divider,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _statusLabel(task),
                        style: TextStyle(
                          color: color,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PlanEmptyState extends StatelessWidget {
  const _PlanEmptyState();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.deepBlue.withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.view_timeline_outlined,
              color: AppColors.deepBlue,
              size: 34,
            ),
          ),
          const SizedBox(height: 16),
          const Text('الخطة جاهزة لاستقبال أول مهمة', style: AppTextStyles.titleMd),
          const SizedBox(height: 6),
          const Text(
            'أضف مهمة وحدد البداية والنهاية لتظهر هنا تلقائيًا.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
        ],
      ),
    ),
  );
}

String _statusLabel(AppTask task) => switch (task.status) {
  TaskStatus.assigned => 'لم يبدأ',
  TaskStatus.inProgress => 'قيد التنفيذ',
  TaskStatus.submitted => 'قيد المراجعة',
  TaskStatus.approved => 'مكتملة',
  TaskStatus.rejected => 'مرفوضة',
  TaskStatus.editRequested => 'تعديل مطلوب',
};

Color _statusColor(AppTask task) => switch (task.status) {
  TaskStatus.assigned => AppColors.textSecondary,
  TaskStatus.inProgress => const Color(0xFF1F6FD2),
  TaskStatus.submitted => AppColors.gold,
  TaskStatus.approved => AppColors.statusApproved,
  TaskStatus.rejected => AppColors.statusRejected,
  TaskStatus.editRequested => AppColors.statusPending,
};

String _weekdayInitial(DateTime date) {
  final label = intl.DateFormat('EEE', 'ar').format(date).trim();
  if (label.isEmpty) return '';
  return String.fromCharCode(label.runes.first);
}
