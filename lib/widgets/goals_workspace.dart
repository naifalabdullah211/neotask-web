import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:intl/intl.dart' as intl;

import '../models/criterion_model.dart';
import '../models/goal_model.dart';
import '../providers/goal_provider.dart';
import '../theme/app_theme.dart';
import '../theme/goal_style_options.dart';
import 'neo_selection_field.dart';
import 'neo_workspace_chrome.dart';

enum _GoalFilter { all, active, completed, late }

class GoalsWorkspace extends StatefulWidget {
  const GoalsWorkspace({
    super.key,
    required this.goals,
    required this.provider,
    required this.onOpenGoal,
  });

  final List<Goal> goals;
  final GoalProvider provider;
  final ValueChanged<Goal> onOpenGoal;

  @override
  State<GoalsWorkspace> createState() => _GoalsWorkspaceState();
}

class _GoalsWorkspaceState extends State<GoalsWorkspace> {
  String? _selectedGoalId;
  _GoalFilter _filter = _GoalFilter.all;

  bool _isCompleted(Goal goal) {
    final progress = widget.provider.progressForGoal(goal.goalId);
    return progress.total > 0 && progress.completed == progress.total;
  }

  bool _isLate(Goal goal) =>
      goal.endDate.isBefore(DateTime.now()) && !_isCompleted(goal);

  List<Goal> get _visibleGoals => switch (_filter) {
    _GoalFilter.all => widget.goals,
    _GoalFilter.active => widget.goals
        .where((goal) => !_isCompleted(goal) && !_isLate(goal))
        .toList(),
    _GoalFilter.completed => widget.goals.where(_isCompleted).toList(),
    _GoalFilter.late => widget.goals.where(_isLate).toList(),
  };

  Goal? get _selectedGoal {
    final goals = _visibleGoals;
    if (goals.isEmpty) return null;
    for (final goal in goals) {
      if (goal.goalId == _selectedGoalId) return goal;
    }
    return goals.first;
  }

