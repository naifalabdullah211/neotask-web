import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../models/custom_form_model.dart';
import '../../providers/auth_provider.dart';
import '../../services/workflow_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_selection_field.dart';
import '../../widgets/neo_workspace_chrome.dart';
import '../../widgets/status_chip.dart' show AppPill;
import 'manager_create_task_screen.dart';

class CustomFormsScreen extends StatelessWidget {
  const CustomFormsScreen({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 620;

    void createForm() {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CustomFormEditorScreen()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'النماذج والحقول المخصصة',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (!readOnly)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: compact
                  ? IconButton.filled(
                      tooltip: context.tr('نموذج جديد'),
                      onPressed: createForm,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.mintAccent,
                        foregroundColor: AppColors.navy,
                      ),
                      icon: const Icon(Icons.add_rounded),
                    )
                  : FilledButton.icon(
                      onPressed: createForm,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.mintAccent,
                        foregroundColor: AppColors.navy,
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text('نموذج جديد'),
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<CustomFormDefinition>>(
          stream: WorkflowService.watchForms(),
          builder: (context, snapshot) {
            final forms = snapshot.data ?? const <CustomFormDefinition>[];
            if (snapshot.connectionState == ConnectionState.waiting &&
                forms.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final active = forms.where((form) => form.isActive).length;
            final paused = forms.length - active;
            final fieldCount = forms.fold<int>(
              0,
              (sum, form) => sum + form.fields.length,
            );

            return Column(
              children: [
                NeoWorkspaceMetricsBar(
                  items: [
                    NeoWorkspaceMetric(
                      label: 'إجمالي النماذج',
                      value: '${forms.length}',
                      icon: Icons.dynamic_form_outlined,
                      color: const Color(0xFF1F6FD2),
                    ),
                    NeoWorkspaceMetric(
                      label: 'نماذج نشطة',
                      value: '$active',
                      icon: Icons.public_rounded,
                      color: AppColors.mintAccent,
                    ),
                    NeoWorkspaceMetric(
                      label: 'نماذج متوقفة',
                      value: '$paused',
                      icon: Icons.pause_circle_outline_rounded,
                      color: AppColors.statusPending,
                    ),
                    NeoWorkspaceMetric(
                      label: 'إجمالي الحقول',
                      value: '$fieldCount',
                      icon: Icons.view_list_outlined,
                      color: AppColors.gold,
                    ),
                  ],
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: AppColors.divider)),
                    ),
                    child: forms.isEmpty
                        ? NeoWorkspaceEmptyState(
                            icon: Icons.dynamic_form_outlined,
                            title: 'مساحة النماذج جاهزة',
                            message:
                                'أنشئ نموذجًا وحدد حقوله ثم شارك رابطه وتابع الردود من نفس المكان.',
                            action: readOnly
                                ? null
                                : FilledButton.icon(
                                    onPressed: createForm,
                                    icon: const Icon(Icons.add_rounded),
                                    label: const Text('نموذج جديد'),
                                  ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const NeoWorkspaceSectionHeader(
                                title: 'مكتبة النماذج',
                                subtitle:
                                    'النماذج وروابطها وحالة استقبال الردود في مساحة واحدة',
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  itemCount: forms.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: AppSpacing.md),
                                  itemBuilder: (context, index) => _FormCard(
                                    form: forms[index],
                                    readOnly: readOnly,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({required this.form, required this.readOnly});

  final CustomFormDefinition form;
  final bool readOnly;

  String get _shareUrl {
    final origin = Uri.base.origin;
    return '$origin/?form=${form.formId}';
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = form.isActive
        ? AppColors.statusApproved
        : AppColors.statusPending;

    return Material(
      color: const Color(0xFFF9FBFD),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    form.isActive
                        ? Icons.public_rounded
                        : Icons.public_off_rounded,
                    color: statusColor,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        form.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (form.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          form.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySecondary,
                        ),
                      ],
                      const SizedBox(height: 9),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          AppPill(
                            color: statusColor,
                            label: form.isActive ? 'نشط' : 'متوقف',
                          ),
                          _FormFact(
                            icon: Icons.view_list_outlined,
                            text:
                                '${form.fields.length} ${context.tr('الحقول')}',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!readOnly)
                  Tooltip(
                    message: context.tr(
                      form.isActive ? 'إيقاف استقبال الردود' : 'تفعيل النموذج',
                    ),
                    child: Switch(
                      value: form.isActive,
                      onChanged: (value) =>
                          WorkflowService.setFormActive(form.formId, value),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: form.isActive
                      ? () async {
                          await Clipboard.setData(
                            ClipboardData(text: _shareUrl),
                          );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم نسخ رابط النموذج'),
                              ),
                            );
                          }
                        }
                      : null,
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text('نسخ الرابط'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          FormResponsesScreen(form: form, readOnly: readOnly),
                    ),
                  ),
                  icon: const Icon(Icons.inbox_outlined, size: 18),
                  label: const Text('الردود'),
                ),
                if (!readOnly)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CustomFormEditorScreen(existing: form),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('تعديل النموذج'),
                  ),
                if (!readOnly)
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusRejected,
                    ),
                    onPressed: () => _deleteFormWithConfirmation(context, form),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('حذف النموذج'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FormFact extends StatelessWidget {
  const _FormFact({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            text,
            style: AppTextStyles.bodySecondary.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

Future<bool> _deleteFormWithConfirmation(
  BuildContext context,
  CustomFormDefinition form,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: const Icon(
        Icons.delete_forever_outlined,
        color: AppColors.statusRejected,
        size: 34,
      ),
      title: const Text('حذف النموذج بالكامل؟'),
      content: Text(
        'سيُحذف نموذج «${form.title}» وجميع الردود المرتبطة به نهائيًا. لا يمكن التراجع عن هذا الإجراء.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('إلغاء'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.statusRejected,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          icon: const Icon(Icons.delete_outline),
          label: const Text('نعم، احذف النموذج'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final rootNavigator = Navigator.of(context, rootNavigator: true);
  final messenger = ScaffoldMessenger.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            SizedBox(width: 16),
            Expanded(child: Text('جارٍ حذف النموذج وردوده…')),
          ],
        ),
      ),
    ),
  );

  try {
    await WorkflowService.deleteForm(form.formId);
    rootNavigator.pop();
    if (context.mounted) {
      messenger.showSnackBar(
        SnackBar(content: Text('تم حذف نموذج «${form.title}»')),
      );
    }
    return true;
  } catch (_) {
    rootNavigator.pop();
    if (context.mounted) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('تعذر حذف النموذج. حاول مرة أخرى.'),
          backgroundColor: AppColors.statusRejected,
        ),
      );
    }
    return false;
  }
}

class CustomFormEditorScreen extends StatefulWidget {
  const CustomFormEditorScreen({super.key, this.existing});
  final CustomFormDefinition? existing;

  @override
  State<CustomFormEditorScreen> createState() => _CustomFormEditorScreenState();
}

class _CustomFormEditorScreenState extends State<CustomFormEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late List<CustomFormField> _fields;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _description = TextEditingController(
      text: widget.existing?.description ?? '',
    );
    _fields = List.of(widget.existing?.fields ?? const []);
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: Text(widget.existing == null ? 'إنشاء نموذج' : 'تعديل النموذج'),
    ),
    body: Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'بيانات النموذج الأساسية',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'يمكنك تعديل عنوان النموذج ووصفه، ثم إدارة الحقول أدناه.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _title,
                    decoration: InputDecoration(
                      labelText: context.tr('عنوان النموذج'),
                    ),
                    validator: _required,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _description,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.tr('وصف وتعليمات النموذج'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'الحقول',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              FilledButton.icon(
                onPressed: () => _editField(),
                icon: const Icon(Icons.add),
                label: const Text('إضافة حقل'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_fields.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('أضف حقلًا واحدًا على الأقل')),
              ),
            )
          else
            ...List.generate(_fields.length, (index) {
              final field = _fields[index];
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Text('${index + 1}')),
                  title: Text(field.label),
                  subtitle: Text(
                    '${_fieldTypeLabel(field.type)} · ${field.isRequired ? 'مطلوب' : 'اختياري'}${field.options.isEmpty ? '' : ' · ${field.options.join('، ')}'}',
                  ),
                  trailing: Wrap(
                    spacing: 2,
                    children: [
                      IconButton(
                        onPressed: index == 0
                            ? null
                            : () => _move(index, index - 1),
                        icon: const Icon(Icons.arrow_upward),
                      ),
                      IconButton(
                        onPressed: index == _fields.length - 1
                            ? null
                            : () => _move(index, index + 1),
                        icon: const Icon(Icons.arrow_downward),
                      ),
                      IconButton(
                        onPressed: () => _editField(index: index),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _fields.removeAt(index)),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.statusRejected,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: const Text('حفظ النموذج'),
          ),
          if (widget.existing != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.statusRejected,
              ),
              onPressed: _saving
                  ? null
                  : () async {
                      final deleted = await _deleteFormWithConfirmation(
                        context,
                        widget.existing!,
                      );
                      if (deleted && mounted) Navigator.pop(context);
                    },
              icon: const Icon(Icons.delete_forever_outlined),
              label: const Text('حذف النموذج بالكامل'),
            ),
          ],
          const SizedBox(height: 40),
        ],
      ),
    ),
  );

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null;

  void _move(int from, int to) => setState(() {
    final field = _fields.removeAt(from);
    _fields.insert(to, field);
  });

  Future<void> _editField({int? index}) async {
    final field = await showDialog<CustomFormField>(
      context: context,
      builder: (_) =>
          _FieldEditor(existing: index == null ? null : _fields[index]),
    );
    if (field == null) return;
    setState(() {
      if (index == null) {
        _fields.add(field);
      } else {
        _fields[index] = field;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fields.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('أضف حقلًا واحدًا على الأقل')),
      );
      return;
    }
    setState(() => _saving = true);
    final now = DateTime.now();
    final managerUid = context.read<AuthProvider>().currentUser!.uid;
    final definition = CustomFormDefinition(
      formId: widget.existing?.formId ?? const Uuid().v4(),
      title: _title.text.trim(),
      description: _description.text.trim(),
      isActive: widget.existing?.isActive ?? true,
      fields: _fields,
      createdBy: widget.existing?.createdBy ?? managerUid,
      createdAt: widget.existing?.createdAt ?? now,
      updatedAt: now,
    );
    await WorkflowService.saveForm(definition);
    if (mounted) Navigator.pop(context);
  }
}

