import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_history_model.dart';
import '../../models/task_model.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/recurrence_utils.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/favorite_star_button.dart';
import '../shared/chat_thread_screen.dart';
import '../shared/request_reassignment_dialog.dart';

/// Employee-facing task detail screen. Lets the employee move a task from
/// assigned -> inProgress -> submitted (with optional note), and resume
/// work after a manager's reject/edit-request feedback. Shows the FULL
/// history/audit trail so past revisions are never lost.
class TaskDetailScreen extends StatefulWidget {
  final AppTask task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Clear the "new task" in-app notification badge once the employee
    // actually opens this task's details.
    if (!widget.task.viewedByEmployee) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<TaskProvider>().markTaskViewedByEmployee(
          widget.task.taskId,
        );
      });
    }
  }

  Future<void> _startWork(String uid) async {
    setState(() => _busy = true);
    await context.read<TaskProvider>().updateStatus(
      widget.task.taskId,
      TaskStatus.inProgress,
      uid,
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _requestReassignment(String uid) async {
    await showRequestReassignmentDialog(
      context,
      task: widget.task,
      currentEmployeeUid: uid,
    );
  }

  Future<void> _resumeWork(String uid) async {
    setState(() => _busy = true);
    await context.read<TaskProvider>().resumeAfterFeedback(
      widget.task.taskId,
      uid,
    );
    if (mounted) setState(() => _busy = false);
  }

  /// "تعليقات سريعة" (Quick Comments) — lets the employee add a short
  /// comment on the task AT ANY TIME, regardless of `current.status`
  /// (including after submission to the manager), via the inline
  /// [_CommentInputBox] rendered in the "التعليقات" section below.
  /// SUPERSEDES the old modal-dialog-based `_addActivityLogNote` (removed):
  /// this feature merges that flow into the same `activityLog`-backed
  /// Quick Comments box used identically on the manager's screen, per the
  /// explicit "check overlap, merge instead of duplicating" instruction —
  /// and additionally logs to `task_history` + notifies the manager,
  /// neither of which the old flow did.
  Future<void> _addComment(String uid, String text) async {
    await context.read<TaskProvider>().addComment(
      taskId: widget.task.taskId,
      authorUid: uid,
      text: text,
    );
  }

  Future<void> _submitForReview(String uid) async {
    final noteCtrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إرسال المهمة للمراجعة'),
        content: TextField(
          controller: noteCtrl,
          maxLines: 4,
          decoration: const InputDecoration(
            labelText: 'ملاحظة (اختياري)',
            hintText: 'أضف أي تفاصيل تريد إطلاع المدير عليها...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(noteCtrl.text),
            child: const Text('إرسال'),
          ),
        ],
      ),
    );
    if (note == null || !mounted) return; // cancelled

    final taskProvider = context.read<TaskProvider>();
    setState(() => _busy = true);
    await taskProvider.submitForReview(
      widget.task.taskId,
      uid,
      note.trim().isEmpty ? null : note.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال المهمة للمراجعة بنجاح')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().currentUser!.uid;
    final taskProvider = context.watch<TaskProvider>();
    final matches = taskProvider.allTasks.where(
      (t) => t.taskId == widget.task.taskId,
    );
    final current = matches.isNotEmpty ? matches.first : widget.task;
    final history = taskProvider.historyForTask(current.taskId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('تفاصيل المهمة'),
        actions: [
          FavoriteStarButton(userUid: uid, taskId: current.taskId),
          _TaskChatButton(taskId: current.taskId, employeeUid: uid),
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
                    _InfoRow('التصنيف', current.category),
                    _InfoRow(
                      'تاريخ الاستحقاق',
                      intl.DateFormat('yyyy/MM/dd').format(current.dueDate),
                    ),
                    _InfoRow(
                      'التكرار',
                      RecurrenceUtils.recurrenceLabelAr(current),
                    ),
                    if (current.reviewNote != null &&
                        current.reviewNote!.isNotEmpty)
                      _InfoRow('ملاحظة المدير الأخيرة', current.reviewNote!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // ---- Reassignment-request status banner (NEW feature) ----
            if (current.reassignRequestedStatus == 'pending')
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.statusPending.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'تم إرسال طلب إسناد هذه المهمة لموظف آخر، وهو بانتظار موافقة المدير. يمكنك الاستمرار بالعمل عليها حتى الرد.',
                  style: TextStyle(fontSize: 13),
                ),
              )
            else if (current.reassignRequestedStatus == 'awaitingNewEmployee')
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.statusApproved.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'وافق المدير على إسناد هذه المهمة لموظف آخر، وهي الآن بانتظار تأكيده. المهمة لا تزال معك حتى يتم التأكيد.',
                  style: TextStyle(fontSize: 13),
                ),
              )
            else
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _requestReassignment(uid),
                icon: const Icon(Icons.swap_horiz),
                label: const Text('طلب إسناد المهمة لموظف آخر'),
              ),
            const SizedBox(height: 8),
            if (current.status == TaskStatus.assigned)
              ElevatedButton.icon(
                onPressed: _busy ? null : () => _startWork(uid),
                icon: const Icon(Icons.play_arrow),
                label: const Text('بدء العمل على المهمة'),
              ),
            if (current.status == TaskStatus.inProgress)
              ElevatedButton.icon(
                onPressed: _busy ? null : () => _submitForReview(uid),
                icon: const Icon(Icons.send),
                label: const Text('إرسال للمراجعة'),
              ),
            if (current.status == TaskStatus.rejected ||
                current.status == TaskStatus.editRequested)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color:
                          (current.status == TaskStatus.rejected
                                  ? AppColors.statusRejected
                                  : AppColors.statusPending)
                              .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      current.status == TaskStatus.rejected
                          ? 'تم رفض المهمة من قِبل المدير. السبب: ${current.reviewNote ?? ''}'
                          : 'طلب المدير تعديل المهمة. الملاحظة: ${current.reviewNote ?? ''}',
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : () => _resumeWork(uid),
                    icon: const Icon(Icons.refresh),
                    label: const Text('استئناف العمل على المهمة'),
                  ),
                ],
              ),
            if (current.status == TaskStatus.submitted)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusSubmitted.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'تم إرسال المهمة وهي الآن بانتظار مراجعة المدير.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            if (current.status == TaskStatus.approved)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusApproved.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'تمت الموافقة على هذه المهمة من قِبل المدير. أحسنت!',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            const SizedBox(height: 20),
            // "التعليقات" (Quick Comments) — MERGED with the former
            // employee-only "التحديثات والملاحظات" section (see
            // TaskProvider.addComment doc comment). Now the employee's
            // input goes through the same inline text-box + إرسال button
            // used on the manager's screen, instead of a modal dialog.
            const Text(
              'التعليقات',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (current.activityLog.isEmpty)
              const Text(
                'لا توجد تعليقات بعد',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ...current.activityLog.reversed.map(
                (e) => _ActivityLogTile(entry: e),
              ),
            const SizedBox(height: 8),
            _CommentInputBox(onSubmit: (text) => _addComment(uid, text)),
            const SizedBox(height: 20),
            const Text(
              'سجل المهمة الكامل',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (history.isEmpty)
              const Text(
                'لا يوجد سجل بعد',
                style: TextStyle(color: AppColors.textSecondary),
              )
            else
              ...history.reversed.map((h) => _HistoryTile(entry: h)),
          ],
        ),
      ),
    );
  }
}

