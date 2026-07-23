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
/// ATTACHMENTS: [attachmentUrl] holds the secure Cloudinary URL of an
/// uploaded image or file (see CloudinaryService — unsigned client-side
/// upload, no backend required). [attachmentName] preserves the original
/// filename for display, since the Cloudinary upload preset used here does
/// NOT keep the original filename (Use filename: false). [attachmentType]
/// is `'image'` or `'file'`, letting the UI decide between an inline
/// thumbnail vs. a generic file chip without re-parsing the URL.
class ChatMessage {
  final String messageId;
  final String conversationId;
  final String? taskId; // null => general DM; non-null => per-task thread
  final String senderUid;
  final String recipientUid;
  final String text;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentType; // 'image' | 'file' | 'voice'
  final DateTime timestamp;
  final DateTime? readAt;

  /// REPLY-TO-MESSAGE FEATURE: when non-null, this message is a reply to
  /// the message with this `messageId` (within the SAME conversationId —
  /// reply targets are never cross-conversation). The original message's
  /// full content is looked up client-side from the already-loaded
  /// conversation message list (see ChatThreadBody._quotedMessageFor) —
  /// deliberately NOT duplicated/denormalized onto this message, since
  /// the whole conversation is already held in memory (same pattern as
  /// every other list in this codebase — see FirestoreService's
  /// in-memory-cache doc comment). If the original message is ever
  /// unavailable (should not normally happen, since messages are
  /// append-only / delete is disabled — see firestore.rules), the UI
  /// falls back to a "الرسالة الأصلية غير متاحة" placeholder instead of
  /// crashing.
  final String? replyToMessageId;

  ChatMessage({
    required this.messageId,
    required this.conversationId,
    this.taskId,
    required this.senderUid,
    required this.recipientUid,
    required this.text,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentType,
    required this.timestamp,
    this.readAt,
    this.replyToMessageId,
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
      attachmentName: attachmentName,
      attachmentType: attachmentType,
      timestamp: timestamp,
      readAt: readAt ?? this.readAt,
      replyToMessageId: replyToMessageId,
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
      'attachmentName': attachmentName,
      'attachmentType': attachmentType,
      'timestamp': timestamp.toIso8601String(),
      'readAt': readAt?.toIso8601String(),
      'replyToMessageId': replyToMessageId,
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
      attachmentName: map['attachmentName'] as String?,
      attachmentType: map['attachmentType'] as String?,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now(),
      readAt: map['readAt'] != null
          ? DateTime.parse(map['readAt'] as String)
          : null,
      // Safe cast — absent for every message sent before this feature
      // existed, which correctly resolves to "not a reply".
      replyToMessageId: map['replyToMessageId'] as String?,
    );
  }
}
