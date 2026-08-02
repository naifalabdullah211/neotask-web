import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/document_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../employee/employee_poll_vote_screen.dart';
import '../employee/task_detail_screen.dart';
import '../manager/manager_poll_detail_screen.dart';
import '../manager/poll_report_screen.dart';
import '../manager/task_review_detail_screen.dart';
import 'knowledge_document_detail_screen.dart';

/// In-app notification inbox — accessible from the [NotificationBell] in
/// both `manager_home_screen.dart` and `employee_home_screen.dart`.
///
/// Renders every [AppNotification] for [userUid] (newest first), marking
/// each one read the moment it is tapped.
///
/// UPGRADED (Phase E) routing for the multi-status voting lifecycle:
///   - [NotificationType.pollEnded] (manager-only, "انتهى التصويت"): opens
///     [PollReportScreen] DIRECTLY (per the exact requirement "اضغط لعرض
///     النتيجة"), not [ManagerPollDetailScreen].
///   - [NotificationType.voteReminder] (employee-only, "حث الموظفين على
///     التصويت"): opens [EmployeePollVoteScreen] directly so the employee
///     can vote immediately.
///   - [NotificationType.pollTieNeedsDecision] (legacy, manager-only):
///     still opens [ManagerPollDetailScreen] for backward-compat with any
///     already-persisted notification of this legacy type.
/// [NotificationType.pollTieNeedsDecision] notifications are visually
/// distinguished with an orange accent and a gavel icon.
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
            tooltip: context.tr('تعليم الكل كمقروء'),
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
                    // pollEnded — manager-only, EXACT requirement: tapping
                    // opens the permanent final report DIRECTLY, not the
                    // live detail screen.
                    if (isManager &&
                        n.type == NotificationType.pollEnded &&
                        n.relatedPollId != null &&
                        context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PollReportScreen(pollId: n.relatedPollId!),
                        ),
                      );
                    }
                    // voteReminder — employee-only: jump straight to the
                    // vote screen so the not-yet-voted employee can act
                    // immediately.
                    else if (!isManager &&
                        n.type == NotificationType.voteReminder &&
                        n.relatedPollId != null &&
                        context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EmployeePollVoteScreen(
                            pollId: n.relatedPollId!,
                            employeeUid: userUid,
                          ),
                        ),
                      );
                    }
                    // Legacy pollTieNeedsDecision / pollClosed (manager-
                    // only) — kept for backward-compat with any
                    // already-persisted notification of these legacy
                    // types; opens the live detail screen as before.
                    else if (isManager &&
                        n.relatedPollId != null &&
                        context.mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ManagerPollDetailScreen(pollId: n.relatedPollId!),
                        ),
                      );
                    }
                    if (n.relatedDocumentId != null && context.mounted) {
                      final document = context
                          .read<DocumentProvider>()
                          .byId(n.relatedDocumentId!);
                      final auth = context.read<AuthProvider>();
                      final user = auth.currentUser;
                      if (document != null && user != null && context.mounted) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => KnowledgeDocumentDetailScreen(
                              initialDocument: document,
                              currentUserUid: user.uid,
                              currentUserName: user.name,
                              isManager: auth.isManager,
                              readOnly: auth.isDesigner,
                            ),
                          ),
                        );
                      }
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
    // NEW — automatic reminders feature: distinct accent/icon per type so
    // the inbox visually distinguishes "reminder" (amber, matches
    // AppColors.statusPending used for "قيد الانتظار" elsewhere) from
    // "overdue escalation" (red, matches AppColors.overdue used by
    // TaskUrgencyIndicator for the exact same concept) instead of both
    // falling back to the generic poll icon/color.
    final isDueSoon = notification.type == NotificationType.taskDueSoon;
    final isOverdue = notification.type == NotificationType.taskOverdue;
    // NEW — voting lifecycle upgrade: pollEnded gets a distinct "result
    // ready" green accent + chart icon (distinguishing it from the
    // generic ballot-box icon used for the legacy pollClosed type), and
    // voteReminder gets an amber "campaign" accent/icon matching the
    // "حث الموظفين على التصويت" action's own icon in
    // ManagerPollDetailScreen.
    final isPollEnded = notification.type == NotificationType.pollEnded;
    final isVoteReminder = notification.type == NotificationType.voteReminder;
    final isAutomation = notification.type == NotificationType.automation;
    final isKnowledge =
        notification.type == NotificationType.knowledgeMention ||
        notification.type == NotificationType.knowledgeReview ||
        notification.type == NotificationType.knowledgeReviewDue;
    final Color accent = isTieDecision || isDueSoon || isVoteReminder
        ? AppColors.statusPending
        : isOverdue
        ? AppColors.overdue
        : isPollEnded
        ? AppColors.statusApproved
        : isAutomation
        ? AppColors.mintAccent
        : isKnowledge
        ? AppColors.gold
        : (notification.isRead ? AppColors.textSecondary : AppColors.deepBlue);
    final IconData icon = isTieDecision
        ? Icons.gavel_outlined
        : isDueSoon
        ? Icons.alarm_outlined
        : isOverdue
        ? Icons.warning_amber_rounded
        : isPollEnded
        ? Icons.assessment_outlined
        : isVoteReminder
        ? Icons.campaign_outlined
        : isAutomation
        ? Icons.bolt_outlined
        : isKnowledge
        ? Icons.auto_stories_outlined
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