class _FieldEditor extends StatefulWidget {
  const _FieldEditor({this.existing});
  final CustomFormField? existing;

  @override
  State<_FieldEditor> createState() => _FieldEditorState();
}

class _FieldEditorState extends State<_FieldEditor> {
  final _key = GlobalKey<FormState>();
  late final TextEditingController _label;
  late final TextEditingController _options;
  late CustomFieldType _type;
  late bool _required;

  @override
  void initState() {
    super.initState();
    _label = TextEditingController(text: widget.existing?.label ?? '');
    _options = TextEditingController(
      text: widget.existing?.options.join('\n') ?? '',
    );
    _type = widget.existing?.type ?? CustomFieldType.shortText;
    _required = widget.existing?.isRequired ?? false;
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.existing == null ? 'إضافة حقل' : 'تعديل الحقل'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _key,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _label,
              decoration: InputDecoration(labelText: context.tr('اسم الحقل')),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.tr('اكتب اسم الحقل')
                  : null,
            ),
            const SizedBox(height: 12),
            NeoSelectionField<CustomFieldType>(
              label: 'نوع الحقل',
              value: _type,
              options: CustomFieldType.values
                  .map(
                    (type) => NeoSelectionOption(
                      value: type,
                      label: _fieldTypeLabel(type),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _type = value!),
            ),
            if (_type == CustomFieldType.choice) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _options,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: context.tr('الخيارات — خيار في كل سطر'),
                ),
                validator: (value) =>
                    (value ?? '')
                            .split('\n')
                            .where((e) => e.trim().isNotEmpty)
                            .length <
                        2
                    ? context.tr('أدخل خيارين على الأقل')
                    : null,
              ),
            ],
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('حقل مطلوب'),
              value: _required,
              onChanged: (value) => setState(() => _required = value),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('إلغاء'),
      ),
      FilledButton(onPressed: _save, child: const Text('اعتماد')),
    ],
  );

  void _save() {
    if (!_key.currentState!.validate()) return;
    Navigator.pop(
      context,
      CustomFormField(
        fieldId: widget.existing?.fieldId ?? const Uuid().v4(),
        label: _label.text.trim(),
        type: _type,
        isRequired: _required,
        options: _type == CustomFieldType.choice
            ? _options.text
                  .split('\n')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList()
            : const [],
      ),
    );
  }
}

