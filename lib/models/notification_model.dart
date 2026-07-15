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
enum NotificationType { pollClosed, pollTieNeedsDecision }

class AppNotification {
  final String notificationId;
  final String recipientUid;
  final NotificationType type;
  final String title;
  final String body;
  final String? relatedPollId;
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
