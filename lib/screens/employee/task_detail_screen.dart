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

  Future<void> _startWork(String uid) async {
    setState(() => _busy = true);
    await context
        .read<TaskProvider>()
        .updateStatus(widget.task.taskId, TaskStatus.inProgress, uid);
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _resumeWork(String uid) async {
    setState(() => _busy = true);
    await context.read<TaskProvider>().resumeAfterFeedback(
          widget.task.taskId,
          uid,
        );
    if (mounted) setState(() => _busy = false);
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
    final matches =
        taskProvider.allTasks.where((t) => t.taskId == widget.task.taskId);
    final current = matches.isNotEmpty ? matches.first : widget.task;
    final history = taskProvider.historyForTask(current.taskId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('تفاصيل المهمة')),
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
                    _InfoRow('التصنيف', current.category),
                    _InfoRow('تاريخ الاستحقاق',
                        intl.DateFormat('yyyy/MM/dd').format(current.dueDate)),
                    _InfoRow(
                        'التكرار', RecurrenceUtils.recurrenceLabelAr(current)),
                    if (current.reviewNote != null &&
                        current.reviewNote!.isNotEmpty)
                      _InfoRow('ملاحظة المدير الأخيرة', current.reviewNote!),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
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
                      color: (current.status == TaskStatus.rejected
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
            const Text('سجل المهمة الكامل',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (history.isEmpty)
              const Text('لا يوجد سجل بعد',
                  style: TextStyle(color: AppColors.textSecondary))
            else
              ...history.reversed.map((h) => _HistoryTile(entry: h)),
          ],
        ),
      ),
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
                style: const TextStyle(color: AppColors.textSecondary)),
            TextSpan(
                text: value,
                style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        title: Text(_label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(intl.DateFormat('yyyy/MM/dd HH:mm').format(entry.timestamp),
                style: const TextStyle(fontSize: 11)),
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
