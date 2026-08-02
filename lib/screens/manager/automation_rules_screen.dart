import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/automation_rule_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/workflow_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_selection_field.dart';

class AutomationRulesScreen extends StatelessWidget {
  const AutomationRulesScreen({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('الأتمتة الشرطية')),
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('قاعدة جديدة'),
            ),
      body: StreamBuilder<List<AutomationRule>>(
        stream: WorkflowService.watchAutomationRules(),
        builder: (context, rulesSnapshot) {
          final rules = rulesSnapshot.data ?? const [];
          return StreamBuilder<List<AutomationRun>>(
            stream: WorkflowService.watchAutomationRuns(),
            builder: (context, runsSnapshot) {
              final runs = runsSnapshot.data ?? const [];
              return ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  _SummaryCard(
                    active: rules.where((r) => r.isActive).length,
                    runs: runs.length,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'القواعد',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (rules.isEmpty)
                    const _EmptyCard(
                      text:
                          'لا توجد قواعد بعد. أنشئ قاعدة تربط حدثًا بشرط وإجراء فعلي.',
                    )
                  else
                    ...rules.map(
                      (rule) => _RuleCard(
                        rule: rule,
                        readOnly: readOnly,
                        onEdit: () => _openEditor(context, existing: rule),
                      ),
                    ),
                  const SizedBox(height: 22),
                  Text(
                    'سجل التنفيذ',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (runs.isEmpty)
                    const _EmptyCard(
                      text: 'سيظهر هنا كل تشغيل مع المهمة والنتيجة والتوقيت.',
                    )
                  else
                    ...runs
                        .take(25)
                        .map(
                          (run) => Card(
                            child: ListTile(
                              leading: Icon(
                                run.status == 'completed'
                                    ? Icons.check_circle
                                    : Icons.error_outline,
                                color: run.status == 'completed'
                                    ? AppColors.mintAccent
                                    : AppColors.statusRejected,
                              ),
                              title: Text('${run.ruleName} · ${run.taskTitle}'),
                              subtitle: Text(
                                '${_actionLabel(run.action)}\n${run.executedAt.toLocal().toString().substring(0, 16)}${run.message == null ? '' : ' · ${run.message}'}',
                              ),
                              isThreeLine: true,
                            ),
                          ),
                        ),
                  const SizedBox(height: 90),
                ],
              );
            },
          );
        },
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
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.active, required this.runs});
  final int active;
  final int runs;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      children: [
        const Icon(
          Icons.account_tree_outlined,
          color: AppColors.gold,
          size: 38,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'قواعد تعمل على المهام تلقائيًا',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '$active قاعدة نشطة · $runs عملية مسجلة',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _RuleCard extends StatelessWidget {
  const _RuleCard({
    required this.rule,
    required this.readOnly,
    required this.onEdit,
  });
  final AutomationRule rule;
  final bool readOnly;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.mintAccent.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.bolt, color: AppColors.navy),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${_triggerLabel(rule.trigger)} ← ${_conditionSummary(rule)} ← ${_actionLabel(rule.action.name)}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: rule.isActive,
            onChanged: readOnly
                ? null
                : (value) =>
                      WorkflowService.setAutomationRuleActive(rule, value),
          ),
          if (!readOnly)
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') onEdit();
                if (value == 'delete')
                  WorkflowService.deleteAutomationRule(rule.ruleId);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('تعديل')),
                PopupMenuItem(value: 'delete', child: Text('حذف')),
              ],
            ),
        ],
      ),
    ),
  );
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
      title: Text(
        widget.existing == null ? 'إنشاء قاعدة أتمتة' : 'تعديل قاعدة الأتمتة',
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'اسم القاعدة'),
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
                          value == null ? 'اختر الموظف' : null,
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
                          value == null ? 'اختر الحالة' : null,
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
                          value == null ? 'اختر الأولوية' : null,
                    )
                  else
                    TextFormField(
                      controller: _condition,
                      keyboardType: _field == AutomationConditionField.progress
                          ? TextInputType.number
                          : TextInputType.text,
                      decoration: InputDecoration(
                        labelText: _conditionHint(_field),
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
                    validator: (value) => value == null ? 'اختر الموظف' : null,
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
                    decoration: const InputDecoration(labelText: 'نص التنبيه'),
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
      value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null;

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

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
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

String _conditionSummary(AutomationRule rule) {
  if (rule.conditionField == AutomationConditionField.any) return 'كل المهام';
  return '${_fieldLabel(rule.conditionField)} ${_operatorLabel(rule.conditionOperator)} ${_conditionValueLabel(rule.conditionValue)}';
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
