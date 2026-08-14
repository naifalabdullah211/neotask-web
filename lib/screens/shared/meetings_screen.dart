import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/meeting_model.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_selection_field.dart';
import '../../widgets/neo_workspace_chrome.dart';

class MeetingsScreen extends StatefulWidget {
  const MeetingsScreen({
    super.key,
    required this.currentUserUid,
    required this.currentUserName,
    required this.isManager,
    this.readOnly = false,
  });
  final String currentUserUid;
  final String currentUserName;
  final bool isManager;
  final bool readOnly;

  @override
  State<MeetingsScreen> createState() => _MeetingsScreenState();
}

class _MeetingsScreenState extends State<MeetingsScreen> {
  bool _showPast = false;

  @override
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

  Future<void> _createMeeting() async {
    final title = TextEditingController();
    final description = TextEditingController();
    final location = TextEditingController();
    final agenda = TextEditingController();
    var start = DateTime.now().add(const Duration(hours: 1));
    final selected = <String>{};
    final employees = FirestoreService.getAllEmployees()
        .where((user) => user.accountStatus == AccountStatus.active)
        .toList();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('اجتماع جديد'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: title,
                    decoration: InputDecoration(
                      labelText: context.tr('عنوان الاجتماع *'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: description,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: context.tr('الغرض من الاجتماع'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: agenda,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: context.tr('جدول الأعمال — بند في كل سطر'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: location,
                    decoration: InputDecoration(
                      labelText: context.tr('المكان أو رابط الاتصال'),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.calendar_month_outlined),
                    title: Text(
                      intl.DateFormat('yyyy/MM/dd HH:mm').format(start),
                    ),
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: start,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 730)),
                      );
                      if (date == null || !context.mounted) return;
                      final time = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(start),
                      );
                      if (time != null)
                        setState(
                          () => start = DateTime(
                            date.year,
                            date.month,
                            date.day,
                            time.hour,
                            time.minute,
                          ),
                        );
                    },
                  ),
                  if (employees.isNotEmpty) ...[
                    const Text('المشاركون', style: AppTextStyles.cardTitle),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: employees
                          .map(
                            (user) => FilterChip(
                              label: Text(user.name),
                              selected: selected.contains(user.uid),
                              onSelected: (value) => setState(
                                () => value
                                    ? selected.add(user.uid)
                                    : selected.remove(user.uid),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isNotEmpty) Navigator.pop(context, true);
              },
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) return;
    await context.read<MeetingProvider>().createMeeting(
      title: title.text.trim(),
      description: description.text.trim(),
      startTime: start,
      location: location.text.trim(),
      createdBy: widget.currentUserUid,
      createdByName: widget.currentUserName,
      participantUids: selected.toList(),
      agendaItems: agenda.text
          .split('\n')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList(),
    );
  }

