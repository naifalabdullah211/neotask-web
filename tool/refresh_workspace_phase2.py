from pathlib import Path
import re


def replace_regex(path_str: str, pattern: str, replacement: str, label: str) -> None:
    path = Path(path_str)
    text = path.read_text(encoding='utf-8')
    updated, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count == 0:
        if replacement.strip() in text:
            return
        raise SystemExit(f'missing phase2 target: {label}')
    path.write_text(updated, encoding='utf-8')


path = Path('lib/screens/manager/custom_forms_screen.dart')
text = path.read_text(encoding='utf-8')
if "../../widgets/neo_workspace_chrome.dart" not in text:
    text = text.replace(
        "import '../../widgets/neo_selection_field.dart';\n",
        "import '../../widgets/neo_selection_field.dart';\n"
        "import '../../widgets/neo_workspace_chrome.dart';\n"
        "import '../../widgets/status_chip.dart' show AppPill;\n",
        1,
    )
path.write_text(text, encoding='utf-8')

replacement = r'''class CustomFormsScreen extends StatelessWidget {
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
    final statusColor =
        form.isActive ? AppColors.statusApproved : AppColors.statusPending;

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
                    form.isActive ? Icons.public_rounded : Icons.public_off_rounded,
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
                      form.isActive
                          ? 'إيقاف استقبال الردود'
                          : 'تفعيل النموذج',
                    ),
                    child: Switch(
                      value: form.isActive,
                      onChanged: (value) => WorkflowService.setFormActive(
                        form.formId,
                        value,
                      ),
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
                          await Clipboard.setData(ClipboardData(text: _shareUrl));
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
                      builder: (_) => FormResponsesScreen(
                        form: form,
                        readOnly: readOnly,
                      ),
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

Future<bool> _deleteFormWithConfirmation'''

replace_regex(
    'lib/screens/manager/custom_forms_screen.dart',
    r'class CustomFormsScreen extends StatelessWidget \{.*?Future<bool> _deleteFormWithConfirmation',
    replacement,
    'custom forms workspace',
)

print('NeoTask workspace phase 2 refresh applied')
