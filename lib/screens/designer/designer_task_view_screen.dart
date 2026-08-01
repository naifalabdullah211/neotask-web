import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_history_model.dart';
import '../../models/task_model.dart';
import '../../models/message_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/recurrence_utils.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/task_plan_summary.dart';
import '../../widgets/linked_knowledge_card.dart';
import '../shared/chat_thread_screen.dart';

/// Read-only task detail view for the `designer` observer role (see
/// UserRole.designer doc comment in user_model.dart). This is a
/// PURPOSE-BUILT screen, not a flag-retrofit of TaskReviewDetailScreen or
/// TaskDetailScreen — it deliberately contains NO action buttons at all
/// (no approve/reject/edit-request, no start/submit/resume), satisfying
/// the "3-no" absolute-zero-write-access requirement by construction:
/// there is simply no code path here that calls into TaskProvider's
/// write methods.
class DesignerTaskViewScreen extends StatelessWidget {
  const DesignerTaskViewScreen({super.key, required this.task});

  final AppTask task;

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final matches = taskProvider.allTasks.where((t) => t.taskId == task.taskId);
    final current = matches.isNotEmpty ? matches.first : task;
    final history = taskProvider.historyForTask(current.taskId);
    final assignee = FirestoreService.getUser(current.assignedTo);
    final designerUid = context.read<AuthProvider>().currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('عرض المهمة (قراءة فقط)'),
        actions: [
          IconButton(
            tooltip: 'عرض محادثة المهمة',
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () {
              final manager = FirestoreService.getManager();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChatThreadScreen(
                    conversationId: ChatMessage.taskConversationId(
                      current.taskId,
                    ),
                    taskId: current.taskId,
                    currentUserUid: designerUid,
                    otherUserUid: manager?.uid ?? current.assignedTo,
                    title: 'محادثة المهمة',
                    subtitle: 'عرض فقط',
                    readOnly: true,
                  ),
                ),
              );
            },
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
                      icon: Icons.person_outline,
                      label: 'الموظف المكلَّف',
                      value: assignee?.name ?? '-',
                    ),
                    _InfoRow(
                      icon: Icons.category_outlined,
                      label: 'التصنيف',
                      value: current.category,
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
                    if (current.reviewNote != null &&
                        current.reviewNote!.isNotEmpty)
                      _InfoRow(
                        icon: Icons.rate_review_outlined,
                        label: 'ملاحظة المدير',
                        value: current.reviewNote!,
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            TaskPlanSummary(task: current),
            if (current.linkedDocumentIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              LinkedKnowledgeCard(task: current),
            ],
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
            const SizedBox(height: 40),
          ],
        ),
      ),
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
