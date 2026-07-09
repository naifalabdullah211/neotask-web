import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../providers/message_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../shared/chat_thread_screen.dart';

/// Manager's chat tab — a list of employees (since the manager talks to
/// MANY employees, unlike the employee side which only ever talks to one
/// manager). Tapping an employee opens their general (task-independent) DM
/// thread. Sorted with most-recently-messaged conversations first; shows an
/// unread-count badge per employee and a message preview when available.
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

    if (employees.isEmpty) {
      return const Center(
        child: Text(
          'لا يوجد موظفون نشطون حاليًا',
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return Consumer<MessageProvider>(
      builder: (context, messageProvider, _) {
        final latest = {
          for (final m in messageProvider.latestMessagesForUser(
            widget.managerUid,
          ))
            m.conversationId: m,
        };

        final sorted = [...employees];
        sorted.sort((a, b) {
          final aMsg = latest[ChatMessage.generalConversationId(a.uid)];
          final bMsg = latest[ChatMessage.generalConversationId(b.uid)];
          if (aMsg == null && bMsg == null) return a.name.compareTo(b.name);
          if (aMsg == null) return 1;
          if (bMsg == null) return -1;
          return bMsg.timestamp.compareTo(aMsg.timestamp);
        });

        return ListView.separated(
          itemCount: sorted.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final employee = sorted[index];
            final conversationId = ChatMessage.generalConversationId(
              employee.uid,
            );
            final lastMsg = latest[conversationId];
            final unread = messageProvider.unreadCountForConversation(
              conversationId,
              widget.managerUid,
            );

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
                lastMsg?.text ?? 'لا توجد رسائل بعد',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (lastMsg != null)
                    Text(
                      DateFormat('HH:mm').format(lastMsg.timestamp),
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
                      currentUserUid: widget.managerUid,
                      otherUserUid: employee.uid,
                      title: employee.name,
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
