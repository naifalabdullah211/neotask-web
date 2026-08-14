from pathlib import Path


def replace_once(path_str: str, old: str, new: str, label: str) -> None:
    path = Path(path_str)
    text = path.read_text(encoding='utf-8')
    if old not in text:
        if new in text:
            return
        raise SystemExit(f'missing phase5 target: {label}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


def replace_between(path_str: str, start: str, end: str, replacement: str, label: str) -> None:
    path = Path(path_str)
    text = path.read_text(encoding='utf-8')
    start_i = text.find(start)
    if start_i < 0:
        if replacement.strip() in text:
            return
        raise SystemExit(f'missing phase5 start: {label}')
    end_i = text.find(end, start_i)
    if end_i < 0:
        raise SystemExit(f'missing phase5 end: {label}')
    path.write_text(text[:start_i] + replacement + text[end_i:], encoding='utf-8')


# ---------------------------------------------------------------------------
# Meetings workspace — preserve meeting/minutes/decision business logic.
# ---------------------------------------------------------------------------
meetings = 'lib/screens/shared/meetings_screen.dart'
replace_once(
    meetings,
    "import '../../widgets/neo_selection_field.dart';\n",
    "import '../../widgets/neo_selection_field.dart';\nimport '../../widgets/neo_workspace_chrome.dart';\n",
    'meetings workspace import',
)
replace_between(
    meetings,
    "  @override\n  Widget build(BuildContext context) {\n    final provider = context.watch<MeetingProvider>();",
    "\n  Future<void> _createMeeting() async {",
    r'''  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MeetingProvider>();
    final list = _showPast ? provider.past : provider.upcoming;
    final compact = MediaQuery.sizeOf(context).width < 620;
    final totalDecisions = provider.meetings.fold<int>(
      0,
      (sum, meeting) => sum + meeting.decisions.length,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'محاضر الاجتماعات',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (!widget.readOnly)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: compact
                  ? IconButton.filled(
                      tooltip: context.tr('اجتماع جديد'),
                      onPressed: _createMeeting,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.mintAccent,
                        foregroundColor: AppColors.navy,
                      ),
                      icon: const Icon(Icons.add_rounded),
                    )
                  : FilledButton.icon(
                      onPressed: _createMeeting,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.mintAccent,
                        foregroundColor: AppColors.navy,
                      ),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('اجتماع جديد'),
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            NeoWorkspaceMetricsBar(
              items: [
                NeoWorkspaceMetric(
                  label: 'إجمالي الاجتماعات',
                  value: '${provider.meetings.length}',
                  icon: Icons.groups_2_outlined,
                  color: AppColors.deepBlue,
                ),
                NeoWorkspaceMetric(
                  label: 'اجتماعات قادمة',
                  value: '${provider.upcoming.length}',
                  icon: Icons.event_available_outlined,
                  color: AppColors.mintAccent,
                ),
                NeoWorkspaceMetric(
                  label: 'محاضر سابقة',
                  value: '${provider.past.length}',
                  icon: Icons.history_rounded,
                  color: AppColors.gold,
                ),
                NeoWorkspaceMetric(
                  label: 'إجمالي القرارات',
                  value: '$totalDecisions',
                  icon: Icons.rule_folder_outlined,
                  color: const Color(0xFF7656C8),
                ),
              ],
            ),
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                children: [
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 330),
                      child: NeoSelectionField<bool>(
                        label: 'عرض الاجتماعات',
                        value: _showPast,
                        options: const [
                          NeoSelectionOption(
                            value: false,
                            label: 'القادمة',
                            icon: Icons.event_available_outlined,
                          ),
                          NeoSelectionOption(
                            value: true,
                            label: 'السابقة والمحاضر',
                            icon: Icons.history,
                          ),
                        ],
                        onChanged: (value) => setState(() => _showPast = value),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: list.isEmpty
                    ? NeoWorkspaceEmptyState(
                        icon: _showPast
                            ? Icons.history_toggle_off_rounded
                            : Icons.event_busy_outlined,
                        title: _showPast
                            ? 'لا توجد محاضر سابقة'
                            : 'لا توجد اجتماعات قادمة',
                        message: _showPast
                            ? 'ستظهر هنا الاجتماعات المكتملة ومحاضرها للرجوع إليها.'
                            : 'أنشئ اجتماعًا جديدًا وحدد المشاركين والموعد لبدء المتابعة.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          NeoWorkspaceSectionHeader(
                            title: _showPast
                                ? 'أرشيف الاجتماعات'
                                : 'مساحة الاجتماعات',
                            subtitle: _showPast
                                ? 'المحاضر والقرارات السابقة في مكان واحد'
                                : 'اختر اجتماعًا لفتح المحضر والقرارات والإجراءات',
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              itemCount: list.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) => _MeetingCard(
                                meeting: list[index],
                                onOpen: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => MeetingMinutesScreen(
                                      initialMeeting: list[index],
                                      currentUserUid: widget.currentUserUid,
                                      currentUserName: widget.currentUserName,
                                      isManager: widget.isManager,
                                      readOnly: widget.readOnly,
                                    ),
                                  ),
                                ),
                                onDelete:
                                    !widget.readOnly &&
                                        (widget.isManager ||
                                            list[index].createdBy ==
                                                widget.currentUserUid)
                                    ? () => _delete(list[index])
                                    : null,
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
    );
  }
''',
    'meetings top workspace',
)
replace_between(
    meetings,
    "class _MeetingCard extends StatelessWidget {",
    "class MeetingMinutesScreen extends StatelessWidget {",
    r'''class _MeetingCard extends StatelessWidget {
  const _MeetingCard({
    required this.meeting,
    required this.onOpen,
    this.onDelete,
  });

  final MeetingItem meeting;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (meeting.status) {
      MeetingStatus.completed => AppColors.statusApproved,
      MeetingStatus.cancelled => AppColors.statusRejected,
      MeetingStatus.scheduled => AppColors.gold,
    };
    final statusLabel = switch (meeting.status) {
      MeetingStatus.completed => 'مكتمل',
      MeetingStatus.cancelled => 'ملغى',
      MeetingStatus.scheduled => 'قادم',
    };
    final locationLabel = meeting.location.isEmpty
        ? context.tr('المكان غير محدد')
        : meeting.location;

    return Material(
      color: const Color(0xFFF9FBFD),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  meeting.status == MeetingStatus.completed
                      ? Icons.fact_check_outlined
                      : Icons.groups_2_outlined,
                  color: statusColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            meeting.title,
                            style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: .10),
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_outlined,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          intl.DateFormat('yyyy/MM/dd HH:mm').format(meeting.startTime),
                          style: AppTextStyles.bodySecondary,
                        ),
                        const SizedBox(width: 12),
                        const Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            locationLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.bodySecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 7,
                      children: [
                        _MeetingFact(
                          icon: Icons.rule_folder_outlined,
                          label:
                              '${meeting.decisions.length} ${context.tr('قرارات')}',
                        ),
                        _MeetingFact(
                          icon: Icons.group_outlined,
                          label:
                              '${meeting.participantUids.length} ${context.tr('مشاركون')}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (onDelete == null)
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                )
              else
                PopupMenuButton<String>(
                  tooltip: context.tr('إجراءات المدير'),
                  onSelected: (_) => onDelete!(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'delete', child: Text('حذف')),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MeetingFact extends StatelessWidget {
  const _MeetingFact({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.deepBlue),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

''',
    'meeting card',
)
replace_once(
    meetings,
    """                  '${intl.DateFormat('yyyy/MM/dd HH:mm').format(meeting.startTime)} · ${meeting.location.isEmpty ? 'المكان غير محدد' : meeting.location}',
""",
    """                  '${intl.DateFormat('yyyy/MM/dd HH:mm').format(meeting.startTime)} · ${meeting.location.isEmpty ? context.tr('المكان غير محدد') : meeting.location}',
""",
    'meeting minutes location',
)


# ---------------------------------------------------------------------------
# Bulk import workspace — keep parsing/validation/import logic unchanged.
# ---------------------------------------------------------------------------
bulk = 'lib/screens/manager/bulk_import_screen.dart'
replace_once(
    bulk,
    "import 'package:neotask_pro/widgets/localized_text.dart';\n",
    "import 'package:neotask_pro/widgets/localized_text.dart';\nimport 'package:neotask_pro/l10n/app_i18n.dart';\n",
    'bulk i18n import',
)
replace_once(
    bulk,
    "import '../../widgets/neo_selection_field.dart';\n",
    "import '../../widgets/neo_selection_field.dart';\nimport '../../widgets/neo_workspace_chrome.dart';\n",
    'bulk workspace import',
)
replace_between(
    bulk,
    "  @override\n  Widget build(BuildContext context) {\n    final validCount = _preview.where((row) => row.errors.isEmpty).length;",
    "\n  Future<void> _pickFile() async {",
    r'''  @override
  Widget build(BuildContext context) {
    final validCount = _preview.where((row) => row.errors.isEmpty).length;
    final errorCount = _preview.length - validCount;
    final totalCount = _preview.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'استيراد Excel / CSV',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (_table != null)
              NeoWorkspaceMetricsBar(
                items: [
                  NeoWorkspaceMetric(
                    label: 'إجمالي الصفوف',
                    value: '$totalCount',
                    icon: Icons.table_rows_outlined,
                    color: AppColors.deepBlue,
                  ),
                  NeoWorkspaceMetric(
                    label: 'صفوف صالحة',
                    value: '$validCount',
                    icon: Icons.check_circle_outline,
                    color: AppColors.statusApproved,
                  ),
                  NeoWorkspaceMetric(
                    label: 'صفوف بها أخطاء',
                    value: '$errorCount',
                    icon: Icons.error_outline_rounded,
                    color: AppColors.statusRejected,
                  ),
                ],
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.upload_file_outlined,
                          color: AppColors.goldLight,
                          size: 38,
                        ),
                        SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'استيراد حقيقي مع فحص قبل الحفظ',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'لن يُحفظ أي صف خاطئ أو مكرر، وسترى نتيجة كل صف أولًا',
                                style: TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const NeoWorkspaceSectionHeader(
                          title: 'إعداد الاستيراد',
                          subtitle:
                              'اختر نوع البيانات وارفع الملف ثم راجع النتيجة قبل الحفظ',
                        ),
                        const Divider(height: 1),
                        Padding(
                          padding: const EdgeInsets.all(AppSpacing.xl),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              NeoSelectionField<_ImportType>(
                                label: 'نوع البيانات',
                                value: _type,
                                enabled: !widget.readOnly,
                                options: const [
                                  NeoSelectionOption(
                                    value: _ImportType.employees,
                                    label: 'الموظفون',
                                    icon: Icons.groups_outlined,
                                  ),
                                  NeoSelectionOption(
                                    value: _ImportType.tasks,
                                    label: 'المهام',
                                    icon: Icons.task_alt_outlined,
                                  ),
                                ],
                                onChanged: widget.readOnly
                                    ? null
                                    : (value) => setState(() {
                                        _type = value;
                                        _fileName = null;
                                        _table = null;
                                        _preview = const [];
                                      }),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              _TemplateCard(type: _type),
                              if (!widget.readOnly) ...[
                                const SizedBox(height: AppSpacing.md),
                                OutlinedButton.icon(
                                  onPressed: _busy ? null : _pickFile,
                                  icon: const Icon(Icons.attach_file_rounded),
                                  label: Text(
                                    _fileName == null
                                        ? 'اختيار ملف CSV أو XLSX'
                                        : '${context.tr('الملف')}: $_fileName',
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_table == null)
                    SizedBox(
                      height: 250,
                      child: NeoWorkspaceEmptyState(
                        icon: Icons.table_view_outlined,
                        title: _fileName == null
                            ? 'لم يتم اختيار ملف بعد'
                            : 'ملف جاهز للمراجعة',
                        message:
                            'اختر ملف CSV أو XLSX لبدء المعاينة والتحقق قبل الحفظ.',
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const NeoWorkspaceSectionHeader(
                            title: 'مراجعة البيانات',
                            subtitle:
                                'راجع الصفوف الصالحة والأخطاء قبل تنفيذ الاستيراد',
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              children: [
                                for (final entry in _preview.asMap().entries)
                                  _PreviewRowCard(
                                    index: entry.key,
                                    row: entry.value,
                                    type: _type,
                                  ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              0,
                              AppSpacing.lg,
                              AppSpacing.lg,
                            ),
                            child: FilledButton.icon(
                              onPressed: _busy || validCount == 0
                                  ? null
                                  : _importValidRows,
                              icon: _busy
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(Icons.cloud_upload_outlined),
                              label: Text('استيراد $validCount صف صالح'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xxl),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
''',
    'bulk import top workspace',
)
replace_once(
    bulk,
    """  void _show(String message) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
  }
""",
    """  void _show(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr(message))),
      );
    }
  }
""",
    'bulk localized snackbar',
)
replace_between(
    bulk,
    "class _TemplateCard extends StatelessWidget {",
    "class _ValidatedRow {",
    r'''class _TemplateCard extends StatelessWidget {
  const _TemplateCard({required this.type});

  final _ImportType type;

  @override
  Widget build(BuildContext context) {
    final columns = type == _ImportType.employees
        ? 'الاسم | الرقم الوظيفي | كلمة المرور'
        : 'عنوان المهمة | الرقم الوظيفي | تاريخ الاستحقاق | الوصف | تاريخ البداية | الساعات | الأولوية | التصنيف';
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.deepBlue.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(
              Icons.view_column_outlined,
              color: AppColors.deepBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('عناوين الصف الأول', style: AppTextStyles.cardTitle),
                const SizedBox(height: 6),
                SelectableText(
                  context.tr(columns),
                  textDirection: Directionality.of(context),
                  style: AppTextStyles.bodySecondary,
                ),
                const SizedBox(height: 5),
                const Text(
                  'تُقبل العناوين العربية أو الإنجليزية، والتاريخ بصيغة YYYY-MM-DD',
                  style: AppTextStyles.bodySecondary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRowCard extends StatelessWidget {
  const _PreviewRowCard({
    required this.index,
    required this.row,
    required this.type,
  });

  final int index;
  final _ValidatedRow row;
  final _ImportType type;

  @override
  Widget build(BuildContext context) {
    final ok = row.errors.isEmpty;
    final title = type == _ImportType.employees
        ? row.data['name']
        : row.data['title'];
    final displayTitle = title == null || title.isEmpty
        ? context.tr('صف بلا عنوان')
        : title;
    final accent = ok ? AppColors.statusApproved : AppColors.statusRejected;
    final details = ok
        ? context.tr('صالح للاستيراد')
        : row.errors.map(context.tr).join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: accent.withValues(alpha: .28)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              ok ? Icons.check_rounded : Icons.close_rounded,
              color: accent,
              size: 20,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${index + 2}. $displayTitle', style: AppTextStyles.cardTitle),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: AppTextStyles.bodySecondary.copyWith(
                    color: ok ? AppColors.textSecondary : AppColors.statusRejected,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            row.data['employeeNumber'] ?? '',
            style: AppTextStyles.bodySecondary.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

''',
    'bulk template and preview cards',
)

print('NeoTask phase 5 workspace refresh applied')
