/// A persisted in-app notification — lives at `notifications/{notifId}`.
///
/// ARCHITECTURAL NOTE (flagged explicitly, not silently introduced): this
/// is a BRAND NEW system. Prior to this feature, this codebase had NO
/// persistent notification/inbox model anywhere — the only precedent was
/// Flutter's built-in `Badge()` widget wrapping bottom-nav icons with a
/// LIVE, ephemeral count derived on-the-fly from existing collections
/// (e.g. unread-message count, pending-review-task count). That pattern
/// cannot express "the poll closed with a Yes result and here is the full
/// per-employee vote breakdown" as a persisted, re-readable record — hence
/// this new collection + provider + bell icon, built specifically to
/// satisfy the Poll feature's notification requirement (§3), and written
/// so any FUTURE feature needing in-app notifications can reuse it too.
///
/// [recipientUid] scopes each notification to exactly one user — the
/// manager's notification and each employee's notification for the SAME
/// poll-closing event are separate documents with different [payload]
/// content (see PollProvider._dispatchClosureNotifications): the manager's
/// carries the full by-name vote breakdown, the employee's carries only
/// the final result — enforced by constructing genuinely different
/// [payload] maps server-side (client-side here, no backend), not by a
/// shared document with a permissions filter.
enum NotificationType {
  // LEGACY — kept for backward compatibility with existing persisted
  // notification documents from the original binary-poll feature; no
  // longer emitted by new code (see pollEnded below, which replaces it
  // for the "poll finished" event under the 4-status lifecycle upgrade).
  pollClosed,
  pollTieNeedsDecision,
  // NEW — Quick Comments feature (تعليقات سريعة): fired when the manager
  // or the assigned employee adds a comment on a task, notifying the
  // OTHER party. See TaskProvider.addComment.
  taskComment,
  // NEW — Automatic reminders feature (التذكيرات التلقائية):
  //   taskDueSoon: sent ONCE to the assigned employee when a task's
  //     dueDate is <=24h away and the task is still pending/inProgress.
  //     See TaskProvider._maybeDispatchDueSoonAndOverdueNotifications and
  //     AppTask.remindedAt (idempotency guard).
  //   taskOverdue: sent ONCE (per task) to every manager account the
  //     moment a task's dueDate has passed while still not completed.
  //     See AppTask.overdueNotifiedAt (idempotency guard).
  taskDueSoon,
  taskOverdue,
  // NEW — Voting lifecycle upgrade (multi-status/multi-choice polls):
  //   pollEnded: sent ONCE to the poll's creating manager the moment a
  //     poll transitions to PollStatus.ended (natural deadline OR manual
  //     tie-decision-required case still uses pollTieNeedsDecision for
  //     backward-compat with the existing tie-decision UI). Title/body are
  //     the EXACT required strings ("انتهى التصويت" / "انتهى التصويت
  //     على: {title}. اضغط لعرض النتيجة.") and [relatedPollId] routes
  //     directly to PollReportScreen (not ManagerPollDetailScreen) — see
  //     PollProvider._endAndGenerateReport.
  //   voteReminder: sent to a single not-yet-voted eligible employee when
  //     the manager triggers "حث الموظفين على التصويت" — see
  //     PollProvider.remindNotYetVoted (cooldown-gated).
  pollEnded,
  voteReminder,
  automation,
}

class AppNotification {
  final String notificationId;
  final String recipientUid;
  final NotificationType type;
  final String title;
  final String body;
  final String? relatedPollId;
  final String? relatedTaskId; // NEW — Quick Comments feature
  final Map<String, dynamic>? payload; // e.g. per-employee vote breakdown
  final DateTime createdAt;
  final DateTime? readAt;

  AppNotification({
    required this.notificationId,
    required this.recipientUid,
    required this.type,
    required this.title,
    required this.body,
    this.relatedPollId,
    this.relatedTaskId,
    this.payload,
    required this.createdAt,
    this.readAt,
  });

  bool get isRead => readAt != null;

  AppNotification copyWith({DateTime? readAt}) {
    return AppNotification(
      notificationId: notificationId,
      recipientUid: recipientUid,
      type: type,
      title: title,
      body: body,
      relatedPollId: relatedPollId,
      relatedTaskId: relatedTaskId,
      payload: payload,
      createdAt: createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'recipientUid': recipientUid,
      'type': type.name,
      'title': title,
      'body': body,
      'relatedPollId': relatedPollId,
      'relatedTaskId': relatedTaskId,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
    };
  }

  factory AppNotification.fromMap(Map<dynamic, dynamic> map) {
    return AppNotification(
      notificationId: map['notificationId'] as String? ?? '',
      recipientUid: map['recipientUid'] as String? ?? '',
      type: NotificationType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => NotificationType.pollClosed,
      ),
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      relatedPollId: map['relatedPollId'] as String?,
      relatedTaskId: map['relatedTaskId'] as String?,
      payload: (map['payload'] as Map?)?.cast<String, dynamic>(),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      readAt: map['readAt'] != null
          ? DateTime.parse(map['readAt'] as String)
          : null,
    );
  }
}
