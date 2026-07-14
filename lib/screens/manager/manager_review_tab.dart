import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/task_urgency_indicator.dart';
import 'task_review_detail_screen.dart';

/// Manager review queue — shows tasks submitted by employees needing a
/// live, real-time Approve / Reject / Request-Edit decision.
/// Backed by TaskProvider, which listens to Firestore's real-time
/// .snapshots() for near-instant updates the moment an employee submits,
/// synced live across devices.
class ManagerReviewTab extends StatelessWidget {
  const ManagerReviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final submitted = provider.submittedForReview;
    // NEW — employee-initiated reassignment requests (per the manager's
    // answer "٧- مراجعة المدير الحالي": surfaced HERE, inside the existing
    // review tab, rather than a separate tab).
    final reassignRequests = provider.reassignmentRequestsForManager;

    if (submitted.isEmpty && reassignRequests.isEmpty) {
      return const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inbox_outlined,
                  size: 56,
                  color: AppColors.textSecondary,
                ),
                SizedBox(height: 12),
                Text(
                  'لا توجد مهام بانتظار المراجعة حاليًا',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (reassignRequests.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'طلبات إسناد المهام',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
            ...reassignRequests.map((t) => _ReassignRequestCard(task: t)),
            const SizedBox(height: 16),
          ],
          if (submitted.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'مهام بانتظار المراجعة',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ...submitted.map((t) => _SubmittedTaskCard(task: t)),
        ],
      ),
    );
  }
}

class _SubmittedTaskCard extends StatelessWidget {
  const _SubmittedTaskCard({required this.task});
  final AppTask task;

  @override
  Widget build(BuildContext context) {
    final t = task;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: TaskUrgencyDot(task: t),
        title: Text(
          t.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                const StatusChip(statusName: 'submitted'),
                PriorityBadge(priorityName: t.priority.name, compact: true),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'أُرسلت: ${t.submittedAt != null ? intl.DateFormat('yyyy/MM/dd HH:mm').format(t.submittedAt!) : '-'}',
              style: const TextStyle(fontSize: 12),
            ),
            if (t.submissionNote != null && t.submissionNote!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'ملاحظة الموظف: ${t.submissionNote}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            if (t.revisionCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'عدد المراجعات: ${t.revisionCount}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.statusPending,
                  ),
                ),
              ),
          ],
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => TaskReviewDetailScreen(task: t)),
        ),
      ),
    );
  }
}

/// One pending reassignment request awaiting the manager's approve/reject
/// decision. Rejection requires NO note (per answer ٤) — a single tap is
/// sufficient, with a lightweight confirm dialog to prevent accidental taps.
class _ReassignRequestCard extends StatefulWidget {
  const _ReassignRequestCard({required this.task});
  final AppTask task;

  @override
  State<_ReassignRequestCard> createState() => _ReassignRequestCardState();
}

class _ReassignRequestCardState extends State<_ReassignRequestCard> {
  bool _busy = false;

  Future<void> _decide(bool approve) async {
    if (!approve) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('رفض طلب الإسناد'),
          content: const Text(
            'سيتم رفض الطلب وتبقى المهمة كاملة عند الموظف الحالي. هل تريد الاستمرار؟',
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
              child: const Text('تأكيد الرفض'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    final managerUid = context.read<AuthProvider>().currentUser!.uid;
    setState(() => _busy = true);
    await context.read<TaskProvider>().decideReassignmentRequest(
      taskId: widget.task.taskId,
      managerUid: managerUid,
      approve: approve,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(approve ? 'تمت الموافقة على طلب الإسناد' : 'تم رفض طلب الإسناد'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.task;
    final currentEmployee = FirestoreService.getUser(t.assignedTo);
    final proposedEmployee = t.reassignRequestedTo != null
        ? FirestoreService.getUser(t.reassignRequestedTo!)
        : null;

    return Card(
      color: AppColors.statusPending.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'من: ${currentEmployee?.name ?? 'غير معروف'}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                const Icon(Icons.person, size: 16, color: AppColors.statusPending),
                const SizedBox(width: 4),
                Text(
                  'إلى: ${proposedEmployee?.name ?? 'غير معروف'}',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            if (t.reassignRequestedAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'تاريخ الطلب: ${intl.DateFormat('yyyy/MM/dd HH:mm').format(t.reassignRequestedAt!)}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.statusRejected,
                      side: const BorderSide(color: AppColors.statusRejected),
                    ),
                    onPressed: _busy ? null : () => _decide(false),
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text('رفض'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.statusApproved,
                    ),
                    onPressed: _busy ? null : () => _decide(true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('موافقة'),
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
