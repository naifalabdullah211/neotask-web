import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/message_model.dart';
import '../../providers/criterion_provider.dart';
import '../../providers/message_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../shared/chat_thread_screen.dart';

/// Read-only "every conversation in the system" tab for the `designer`
/// observer role — satisfies the "1-a" answer that chat/task-chat/
/// criterion-chat CONTENT must also be fully readable, not just
/// task/goal data. Unlike ManagerChatTab (scoped to the manager as
/// participant via `latestMessagesForUser`), this consumes the new
/// UNSCOPED `MessageProvider.watchAllLatestConversations()` so every
/// general DM, per-task thread, and per-criterion thread appears here
/// regardless of which two real participants it belongs to. Tapping a
/// row always opens [ChatThreadScreen] with `readOnly: true`.
class DesignerChatTab extends StatelessWidget {
  const DesignerChatTab({super.key, required this.designerUid});

  final String designerUid;

  /// Resolves a human-readable title + the "other participant" uid (used
  /// only to satisfy ChatThreadScreen's required otherUserUid param — since
  /// the thread is readOnly, no message is ever sent to it) for a given
  /// conversationId, based on its deterministic prefix pattern (see
  /// ChatMessage.generalConversationId / taskConversationId /
  /// criterionConversationId).
  ({String title, String subtitle, String otherUid, String? taskId}) _resolve(
    BuildContext context,
    String conversationId,
  ) {
    final taskProvider = context.read<TaskProvider>();
    final criterionProvider = context.read<CriterionProvider>();

    if (conversationId.startsWith('general_')) {
      final uid = conversationId.substring('general_'.length);
      final user = FirestoreService.getUser(uid);
      return (
        title: user?.name ?? 'موظف',
        subtitle: 'محادثة عامة',
        otherUid: uid,
        taskId: null,
      );
    }
    if (conversationId.startsWith('task_')) {
      final taskId = conversationId.substring('task_'.length);
      final matches = taskProvider.allTasks.where((t) => t.taskId == taskId);
      final task = matches.isNotEmpty ? matches.first : null;
      final manager = FirestoreService.getManager();
      return (
        title: task?.title ?? 'محادثة مهمة',
        subtitle: 'محادثة مهمة',
        otherUid: manager?.uid ?? task?.assignedTo ?? '',
        taskId: taskId,
      );
    }
    if (conversationId.startsWith('criterion_')) {
      final criterionId = conversationId.substring('criterion_'.length);
      final criterion = criterionProvider.getCriterion(criterionId);
      final manager = FirestoreService.getManager();
      final firstAssignee =
          (criterion != null && criterion.assignedTo.isNotEmpty)
          ? criterion.assignedTo.first
          : '';
      return (
        title: criterion?.title ?? 'محادثة معيار',
        subtitle: 'محادثة معيار',
        otherUid: manager?.uid ?? firstAssignee,
        taskId: null,
      );
    }
    return (
      title: conversationId,
      subtitle: 'محادثة',
      otherUid: '',
      taskId: null,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Keep TaskProvider/CriterionProvider "watched" so title/subject
    // resolution stays fresh as tasks/criteria change.
    context.watch<TaskProvider>();
    context.watch<CriterionProvider>();

    return StreamBuilder<List<ChatMessage>>(
      stream: context.read<MessageProvider>().watchAllLatestConversations(),
      initialData: context.read<MessageProvider>().allLatestConversations(),
      builder: (context, snapshot) {
        final conversations = snapshot.data ?? [];
        if (conversations.isEmpty) {
          return const Center(
            child: Text(
              'لا توجد محادثات حتى الآن',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }
        return ListView.separated(
          itemCount: conversations.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final msg = conversations[index];
            final resolved = _resolve(context, msg.conversationId);
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.deepBlue,
                child: Icon(
                  msg.conversationId.startsWith('general_')
                      ? Icons.person_outline
                      : msg.conversationId.startsWith('task_')
                      ? Icons.task_outlined
                      : Icons.flag_outlined,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              title: Text(resolved.title),
              subtitle: Text(
                '${resolved.subtitle} · ${msg.text.isEmpty ? "(مرفق)" : msg.text}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              trailing: Text(
                DateFormat('yyyy/MM/dd HH:mm').format(msg.timestamp),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 11,
                ),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatThreadScreen(
                      conversationId: msg.conversationId,
                      taskId: resolved.taskId,
                      currentUserUid: designerUid,
                      otherUserUid: resolved.otherUid,
                      title: resolved.title,
                      subtitle: '${resolved.subtitle} · عرض فقط',
                      readOnly: true,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