  Future<void> _delete(MeetingItem meeting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الاجتماع'),
        content: Text('هل تريد حذف «${meeting.title}» ومحضره؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusRejected,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted)
      await context.read<MeetingProvider>().deleteMeeting(meeting.meetingId);
  }
}

class _MeetingCard extends StatelessWidget {
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
                            style: AppTextStyles.cardTitle.copyWith(
                              fontSize: 15,
                            ),
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
                          intl.DateFormat(
                            'yyyy/MM/dd HH:mm',
                          ).format(meeting.startTime),
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

class MeetingMinutesScreen extends StatelessWidget {
  const MeetingMinutesScreen({
    super.key,
    required this.initialMeeting,
    required this.currentUserUid,
    required this.currentUserName,
    required this.isManager,
    required this.readOnly,
  });
  final MeetingItem initialMeeting;
  final String currentUserUid;
  final String currentUserName;
  final bool isManager;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final meeting =
        context.watch<MeetingProvider>().byId(initialMeeting.meetingId) ??
        initialMeeting;
    final canManage =
        !readOnly && (isManager || meeting.createdBy == currentUserUid);
    return Scaffold(
      appBar: AppBar(title: const Text('محضر الاجتماع')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  meeting.title,
                  style: AppTextStyles.headlineLg.copyWith(fontSize: 24),
                ),
                const SizedBox(height: 8),
                Text(
                  '${intl.DateFormat('yyyy/MM/dd HH:mm').format(meeting.startTime)} · ${meeting.location.isEmpty ? context.tr('المكان غير محدد') : meeting.location}',
                  style: AppTextStyles.bodySm,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _MeetingSection(
            title: 'جدول الأعمال',
            icon: Icons.format_list_numbered,
            child: meeting.agendaItems.isEmpty
                ? const Text(
                    'لم يُضف جدول أعمال',
                    style: AppTextStyles.bodySecondary,
                  )
                : Column(
                    children: meeting.agendaItems
                        .asMap()
                        .entries
                        .map(
                          (entry) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 13,
                              child: Text(
                                '${entry.key + 1}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            title: Text(entry.value),
                          ),
                        )
                        .toList(),
                  ),
          ),
          const SizedBox(height: 12),
          _MeetingSection(
            title: 'المحضر',
            icon: Icons.notes_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  meeting.minutes.isEmpty
                      ? 'لم يُكتب المحضر بعد'
                      : meeting.minutes,
                  style: meeting.minutes.isEmpty
                      ? AppTextStyles.bodySecondary
                      : AppTextStyles.body,
                ),
                if (canManage)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _editMinutes(context, meeting),
                      icon: const Icon(Icons.edit_note),
                      label: Text(
                        meeting.minutes.isEmpty
                            ? 'كتابة المحضر'
                            : 'تعديل المحضر',
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _MeetingSection(
            title: 'القرارات والإجراءات',
            icon: Icons.rule_folder_outlined,
            child: Column(
              children: [
                if (meeting.decisions.isEmpty)
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'لم تُسجل قرارات بعد',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ),
                ...meeting.decisions.map(
                  (decision) => _DecisionTile(
                    decision: decision,
                    canManage: canManage,
                    canCreateTask: isManager && !readOnly,
                    onToggle: () => context
                        .read<MeetingProvider>()
                        .toggleDecision(meeting, decision.decisionId),
                    onCreateTask: () =>
                        _convertToTask(context, meeting, decision),
                  ),
                ),
                if (canManage)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _addDecision(context, meeting),
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة قرار'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _editMinutes(BuildContext context, MeetingItem meeting) async {
    final controller = TextEditingController(text: meeting.minutes);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('محضر الاجتماع'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: controller,
            minLines: 8,
            maxLines: 16,
            decoration: InputDecoration(
              hintText: context.tr('اكتب النقاشات والنتائج الأساسية'),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('حفظ وإغلاق الاجتماع'),
          ),
        ],
      ),
    );
    if (value != null && context.mounted)
      await context.read<MeetingProvider>().saveMinutes(meeting, value);
  }

  Future<void> _addDecision(BuildContext context, MeetingItem meeting) async {
    final employees = FirestoreService.getAllEmployees()
        .where((user) => user.accountStatus == AccountStatus.active)
        .toList();
    if (employees.isEmpty) return;
    var owner = employees.first;
    var due = DateTime.now().add(const Duration(days: 7));
    final text = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('قرار جديد'),
          content: SizedBox(
            width: 500,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: text,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: context.tr('نص القرار *'),
                  ),
                ),
                const SizedBox(height: 10),
                NeoSelectionField<AppUser>(
                  label: 'المسؤول',
                  value: owner,
                  searchable: true,
                  options: employees
                      .map(
                        (user) => NeoSelectionOption(
                          value: user,
                          label: user.name,
                          subtitle: 'الرقم الوظيفي ${user.employeeNumber}',
                          icon: Icons.badge_outlined,
                          searchTerms: [user.employeeNumber],
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => owner = value),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'الموعد: ${intl.DateFormat('yyyy/MM/dd').format(due)}',
                  ),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: due,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 730)),
                    );
                    if (picked != null) setState(() => due = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (text.text.trim().isNotEmpty) Navigator.pop(context, true);
              },
              child: const Text('حفظ القرار'),
            ),
          ],
        ),
      ),
    );
    if (result == true && context.mounted)
      await context.read<MeetingProvider>().addDecision(
        meeting: meeting,
        text: text.text,
        ownerUid: owner.uid,
        ownerName: owner.name,
        dueDate: due,
      );
  }

  Future<void> _convertToTask(
    BuildContext context,
    MeetingItem meeting,
    MeetingDecision decision,
  ) async {
    if (decision.linkedTaskId != null) return;
    final task = await context.read<TaskProvider>().createTask(
      title: decision.text,
      description: 'قرار من اجتماع: ${meeting.title}\n${meeting.minutes}',
      assignedTo: decision.ownerUid,
      assignedBy: currentUserUid,
      dueDate: decision.dueDate,
      priority: TaskPriority.medium,
      category: 'قرارات الاجتماعات',
    );
    if (!context.mounted) return;
    await context.read<MeetingProvider>().linkDecisionToTask(
      meeting: meeting,
      decisionId: decision.decisionId,
      taskId: task.taskId,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحويل القرار إلى مهمة وإسنادها')),
    );
  }
}

class _MeetingSection extends StatelessWidget {
  const _MeetingSection({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.deepBlue),
              const SizedBox(width: 8),
              Text(title, style: AppTextStyles.screenTitle),
            ],
          ),
          const Divider(height: 24),
          child,
        ],
      ),
    ),
  );
}

class _DecisionTile extends StatelessWidget {
  const _DecisionTile({
    required this.decision,
    required this.canManage,
    required this.canCreateTask,
    required this.onToggle,
    required this.onCreateTask,
  });
  final MeetingDecision decision;
  final bool canManage;
  final bool canCreateTask;
  final VoidCallback onToggle;
  final VoidCallback onCreateTask;
  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: const Color(0xFFF7F9FB),
    child: ListTile(
      leading: Checkbox(
        value: decision.isCompleted,
        onChanged: canManage ? (_) => onToggle() : null,
      ),
      title: Text(
        decision.text,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          decoration: decision.isCompleted ? TextDecoration.lineThrough : null,
        ),
      ),
      subtitle: Text(
        '${decision.ownerName} · ${intl.DateFormat('yyyy/MM/dd').format(decision.dueDate)}${decision.linkedTaskId == null ? '' : ' · مرتبطة بمهمة'}',
      ),
      trailing: decision.linkedTaskId == null && canCreateTask
          ? TextButton.icon(
              onPressed: onCreateTask,
              icon: const Icon(Icons.add_task),
              label: const Text('تحويل لمهمة'),
            )
          : const Icon(Icons.link, color: AppColors.emerald),
    ),
  );
}
