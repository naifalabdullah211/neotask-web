/// Chat message model — supports BOTH scopes required by the product spec:
///
/// 1. General (task-independent) direct-message conversation between a single
///    employee and the single manager. `conversationId` for this scope is
///    deterministically derived as `'general_<employeeUid>'` — since there is
///    only ever one manager account (see AuthProvider.ensureManagerExists),
///    this uniquely and stably identifies "the" conversation between that
///    employee and the manager without needing a separate conversations
///    collection.
/// 2. Per-task conversation thread, scoped to a single [AppTask]. For this
///    scope `conversationId` is `'task_<taskId>'` and [taskId] is non-null.
///
/// Using a single deterministic `conversationId` string field (rather than a
/// composite query on two fields) lets every read use a single simple
/// `.where('conversationId', isEqualTo: ...)` query — no Firestore composite
/// index is required, and results are sorted by [timestamp] in memory after
/// fetching (same pattern used elsewhere in this codebase, see
/// FirestoreService.getHistoryForTask / getAllInvitations).
///
/// NOTE ON ATTACHMENTS: [attachmentUrl] exists purely for forward-compatibility
/// so that enabling file/image attachments later (once Firebase Storage
/// billing is provisioned) requires NO model/schema migration — only a new
/// UI control that populates this already-existing field. No attachment
/// UI is rendered anywhere in the current release; this field is always
/// null for every message created today.
class ChatMessage {
  final String messageId;
  final String conversationId;
  final String? taskId; // null => general DM; non-null => per-task thread
  final String senderUid;
  final String recipientUid;
  final String text;
  final String? attachmentUrl; // reserved for future use — always null today
  final DateTime timestamp;
  final DateTime? readAt;

  ChatMessage({
    required this.messageId,
    required this.conversationId,
    this.taskId,
    required this.senderUid,
    required this.recipientUid,
    required this.text,
    this.attachmentUrl,
    required this.timestamp,
    this.readAt,
  });

  /// Deterministic conversationId for the general (task-independent) DM
  /// between [employeeUid] and the single manager account.
  static String generalConversationId(String employeeUid) =>
      'general_$employeeUid';

  /// Deterministic conversationId for the per-task thread of [taskId].
  static String taskConversationId(String taskId) => 'task_$taskId';

  ChatMessage copyWith({DateTime? readAt}) {
    return ChatMessage(
      messageId: messageId,
      conversationId: conversationId,
      taskId: taskId,
      senderUid: senderUid,
      recipientUid: recipientUid,
      text: text,
      attachmentUrl: attachmentUrl,
      timestamp: timestamp,
      readAt: readAt ?? this.readAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'conversationId': conversationId,
      'taskId': taskId,
      'senderUid': senderUid,
      'recipientUid': recipientUid,
      'text': text,
      'attachmentUrl': attachmentUrl,
      'timestamp': timestamp.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
    };
  }

  factory ChatMessage.fromMap(Map<dynamic, dynamic> map) {
    return ChatMessage(
      messageId: map['messageId'] as String,
      conversationId: map['conversationId'] as String? ?? '',
      taskId: map['taskId'] as String?,
      senderUid: map['senderUid'] as String? ?? '',
      recipientUid: map['recipientUid'] as String? ?? '',
      text: map['text'] as String? ?? '',
      attachmentUrl: map['attachmentUrl'] as String?,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now(),
      readAt: map['readAt'] != null
          ? DateTime.parse(map['readAt'] as String)
          : null,
    );
  }
}
