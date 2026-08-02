import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/message_model.dart';
import '../../models/task_model.dart';
import '../../providers/message_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../shared/chat_thread_screen.dart';

/// Employee's chat tab — the general (task-independent) DM with the
/// manager, PLUS every per-task conversation thread that has activity
/// (added as part of the bottom-nav badge fix below).
///
/// BUG FIX (recurring "بادج المحادثة لا يختفي بعد القراءة" report): same
/// root cause as the manager side (see manager_chat_tab.dart doc
/// comment) — the bottom-nav unread badge sums unread messages across
/// ALL of the employee's conversations, general DM AND per-task threads
/// alike, but this tab previously opened ONLY the general DM directly
/// (`ChatThreadBody` for `generalConversationId`). A per-task thread
/// (opened via `_TaskChatButton` on that task's own detail screen) was
/// never reachable from this tab, so an employee could fully read the
/// general DM and still see the badge stuck at a nonzero count because
/// unread messages remained in an unreachable per-task thread. FIX: this
/// tab now shows the general DM first, then every task conversation with
/// activity below it, so every unread source is reachable from here.
class EmployeeChatTab extends StatelessWidget {
  const EmployeeChatTab({super.key, required this.employeeUid});

  final String employeeUid;

  @override
  Widget build(BuildContext context) {
    final manager = FirestoreService.getManager();
    if (manager == null) {
      return const Center(child: Text('لا يوجد مدير مسجّل حاليًا'));
    }

    return Consumer2<MessageProvider, TaskProvider>(
      builder: (context, messageProvider, taskProvider, _) {
        final generalConversationId = ChatMessage.generalConversationId(
          employeeUid,
        );
        final generalMessages = messageProvider.conversation(
          generalConversationId,
        );
        final generalUnread = messageProvider.unreadCountForConversation(
          generalConversationId,
          employeeUid,
        );

        final taskEntries = <_TaskConversationEntry>[];
        for (final task in taskProvider.tasksForEmployee(employeeUid)) {
          final conversationId = ChatMessage.taskConversationId(task.taskId);
          final messages = messageProvider.conversation(conversationId);
          if (messages.isEmpty) continue;
          taskEntries.add(
            _TaskConversationEntry(
              task: task,
              conversationId: conversationId,
              lastMessage: messages.last,
              unread: messageProvider.unreadCountForConversation(
                conversationId,
                employeeUid,
              ),
            ),
          );
        }
        taskEntries.sort(
          (a, b) => b.lastMessage.timestamp.compareTo(a.lastMessage.timestamp),
        );

        return ListView(
          children: [
            ListTile(
              leading: CircleAvatar(
                backgroundColor: AppColors.deepBlue,
                child: Text(
                  manager.name.isNotEmpty ? manager.name[0] : '?',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              title: Text(manager.name),
              subtitle: Text(
                generalMessages.isEmpty
                    ? 'لا توجد رسائل بعد — ابدأ المحادثة'
                    : generalMessages.last.text.isNotEmpty
                    ? generalMessages.last.text
                    : 'مرفق',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (generalMessages.isNotEmpty)
                    Text(
                      DateFormat(
                        'HH:mm',
                      ).format(generalMessages.last.timestamp),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  if (generalUnread > 0) ...[
                    const SizedBox(height: 4),
                    Badge(label: Text('$generalUnread')),
                  ],
                ],
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatThreadScreen(
                      conversationId: generalConversationId,
                      currentUserUid: employeeUid,
                      otherUserUid: manager.uid,
                      title: manager.name,
                    ),
                  ),
                );
              },
            ),
            if (taskEntries.isNotEmpty) ...[
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'محادثات المهام',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              for (final entry in taskEntries)
                _TaskConversationTile(
                  entry: entry,
                  employeeUid: employeeUid,
                  managerUid: manager.uid,
                ),
            ],
          ],
        );
      },
    );
  }
}

class _TaskConversationEntry {
  _TaskConversationEntry({
    required this.task,
    required this.conversationId,
    required this.lastMessage,
    required this.unread,
  });

  final AppTask task;
  final String conversationId;
  final ChatMessage lastMessage;
  final int unread;
}

class _TaskConversationTile extends StatelessWidget {
  const _TaskConversationTile({
    required this.entry,
    required this.employeeUid,
    required this.managerUid,
  });

  final _TaskConversationEntry entry;
  final String employeeUid;
  final String managerUid;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.gold.withValues(alpha: 0.15),
        child: const Icon(
          Icons.task_alt_outlined,
          color: AppColors.gold,
          size: 20,
        ),
      ),
      title: Text(
        entry.task.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        entry.lastMessage.text.isNotEmpty ? entry.lastMessage.text : 'مرفق',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            DateFormat('HH:mm').format(entry.lastMessage.timestamp),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
            ),
          ),
          if (entry.unread > 0) ...[
            const SizedBox(height: 4),
            Badge(label: Text('${entry.unread}')),
          ],
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatThreadScreen(
              conversationId: entry.conversationId,
              taskId: entry.task.taskId,
              currentUserUid: employeeUid,
              otherUserUid: managerUid,
              title: entry.task.title,
              subtitle: 'محادثة المهمة',
            ),
          ),
        );
      },
    );
  }
}
