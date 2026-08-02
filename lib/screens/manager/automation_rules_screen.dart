import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/automation_rule_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/workflow_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/automation_workspace.dart';
import '../../widgets/neo_selection_field.dart';

class AutomationRulesScreen extends StatelessWidget {
  const AutomationRulesScreen({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          centerTitle: false,
          title: const Text(
            'الأتمتة',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
          actions: [
            if (!readOnly)
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: MediaQuery.sizeOf(context).width < 620
                    ? IconButton.filled(
                        tooltip: context.tr('قاعدة جديدة'),
                        onPressed: () => _openEditor(context),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.mintAccent,
                          foregroundColor: AppColors.navy,
                        ),
                        icon: const Icon(Icons.add_rounded),
                      )
                    : FilledButton.icon(
                        onPressed: () => _openEditor(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.mintAccent,
                          foregroundColor: AppColors.navy,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: const Text(
                          'قاعدة جديدة',
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
                    indicatorColor: AppColors.mintAccent,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicatorWeight: 3,
                    labelColor: AppColors.deepBlue,
                    unselectedLabelColor: AppColors.textSecondary,
                    labelStyle: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                    tabs: [
                      Tab(text: context.tr('مساحة القواعد')),
                      Tab(text: context.tr('سجل التنفيذ')),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        body: StreamBuilder<List<AutomationRule>>(
          stream: WorkflowService.watchAutomationRules(),
          builder: (context, rulesSnapshot) {
            final rules = rulesSnapshot.data ?? const <AutomationRule>[];
            return StreamBuilder<List<AutomationRun>>(
              stream: WorkflowService.watchAutomationRuns(),
              builder: (context, runsSnapshot) {
                final runs = runsSnapshot.data ?? const <AutomationRun>[];
                return Column(
                  children: [
                    AutomationMetricsBar(rules: rules, runs: runs),
                    Expanded(
                      child: TabBarView(
                        children: [
                          AutomationRulesWorkspace(
                            rules: rules,
                            runs: runs,
                            readOnly: readOnly,
                            resolveUserName: (uid) =>
                                FirestoreService.getUser(uid)?.name,
                            resolveUserPhotoUrl: (uid) =>
                                FirestoreService.getUser(uid)?.profilePhotoUrl,
                            onEdit: (rule) =>
                                _openEditor(context, existing: rule),
                            onDuplicate: (rule) =>
                                _duplicateRule(context, rule),
                            onDelete: (rule) =>
                                _confirmDelete(context, rule),
                            onToggle: (rule, active) => WorkflowService
                                .setAutomationRuleActive(rule, active),
                          ),
                          AutomationRunLog(runs: runs),
                        ],
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openEditor(
    BuildContext context, {
    AutomationRule? existing,
  }) async {
    final manager = context.read<AuthProvider>().currentUser!;
    final result = await showDialog<AutomationRule>(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          _AutomationEditor(existing: existing, managerUid: manager.uid),
    );
    if (result == null) return;
    await WorkflowService.saveAutomationRule(result);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حفظ قاعدة الأتمتة')));
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AutomationRule rule,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف قاعدة الأتمتة'),
        content: Text('سيتم حذف «${rule.name}» نهائيًا.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusRejected,
            ),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await WorkflowService.deleteAutomationRule(rule.ruleId);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف قاعدة الأتمتة')),
      );
    }
  }

  Future<void> _duplicateRule(
    BuildContext context,
    AutomationRule source,
  ) async {
    final now = DateTime.now();
    final manager = context.read<AuthProvider>().currentUser!;
    final copy = AutomationRule(
      ruleId: const Uuid().v4(),
      name: '${source.name} - نسخة',
      isActive: false,
      trigger: source.trigger,
      conditionField: source.conditionField,
      conditionOperator: source.conditionOperator,
      conditionValue: source.conditionValue,
      action: source.action,
      actionValue: source.actionValue,
      dueWithinHours: source.dueWithinHours,
      createdBy: manager.uid,
      createdAt: now,
      updatedAt: now,
    );
    await WorkflowService.saveAutomationRule(copy);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء نسخة متوقفة من القاعدة')),
      );
    }
  }
}

class _AutomationEditor extends StatefulWidget {
  const _AutomationEditor({required this.managerUid, this.existing});
  final String managerUid;
  final AutomationRule? existing;

  @override
  State<_AutomationEditor> createState() => _AutomationEditorState();
}

class _AutomationEditorState extends State<_AutomationEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _condition;
  late final TextEditingController _actionValue;
  late AutomationTrigger _trigger;
  late AutomationConditionField _field;
  late AutomationOperator _operator;
  late AutomationAction _action;
  late int _hours;

  @override
  void initState() {
    super.initState();
    final rule = widget.existing;
    _name = TextEditingController(text: rule?.name ?? '');
    _condition = TextEditingController(text: rule?.conditionValue ?? '');
    _actionValue = TextEditingController(text: rule?.actionValue ?? '');
    _trigger = rule?.trigger ?? AutomationTrigger.statusChanged;
    _field = rule?.conditionField ?? AutomationConditionField.status;
    _operator = rule?.conditionOperator ?? AutomationOperator.equals;
    _action = rule?.action ?? AutomationAction.notifyManager;
    _hours = rule?.dueWithinHours ?? 24;
  }

  @override
  void dispose() {
    _name.dispose();
    _condition.dispose();
    _actionValue.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final employees = FirestoreService.getAllEmployees()
        .where((u) => u.accountStatus == AccountStatus.active)
        .toList();
    return AlertDialog(
      title: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.mintAccent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(Icons.bolt_rounded, color: AppColors.deepBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              widget.existing == null
                  ? 'إنشاء قاعدة أتمتة'
                  : 'تعديل قاعدة الأتمتة',
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _EditorFlowPreview(
                  trigger: _trigger,
                  field: _field,
                  action: _action,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(labelText: context.tr('اسم القاعدة')),
                  validator: _required,
                ),
                const SizedBox(height: 12),
                NeoSelectionField<AutomationTrigger>(
                  label: 'عند حدوث',
                  value: _trigger,
                  options: AutomationTrigger.values
                      .map(
                        (value) => NeoSelectionOption(
                          value: value,
                          label: _triggerLabel(value),
                          icon: Icons.bolt_outlined,
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _trigger = value),
                ),
                if (_trigger == AutomationTrigger.dueSoon) ...[
                  const SizedBox(height: 12),
                  NeoSelectionField<int>(
                    label: 'قبل الاستحقاق بـ',
                    value: _hours,
                    options: const [1, 6, 12, 24, 48, 72]
                        .map(
                          (value) => NeoSelectionOption(
                            value: value,
                            label: '$value ساعة',
                            icon: Icons.schedule_outlined,
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _hours = value),
                  ),
                ],
                const SizedBox(height: 12),
                NeoSelectionField<AutomationConditionField>(
                  label: 'الشرط',
                  value: _field,
                  options: AutomationConditionField.values
                      .map(
                        (value) => NeoSelectionOption(
                          value: value,
                          label: _fieldLabel(value),
                          icon: Icons.rule_outlined,
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _field = value;
                    final allowed = _operatorsForField(_field);
                    if (!allowed.contains(_operator)) _operator = allowed.first;
                  }),
                ),
                if (_field != AutomationConditionField.any) ...[
                  const SizedBox(height: 12),
                  NeoSelectionField<AutomationOperator>(
                    label: 'المعامل',
                    value: _operator,
                    options: _operatorsForField(_field)
                        .map(
                          (value) => NeoSelectionOption(
                            value: value,
                            label: _operatorLabel(value),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _operator = value),
                  ),
                  const SizedBox(height: 12),
                  if (_field == AutomationConditionField.assignee)
                    NeoSelectionField<String>(
                      label: 'الموظف',
                      value: employees.any((e) => e.uid == _condition.text)
                          ? _condition.text
                          : null,
                      searchable: true,
                      options: employees
                          .map(
                            (employee) => NeoSelectionOption(
                              value: employee.uid,
                              label: employee.name,
                              subtitle:
                                  'الرقم الوظيفي ${employee.employeeNumber}',
                              icon: Icons.badge_outlined,
                              searchTerms: [employee.employeeNumber],
                            ),
                          )
                          .toList(),
                      onChanged: (value) => _condition.text = value,
                      validator: (value) =>
                          value == null ? context.tr('اختر الموظف') : null,
                    )
                  else if (_field == AutomationConditionField.status)
                    NeoSelectionField<String>(
                      label: 'حالة المهمة',
                      value:
                          const [
                            'assigned',
                            'inProgress',
                            'submitted',
                            'approved',
                            'rejected',
                            'editRequested',
                          ].contains(_condition.text)
                          ? _condition.text
                          : null,
                      options: const [
                        NeoSelectionOption(
                          value: 'assigned',
                          label: 'قيد الانتظار',
                          color: AppColors.statusPending,
                        ),
                        NeoSelectionOption(
                          value: 'inProgress',
                          label: 'قيد التنفيذ',
                          color: AppColors.statusInProgress,
                        ),
                        NeoSelectionOption(
                          value: 'submitted',
                          label: 'بانتظار المراجعة',
                          color: AppColors.statusSubmitted,
                        ),
                        NeoSelectionOption(
                          value: 'approved',
                          label: 'مكتملة',
                          color: AppColors.statusApproved,
                        ),
                        NeoSelectionOption(
                          value: 'rejected',
                          label: 'مرفوضة',
                          color: AppColors.statusRejected,
                        ),
                        NeoSelectionOption(
                          value: 'editRequested',
                          label: 'مطلوب تعديلها',
                          color: AppColors.overdue,
                        ),
                      ],
                      onChanged: (value) => _condition.text = value,
                      validator: (value) =>
                          value == null ? context.tr('اختر الحالة') : null,
                    )
                  else if (_field == AutomationConditionField.priority)
                    NeoSelectionField<String>(
                      label: 'الأولوية',
                      value:
                          const [
                            'low',
                            'medium',
                            'high',
                          ].contains(_condition.text)
                          ? _condition.text
                          : null,
                      options: const [
                        NeoSelectionOption(
                          value: 'low',
                          label: 'منخفضة',
                          color: AppColors.statusApproved,
                        ),
                        NeoSelectionOption(
                          value: 'medium',
                          label: 'متوسطة',
                          color: AppColors.gold,
                        ),
                        NeoSelectionOption(
                          value: 'high',
                          label: 'عالية',
                          color: AppColors.statusRejected,
                        ),
                      ],
                      onChanged: (value) => _condition.text = value,
                      validator: (value) =>
                          value == null ? context.tr('اختر الأولوية') : null,
                    )
                  else
                    TextFormField(
                      controller: _condition,
                      keyboardType: _field == AutomationConditionField.progress
                          ? TextInputType.number
                          : TextInputType.text,
                      decoration: InputDecoration(
                        labelText: context.tr(_conditionHint(_field)),
                      ),
                      validator: (value) {
                        final missing = _required(value);
                        if (missing != null) return missing;
                        if (_field == AutomationConditionField.progress &&
                            (num.tryParse(value!) == null ||
                                num.parse(value) < 0 ||
                                num.parse(value) > 100))
                          return 'أدخل نسبة من 0 إلى 100';
                        return null;
                      },
                    ),
                ],
                const SizedBox(height: 12),
                NeoSelectionField<AutomationAction>(
                  label: 'نفّذ الإجراء',
                  value: _action,
                  options: AutomationAction.values
                      .map(
                        (value) => NeoSelectionOption(
                          value: value,
                          label: _actionLabel(value.name),
                          icon: Icons.play_circle_outline_rounded,
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    _action = value;
                    _actionValue.clear();
                  }),
                ),
                const SizedBox(height: 12),
                if (_action == AutomationAction.reassign)
                  NeoSelectionField<String>(
                    label: 'إعادة الإسناد إلى',
                    value: employees.any((e) => e.uid == _actionValue.text)
                        ? _actionValue.text
                        : null,
                    searchable: true,
                    options: employees
                        .map(
                          (employee) => NeoSelectionOption(
                            value: employee.uid,
                            label: employee.name,
                            subtitle:
                                'الرقم الوظيفي ${employee.employeeNumber}',
                            icon: Icons.badge_outlined,
                            searchTerms: [employee.employeeNumber],
                          ),
                        )
                        .toList(),
                    onChanged: (value) => _actionValue.text = value,
                    validator: (value) =>
                        value == null ? context.tr('اختر الموظف') : null,
                  )
                else if (_action == AutomationAction.setPriority)
                  NeoSelectionField<String>(
                    label: 'الأولوية الجديدة',
                    value:
                        const [
                          'low',
                          'medium',
                          'high',
                        ].contains(_actionValue.text)
                        ? _actionValue.text
                        : 'high',
                    options: const [
                      NeoSelectionOption(
                        value: 'low',
                        label: 'منخفضة',
                        color: AppColors.statusApproved,
                      ),
                      NeoSelectionOption(
                        value: 'medium',
                        label: 'متوسطة',
                        color: AppColors.gold,
                      ),
                      NeoSelectionOption(
                        value: 'high',
                        label: 'عالية',
                        color: AppColors.statusRejected,
                      ),
                    ],
                    onChanged: (value) => _actionValue.text = value,
                  )
                else
                  TextFormField(
                    controller: _actionValue,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: context.tr('نص التنبيه')),
                    validator: _required,
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(onPressed: _save, child: const Text('حفظ وتشغيل')),
      ],
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty
      ? context.tr('هذا الحقل مطلوب')
      : null;

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (_action == AutomationAction.setPriority && _actionValue.text.isEmpty)
      _actionValue.text = 'high';
    final now = DateTime.now();
    Navigator.pop(
      context,
      AutomationRule(
        ruleId: widget.existing?.ruleId ?? const Uuid().v4(),
        name: _name.text.trim(),
        isActive: widget.existing?.isActive ?? true,
        trigger: _trigger,
        conditionField: _field,
        conditionOperator: _operator,
        conditionValue: _field == AutomationConditionField.any
            ? ''
            : _condition.text.trim(),
        action: _action,
        actionValue: _actionValue.text.trim(),
        dueWithinHours: _hours,
        createdBy: widget.existing?.createdBy ?? widget.managerUid,
        createdAt: widget.existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
  }
}

class _EditorFlowPreview extends StatelessWidget {
  const _EditorFlowPreview({
    required this.trigger,
    required this.field,
    required this.action,
  });

  final AutomationTrigger trigger;
  final AutomationConditionField field;
  final AutomationAction action;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      border: Border.all(color: AppColors.divider),
    ),
    child: Row(
      textDirection: Directionality.of(context),
      children: [
        Expanded(
          child: _EditorFlowStep(
            label: 'الحدث',
            value: _triggerLabel(trigger),
            icon: Icons.bolt_outlined,
            color: const Color(0xFF1F6FD2),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 7),
          child: Icon(
            Icons.arrow_back_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: _EditorFlowStep(
            label: 'الشرط',
            value: _fieldLabel(field),
            icon: Icons.rule_outlined,
            color: AppColors.gold,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 7),
          child: Icon(
            Icons.arrow_back_rounded,
            size: 18,
            color: AppColors.textSecondary,
          ),
        ),
        Expanded(
          child: _EditorFlowStep(
            label: 'الإجراء',
            value: _actionLabel(action.name),
            icon: Icons.play_circle_outline_rounded,
            color: AppColors.mintAccent,
          ),
        ),
      ],
    ),
  );
}

class _EditorFlowStep extends StatelessWidget {
  const _EditorFlowStep({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, color: color, size: 21),
      const SizedBox(height: 5),
      Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900),
      ),
      const SizedBox(height: 3),
      Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
      ),
    ],
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

List<AutomationOperator> _operatorsForField(AutomationConditionField field) =>
    switch (field) {
      AutomationConditionField.category => const [
        AutomationOperator.equals,
        AutomationOperator.contains,
      ],
      AutomationConditionField.progress => const [
        AutomationOperator.equals,
        AutomationOperator.greaterOrEqual,
      ],
      _ => const [AutomationOperator.equals],
    };

String _actionLabel(String value) => switch (value) {
  'notifyAssignee' => 'إشعار الموظف',
  'notifyManager' => 'إشعار المدير',
  'setPriority' => 'تغيير الأولوية',
  'reassign' => 'إعادة إسناد المهمة',
  _ => value,
};

String _conditionHint(AutomationConditionField field) => switch (field) {
  AutomationConditionField.status =>
    'القيمة: assigned / inProgress / submitted / approved / rejected',
  AutomationConditionField.priority => 'القيمة: low / medium / high',
  AutomationConditionField.category => 'اسم التصنيف',
  AutomationConditionField.progress => 'النسبة مثل 80',
  _ => 'قيمة الشرط',
};
