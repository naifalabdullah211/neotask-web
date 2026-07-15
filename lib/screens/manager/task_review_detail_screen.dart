import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_history_model.dart';
import '../../models/task_model.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/recurrence_utils.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/favorite_star_button.dart';
import '../shared/chat_thread_screen.dart';

/// Full task detail + three-way review decision screen for the manager.
/// Enforces the mandatory-note rule on Reject / Request-Edit, and shows
/// the FULL audit trail/history (never overwritten across revisions).
class TaskReviewDetailScreen extends StatefulWidget {
  final AppTask task;
  const TaskReviewDetailScreen({super.key, required this.task});

  @override
  State<TaskReviewDetailScreen> createState() => _TaskReviewDetailScreenState();
}

class _TaskReviewDetailScreenState extends State<TaskReviewDetailScreen> {
  bool _submitting = false;

  Future<void> _decide(String decision) async {
    final managerUid = context.read<AuthProvider>().currentUser!.uid;
    String? note;

    if (decision != 'approve') {
      note = await _promptForNote(decision);
      if (note == null) return; // cancelled
      if (note.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('يجب إدخال سبب أو ملاحظة عند الرفض أو طلب التعديل'),
            backgroundColor: AppColors.statusRejected,
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    final taskProvider = context.read<TaskProvider>();
    setState(() => _submitting = true);
    try {
      await taskProvider.reviewDecision(
        taskId: widget.task.taskId,
        managerUid: managerUid,
        decision: decision,
        note: note,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_decisionSuccessLabel(decision))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  /// Part 4 — MANAGER-ONLY edit of `priority`/`dueDate`. Available
  /// regardless of the task's current status (per the explicit
  /// requirement that this restriction/permission is unconditional).
  Future<void> _editPriorityAndDueDate(AppTask current) async {
    final managerUid = context.read<AuthProvider>().currentUser!.uid;
    TaskPriority selectedPriority = current.priority;
    DateTime selectedDueDate = current.dueDate;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تعديل الأولوية وتاريخ الاستحقاق'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'الأولوية',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SegmentedButton<TaskPriority>(
                segments: const [
                  ButtonSegment(value: TaskPriority.low, label: Text('منخفضة')),
                  ButtonSegment(
                    value: TaskPriority.medium,
                    label: Text('متوسطة'),
                  ),
                  ButtonSegment(value: TaskPriority.high, label: Text('عالية')),
                ],
                selected: {selectedPriority},
                onSelectionChanged: (s) =>
                    setDialogState(() => selectedPriority = s.first),
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تاريخ الاستحقاق'),
                subtitle: Text(
                  intl.DateFormat('yyyy/MM/dd').format(selectedDueDate),
                ),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: selectedDueDate,
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 3650),
                    ),
                    lastDate: DateTime.now().add(const Duration(days: 3650)),
                  );
                  if (picked != null) {
                    setDialogState(() => selectedDueDate = picked);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<TaskProvider>().updatePriorityAndDueDate(
      taskId: current.taskId,
      managerUid: managerUid,
      priority: selectedPriority,
      dueDate: selectedDueDate,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم تحديث الأولوية وتاريخ الاستحقاق')),
    );
  }

  // ===========================================================================
  // NEW MANAGER-ONLY ACTIONS — always available regardless of task status
  // (تحديث الحالة / تحويل لموظف آخر / حذف المهمة / إغلاق). Distinct from the
  // three-way review decision above (_decide), which stays gated to
  // `status == submitted` and represents a different, narrower workflow
  // (approve/reject/edit_request on a just-submitted task). These four
  // actions are the general-purpose control panel requested for ANY task
  // card tap by the manager.
  // ===========================================================================

  /// "تحديث الحالة" — direct status override to any of the 6 [TaskStatus]
  /// values, via [TaskProvider.updateStatus] (already existed, reused
  /// as-is). Logs to history automatically.
  Future<void> _updateStatusAction(AppTask current, String managerUid) async {
    TaskStatus selected = current.status;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تحديث الحالة'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'اختر الحالة الجديدة للمهمة:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<TaskStatus>(
                initialValue: selected,
                decoration: const InputDecoration(isDense: true),
                items: TaskStatus.values
                    .map(
                      (s) => DropdownMenuItem(
                        value: s,
                        child: Text(statusLabelAr(s.name)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selected = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<TaskProvider>().updateStatus(
      current.taskId,
      selected,
      managerUid,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم تحديث الحالة إلى ${statusLabelAr(selected.name)}'),
      ),
    );
  }

  /// "تحويل لموظف آخر" — immediate, unconditional manager reassignment
  /// (no approval/confirmation steps, unlike the employee-initiated
  /// request/approve/confirm workflow used elsewhere). Only ACTIVE
  /// employees are listed, matching the established
  /// `getAllEmployees().where(accountStatus == active)` pattern used by
  /// `manager_reports_tab.dart` / `request_reassignment_dialog.dart`.
  Future<void> _transferAction(AppTask current, String managerUid) async {
    final candidates = FirestoreService.getAllEmployees()
        .where(
          (u) =>
              u.accountStatus == AccountStatus.active &&
              u.uid != current.assignedTo,
        )
        .toList();

    if (candidates.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد موظفون نشطون آخرون لتحويل المهمة إليهم'),
        ),
      );
      return;
    }

    AppUser? selected = candidates.first;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('تحويل المهمة لموظف آخر'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'سيتم تحويل المهمة فورًا للموظف المحدد، مع بقاء جميع تفاصيل المهمة كما هي.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AppUser>(
                initialValue: selected,
                decoration: const InputDecoration(isDense: true),
                items: candidates
                    .map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setDialogState(() => selected = v);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('تحويل'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || selected == null || !mounted) return;
    await context.read<TaskProvider>().reassignTaskDirect(
      taskId: current.taskId,
      managerUid: managerUid,
      newAssigneeUid: selected!.uid,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('تم تحويل المهمة إلى ${selected!.name}')),
    );
  }

  /// "حذف المهمة" — requires the EXACT confirmation text specified by the
  /// manager before final, irreversible deletion. Logs a history entry
  /// (via [TaskProvider.deleteTask]'s `actorUid` parameter) before the
  /// task document is removed, then returns to the previous screen (the
  /// task list) since the task no longer exists to display.
  Future<void> _deleteAction(AppTask current, String managerUid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المهمة'),
        content: const Text(
          'هل أنت متأكد من حذف هذه المهمة؟ هذا الإجراء لا يمكن التراجع عنه',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusRejected,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await context.read<TaskProvider>().deleteTask(
      current.taskId,
      actorUid: managerUid,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم حذف المهمة')));
  }

  String _decisionSuccessLabel(String decision) {
    switch (decision) {
      case 'approve':
        return 'تمت الموافقة على المهمة';
      case 'reject':
        return 'تم رفض المهمة';
      default:
        return 'تم إرسال طلب التعديل للموظف';
    }
  }

  Future<String?> _promptForNote(String decision) async {
    final ctrl = TextEditingController();
    final title = decision == 'reject'
        ? 'سبب الرفض (إلزامي)'
        : 'ملاحظة طلب التعديل (إلزامي)';
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'اكتب السبب أو الملاحظة هنا...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(ctrl.text),
            child: const Text('تأكيد'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    // Get the freshest version of the task (in case it changed).
    final current =
        taskProvider.allTasks
            .where((t) => t.taskId == widget.task.taskId)
            .isNotEmpty
        ? taskProvider.allTasks.firstWhere(
            (t) => t.taskId == widget.task.taskId,
          )
        : widget.task;
    final history = taskProvider.historyForTask(current.taskId);
    final managerUid = context.read<AuthProvider>().currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('مراجعة المهمة'),
        actions: [
          FavoriteStarButton(userUid: managerUid, taskId: current.taskId),
          // Part 4 — manager-only, available regardless of task status.
          IconButton(
            tooltip: 'تعديل الأولوية وتاريخ الاستحقاق',
            icon: const Icon(Icons.edit_calendar_outlined),
            onPressed: () => _editPriorityAndDueDate(current),
          ),
          _TaskChatButton(
            taskId: current.taskId,
            managerUid: managerUid,
            employeeUid: current.assignedTo,
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            current.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        StatusChip(statusName: current.status.name),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      current.description,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.category_outlined,
                      label: 'التصنيف',
                      value: current.category,
                    ),
                    _InfoRow(
                      icon: Icons.flag_outlined,
                      label: 'الأولوية',
                      value: priorityLabelAr(current.priority.name),
                    ),
                    _InfoRow(
                      icon: Icons.event_outlined,
                      label: 'تاريخ الاستحقاق',
                      value: intl.DateFormat(
                        'yyyy/MM/dd',
                      ).format(current.dueDate),
                    ),
                    _InfoRow(
                      icon: Icons.repeat,
                      label: 'التكرار',
                      value: RecurrenceUtils.recurrenceLabelAr(current),
                    ),
                    if (current.submittedAt != null)
                      _InfoRow(
                        icon: Icons.send_outlined,
                        label: 'تاريخ الإرسال',
                        value: intl.DateFormat(
                          'yyyy/MM/dd HH:mm',
                        ).format(current.submittedAt!),
                      ),
                    if (current.submissionNote != null &&
                        current.submissionNote!.isNotEmpty)
                      _InfoRow(
                        icon: Icons.comment_outlined,
                        label: 'ملاحظة الموظف',
                        value: current.submissionNote!,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // NEW — manager-only action panel (تحديث الحالة / تحويل لموظف
            // آخر / حذف المهمة / إغلاق), always visible regardless of the
            // task's status. Gated strictly on `isManager` so an employee
            // opening the same screen (e.g. via a shared route, if ever
            // reused) never sees these controls — matches requirement #4
            // ("قراءة فقط" for non-managers).
            if (context.watch<AuthProvider>().isManager)
              _ManagerActionsPanel(
                onUpdateStatus: () => _updateStatusAction(current, managerUid),
                onTransfer: () => _transferAction(current, managerUid),
                onDelete: () => _deleteAction(current, managerUid),
                onClose: () => Navigator.of(context).pop(),
              ),
            if (context.watch<AuthProvider>().isManager)
              const SizedBox(height: 16),
            // "التعليقات" (Quick Comments) — MERGED with the former
            // employee-only "التحديثات والملاحظات من الموظف" section, since
            // both display the same underlying `activityLog` array and
            // serve the same purpose (short, contextual notes on the
            // task). Now writable by BOTH manager and employee — see
            // TaskProvider.addComment doc comment for the full rationale.
            const Text(
              'التعليقات',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (current.activityLog.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'لا توجد تعليقات بعد',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ...current.activityLog.reversed.map(
                (e) => _ActivityLogTile(entry: e),
              ),
            const SizedBox(height: 8),
            _CommentInputBox(
              onSubmit: (text) => context.read<TaskProvider>().addComment(
                taskId: current.taskId,
                authorUid: managerUid,
                text: text,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'سجل المهمة الكامل',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'لا يوجد سجل بعد',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ...history.reversed.map((h) => _HistoryTile(entry: h)),
            const SizedBox(height: 90),
          ],
        ),
      ),
      bottomNavigationBar: current.status == TaskStatus.submitted
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.statusRejected,
                          side: const BorderSide(
                            color: AppColors.statusRejected,
                          ),
                        ),
                        onPressed: _submitting ? null : () => _decide('reject'),
                        icon: const Icon(Icons.close),
                        label: const Text('رفض'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.statusPending,
                          side: const BorderSide(
                            color: AppColors.statusPending,
                          ),
                        ),
                        onPressed: _submitting
                            ? null
                            : () => _decide('edit_request'),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('طلب تعديل'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.statusApproved,
                        ),
                        onPressed: _submitting
                            ? null
                            : () => _decide('approve'),
                        icon: const Icon(Icons.check),
                        label: const Text('موافقة'),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }
}

/// Manager-only control panel: تحديث الحالة / تحويل لموظف آخر / حذف المهمة /
/// إغلاق. Rendered unconditionally regardless of task status (unlike the
/// `bottomNavigationBar` approve/reject/edit_request trio, which stays
/// gated to `status == submitted`). "إغلاق" is a pure no-op navigation back
/// to the task list — equivalent to "leave as is".
class _ManagerActionsPanel extends StatelessWidget {
  const _ManagerActionsPanel({
    required this.onUpdateStatus,
    required this.onTransfer,
    required this.onDelete,
    required this.onClose,
  });

  final VoidCallback onUpdateStatus;
  final VoidCallback onTransfer;
  final VoidCallback onDelete;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إجراءات المدير',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onUpdateStatus,
                    icon: const Icon(Icons.sync_alt),
                    label: const Text('تحديث الحالة'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onTransfer,
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('تحويل لموظف آخر'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusRejected,
                      side: const BorderSide(color: AppColors.statusRejected),
                    ),
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('حذف المهمة'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: onClose,
                    icon: const Icon(Icons.close),
                    label: const Text('إغلاق'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// AppBar action opening the per-task chat thread with the employee. Shows
/// an unread-count badge when the employee has sent unread messages tied to
/// this specific task.
class _TaskChatButton extends StatelessWidget {
  const _TaskChatButton({
    required this.taskId,
    required this.managerUid,
    required this.employeeUid,
  });

  final String taskId;
  final String managerUid;
  final String employeeUid;

  @override
  Widget build(BuildContext context) {
    final conversationId = ChatMessage.taskConversationId(taskId);

    return StreamBuilder<List<ChatMessage>>(
      stream: context.watch<MessageProvider>().watchConversation(
        conversationId,
      ),
      initialData: context.read<MessageProvider>().conversation(conversationId),
      builder: (context, snapshot) {
        final unread = (snapshot.data ?? [])
            .where((m) => m.recipientUid == managerUid && m.readAt == null)
            .length;
        return IconButton(
          tooltip: 'محادثة المهمة',
          icon: Badge(
            isLabelVisible: unread > 0,
            label: Text('$unread'),
            child: const Icon(Icons.chat_bubble_outline),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatThreadScreen(
                  conversationId: conversationId,
                  taskId: taskId,
                  currentUserUid: managerUid,
                  otherUserUid: employeeUid,
                  title: 'محادثة المهمة',
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renders one `activityLog` entry — now used for BOTH the legacy
/// employee-authored update/note feature and the new Quick Comments
/// feature (comments from manager OR employee), which were merged into
/// this single array/tile per the explicit "check overlap, merge instead
/// of duplicating" instruction. Distinct from [_HistoryTile] (which
/// renders the separate `task_history` audit-log collection driven by
/// lifecycle transitions). Shows author name + timestamp + text, per the
/// Quick Comments requirement.
class _ActivityLogTile extends StatelessWidget {
  final ActivityLogEntry entry;
  const _ActivityLogTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final authorName =
        FirestoreService.getUser(entry.updatedBy)?.name ?? 'مستخدم';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.statusPending.withValues(alpha: 0.05),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.note_alt_outlined),
        title: entry.note != null && entry.note!.isNotEmpty
            ? Text(entry.note!, style: const TextStyle(fontSize: 13))
            : const Text(
                '(بدون نص)',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
        subtitle: Text(
          '$authorName • '
          '${intl.DateFormat('yyyy/MM/dd HH:mm').format(entry.updatedAt)}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Inline "تعليقات سريعة" input box: a plain multi-line [TextField] plus an
/// "إرسال" (Send) [FilledButton] — deliberately NOT a modal dialog (unlike
/// the legacy `_addActivityLogNote` flow this feature supersedes on the
/// employee screen), per the explicit requirement of a simple inline text
/// box + Send button under the comment list. Duplicated verbatim in
/// `task_detail_screen.dart`, matching this codebase's existing convention
/// of per-screen private widgets (see `_ActivityLogTile`/`_HistoryTile`).
class _CommentInputBox extends StatefulWidget {
  const _CommentInputBox({required this.onSubmit});

  final Future<void> Function(String text) onSubmit;

  @override
  State<_CommentInputBox> createState() => _CommentInputBoxState();
}

class _CommentInputBoxState extends State<_CommentInputBox> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    await widget.onSubmit(text);
    if (!mounted) return;
    _controller.clear();
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          enabled: !_sending,
          minLines: 1,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'اكتب تعليقًا سريعًا...',
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, size: 18),
            label: const Text('إرسال'),
          ),
        ),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final TaskHistoryEntry entry;
  const _HistoryTile({required this.entry});

  IconData get _icon {
    switch (entry.action) {
      case HistoryAction.submit:
        return Icons.send_outlined;
      case HistoryAction.approve:
        return Icons.check_circle_outline;
      case HistoryAction.reject:
        return Icons.cancel_outlined;
      case HistoryAction.editRequest:
        return Icons.edit_outlined;
      case HistoryAction.statusChange:
        return Icons.sync_alt;
      case HistoryAction.reassignRequested:
        return Icons.swap_horiz;
      case HistoryAction.reassignApproved:
        return Icons.check_circle_outline;
      case HistoryAction.reassignRejected:
        return Icons.cancel_outlined;
      case HistoryAction.reassignConfirmed:
        return Icons.assignment_turned_in_outlined;
      case HistoryAction.comment:
        return Icons.chat_bubble_outline;
    }
  }

  String get _label {
    switch (entry.action) {
      case HistoryAction.submit:
        return 'إرسال للمراجعة';
      case HistoryAction.approve:
        return 'موافقة المدير';
      case HistoryAction.reject:
        return 'رفض المدير';
      case HistoryAction.editRequest:
        return 'طلب تعديل من المدير';
      case HistoryAction.statusChange:
        return 'تحديث الحالة';
      case HistoryAction.reassignRequested:
        return 'طلب إسناد لموظف آخر';
      case HistoryAction.reassignApproved:
        return 'موافقة على الإسناد';
      case HistoryAction.reassignRejected:
        return 'رفض الإسناد';
      case HistoryAction.reassignConfirmed:
        return 'تأكيد استلام الموظف الجديد';
      case HistoryAction.comment:
        return 'تعليق جديد';
    }
  }

  Color get _color {
    switch (entry.action) {
      case HistoryAction.approve:
      case HistoryAction.reassignApproved:
      case HistoryAction.reassignConfirmed:
        return AppColors.statusApproved;
      case HistoryAction.reject:
      case HistoryAction.reassignRejected:
        return AppColors.statusRejected;
      case HistoryAction.editRequest:
      case HistoryAction.reassignRequested:
        return AppColors.statusPending;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(_icon, color: _color),
        title: Text(
          _label,
          style: TextStyle(fontWeight: FontWeight.w600, color: _color),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              intl.DateFormat('yyyy/MM/dd HH:mm').format(entry.timestamp),
              style: const TextStyle(fontSize: 11),
            ),
            if (entry.note != null && entry.note!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(entry.note!),
              ),
          ],
        ),
      ),
    );
  }
}
