import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../employee/task_detail_screen.dart';
import '../manager/manager_poll_detail_screen.dart';
import '../manager/task_review_detail_screen.dart';

/// In-app notification inbox — accessible from the [NotificationBell] in
/// both `manager_home_screen.dart` and `employee_home_screen.dart`.
///
/// Renders every [AppNotification] for [userUid] (newest first), marking
/// each one read the moment it is tapped. [NotificationType.pollTieNeedsDecision]
/// notifications (requirement #3's "special notification to manager for
/// manual decision") are visually distinguished with an orange accent and
/// a gavel icon, and tapping one jumps straight to
/// [ManagerPollDetailScreen] for that poll so the manager can act
/// immediately instead of having to locate the poll manually.
class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key, required this.userUid});

  final String userUid;

  @override
  Widget build(BuildContext context) {
    final isManager = context.read<AuthProvider>().isManager;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('الإشعارات'),
        actions: [
          IconButton(
            tooltip: 'تعليم الكل كمقروء',
            icon: const Icon(Icons.done_all),
            onPressed: () => context
                .read<NotificationProvider>()
                .markAllReadForUser(userUid),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<AppNotification>>(
          stream: context.read<NotificationProvider>().watchForUser(userUid),
          builder: (context, snapshot) {
            final notifications = List<AppNotification>.from(
              snapshot.data ?? const <AppNotification>[],
            )..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (notifications.isEmpty) {
              return const Center(
                child: Text(
                  'لا توجد إشعارات',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final n = notifications[index];
                return _NotificationTile(
                  notification: n,
                  isManager: isManager,
                  onTap: () async {
                    if (!n.isRead) {
                      await context.read<NotificationProvider>().markRead(
                        n.notificationId,
                      );
                    }
                    // Only the manager may open ManagerPollDetailScreen —
                    // it reads watchVotesForPoll(), which firestore.rules
                    // restricts to the poll's manager only. An employee's
                    // "result only" notification has no equivalent detail
                    // screen to jump to (by design — see requirement #2's
                    // secrecy rule), so tapping it just marks it read.
                    if (isManager &&
                        n.relatedPollId != null &&
                        context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ManagerPollDetailScreen(pollId: n.relatedPollId!),
                        ),
                      );
                    }
                    // NEW — Quick Comments feature: tapping a task-comment
                    // notification jumps straight to that task's detail
                    // screen (manager -> TaskReviewDetailScreen, employee
                    // -> TaskDetailScreen), matching the poll-notification
                    // navigation pattern above.
                    if (n.relatedTaskId != null && context.mounted) {
                      final task = FirestoreService.getTask(n.relatedTaskId!);
                      if (task != null && context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => isManager
                                ? TaskReviewDetailScreen(task: task)
                                : TaskDetailScreen(task: task),
                          ),
                        );
                      }
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.isManager,
    required this.onTap,
  });

  final AppNotification notification;
  final bool isManager;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isTieDecision =
        notification.type == NotificationType.pollTieNeedsDecision;
    final isTaskComment = notification.type == NotificationType.taskComment;
    final Color accent = isTieDecision
        ? AppColors.statusPending
        : (notification.isRead ? AppColors.textSecondary : AppColors.deepBlue);
    final IconData icon = isTieDecision
        ? Icons.gavel_outlined
        : (isTaskComment
              ? Icons.chat_bubble_outline
              : Icons.how_to_vote_outlined);

    return Card(
      color: notification.isRead ? null : accent.withValues(alpha: 0.06),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isTieDecision
            ? BorderSide(color: accent.withValues(alpha: 0.5))
            : BorderSide.none,
      ),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.15),
          child: Icon(icon, color: accent),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead
                ? FontWeight.normal
                : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(notification.body),
            const SizedBox(height: 4),
            Text(
              intl.DateFormat(
                'yyyy/MM/dd — HH:mm',
              ).format(notification.createdAt),
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        trailing: !notification.isRead
            ? Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              )
            : null,
        isThreeLine: true,
        onTap: onTap,
      ),
    );
  }
}
