import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_history_model.dart';
import '../../models/task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/recurrence_utils.dart';
import '../../widgets/status_chip.dart';

/// Full task detail + three-way review decision screen for the manager.
/// Enforces the mandatory-note rule on Reject / Request-Edit, and shows
/// the FULL audit trail/history (never overwritten across revisions).
class TaskReviewDetailScreen extends StatefulWidget {
  final AppTask task;
  const TaskReviewDetailScreen({super.key, required this.task});

  @override
  State<TaskReviewDetailScreen> createState() =>
      _TaskReviewDetailScreenState();
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_decisionSuccessLabel(decision))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
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
    final title =
        decision == 'reject' ? 'سبب الرفض (إلزامي)' : 'ملاحظة طلب التعديل (إلزامي)';
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
    final current = taskProvider.allTasks
            .where((t) => t.taskId == widget.task.taskId)
            .isNotEmpty
        ? taskProvider.allTasks
            .firstWhere((t) => t.taskId == widget.task.taskId)
        : widget.task;
    final history = taskProvider.historyForTask(current.taskId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('مراجعة المهمة')),
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
                          child: Text(current.title,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        StatusChip(statusName: current.status.name),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(current.description,
                        style:
                            const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 12),
                    _InfoRow(
                        icon: Icons.category_outlined,
                        label: 'التصنيف',
                        value: current.category),
                    _InfoRow(
                        icon: Icons.event_outlined,
                        label: 'تاريخ الاستحقاق',
                        value: intl.DateFormat('yyyy/MM/dd')
                            .format(current.dueDate)),
                    _InfoRow(
                        icon: Icons.repeat,
                        label: 'التكرار',
                        value: RecurrenceUtils.recurrenceLabelAr(current)),
                    if (current.submittedAt != null)
                      _InfoRow(
                          icon: Icons.send_outlined,
                          label: 'تاريخ الإرسال',
                          value: intl.DateFormat('yyyy/MM/dd HH:mm')
                              .format(current.submittedAt!)),
                    if (current.submissionNote != null &&
                        current.submissionNote!.isNotEmpty)
                      _InfoRow(
                          icon: Icons.comment_outlined,
                          label: 'ملاحظة الموظف',
                          value: current.submissionNote!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text('سجل المهمة الكامل',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (history.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('لا يوجد سجل بعد',
                    style: TextStyle(color: AppColors.textSecondary)),
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
                            side:
                                const BorderSide(color: AppColors.statusRejected)),
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
                            side:
                                const BorderSide(color: AppColors.statusPending)),
                        onPressed:
                            _submitting ? null : () => _decide('edit_request'),
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('طلب تعديل'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.statusApproved),
                        onPressed: _submitting ? null : () => _decide('approve'),
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

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text('$label: ',
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary)),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
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
    }
  }

  Color get _color {
    switch (entry.action) {
      case HistoryAction.approve:
        return AppColors.statusApproved;
      case HistoryAction.reject:
        return AppColors.statusRejected;
      case HistoryAction.editRequest:
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
        title: Text(_label,
            style: TextStyle(fontWeight: FontWeight.w600, color: _color)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(intl.DateFormat('yyyy/MM/dd HH:mm').format(entry.timestamp),
                style: const TextStyle(fontSize: 11)),
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
