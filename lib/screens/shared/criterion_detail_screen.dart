import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/criterion_history_model.dart';
import '../../models/criterion_model.dart';
import '../../models/message_model.dart';
import '../../models/task_model.dart' show TaskStatus;
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/criterion_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';
import 'chat_thread_screen.dart';

/// The core new UI required by the manager: a Criterion's details on the
/// LEFT and its live chat thread on the RIGHT, Smartsheet-row-comment
/// style (manager's exact words: "المعيار يكون يسار و الدردشة يمين").
///
/// CRITICAL IMPLEMENTATION NOTE — RTL override: `main.dart` wraps the
/// whole app in `Directionality(textDirection: TextDirection.rtl, ...)`.
/// Under RTL, a plain `Row(children: [A, B])` renders A on the PHYSICAL
/// RIGHT and B on the PHYSICAL LEFT (the opposite of what the manager
/// asked for). To guarantee criterion-physically-left / chat-physically-
/// right regardless of the app-wide RTL wrapper, the split-panel `Row`
/// below explicitly sets `textDirection: TextDirection.ltr`.
///
/// JUDGMENT CALL (flagged, not covered by the manager's answers): the
/// manager did not specify a minimum screen width for this side-by-side
/// layout. A true 50/50 split is unusable on a narrow phone in portrait
/// orientation (which is this app's primary target per the system
/// design). So: on wide viewports (>= 700 logical px — tablet/landscape)
/// this renders the literal left/right split; on narrow phones it
/// degrades to two tabs ordered "المعيار" (first/left-reading-position)
/// then "المحادثة" (second/right-reading-position), preserving the same
/// reading-order intent without an unusable cramped split.
class CriterionDetailScreen extends StatelessWidget {
  const CriterionDetailScreen({super.key, required this.criterionId});

  final String criterionId;

