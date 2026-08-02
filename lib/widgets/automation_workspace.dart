import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:intl/intl.dart' as intl;

import '../models/automation_rule_model.dart';
import '../theme/app_theme.dart';
import 'neo_selection_field.dart';
import 'user_avatar.dart';

enum _RuleFilter { all, active, paused }

enum _RunFilter { all, completed, failed }

class AutomationMetricsBar extends StatelessWidget {
  const AutomationMetricsBar({
    super.key,
    required this.rules,
    required this.runs,
  });

  final List<AutomationRule> rules;
  final List<AutomationRun> runs;

  @override
  Widget build(BuildContext context) {
    final active = rules.where((rule) => rule.isActive).length;
    final now = DateTime.now();
    final completedToday = runs.where((run) {
      final executed = run.executedAt.toLocal();
      return run.status == 'completed' &&
          executed.year == now.year &&
          executed.month == now.month &&
          executed.day == now.day;
    }).length;
    final failed = runs.where((run) => run.status != 'completed').length;
    final items = [
      _AutomationMetric(
        label: 'إجمالي القواعد',
        value: '${rules.length}',
        icon: Icons.account_tree_outlined,
        color: const Color(0xFF1F6FD2),
      ),
      _AutomationMetric(
        label: 'نشطة',
        value: '$active',
        icon: Icons.play_circle_outline_rounded,
        color: AppColors.mintAccent,
      ),
      _AutomationMetric(
        label: 'نُفذت اليوم',
        value: '$completedToday',
        icon: Icons.timeline_rounded,
        color: AppColors.gold,
      ),
      _AutomationMetric(
        label: 'تحتاج مراجعة',
        value: '$failed',
        icon: Icons.error_outline_rounded,
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
          textDirection: Directionality.of(context),
          children: [
            for (var index = 0; index < items.length; index++) ...[
              _AutomationMetricView(data: items[index]),
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

class AutomationRulesWorkspace extends StatefulWidget {
  const AutomationRulesWorkspace({
    super.key,
    required this.rules,
    required this.runs,
    required this.readOnly,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onToggle,
    this.resolveUserName,
    this.resolveUserPhotoUrl,
  });

  final List<AutomationRule> rules;
  final List<AutomationRun> runs;
  final bool readOnly;
  final ValueChanged<AutomationRule> onEdit;
  final ValueChanged<AutomationRule> onDuplicate;
  final ValueChanged<AutomationRule> onDelete;
  final void Function(AutomationRule rule, bool active) onToggle;
  final String? Function(String uid)? resolveUserName;
  final String? Function(String uid)? resolveUserPhotoUrl;

  @override
  State<AutomationRulesWorkspace> createState() =>
      _AutomationRulesWorkspaceState();
}

class _AutomationRulesWorkspaceState extends State<AutomationRulesWorkspace> {
  String? _selectedRuleId;
  _RuleFilter _filter = _RuleFilter.all;

  List<AutomationRule> get _visibleRules => switch (_filter) {
    _RuleFilter.all => widget.rules,
    _RuleFilter.active => widget.rules.where((rule) => rule.isActive).toList(),
    _RuleFilter.paused => widget.rules.where((rule) => !rule.isActive).toList(),
  };

  AutomationRule? get _selectedRule {
    final rules = _visibleRules;
    if (rules.isEmpty) return null;
    for (final rule in rules) {
      if (rule.ruleId == _selectedRuleId) return rule;
    }
    return rules.first;
  }

  List<AutomationRun> _runsFor(AutomationRule rule) => widget.runs
      .where((run) => run.ruleId == rule.ruleId)
      .toList();

  void _selectRule(AutomationRule rule, {required bool showSheet}) {
    setState(() => _selectedRuleId = rule.ruleId);
    if (!showSheet) return;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .82,
        child: _AutomationDetailsPanel(
          rule: rule,
          runs: _runsFor(rule),
          readOnly: widget.readOnly,
          resolveUserName: widget.resolveUserName,
          resolveUserPhotoUrl: widget.resolveUserPhotoUrl,
          onEdit: () {
            Navigator.pop(sheetContext);
            widget.onEdit(rule);
          },
          onDelete: () {
            Navigator.pop(sheetContext);
            widget.onDelete(rule);
          },
          onDuplicate: () {
            Navigator.pop(sheetContext);
            widget.onDuplicate(rule);
          },
          onToggle: (active) => widget.onToggle(rule, active),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.rules.isEmpty) {
      return const _AutomationEmptyState(
        icon: Icons.account_tree_outlined,
        title: 'مساحة الأتمتة جاهزة لأول قاعدة',
        message: 'أنشئ قاعدة تربط حدثًا بشرط وإجراء ليعمل NeoTask تلقائيًا.',
      );
    }

    final visibleRules = _visibleRules;
    final selected = _selectedRule;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return _MobileAutomationView(
            rules: visibleRules,
            filter: _filter,
            onFilterChanged: (value) => setState(() => _filter = value),
            onSelect: (rule) => _selectRule(rule, showSheet: true),
            readOnly: widget.readOnly,
            onToggle: widget.onToggle,
            resolveUserName: widget.resolveUserName,
            runs: widget.runs,
          );
        }

        final showDetails = constraints.maxWidth >= 1180;
        return Column(
          children: [
            _AutomationToolbar(
              filter: _filter,
              visibleCount: visibleRules.length,
              onFilterChanged: (value) => setState(() => _filter = value),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: visibleRules.isEmpty || selected == null
                    ? const _AutomationEmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'لا توجد قواعد ضمن هذا العرض',
                        message: 'غيّر عامل التصفية لعرض بقية قواعد الأتمتة.',
                      )
                    : Row(
                        textDirection: Directionality.of(context),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: showDetails ? 410 : 370,
                            child: _AutomationRuleListPanel(
                              rules: visibleRules,
                              selectedRuleId: selected.ruleId,
                              readOnly: widget.readOnly,
                              onSelect: (rule) => _selectRule(
                                rule,
                                showSheet: !showDetails,
                              ),
                              onToggle: widget.onToggle,
                              runs: widget.runs,
                            ),
                          ),
                          Expanded(
                            child: _AutomationFlowCanvas(
                              rule: selected,
                              runs: _runsFor(selected),
                              resolveUserName: widget.resolveUserName,
                            ),
                          ),
                          if (showDetails)
                            SizedBox(
                              width: 320,
                              child: _AutomationDetailsPanel(
                                rule: selected,
                                runs: _runsFor(selected),
                                readOnly: widget.readOnly,
                                resolveUserName: widget.resolveUserName,
                                resolveUserPhotoUrl:
                                    widget.resolveUserPhotoUrl,
                                onEdit: () => widget.onEdit(selected),
                                onDuplicate: () =>
                                    widget.onDuplicate(selected),
                                onDelete: () => widget.onDelete(selected),
                                onToggle: (active) =>
                                    widget.onToggle(selected, active),
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

class AutomationRunLog extends StatefulWidget {
  const AutomationRunLog({super.key, required this.runs});

  final List<AutomationRun> runs;

  @override
  State<AutomationRunLog> createState() => _AutomationRunLogState();
}

class _AutomationRunLogState extends State<AutomationRunLog> {
  _RunFilter _filter = _RunFilter.all;

  @override
  Widget build(BuildContext context) {
    final visible = switch (_filter) {
      _RunFilter.all => widget.runs,
      _RunFilter.completed => widget.runs
          .where((run) => run.status == 'completed')
          .toList(),
      _RunFilter.failed => widget.runs
          .where((run) => run.status != 'completed')
          .toList(),
    };

    return Column(
      children: [
        Container(
          color: const Color(0xFFF9FAFC),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            textDirection: Directionality.of(context),
            children: [
              const Expanded(
                child: Text(
                  'سجل التنفيذ',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              SizedBox(
                width: 165,
                child: NeoSelectionField<_RunFilter>(
                  label: 'النتيجة',
                  value: _filter,
                  options: const [
                    NeoSelectionOption(
                      value: _RunFilter.all,
                      label: 'كل العمليات',
                      icon: Icons.receipt_long_outlined,
                    ),
                    NeoSelectionOption(
                      value: _RunFilter.completed,
                      label: 'ناجحة',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.statusApproved,
                    ),
                    NeoSelectionOption(
                      value: _RunFilter.failed,
                      label: 'متعثرة',
                      icon: Icons.error_outline_rounded,
                      color: AppColors.overdue,
                    ),
                  ],
                  onChanged: (value) => setState(() => _filter = value),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: visible.isEmpty
              ? const _AutomationEmptyState(
                  icon: Icons.history_toggle_off_outlined,
                  title: 'لا توجد عمليات ضمن هذا العرض',
                  message: 'تظهر هنا نتائج تشغيل القواعد مع المهمة والتوقيت.',
                )
              : Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                      itemCount: visible.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 9),
                      itemBuilder: (context, index) =>
                          _AutomationRunCard(run: visible[index]),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _AutomationToolbar extends StatelessWidget {
  const _AutomationToolbar({
    required this.filter,
    required this.visibleCount,
    required this.onFilterChanged,
  });

  final _RuleFilter filter;
  final int visibleCount;
  final ValueChanged<_RuleFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFF9FAFC),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: Row(
      textDirection: Directionality.of(context),
      children: [
        const Text(
          'مسار الأتمتة',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: AppColors.deepBlue.withValues(alpha: .08),
            borderRadius: BorderRadius.circular(AppRadius.pill),
          ),
          child: Text(
            '$visibleCount قاعدة',
            style: const TextStyle(
              color: AppColors.deepBlue,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: 154,
          child: NeoSelectionField<_RuleFilter>(
            label: 'العرض',
            value: filter,
            options: const [
              NeoSelectionOption(
                value: _RuleFilter.all,
                label: 'كل القواعد',
                icon: Icons.account_tree_outlined,
              ),
              NeoSelectionOption(
                value: _RuleFilter.active,
                label: 'النشطة',
                icon: Icons.play_circle_outline_rounded,
                color: AppColors.statusApproved,
              ),
              NeoSelectionOption(
                value: _RuleFilter.paused,
                label: 'المتوقفة',
                icon: Icons.pause_circle_outline_rounded,
                color: AppColors.textSecondary,
              ),
            ],
            onChanged: onFilterChanged,
          ),
        ),
      ],
    ),
  );
}

class _AutomationRuleListPanel extends StatelessWidget {
  const _AutomationRuleListPanel({
    required this.rules,
    required this.selectedRuleId,
    required this.readOnly,
    required this.onSelect,
    required this.onToggle,
    required this.runs,
  });

  final List<AutomationRule> rules;
  final String selectedRuleId;
  final bool readOnly;
  final ValueChanged<AutomationRule> onSelect;
  final void Function(AutomationRule rule, bool active) onToggle;
  final List<AutomationRun> runs;

  @override
  Widget build(BuildContext context) {
    final active = rules.where((rule) => rule.isActive).toList();
    final paused = rules.where((rule) => !rule.isActive).toList();
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(left: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        children: [
          Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Color(0xFFFAFBFD),
              border: Border(bottom: BorderSide(color: AppColors.divider)),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.account_tree_outlined,
                  size: 19,
                  color: AppColors.deepBlue,
                ),
                SizedBox(width: 8),
                Text(
                  'قواعد الأتمتة',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (active.isNotEmpty) ...[
                  _RuleGroupHeader(
                    index: 1,
                    label: 'نشطة',
                    count: active.length,
                    color: AppColors.mintAccent,
                  ),
                  ...active.map(_buildRow),
                ],
                if (paused.isNotEmpty) ...[
                  _RuleGroupHeader(
                    index: active.isEmpty ? 1 : 2,
                    label: 'متوقفة',
                    count: paused.length,
                    color: AppColors.overdue,
                  ),
                  ...paused.map(_buildRow),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(AutomationRule rule) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: _AutomationRuleRow(
        rule: rule,
        latestRun: _latestRunFor(rule, runs),
        selected: rule.ruleId == selectedRuleId,
        readOnly: readOnly,
        onTap: () => onSelect(rule),
        onToggle: (active) => onToggle(rule, active),
      ),
    );
  }
}

class _RuleGroupHeader extends StatelessWidget {
  const _RuleGroupHeader({
    required this.index,
    required this.label,
    required this.count,
    required this.color,
  });

  final int index;
  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    height: 48,
    padding: const EdgeInsets.symmetric(horizontal: 16),
    color: const Color(0xFFFAFBFD),
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$index. $label',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ),
        Text('$count', style: AppTextStyles.bodySecondary),
      ],
    ),
  );
}

class _AutomationRuleRow extends StatelessWidget {
  const _AutomationRuleRow({
    required this.rule,
    required this.latestRun,
    required this.selected,
    required this.readOnly,
    required this.onTap,
    required this.onToggle,
  });

  final AutomationRule rule;
  final AutomationRun? latestRun;
  final bool selected;
  final bool readOnly;
  final VoidCallback onTap;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? AppColors.deepBlue.withValues(alpha: .055)
        : Colors.white,
    child: InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 84),
        padding: const EdgeInsets.fromLTRB(14, 11, 12, 11),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(
              color: selected ? AppColors.mintAccent : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: (rule.isActive ? AppColors.mintAccent : AppColors.textSecondary)
                    .withValues(alpha: .11),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                rule.isActive
                    ? Icons.bolt_rounded
                    : Icons.pause_rounded,
                color: rule.isActive
                    ? AppColors.deepBlue
                    : AppColors.textSecondary,
                size: 21,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rule.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.cardTitle,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    latestRun == null
                        ? (rule.isActive ? 'بانتظار أول تنفيذ' : 'لم تُنفذ بعد')
                        : '${latestRun!.status == 'completed' ? 'تم التنفيذ' : 'تحتاج مراجعة'} • ${_relativeTime(latestRun!.executedAt)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: latestRun?.status == 'completed'
                          ? AppColors.statusApproved
                          : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Switch.adaptive(
              value: rule.isActive,
              onChanged: readOnly ? null : onToggle,
            ),
          ],
        ),
      ),
    ),
  );
}

class _AutomationFlowCanvas extends StatelessWidget {
  const _AutomationFlowCanvas({
    required this.rule,
    required this.runs,
    required this.resolveUserName,
  });

  final AutomationRule rule;
  final List<AutomationRun> runs;
  final String? Function(String uid)? resolveUserName;

  @override
  Widget build(BuildContext context) {
    final latest = runs.isEmpty ? null : runs.first;
    final completed = latest?.status == 'completed';
    return Container(
      color: Colors.white,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(22, 18, 22, 20),
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'مسار القاعدة',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                latest == null ? 'بانتظار التنفيذ' : _relativeTime(latest.executedAt),
                style: AppTextStyles.bodySecondary,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'اليوم',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: rule.isActive
                  ? AppColors.mintAccent
                  : AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 310),
              child: Column(
                children: [
                  _FlowNode(
                    eyebrow: 'عند حدوث',
                    title: _triggerLabel(rule.trigger),
                    subtitle: rule.trigger == AutomationTrigger.dueSoon
                        ? 'قبل الموعد بـ ${rule.dueWithinHours} ساعة'
                        : 'مشغّل القاعدة',
                    icon: Icons.bolt_rounded,
                    color: AppColors.deepBlue,
                    completed: completed,
                  ),
                  const _VerticalFlowArrow(),
                  _FlowNode(
                    eyebrow: 'إذا تحقق',
                    title: _conditionTitle(rule),
                    subtitle: _conditionSummary(rule, resolveUserName),
                    icon: Icons.filter_alt_outlined,
                    color: AppColors.gold,
                    completed: completed,
                  ),
                  const _VerticalFlowArrow(),
                  _FlowNode(
                    eyebrow: 'نفّذ',
                    title: _actionLabel(rule.action.name),
                    subtitle: _actionSummary(rule, resolveUserName),
                    icon: Icons.notifications_none_rounded,
                    color: AppColors.deepBlue,
                    completed: completed,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: (latest == null
                        ? AppColors.textSecondary
                        : completed
                        ? AppColors.statusApproved
                        : AppColors.overdue)
                    .withValues(alpha: .08),
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(
                  color: (latest == null
                          ? AppColors.textSecondary
                          : completed
                          ? AppColors.statusApproved
                          : AppColors.overdue)
                      .withValues(alpha: .30),
                ),
              ),
              child: Text(
                latest == null
                    ? 'لم تُنفذ بعد'
                    : completed
                    ? 'تم التنفيذ بنجاح'
                    : 'التنفيذ يحتاج مراجعة',
                style: TextStyle(
                  color: latest == null
                      ? AppColors.textSecondary
                      : completed
                      ? AppColors.statusApproved
                      : AppColors.overdue,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Divider(height: 1),
          const SizedBox(height: 14),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 22,
            runSpacing: 8,
            children: [
              _FlowLegend(color: AppColors.deepBlue, label: 'مشغّل'),
              _FlowLegend(color: AppColors.gold, label: 'شرط'),
              _FlowLegend(color: AppColors.deepBlue, label: 'إجراء'),
              _FlowLegend(color: AppColors.mintAccent, label: 'تم التنفيذ'),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowNode extends StatelessWidget {
  const _FlowNode({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.completed,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool completed;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 92),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(AppRadius.md),
      boxShadow: AppElevation.lowShadow,
    ),
    child: Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Icon(
          completed ? Icons.check_circle_outline_rounded : Icons.circle_outlined,
          color: completed ? AppColors.mintAccent : Colors.white54,
          size: 20,
        ),
      ],
    ),
  );
}

class _VerticalFlowArrow extends StatelessWidget {
  const _VerticalFlowArrow();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Icon(
      Icons.arrow_downward_rounded,
      color: AppColors.textSecondary,
      size: 22,
    ),
  );
}

class _FlowLegend extends StatelessWidget {
  const _FlowLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 6),
      Text(label, style: AppTextStyles.bodySecondary),
    ],
  );
}

class _AutomationDetailsPanel extends StatefulWidget {
  const _AutomationDetailsPanel({
    required this.rule,
    required this.runs,
    required this.readOnly,
    required this.onEdit,
    required this.onDuplicate,
    required this.onDelete,
    required this.onToggle,
    required this.resolveUserName,
    required this.resolveUserPhotoUrl,
  });

  final AutomationRule rule;
  final List<AutomationRun> runs;
  final bool readOnly;
  final VoidCallback onEdit;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;
  final String? Function(String uid)? resolveUserName;
  final String? Function(String uid)? resolveUserPhotoUrl;

  @override
  State<_AutomationDetailsPanel> createState() =>
      _AutomationDetailsPanelState();
}

class _AutomationDetailsPanelState extends State<_AutomationDetailsPanel> {
  late bool _active;

  @override
  void initState() {
    super.initState();
    _active = widget.rule.isActive;
  }

  @override
  void didUpdateWidget(covariant _AutomationDetailsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rule.ruleId != widget.rule.ruleId ||
        oldWidget.rule.isActive != widget.rule.isActive) {
      _active = widget.rule.isActive;
    }
  }

  @override
  Widget build(BuildContext context) {
    final rule = widget.rule;
    final runs = widget.runs;
    final completed = runs.where((run) => run.status == 'completed').length;
    final latest = runs.isEmpty ? null : runs.first;
    final creatorName =
        widget.resolveUserName?.call(rule.createdBy) ?? 'مدير النظام';
    final successRate = runs.isEmpty ? 0 : (completed * 100 / runs.length).round();
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
                  'تفاصيل القاعدة',
                  style: TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (!widget.readOnly)
                IconButton(
                  tooltip: context.tr('تعديل القاعدة'),
                  onPressed: widget.onEdit,
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
                  color: _active
                      ? AppColors.mintAccent
                      : AppColors.textSecondary,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  rule.name,
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FA),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _active ? 'القاعدة تعمل الآن' : 'القاعدة متوقفة',
                    style: AppTextStyles.bodySecondary,
                  ),
                ),
                Switch.adaptive(
                  value: _active,
                  onChanged: widget.readOnly
                      ? null
                      : (active) {
                          setState(() => _active = active);
                          widget.onToggle(active);
                        },
                ),
              ],
            ),
          ),
          const Divider(height: 30),
          const _DetailLabel('المنشئ'),
          const SizedBox(height: 9),
          Row(
            children: [
              UserAvatar(
                name: creatorName,
                imageUrl: widget.resolveUserPhotoUrl?.call(rule.createdBy),
                radius: 21,
                borderColor: AppColors.mintAccent,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(creatorName, style: AppTextStyles.cardTitle),
                    const Text('منشئ القاعدة', style: AppTextStyles.bodySecondary),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 30),
          const _DetailLabel('المسار'),
          const SizedBox(height: 10),
          _DetailLine(
            icon: Icons.bolt_outlined,
            label: 'الحدث',
            value: _triggerLabel(rule.trigger),
          ),
          _DetailLine(
            icon: Icons.rule_outlined,
            label: 'الشرط',
            value: _conditionSummary(rule, widget.resolveUserName),
          ),
          _DetailLine(
            icon: Icons.play_circle_outline_rounded,
            label: 'الإجراء',
            value: _actionSummary(rule, widget.resolveUserName),
          ),
          const Divider(height: 30),
          const _DetailLabel('الأداء'),
          const SizedBox(height: 10),
          _DetailLine(
            icon: Icons.history_rounded,
            label: 'مرات التنفيذ',
            value: '${runs.length}',
          ),
          _DetailLine(
            icon: Icons.check_circle_outline_rounded,
            label: 'عمليات ناجحة',
            value: '$completed',
          ),
          _DetailLine(
            icon: Icons.error_outline_rounded,
            label: 'عمليات متعثرة',
            value: '${runs.length - completed}',
          ),
          _DetailLine(
            icon: Icons.track_changes_rounded,
            label: 'معدل النجاح',
            value: '$successRate%',
          ),
          if (latest != null)
            _DetailLine(
              icon: Icons.schedule_outlined,
              label: 'آخر تنفيذ',
              value: _formatDate(latest.executedAt),
            ),
          const Divider(height: 30),
          const _DetailLabel('آخر تحديث'),
          const SizedBox(height: 8),
          Text(_formatDate(rule.updatedAt), style: AppTextStyles.bodySecondary),
          if (latest != null) ...[
            const Divider(height: 30),
            const _DetailLabel('النشاط الأخير'),
            const SizedBox(height: 9),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: latest.status == 'completed'
                    ? AppColors.mintAccent.withValues(alpha: .08)
                    : AppColors.overdue.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                children: [
                  Icon(
                    latest.status == 'completed'
                        ? Icons.check_circle_rounded
                        : Icons.error_outline_rounded,
                    color: latest.status == 'completed'
                        ? AppColors.statusApproved
                        : AppColors.overdue,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      latest.status == 'completed'
                          ? 'نجح التنفيذ • ${_relativeTime(latest.executedAt)}'
                          : 'التنفيذ يحتاج مراجعة • ${_relativeTime(latest.executedAt)}',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (!widget.readOnly) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      final active = !_active;
                      setState(() => _active = active);
                      widget.onToggle(active);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _active
                          ? AppColors.statusRejected
                          : AppColors.statusApproved,
                    ),
                    icon: Icon(
                      _active ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      size: 17,
                    ),
                    label: Text(_active ? 'إيقاف' : 'تشغيل'),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onDuplicate,
                    icon: const Icon(Icons.copy_all_outlined, size: 17),
                    label: const Text('تكرار'),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.onEdit,
                    icon: const Icon(Icons.edit_outlined, size: 17),
                    label: const Text('تعديل'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: widget.onDelete,
              style: TextButton.styleFrom(
                foregroundColor: AppColors.statusRejected,
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              label: const Text('حذف القاعدة'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MobileAutomationView extends StatelessWidget {
  const _MobileAutomationView({
    required this.rules,
    required this.filter,
    required this.onFilterChanged,
    required this.onSelect,
    required this.readOnly,
    required this.onToggle,
    required this.resolveUserName,
    required this.runs,
  });

  final List<AutomationRule> rules;
  final _RuleFilter filter;
  final ValueChanged<_RuleFilter> onFilterChanged;
  final ValueChanged<AutomationRule> onSelect;
  final bool readOnly;
  final void Function(AutomationRule rule, bool active) onToggle;
  final String? Function(String uid)? resolveUserName;
  final List<AutomationRun> runs;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _AutomationToolbar(
        filter: filter,
        visibleCount: rules.length,
        onFilterChanged: onFilterChanged,
      ),
      const Divider(height: 1),
      Expanded(
        child: rules.isEmpty
            ? const _AutomationEmptyState(
                icon: Icons.filter_alt_off_outlined,
                title: 'لا توجد قواعد ضمن هذا العرض',
                message: 'غيّر عامل التصفية لعرض بقية قواعد الأتمتة.',
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                itemCount: rules.length,
                itemBuilder: (context, index) {
                  final rule = rules[index];
                  final latest = _latestRunFor(rule, runs);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    elevation: AppElevation.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      side: const BorderSide(color: AppColors.divider),
                    ),
                    child: InkWell(
                      onTap: () => onSelect(rule),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: rule.isActive
                                        ? AppColors.mintAccent
                                        : AppColors.textSecondary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    rule.name,
                                    style: AppTextStyles.cardTitle,
                                  ),
                                ),
                                Switch.adaptive(
                                  value: rule.isActive,
                                  onChanged: readOnly
                                      ? null
                                      : (active) => onToggle(rule, active),
                                ),
                                const Icon(
                                  Icons.chevron_left_rounded,
                                  color: AppColors.textSecondary,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _MobileFlowSummary(
                              rule: rule,
                              resolveUserName: resolveUserName,
                            ),
                            const SizedBox(height: 9),
                            Row(
                              children: [
                                Icon(
                                  latest?.status == 'completed'
                                      ? Icons.check_circle_outline_rounded
                                      : latest == null
                                      ? Icons.schedule_outlined
                                      : Icons.error_outline_rounded,
                                  size: 17,
                                  color: latest?.status == 'completed'
                                      ? AppColors.statusApproved
                                      : latest == null
                                      ? AppColors.textSecondary
                                      : AppColors.overdue,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    latest == null
                                        ? 'بانتظار أول تنفيذ'
                                        : '${latest.status == 'completed' ? 'تم التنفيذ' : 'تحتاج مراجعة'} • ${_relativeTime(latest.executedAt)}',
                                    style: AppTextStyles.bodySecondary,
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
              ),
      ),
    ],
  );
}

class _MobileFlowSummary extends StatelessWidget {
  const _MobileFlowSummary({
    required this.rule,
    required this.resolveUserName,
  });

  final AutomationRule rule;
  final String? Function(String uid)? resolveUserName;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(AppRadius.md),
    ),
    child: Row(
      textDirection: Directionality.of(context),
      children: [
        Expanded(
          child: Text(
            _triggerLabel(rule.trigger),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        const Icon(
          Icons.arrow_back_rounded,
          size: 16,
          color: AppColors.textSecondary,
        ),
        Expanded(
          child: Text(
            _conditionTitle(rule),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
        const Icon(
          Icons.arrow_back_rounded,
          size: 16,
          color: AppColors.textSecondary,
        ),
        Expanded(
          child: Text(
            _actionSummary(rule, resolveUserName),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _AutomationRunCard extends StatelessWidget {
  const _AutomationRunCard({required this.run});

  final AutomationRun run;

  @override
  Widget build(BuildContext context) {
    final completed = run.status == 'completed';
    final color = completed ? AppColors.statusApproved : AppColors.overdue;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              completed
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: color,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  run.ruleName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.cardTitle,
                ),
                const SizedBox(height: 4),
                Text(
                  '${run.taskTitle} • ${_actionLabel(run.action)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySecondary,
                ),
                if ((run.message ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(run.message!, style: AppTextStyles.bodySecondary),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                completed ? 'ناجح' : 'متعثر',
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(_formatDate(run.executedAt), style: AppTextStyles.bodySecondary),
            ],
          ),
        ],
      ),
    );
  }
}

class _AutomationMetric {
  const _AutomationMetric({
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

class _AutomationMetricView extends StatelessWidget {
  const _AutomationMetricView({required this.data});

  final _AutomationMetric data;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 174,
    child: Row(
      textDirection: Directionality.of(context),
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
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        SizedBox(
          width: 64,
          child: Text(label, style: AppTextStyles.bodySecondary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _AutomationEmptyState extends StatelessWidget {
  const _AutomationEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

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
            child: Icon(icon, color: AppColors.deepBlue, size: 34),
          ),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: AppTextStyles.titleMd),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary,
          ),
        ],
      ),
    ),
  );
}

String _triggerLabel(AutomationTrigger value) => switch (value) {
  AutomationTrigger.taskCreated => 'إنشاء مهمة',
  AutomationTrigger.statusChanged => 'تغيّر حالة المهمة',
  AutomationTrigger.dueSoon => 'اقتراب موعد الاستحقاق',
  AutomationTrigger.overdue => 'تأخر المهمة',
};

String _fieldLabel(AutomationConditionField value) => switch (value) {
  AutomationConditionField.any => 'بدون شرط إضافي',
  AutomationConditionField.status => 'حالة المهمة',
  AutomationConditionField.priority => 'الأولوية',
  AutomationConditionField.category => 'التصنيف',
  AutomationConditionField.assignee => 'الموظف المسؤول',
  AutomationConditionField.progress => 'نسبة الإنجاز',
};

String _operatorLabel(AutomationOperator value) => switch (value) {
  AutomationOperator.equals => 'يساوي',
  AutomationOperator.contains => 'يحتوي',
  AutomationOperator.greaterOrEqual => 'أكبر من أو يساوي',
};

String _actionLabel(String value) => switch (value) {
  'notifyAssignee' => 'إشعار الموظف',
  'notifyManager' => 'إشعار المدير',
  'setPriority' => 'تغيير الأولوية',
  'reassign' => 'إعادة إسناد المهمة',
  _ => value,
};

String _conditionTitle(AutomationRule rule) =>
    rule.conditionField == AutomationConditionField.any
    ? 'كل المهام'
    : _fieldLabel(rule.conditionField);

String _conditionSummary(
  AutomationRule rule,
  String? Function(String uid)? resolveUserName,
) {
  if (rule.conditionField == AutomationConditionField.any) {
    return 'يُطبق دون شرط إضافي';
  }
  final rawValue = rule.conditionValue;
  final value = rule.conditionField == AutomationConditionField.assignee
      ? (resolveUserName?.call(rawValue) ?? rawValue)
      : _conditionValueLabel(rawValue);
  return '${_operatorLabel(rule.conditionOperator)} $value';
}

String _actionSummary(
  AutomationRule rule,
  String? Function(String uid)? resolveUserName,
) {
  if (rule.action == AutomationAction.reassign) {
    return resolveUserName?.call(rule.actionValue) ?? 'إعادة إسناد المهمة';
  }
  if (rule.action == AutomationAction.setPriority) {
    return 'إلى ${_conditionValueLabel(rule.actionValue)}';
  }
  return rule.actionValue.trim().isEmpty
      ? _actionLabel(rule.action.name)
      : rule.actionValue.trim();
}

String _conditionValueLabel(String value) => switch (value) {
  'assigned' => 'قيد الانتظار',
  'inProgress' => 'قيد التنفيذ',
  'submitted' => 'بانتظار المراجعة',
  'approved' => 'مكتملة',
  'rejected' => 'مرفوضة',
  'editRequested' => 'مطلوب تعديلها',
  'low' => 'منخفضة',
  'medium' => 'متوسطة',
  'high' => 'عالية',
  _ => value,
};

String _formatDate(DateTime value) =>
    intl.DateFormat('yyyy/MM/dd • HH:mm').format(value.toLocal());

AutomationRun? _latestRunFor(
  AutomationRule rule,
  List<AutomationRun> runs,
) {
  AutomationRun? latest;
  for (final run in runs) {
    if (run.ruleId != rule.ruleId) continue;
    if (latest == null || run.executedAt.isAfter(latest.executedAt)) {
      latest = run;
    }
  }
  return latest;
}

String _relativeTime(DateTime value) {
  final difference = DateTime.now().difference(value.toLocal());
  if (difference.isNegative || difference.inMinutes < 1) return 'الآن';
  if (difference.inMinutes < 60) return 'منذ ${difference.inMinutes} دقيقة';
  if (difference.inHours < 24) return 'منذ ${difference.inHours} ساعة';
  return 'منذ ${difference.inDays} يوم';
}
