import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/message_model.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/message_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../shared/chat_thread_screen.dart';

/// Manager's chat tab — a list of employees (since the manager talks to
/// MANY employees, unlike the employee side which only ever talks to one
/// manager). Tapping an employee opens their general (task-independent) DM
/// thread. Sorted with most-recently-messaged conversations first; shows an
/// unread-count badge per employee and a message preview when available.
///
/// BUG FIX (recurring "بادج المحادثات لا يختفي بعد القراءة" report):
/// root-caused via direct Firestore inspection — the bottom-nav unread
/// badge (`FirestoreService.getTotalUnreadCountForUser`) sums UNREAD
/// messages across ALL of the manager's conversations, general DMs AND
/// per-task threads alike. But this screen previously listed ONLY the
/// general per-employee conversations — a per-task thread (opened via
/// `_TaskChatButton` on a task's own review-detail screen) was never
/// reachable from here. So a manager who read every general conversation
/// on this tab could still see the badge "stuck" at a nonzero number,
/// because 1+ unread messages were sitting in a per-task thread this
/// screen had no way to surface or mark read. Confirmed with a concrete
/// case: task "تدريب ثمانية" (status rejected) held 2 unread employee
/// messages in `task_1cc3f48e-...` addressed to the manager — exactly
/// matching a "stuck 2" badge. FIX: surface every task-scoped conversation
/// with activity in a second section below, so every unread source is
/// reachable (and therefore clearable) from this one screen.
class ManagerChatTab extends StatefulWidget {
  const ManagerChatTab({super.key, required this.managerUid});

  final String managerUid;

  @override
  State<ManagerChatTab> createState() => _ManagerChatTabState();
}

class _ManagerChatTabState extends State<ManagerChatTab> {
  @override
  Widget build(BuildContext context) {
    final employees = FirestoreService.getAllEmployees()
        .where((e) => e.accountStatus == AccountStatus.active)
        .toList();
    final employeesByUid = {for (final e in employees) e.uid: e};

    return Consumer2<MessageProvider, TaskProvider>(
      builder: (context, messageProvider, taskProvider, _) {
        final latest = {
          for (final m in messageProvider.latestMessagesForUser(
            widget.managerUid,
          ))
            m.conversationId: m,
        };

        final sortedEmployees = [...employees];
        sortedEmployees.sort((a, b) {
          final aMsg = latest[ChatMessage.generalConversationId(a.uid)];
          final bMsg = latest[ChatMessage.generalConversationId(b.uid)];
          if (aMsg == null && bMsg == null) return a.name.compareTo(b.name);
          if (aMsg == null) return 1;
          if (bMsg == null) return -1;
          return bMsg.timestamp.compareTo(aMsg.timestamp);
        });

        // Every per-task thread that has at least one message, across
        // every task this manager assigned — previously entirely absent
        // from this screen (see class doc comment above).
        final taskEntries = <_TaskConversationEntry>[];
        for (final task in taskProvider.allTasks) {
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
                widget.managerUid,
              ),
            ),
          );
        }
        taskEntries.sort(
          (a, b) => b.lastMessage.timestamp.compareTo(a.lastMessage.timestamp),
        );

        if (sortedEmployees.isEmpty && taskEntries.isEmpty) {
          return const Center(
            child: Text(
              'لا يوجد موظفون نشطون حاليًا',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          );
        }

        return ListView(
          children: [
            for (final employee in sortedEmployees)
              _EmployeeConversationTile(
                employee: employee,
                managerUid: widget.managerUid,
                lastMessage:
                    latest[ChatMessage.generalConversationId(employee.uid)],
                unread: messageProvider.unreadCountForConversation(
                  ChatMessage.generalConversationId(employee.uid),
                  widget.managerUid,
                ),
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
                  managerUid: widget.managerUid,
                  employeeName:
                      employeesByUid[entry.task.assignedTo]?.name ?? 'موظف',
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

class _EmployeeConversationTile extends StatelessWidget {
  const _EmployeeConversationTile({
    required this.employee,
    required this.managerUid,
    required this.lastMessage,
    required this.unread,
  });

  final AppUser employee;
  final String managerUid;
  final ChatMessage? lastMessage;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final conversationId = ChatMessage.generalConversationId(employee.uid);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.deepBlue,
        child: Text(
          employee.name.isNotEmpty ? employee.name[0] : '?',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      title: Text(employee.name),
      subtitle: Text(
        lastMessage?.text ?? 'لا توجد رسائل بعد',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: AppColors.textSecondary),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (lastMessage != null)
            Text(
              DateFormat('HH:mm').format(lastMessage!.timestamp),
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 11,
              ),
            ),
          if (unread > 0) ...[
            const SizedBox(height: 4),
            Badge(label: Text('$unread')),
          ],
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ChatThreadScreen(
              conversationId: conversationId,
              currentUserUid: managerUid,
              otherUserUid: employee.uid,
              title: employee.name,
            ),
          ),
        );
      },
    );
  }
}

/// One per-task conversation row — makes threads previously reachable
/// ONLY via a specific task's own review-detail screen directly
/// accessible (and therefore mark-as-read-able) from the main chat list,
/// fixing the "stuck badge" bug at its root cause.
class _TaskConversationTile extends StatelessWidget {
  const _TaskConversationTile({
    required this.entry,
    required this.managerUid,
    required this.employeeName,
  });

  final _TaskConversationEntry entry;
  final String managerUid;
  final String employeeName;

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
        '$employeeName · ${entry.lastMessage.text.isNotEmpty ? entry.lastMessage.text : 'مرفق'}',
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
              currentUserUid: managerUid,
              otherUserUid: entry.task.assignedTo,
              title: entry.task.title,
              subtitle: 'محادثة المهمة مع $employeeName',
            ),
          ),
        );
      },
    );
  }
}
