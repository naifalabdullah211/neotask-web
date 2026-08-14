import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/document_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_workspace_chrome.dart';
import '../employee/employee_poll_vote_screen.dart';
import '../employee/task_detail_screen.dart';
import '../manager/manager_poll_detail_screen.dart';
import '../manager/poll_report_screen.dart';
import '../manager/task_review_detail_screen.dart';
import 'knowledge_document_detail_screen.dart';

class NotificationCenterScreen extends StatelessWidget {
  const NotificationCenterScreen({super.key, required this.userUid});

  final String userUid;

  @override
  Widget build(BuildContext context) {
    final isManager = context.read<AuthProvider>().isManager;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'الإشعارات',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: context.tr('تعليم الكل كمقروء'),
            icon: const Icon(Icons.done_all_rounded),
            onPressed: () => context
                .read<NotificationProvider>()
                .markAllReadForUser(userUid),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<AppNotification>>(
          stream: context.read<NotificationProvider>().watchForUser(userUid),
          builder: (context, snapshot) {
            final notifications = List<AppNotification>.from(
              snapshot.data ?? const <AppNotification>[],
            )..sort((a, b) => b.createdAt.compareTo(a.createdAt));

            if (snapshot.connectionState == ConnectionState.waiting &&
                notifications.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }

            final unread = notifications.where((item) => !item.isRead).length;
            final taskRelated = notifications
                .where((item) => item.relatedTaskId != null)
                .length;
            final pollRelated = notifications
                .where((item) => item.relatedPollId != null)
                .length;
            final knowledgeRelated = notifications
                .where((item) => item.relatedDocumentId != null)
                .length;

            return Column(
              children: [
                NeoWorkspaceMetricsBar(
                  items: [
                    NeoWorkspaceMetric(
                      label: 'إجمالي الإشعارات',
                      value: '${notifications.length}',
                      icon: Icons.notifications_none_rounded,
                      color: const Color(0xFF1F6FD2),
                    ),
                    NeoWorkspaceMetric(
                      label: 'غير مقروءة',
                      value: '$unread',
                      icon: Icons.mark_email_unread_outlined,
                      color: AppColors.statusPending,
                    ),
                    NeoWorkspaceMetric(
                      label: 'مرتبطة بمهام',
                      value: '$taskRelated',
                      icon: Icons.task_alt_outlined,
                      color: AppColors.mintAccent,
                    ),
                    NeoWorkspaceMetric(
                      label: 'مرتبطة بتصويت',
                      value: '$pollRelated',
                      icon: Icons.how_to_vote_outlined,
                      color: AppColors.gold,
                    ),
                    NeoWorkspaceMetric(
                      label: 'معرفة ووثائق',
                      value: '$knowledgeRelated',
                      icon: Icons.auto_stories_outlined,
                      color: const Color(0xFF7656C8),
                    ),
                  ],
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        top: BorderSide(color: AppColors.divider),
                      ),
                    ),
                    child: notifications.isEmpty
                        ? const NeoWorkspaceEmptyState(
                            icon: Icons.notifications_none_rounded,
                            title: 'لا توجد إشعارات',
                            message:
                                'ستظهر هنا التنبيهات والتحديثات المرتبطة بمهامك وتصويتاتك ووثائقك.',
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              NeoWorkspaceSectionHeader(
                                title: 'مركز الإشعارات',
                                subtitle: unread == 0
                                    ? 'جميع الإشعارات مقروءة'
                                    : '$unread غير مقروءة وتحتاج انتباهك',
                                trailing: unread == 0
                                    ? const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.statusApproved,
                                      )
                                    : null,
                              ),
                              const Divider(height: 1),
                              Expanded(
                                child: ListView.separated(
                                  padding: const EdgeInsets.all(AppSpacing.lg),
                                  itemCount: notifications.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: AppSpacing.md),
                                  itemBuilder: (context, index) {
                                    final item = notifications[index];
                                    return _NotificationCard(
                                      notification: item,
                                      onTap: () => _openNotification(
                                        context,
                                        notification: item,
                                        isManager: isManager,
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _openNotification(
    BuildContext context, {
    required AppNotification notification,
    required bool isManager,
  }) async {
    if (!notification.isRead) {
      await context
          .read<NotificationProvider>()
          .markRead(notification.notificationId);
    }
    if (!context.mounted) return;

    if (isManager &&
        notification.type == NotificationType.pollEnded &&
        notification.relatedPollId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PollReportScreen(
            pollId: notification.relatedPollId!,
          ),
        ),
      );
      return;
    }

    if (!isManager &&
        notification.type == NotificationType.voteReminder &&
        notification.relatedPollId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmployeePollVoteScreen(
            pollId: notification.relatedPollId!,
            employeeUid: userUid,
          ),
        ),
      );
      return;
    }

    if (isManager && notification.relatedPollId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ManagerPollDetailScreen(
            pollId: notification.relatedPollId!,
          ),
        ),
      );
      return;
    }

    if (notification.relatedDocumentId != null) {
      final document = context
          .read<DocumentProvider>()
          .byId(notification.relatedDocumentId!);
      final auth = context.read<AuthProvider>();
      final user = auth.currentUser;
      if (document != null && user != null && context.mounted) {
        await Navigator.of(context).push(
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
        return;
      }
    }

    if (notification.relatedTaskId != null && context.mounted) {
      final task = FirestoreService.getTask(notification.relatedTaskId!);
      if (task != null) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => isManager
                ? TaskReviewDetailScreen(task: task)
                : TaskDetailScreen(task: task),
          ),
        );
      }
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  final AppNotification notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final style = _styleFor(notification);

    return Material(
      color: notification.isRead
          ? const Color(0xFFF9FBFD)
          : style.color.withValues(alpha: .055),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: notification.isRead
                  ? AppColors.divider
                  : style.color.withValues(alpha: .28),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: style.color.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(style.icon, color: style.color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 14,
                              fontWeight: notification.isRead
                                  ? FontWeight.w700
                                  : FontWeight.w900,
                            ),
                          ),
                        ),
                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsetsDirectional.only(start: 8),
                            decoration: BoxDecoration(
                              color: style.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notification.body,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySecondary.copyWith(
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        const Icon(
                          Icons.schedule_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          intl.DateFormat(
                            'yyyy/MM/dd — HH:mm',
                          ).format(notification.createdAt),
                          style: AppTextStyles.bodySecondary.copyWith(
                            fontSize: 11,
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  _NotificationStyle _styleFor(AppNotification item) {
    final isTieDecision = item.type == NotificationType.pollTieNeedsDecision;
    final isTaskComment = item.type == NotificationType.taskComment;
    final isDueSoon = item.type == NotificationType.taskDueSoon;
    final isOverdue = item.type == NotificationType.taskOverdue;
    final isPollEnded = item.type == NotificationType.pollEnded;
    final isVoteReminder = item.type == NotificationType.voteReminder;
    final isAutomation = item.type == NotificationType.automation;
    final isKnowledge =
        item.type == NotificationType.knowledgeMention ||
        item.type == NotificationType.knowledgeReview ||
        item.type == NotificationType.knowledgeReviewDue;

    if (isTieDecision) {
      return const _NotificationStyle(
        color: AppColors.statusPending,
        icon: Icons.gavel_outlined,
      );
    }
    if (isDueSoon) {
      return const _NotificationStyle(
        color: AppColors.statusPending,
        icon: Icons.alarm_outlined,
      );
    }
    if (isOverdue) {
      return const _NotificationStyle(
        color: AppColors.overdue,
        icon: Icons.warning_amber_rounded,
      );
    }
    if (isPollEnded) {
      return const _NotificationStyle(
        color: AppColors.statusApproved,
        icon: Icons.assessment_outlined,
      );
    }
    if (isVoteReminder) {
      return const _NotificationStyle(
        color: AppColors.statusPending,
        icon: Icons.campaign_outlined,
      );
    }
    if (isAutomation) {
      return const _NotificationStyle(
        color: AppColors.mintAccent,
        icon: Icons.bolt_outlined,
      );
    }
    if (isKnowledge) {
      return const _NotificationStyle(
        color: AppColors.gold,
        icon: Icons.auto_stories_outlined,
      );
    }
    if (isTaskComment) {
      return const _NotificationStyle(
        color: AppColors.deepBlue,
        icon: Icons.chat_bubble_outline_rounded,
      );
    }
    return const _NotificationStyle(
      color: AppColors.steel,
      icon: Icons.notifications_none_rounded,
    );
  }
}

class _NotificationStyle {
  const _NotificationStyle({required this.color, required this.icon});

  final Color color;
  final IconData icon;
}