/// AppBar action opening the per-task chat thread with the manager. Shows
/// an unread-count badge when the manager has sent unread messages tied to
/// this specific task.
class _TaskChatButton extends StatelessWidget {
  const _TaskChatButton({required this.taskId, required this.employeeUid});

  final String taskId;
  final String employeeUid;

  @override
  Widget build(BuildContext context) {
    final manager = FirestoreService.getManager();
    if (manager == null) return const SizedBox.shrink();
    final conversationId = ChatMessage.taskConversationId(taskId);

    return StreamBuilder<List<ChatMessage>>(
      stream: context.watch<MessageProvider>().watchConversation(
        conversationId,
      ),
      initialData: context.read<MessageProvider>().conversation(conversationId),
      builder: (context, snapshot) {
        final unread = (snapshot.data ?? [])
            .where((m) => m.recipientUid == employeeUid && m.readAt == null)
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
                  currentUserUid: employeeUid,
                  otherUserUid: manager.uid,
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
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            TextSpan(
              text: value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Renders one `activityLog` entry — used for BOTH the legacy
/// employee-authored update/note feature and the new Quick Comments
/// feature (comments from manager OR employee), merged into this single
/// array/tile per the explicit "check overlap, merge instead of
/// duplicating" instruction. Distinct from [_HistoryTile] (which renders
/// the separate `task_history` audit-log collection driven by lifecycle
/// transitions). Shows author name + timestamp + text.
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
/// "إرسال" (Send) [FilledButton] — deliberately NOT a modal dialog, per the
/// explicit requirement of a simple inline text box + Send button under
/// the comment list. Duplicated verbatim from
/// `task_review_detail_screen.dart`, matching this codebase's existing
/// convention of per-screen private widgets (see
/// `_ActivityLogTile`/`_HistoryTile`).
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

  String get _label {
    switch (entry.action) {
      case HistoryAction.submit:
        return 'تم الإرسال للمراجعة';
      case HistoryAction.approve:
        return 'تمت الموافقة';
      case HistoryAction.reject:
        return 'تم الرفض';
      case HistoryAction.editRequest:
        return 'طُلب تعديل';
      case HistoryAction.statusChange:
        return 'تحديث الحالة';
      case HistoryAction.reassignRequested:
        return 'طلب إسناد لموظف آخر';
      case HistoryAction.reassignApproved:
        return 'وافق المدير على الإسناد';
      case HistoryAction.reassignRejected:
        return 'رفض المدير الإسناد';
      case HistoryAction.reassignConfirmed:
        return 'تأكيد استلام المهمة من الموظف الجديد';
      case HistoryAction.comment:
        return 'تعليق جديد';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(
          _label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
                child: Text(entry.note!, style: const TextStyle(fontSize: 12)),
              ),
          ],
        ),
      ),
    );
  }
}
