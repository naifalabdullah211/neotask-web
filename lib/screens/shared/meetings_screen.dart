import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/meeting_model.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/meeting_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

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
    return Scaffold(
      appBar: AppBar(title: const Text('محاضر الاجتماعات')),
      body: SafeArea(
        child: Column(children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(AppRadius.lg)),
            child: Row(children: [
              const Icon(Icons.groups_2_outlined, color: AppColors.goldLight, size: 32),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('من الاجتماع إلى التنفيذ', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                Text('سجّل القرارات وحوّلها إلى مهام قابلة للمتابعة', style: AppTextStyles.bodySm),
              ])),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('القادمة'), icon: Icon(Icons.event_available_outlined)),
                ButtonSegment(value: true, label: Text('السابقة والمحاضر'), icon: Icon(Icons.history)),
              ],
              selected: {_showPast},
              onSelectionChanged: (values) => setState(() => _showPast = values.first),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: list.isEmpty
                ? Center(child: Text(_showPast ? 'لا توجد محاضر سابقة' : 'لا توجد اجتماعات قادمة', style: AppTextStyles.bodySecondary))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) => _MeetingCard(
                      meeting: list[index],
                      onOpen: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => MeetingMinutesScreen(
                          initialMeeting: list[index],
                          currentUserUid: widget.currentUserUid,
                          currentUserName: widget.currentUserName,
                          isManager: widget.isManager,
                          readOnly: widget.readOnly,
                        ),
                      )),
                      onDelete: !widget.readOnly && (widget.isManager || list[index].createdBy == widget.currentUserUid)
                          ? () => _delete(list[index])
                          : null,
                    ),
                  ),
          ),
        ]),
      ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(onPressed: _createMeeting, icon: const Icon(Icons.add), label: const Text('اجتماع جديد')),
    );
  }

  Future<void> _createMeeting() async {
    final title = TextEditingController();
    final description = TextEditingController();
    final location = TextEditingController();
    final agenda = TextEditingController();
    var start = DateTime.now().add(const Duration(hours: 1));
    final selected = <String>{};
    final employees = FirestoreService.getAllEmployees().where((user) => user.accountStatus == AccountStatus.active).toList();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('اجتماع جديد'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان الاجتماع *')),
                const SizedBox(height: 10),
                TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'الغرض من الاجتماع')),
                const SizedBox(height: 10),
                TextField(controller: agenda, maxLines: 4, decoration: const InputDecoration(labelText: 'جدول الأعمال — بند في كل سطر')),
                const SizedBox(height: 10),
                TextField(controller: location, decoration: const InputDecoration(labelText: 'المكان أو رابط الاتصال')),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_month_outlined),
                  title: Text(intl.DateFormat('yyyy/MM/dd HH:mm').format(start)),
                  onTap: () async {
                    final date = await showDatePicker(context: context, initialDate: start, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
                    if (date == null || !context.mounted) return;
                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(start));
                    if (time != null) setState(() => start = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                  },
                ),
                if (employees.isNotEmpty) ...[
                  const Text('المشاركون', style: AppTextStyles.cardTitle),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: employees.map((user) => FilterChip(
                    label: Text(user.name),
                    selected: selected.contains(user.uid),
                    onSelected: (value) => setState(() => value ? selected.add(user.uid) : selected.remove(user.uid)),
                  )).toList()),
                ],
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () {
              if (title.text.trim().isNotEmpty) Navigator.pop(context, true);
            }, child: const Text('إنشاء')),
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
      agendaItems: agenda.text.split('\n').map((item) => item.trim()).where((item) => item.isNotEmpty).toList(),
    );
  }

  Future<void> _delete(MeetingItem meeting) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الاجتماع'),
        content: Text('هل تريد حذف «${meeting.title}» ومحضره؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.statusRejected), onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed == true && mounted) await context.read<MeetingProvider>().deleteMeeting(meeting.meetingId);
  }
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({required this.meeting, required this.onOpen, this.onDelete});
  final MeetingItem meeting;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.all(12),
      leading: CircleAvatar(
        backgroundColor: meeting.status == MeetingStatus.completed ? const Color(0xFFE6F6EC) : const Color(0xFFFFF4D9),
        child: Icon(meeting.status == MeetingStatus.completed ? Icons.fact_check_outlined : Icons.groups_outlined, color: meeting.status == MeetingStatus.completed ? AppColors.emerald : AppColors.gold),
      ),
      title: Text(meeting.title, style: AppTextStyles.cardTitle),
      subtitle: Text('${intl.DateFormat('yyyy/MM/dd HH:mm').format(meeting.startTime)}\n${meeting.decisions.length} قرار · ${meeting.participantUids.length} مشارك'),
      isThreeLine: true,
      onTap: onOpen,
      trailing: onDelete == null ? const Icon(Icons.chevron_left) : PopupMenuButton<String>(onSelected: (_) => onDelete!(), itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('حذف'))]),
    ),
  );
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
    final meeting = context.watch<MeetingProvider>().byId(initialMeeting.meetingId) ?? initialMeeting;
    final canManage = !readOnly && (isManager || meeting.createdBy == currentUserUid);
    return Scaffold(
      appBar: AppBar(title: const Text('محضر الاجتماع')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(AppRadius.lg)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(meeting.title, style: AppTextStyles.headlineLg.copyWith(fontSize: 24)),
            const SizedBox(height: 8),
            Text('${intl.DateFormat('yyyy/MM/dd HH:mm').format(meeting.startTime)} · ${meeting.location.isEmpty ? 'المكان غير محدد' : meeting.location}', style: AppTextStyles.bodySm),
          ]),
        ),
        const SizedBox(height: 12),
        _MeetingSection(title: 'جدول الأعمال', icon: Icons.format_list_numbered, child: meeting.agendaItems.isEmpty
            ? const Text('لم يُضف جدول أعمال', style: AppTextStyles.bodySecondary)
            : Column(children: meeting.agendaItems.asMap().entries.map((entry) => ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(radius: 13, child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 11))), title: Text(entry.value))).toList())),
        const SizedBox(height: 12),
        _MeetingSection(
          title: 'المحضر',
          icon: Icons.notes_outlined,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(meeting.minutes.isEmpty ? 'لم يُكتب المحضر بعد' : meeting.minutes, style: meeting.minutes.isEmpty ? AppTextStyles.bodySecondary : AppTextStyles.body),
            if (canManage) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => _editMinutes(context, meeting), icon: const Icon(Icons.edit_note), label: Text(meeting.minutes.isEmpty ? 'كتابة المحضر' : 'تعديل المحضر'))),
          ]),
        ),
        const SizedBox(height: 12),
        _MeetingSection(
          title: 'القرارات والإجراءات',
          icon: Icons.rule_folder_outlined,
          child: Column(children: [
            if (meeting.decisions.isEmpty) const Align(alignment: Alignment.centerRight, child: Text('لم تُسجل قرارات بعد', style: AppTextStyles.bodySecondary)),
            ...meeting.decisions.map((decision) => _DecisionTile(
              decision: decision,
              canManage: canManage,
              canCreateTask: isManager && !readOnly,
              onToggle: () => context.read<MeetingProvider>().toggleDecision(meeting, decision.decisionId),
              onCreateTask: () => _convertToTask(context, meeting, decision),
            )),
            if (canManage) Align(alignment: Alignment.centerLeft, child: TextButton.icon(onPressed: () => _addDecision(context, meeting), icon: const Icon(Icons.add), label: const Text('إضافة قرار'))),
          ]),
        ),
      ]),
    );
  }

  Future<void> _editMinutes(BuildContext context, MeetingItem meeting) async {
    final controller = TextEditingController(text: meeting.minutes);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('محضر الاجتماع'),
        content: SizedBox(width: 560, child: TextField(controller: controller, minLines: 8, maxLines: 16, decoration: const InputDecoration(hintText: 'اكتب النقاشات والنتائج الأساسية'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('حفظ وإغلاق الاجتماع')),
        ],
      ),
    );
    if (value != null && context.mounted) await context.read<MeetingProvider>().saveMinutes(meeting, value);
  }

  Future<void> _addDecision(BuildContext context, MeetingItem meeting) async {
    final employees = FirestoreService.getAllEmployees().where((user) => user.accountStatus == AccountStatus.active).toList();
    if (employees.isEmpty) return;
    var owner = employees.first;
    var due = DateTime.now().add(const Duration(days: 7));
    final text = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('قرار جديد'),
          content: SizedBox(width: 500, child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: text, maxLines: 3, decoration: const InputDecoration(labelText: 'نص القرار *')),
            const SizedBox(height: 10),
            DropdownButtonFormField<AppUser>(initialValue: owner, decoration: const InputDecoration(labelText: 'المسؤول'), items: employees.map((user) => DropdownMenuItem(value: user, child: Text(user.name))).toList(), onChanged: (value) => setState(() => owner = value ?? owner)),
            ListTile(contentPadding: EdgeInsets.zero, title: Text('الموعد: ${intl.DateFormat('yyyy/MM/dd').format(due)}'), trailing: const Icon(Icons.calendar_month_outlined), onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: due, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
              if (picked != null) setState(() => due = picked);
            }),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () {
              if (text.text.trim().isNotEmpty) Navigator.pop(context, true);
            }, child: const Text('حفظ القرار')),
          ],
        ),
      ),
    );
    if (result == true && context.mounted) await context.read<MeetingProvider>().addDecision(meeting: meeting, text: text.text, ownerUid: owner.uid, ownerName: owner.name, dueDate: due);
  }

  Future<void> _convertToTask(BuildContext context, MeetingItem meeting, MeetingDecision decision) async {
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
    await context.read<MeetingProvider>().linkDecisionToTask(meeting: meeting, decisionId: decision.decisionId, taskId: task.taskId);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم تحويل القرار إلى مهمة وإسنادها')));
  }
}

class _MeetingSection extends StatelessWidget {
  const _MeetingSection({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Row(children: [Icon(icon, color: AppColors.deepBlue), const SizedBox(width: 8), Text(title, style: AppTextStyles.screenTitle)]),
    const Divider(height: 24),
    child,
  ])));
}

class _DecisionTile extends StatelessWidget {
  const _DecisionTile({required this.decision, required this.canManage, required this.canCreateTask, required this.onToggle, required this.onCreateTask});
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
      leading: Checkbox(value: decision.isCompleted, onChanged: canManage ? (_) => onToggle() : null),
      title: Text(decision.text, style: TextStyle(fontWeight: FontWeight.w600, decoration: decision.isCompleted ? TextDecoration.lineThrough : null)),
      subtitle: Text('${decision.ownerName} · ${intl.DateFormat('yyyy/MM/dd').format(decision.dueDate)}${decision.linkedTaskId == null ? '' : ' · مرتبطة بمهمة'}'),
      trailing: decision.linkedTaskId == null && canCreateTask ? TextButton.icon(onPressed: onCreateTask, icon: const Icon(Icons.add_task), label: const Text('تحويل لمهمة')) : const Icon(Icons.link, color: AppColors.emerald),
    ),
  );
}