  @override
  Widget build(BuildContext context) {
    final criterionProvider = context.watch<CriterionProvider>();
    final criterion = criterionProvider.getCriterion(criterionId);
    final currentUser = context.watch<AuthProvider>().currentUser!;
    final isManager = context.watch<AuthProvider>().isManager;

    if (criterion == null) {
      return const Scaffold(body: Center(child: Text('المعيار غير موجود')));
    }

    // Group-chat-over-a-shared-conversationId design (JUDGMENT CALL): a
    // Criterion may have MULTIPLE assignees (answer "٤"), but ChatMessage
    // requires a single recipientUid per message. All participants read
    // the SAME conversationId (`criterion_$criterionId`) regardless of
    // recipientUid — so every message is visible to everyone on the
    // thread; recipientUid only affects whose per-message "unread" flag
    // is set. When the manager sends, recipientUid targets the FIRST
    // assigned employee (read-receipts for the others are best-effort).
    final otherUid = isManager
        ? (criterion.assignedTo.isNotEmpty
              ? criterion.assignedTo.first
              : currentUser.uid)
        : criterion.assignedBy;

    final goal = FirestoreService.getGoal(criterion.goalId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(criterion.title),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              goal != null ? 'ضمن الهدف: ${goal.title}' : '',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            final criterionPanel = _CriterionPanel(
              criterion: criterion,
              currentUser: currentUser,
              isManager: isManager,
            );
            final chatPanel = ChatThreadBody(
              conversationId: ChatMessage.criterionConversationId(
                criterionId,
              ),
              currentUserUid: currentUser.uid,
              otherUserUid: otherUid,
            );

            if (isWide) {
              // Forced LTR order: criterion physically LEFT, chat
              // physically RIGHT, independent of the app-wide RTL wrap.
              return Row(
                textDirection: TextDirection.ltr,
                children: [
                  Expanded(flex: 5, child: criterionPanel),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 6, child: chatPanel),
                ],
              );
            }

            return DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'المعيار'),
                      Tab(text: 'المحادثة'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [criterionPanel, chatPanel],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// LEFT panel — criterion info, status/priority, assignees, due date,
/// history, and the manager's/employee's action buttons. IDENTICAL
/// review-workflow semantics to TaskReviewDetailScreen/TaskDetailScreen
/// (per the manager's answer "٢- نفس سير العمل").
class _CriterionPanel extends StatefulWidget {
  const _CriterionPanel({
    required this.criterion,
    required this.currentUser,
    required this.isManager,
  });

  final Criterion criterion;
  final AppUser currentUser;
  final bool isManager;

  @override
  State<_CriterionPanel> createState() => _CriterionPanelState();
}

class _CriterionPanelState extends State<_CriterionPanel> {
  bool _busy = false;

  Future<void> _startWork() async {
    setState(() => _busy = true);
    await context.read<CriterionProvider>().updateStatus(
      widget.criterion.criterionId,
      TaskStatus.inProgress,
      widget.currentUser.uid,
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _resumeWork() async {
    setState(() => _busy = true);
    await context.read<CriterionProvider>().resumeAfterFeedback(
      widget.criterion.criterionId,
      widget.currentUser.uid,
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _submitForReview() async {
    final noteCtrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إرسال المعيار للمراجعة'),
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
    if (note == null || !mounted) return;
    setState(() => _busy = true);
    await context.read<CriterionProvider>().submitForReview(
      widget.criterion.criterionId,
      widget.currentUser.uid,
      note.trim().isEmpty ? null : note.trim(),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال المعيار للمراجعة بنجاح')),
    );
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

  Future<void> _decide(String decision) async {
    String? note;
    if (decision != 'approve') {
      note = await _promptForNote(decision);
      if (note == null) return;
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
    setState(() => _busy = true);
    try {
      await context.read<CriterionProvider>().reviewDecision(
        criterionId: widget.criterion.criterionId,
        managerUid: widget.currentUser.uid,
        decision: decision,
        note: note,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            decision == 'approve'
                ? 'تمت الموافقة على المعيار'
                : decision == 'reject'
                ? 'تم رفض المعيار'
                : 'تم إرسال طلب التعديل للموظف',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final criterion = widget.criterion;
    final history = context.watch<CriterionProvider>().historyForCriterion(
      criterion.criterionId,
    );
    final assigneeNames = criterion.assignedTo
        .map((uid) => FirestoreService.getUser(uid)?.name ?? 'موظف')
        .join('، ');
    final isAssignedToMe = criterion.assignedTo.contains(
      widget.currentUser.uid,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                criterion.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            StatusChip(statusName: criterion.status.name),
            PriorityBadge(priorityName: criterion.priority.name),
          ],
        ),
        if (criterion.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            criterion.description,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.people_outline,
          label: 'الموظفون المشاركون',
          value: assigneeNames.isEmpty ? 'بدون موظف' : assigneeNames,
        ),
        _InfoRow(
          icon: Icons.event_outlined,
          label: 'تاريخ الاستحقاق',
          value: intl.DateFormat('yyyy/MM/dd').format(criterion.dueDate),
        ),
        if (criterion.submittedAt != null)
          _InfoRow(
            icon: Icons.send_outlined,
            label: 'تاريخ الإرسال',
            value: intl.DateFormat(
              'yyyy/MM/dd HH:mm',
            ).format(criterion.submittedAt!),
          ),
        if (criterion.submissionNote != null &&
            criterion.submissionNote!.isNotEmpty)
          _InfoRow(
            icon: Icons.comment_outlined,
            label: 'ملاحظة الموظف',
            value: criterion.submissionNote!,
          ),
        if (criterion.reviewNote != null && criterion.reviewNote!.isNotEmpty)
          _InfoRow(
            icon: Icons.rate_review_outlined,
            label: 'ملاحظة المدير',
            value: criterion.reviewNote!,
          ),
        const SizedBox(height: 16),

        // ---- Employee actions ----
        if (!widget.isManager && isAssignedToMe) ...[
          if (criterion.status == TaskStatus.assigned)
            ElevatedButton.icon(
              onPressed: _busy ? null : _startWork,
              icon: const Icon(Icons.play_arrow),
              label: const Text('بدء العمل'),
            ),
          if (criterion.status == TaskStatus.inProgress)
            ElevatedButton.icon(
              onPressed: _busy ? null : _submitForReview,
              icon: const Icon(Icons.send_outlined),
              label: const Text('إرسال للمراجعة'),
            ),
          if (criterion.status == TaskStatus.rejected ||
              criterion.status == TaskStatus.editRequested)
            ElevatedButton.icon(
              onPressed: _busy ? null : _resumeWork,
              icon: const Icon(Icons.replay),
              label: const Text('استئناف العمل'),
            ),
          if (criterion.status == TaskStatus.submitted)
            const Text(
              'المعيار قيد المراجعة من المدير',
              style: TextStyle(color: AppColors.statusSubmitted),
            ),
          if (criterion.status == TaskStatus.approved)
            const Text(
              'تمت الموافقة على المعيار',
              style: TextStyle(color: AppColors.statusApproved),
            ),
        ],

        // ---- Manager review actions ----
        if (widget.isManager && criterion.status == TaskStatus.submitted) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusRejected,
                    side: const BorderSide(color: AppColors.statusRejected),
                  ),
                  onPressed: _busy ? null : () => _decide('reject'),
                  icon: const Icon(Icons.close),
                  label: const Text('رفض'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.statusPending,
                    side: const BorderSide(color: AppColors.statusPending),
                  ),
                  onPressed: _busy ? null : () => _decide('edit_request'),
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
                  onPressed: _busy ? null : () => _decide('approve'),
                  icon: const Icon(Icons.check),
                  label: const Text('موافقة'),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 20),
        const Text(
          'سجل المعيار',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (history.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'لا يوجد سجل بعد',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          ...history.reversed.map((h) => _HistoryTile(entry: h)),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

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
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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

class _HistoryTile extends StatelessWidget {
  final CriterionHistoryEntry entry;
  const _HistoryTile({required this.entry});

  IconData get _icon {
    switch (entry.action) {
      case CriterionHistoryAction.submit:
        return Icons.send_outlined;
      case CriterionHistoryAction.approve:
        return Icons.check_circle_outline;
      case CriterionHistoryAction.reject:
        return Icons.cancel_outlined;
      case CriterionHistoryAction.editRequest:
        return Icons.edit_outlined;
      case CriterionHistoryAction.statusChange:
        return Icons.sync_alt;
    }
  }

  String get _label {
    switch (entry.action) {
      case CriterionHistoryAction.submit:
        return 'إرسال للمراجعة';
      case CriterionHistoryAction.approve:
        return 'موافقة المدير';
      case CriterionHistoryAction.reject:
        return 'رفض المدير';
      case CriterionHistoryAction.editRequest:
        return 'طلب تعديل من المدير';
      case CriterionHistoryAction.statusChange:
        return 'تحديث الحالة';
    }
  }

  Color get _color {
    switch (entry.action) {
      case CriterionHistoryAction.approve:
        return AppColors.statusApproved;
      case CriterionHistoryAction.reject:
        return AppColors.statusRejected;
      case CriterionHistoryAction.editRequest:
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
        title: Text(_label, style: TextStyle(fontWeight: FontWeight.w600, color: _color)),
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