  void _selectGoal(Goal goal, {required bool showSheet}) {
    setState(() => _selectedGoalId = goal.goalId);
    if (!showSheet) return;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .82,
        child: _GoalDetailsPanel(
          goal: goal,
          criteria: widget.provider.criteriaForGoal(goal.goalId),
          onOpen: () {
            Navigator.pop(sheetContext);
            widget.onOpenGoal(goal);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.goals.isEmpty) {
      return const NeoWorkspaceEmptyState(
        icon: Icons.flag_outlined,
        title: 'مساحة الأهداف جاهزة',
        message: 'أنشئ هدفًا وحدد معاييره وفترته لمتابعة التقدم من مكان واحد.',
      );
    }

    final visible = _visibleGoals;
    final selected = _selectedGoal;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return _MobileGoalsView(
            goals: visible,
            provider: widget.provider,
            filter: _filter,
            onFilterChanged: (value) => setState(() => _filter = value),
            onSelect: (goal) => _selectGoal(goal, showSheet: true),
          );
        }

        final showDetails = constraints.maxWidth >= 1180;
        return Column(
          children: [
            _GoalsToolbar(
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
                        title: 'لا توجد أهداف ضمن هذا العرض',
                        message: 'غيّر عامل التصفية لعرض بقية الأهداف.',
                      )
                    : Row(
                        textDirection: Directionality.of(context),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          NeoWorkspacePanel(
                            width: showDetails ? 390 : 350,
                            borderEnd: true,
                            child: _GoalListPanel(
                              goals: visible,
                              provider: widget.provider,
                              selectedGoalId: selected.goalId,
                              onSelect: (goal) => _selectGoal(
                                goal,
                                showSheet: !showDetails,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _GoalProgressCanvas(
                              goal: selected,
                              criteria: widget.provider.criteriaForGoal(
                                selected.goalId,
                              ),
                              onOpen: () => widget.onOpenGoal(selected),
                            ),
                          ),
                          if (showDetails)
                            NeoWorkspacePanel(
                              width: 320,
                              borderStart: true,
                              child: _GoalDetailsPanel(
                                goal: selected,
                                criteria: widget.provider.criteriaForGoal(
                                  selected.goalId,
                                ),
                                onOpen: () => widget.onOpenGoal(selected),
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

class GoalsMetricsBar extends StatelessWidget {
  const GoalsMetricsBar({super.key, required this.goals, required this.provider});

  final List<Goal> goals;
  final GoalProvider provider;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    bool complete(Goal goal) {
      final progress = provider.progressForGoal(goal.goalId);
      return progress.total > 0 && progress.completed == progress.total;
    }

    final completed = goals.where(complete).length;
    final active = goals
        .where(
          (goal) =>
              !complete(goal) &&
              !goal.startDate.isAfter(now) &&
              !goal.endDate.isBefore(now),
        )
        .length;
    final late = goals
        .where((goal) => goal.endDate.isBefore(now) && !complete(goal))
        .length;
    final criteriaCount = goals.fold<int>(
      0,
      (sum, goal) => sum + provider.criteriaForGoal(goal.goalId).length,
    );

    return NeoWorkspaceMetricsBar(
      items: [
        NeoWorkspaceMetric(
          label: 'إجمالي الأهداف',
          value: '${goals.length}',
          icon: Icons.flag_outlined,
          color: const Color(0xFF1F6FD2),
        ),
        NeoWorkspaceMetric(
          label: 'نشطة',
          value: '$active',
          icon: Icons.play_circle_outline_rounded,
          color: AppColors.mintAccent,
        ),
        NeoWorkspaceMetric(
          label: 'مكتملة',
          value: '$completed',
          icon: Icons.task_alt_rounded,
          color: AppColors.gold,
        ),
        NeoWorkspaceMetric(
          label: 'إجمالي المعايير',
          value: '$criteriaCount',
          icon: Icons.checklist_rtl_rounded,
          color: const Color(0xFF7656C8),
        ),
        NeoWorkspaceMetric(
          label: 'متأخرة',
          value: '$late',
          icon: Icons.schedule_rounded,
          color: AppColors.overdue,
        ),
      ],
    );
  }
}

class _GoalsToolbar extends StatelessWidget {
  const _GoalsToolbar({
    required this.filter,
    required this.visibleCount,
    required this.onFilterChanged,
  });

  final _GoalFilter filter;
  final int visibleCount;
  final ValueChanged<_GoalFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox(
            width: 230,
            child: NeoSelectionField<_GoalFilter>(
              label: 'تصفية الأهداف',
              value: filter,
              options: const [
                NeoSelectionOption(
                  value: _GoalFilter.all,
                  label: 'الكل',
                  icon: Icons.dashboard_outlined,
                ),
                NeoSelectionOption(
                  value: _GoalFilter.active,
                  label: 'نشطة',
                  icon: Icons.play_circle_outline,
                ),
                NeoSelectionOption(
                  value: _GoalFilter.completed,
                  label: 'مكتملة',
                  icon: Icons.task_alt_outlined,
                ),
                NeoSelectionOption(
                  value: _GoalFilter.late,
                  label: 'متأخرة',
                  icon: Icons.schedule_outlined,
                ),
              ],
              onChanged: onFilterChanged,
            ),
          ),
          const Spacer(),
          Text(
            '$visibleCount هدف في العرض',
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

class _GoalListPanel extends StatelessWidget {
  const _GoalListPanel({
    required this.goals,
    required this.provider,
    required this.selectedGoalId,
    required this.onSelect,
  });

  final List<Goal> goals;
  final GoalProvider provider;
  final String selectedGoalId;
  final ValueChanged<Goal> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NeoWorkspaceSectionHeader(
          title: 'محفظة الأهداف',
          subtitle: 'اختر هدفًا لاستعراض تقدمه ومعاييره',
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: goals.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _GoalListCard(
              goal: goals[index],
              provider: provider,
              selected: goals[index].goalId == selectedGoalId,
              onTap: () => onSelect(goals[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalListCard extends StatelessWidget {
  const _GoalListCard({
    required this.goal,
    required this.provider,
    required this.selected,
    required this.onTap,
  });

  final Goal goal;
  final GoalProvider provider;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = provider.progressForGoal(goal.goalId);
    final percent = progress.total == 0
        ? 0
        : ((progress.completed / progress.total) * 100).round();
    final color = goalColorFromName(goal.colorName);
    final late = goal.endDate.isBefore(DateTime.now()) && percent < 100;
    return Material(
      color: selected ? AppColors.deepBlue.withValues(alpha: .055) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: selected ? color : AppColors.divider,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(goalIconFromName(goal.iconName), color: color),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      goal.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: percent / 100,
                  minHeight: 7,
                  backgroundColor: color.withValues(alpha: .12),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  Text(
                    '${progress.completed}/${progress.total} معايير',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (late)
                    const Text(
                      'متأخر',
                      style: TextStyle(
                        color: AppColors.overdue,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    )
                  else
                    Text(
                      intl.DateFormat('yyyy/MM/dd').format(goal.endDate),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalProgressCanvas extends StatelessWidget {
  const _GoalProgressCanvas({
    required this.goal,
    required this.criteria,
    required this.onOpen,
  });

  final Goal goal;
  final List<Criterion> criteria;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final completed = criteria
        .where((criterion) => criterion.aggregateStatus == CriterionStatus.completed)
        .length;
    final percent = criteria.isEmpty ? 0 : ((completed / criteria.length) * 100).round();
    final color = goalColorFromName(goal.colorName);
    return ColoredBox(
      color: const Color(0xFFF8FAFD),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      goal.description.isEmpty ? 'لا يوجد وصف للهدف' : goal.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12.5,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 82,
                height: 82,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: percent / 100,
                      strokeWidth: 8,
                      backgroundColor: color.withValues(alpha: .12),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        color: color,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'مسار المعايير',
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (criteria.isEmpty)
            const NeoWorkspaceEmptyState(
              icon: Icons.rule_outlined,
              title: 'لا توجد معايير بعد',
              message: 'افتح الهدف لإضافة معايير قابلة للقياس والتوزيع.',
            )
          else
            ...criteria.map(
              (criterion) => _CriterionProgressTile(criterion: criterion),
            ),
          const SizedBox(height: 16),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('فتح الهدف وإدارة المعايير'),
            ),
          ),
        ],
      ),
    );
  }
}

class _CriterionProgressTile extends StatelessWidget {
  const _CriterionProgressTile({required this.criterion});

  final Criterion criterion;

  @override
  Widget build(BuildContext context) {
    final status = criterion.aggregateStatus;
    final ratio = criterion.completionRatio;
    final color = switch (status) {
      CriterionStatus.completed => AppColors.mintAccent,
      CriterionStatus.inProgress => AppColors.gold,
      CriterionStatus.notStarted => AppColors.textSecondary,
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Icon(
            status == CriterionStatus.completed
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  criterion.title,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                ),
                const SizedBox(height: 4),
                Text(
                  '${criterionStatusLabelAr(status)} · ${ratio.completed} من ${ratio.total} مكتمل',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11.5,
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

class _GoalDetailsPanel extends StatelessWidget {
  const _GoalDetailsPanel({
    required this.goal,
    required this.criteria,
    required this.onOpen,
  });

  final Goal goal;
  final List<Criterion> criteria;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final completed = criteria
        .where((criterion) => criterion.aggregateStatus == CriterionStatus.completed)
        .length;
    final days = goal.endDate.difference(DateTime.now()).inDays;
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'تفاصيل الهدف',
          style: TextStyle(
            color: AppColors.deepBlue,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        _DetailLine(
          icon: Icons.calendar_today_outlined,
          label: 'الفترة',
          value:
              '${intl.DateFormat('yyyy/MM/dd').format(goal.startDate)} — ${intl.DateFormat('yyyy/MM/dd').format(goal.endDate)}',
        ),
        _DetailLine(
          icon: Icons.timelapse_rounded,
          label: 'الوقت المتبقي',
          value: days < 0 ? 'متأخر ${days.abs()} يوم' : '$days يوم',
          valueColor: days < 0 ? AppColors.overdue : null,
        ),
        _DetailLine(
          icon: Icons.rule_outlined,
          label: 'المعايير',
          value: '$completed من ${criteria.length} مكتمل',
        ),
        _DetailLine(
          icon: Icons.comment_outlined,
          label: 'التعليقات',
          value: '${goal.comments.length}',
        ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('فتح التفاصيل'),
        ),
      ],
    );
  }
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({
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
                    height: 1.4,
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

class _MobileGoalsView extends StatelessWidget {
  const _MobileGoalsView({
    required this.goals,
    required this.provider,
    required this.filter,
    required this.onFilterChanged,
    required this.onSelect,
  });

  final List<Goal> goals;
  final GoalProvider provider;
  final _GoalFilter filter;
  final ValueChanged<_GoalFilter> onFilterChanged;
  final ValueChanged<Goal> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GoalsToolbar(
          filter: filter,
          visibleCount: goals.length,
          onFilterChanged: onFilterChanged,
        ),
        Expanded(
          child: goals.isEmpty
              ? const NeoWorkspaceEmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'لا توجد أهداف ضمن هذا العرض',
                  message: 'غيّر عامل التصفية لعرض بقية الأهداف.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                  itemCount: goals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (context, index) => _GoalListCard(
                    goal: goals[index],
                    provider: provider,
                    selected: false,
                    onTap: () => onSelect(goals[index]),
                  ),
                ),
        ),
      ],
    );
  }
}