class FormResponsesScreen extends StatelessWidget {
  const FormResponsesScreen({
    super.key,
    required this.form,
    this.readOnly = false,
  });
  final CustomFormDefinition form;
  final bool readOnly;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: Text('ردود: ${form.title}')),
    body: StreamBuilder<List<CustomFormResponse>>(
      stream: WorkflowService.watchFormResponses(form.formId),
      builder: (context, snapshot) {
        final responses = snapshot.data ?? const [];
        if (responses.isEmpty)
          return const Center(child: Text('لم يصل أي رد حتى الآن'));
        return ListView.builder(
          padding: const EdgeInsets.all(18),
          itemCount: responses.length,
          itemBuilder: (context, index) {
            final response = responses[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ExpansionTile(
                title: Text('رد رقم ${responses.length - index}'),
                subtitle: Text(
                  response.submittedAt.toLocal().toString().substring(0, 16),
                ),
                children: [
                  ...form.fields.map((field) {
                    final value = response.answers[field.fieldId];
                    return ListTile(
                      title: Text(field.label),
                      subtitle: Text(
                        value is bool
                            ? (value ? 'نعم' : 'لا')
                            : (value?.toString() ?? '—'),
                      ),
                    );
                  }),
                  if (!readOnly)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: FilledButton.icon(
                          icon: const Icon(Icons.add_task_outlined),
                          label: const Text('تحويل الرد إلى مهمة'),
                          onPressed: () {
                            final details = form.fields
                                .map((field) {
                                  final value = response.answers[field.fieldId];
                                  final shown = value is bool
                                      ? (value ? 'نعم' : 'لا')
                                      : (value?.toString() ?? '—');
                                  return '${field.label}: $shown';
                                })
                                .join('\n');
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ManagerCreateTaskScreen(
                                  initialTitle: form.title,
                                  initialDescription:
                                      'رد وارد من نموذج «${form.title}»\n\n$details',
                                  initialCategory: 'نموذج: ${form.title}',
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

String _fieldTypeLabel(CustomFieldType type) => switch (type) {
  CustomFieldType.shortText => 'نص قصير',
  CustomFieldType.longText => 'نص طويل',
  CustomFieldType.number => 'رقم',
  CustomFieldType.date => 'تاريخ',
  CustomFieldType.choice => 'قائمة اختيار',
  CustomFieldType.checkbox => 'نعم / لا',
};
