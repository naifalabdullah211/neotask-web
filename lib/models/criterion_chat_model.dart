/// Chat message model for a single Criterion's dedicated chat thread.
///
/// CRITICAL DESIGN CONSTRAINT (explicit, verbatim requirement from the
/// manager): this is a COMPLETELY SEPARATE chat system from the existing
/// Task-chat / general-DM `ChatMessage` (see message_model.dart). It does
/// NOT share the same Firestore collection, the same Dart model, or the
/// same provider. Each Criterion's chat lives ONLY at the literal Firestore
/// subcollection path:
///
///   goals/{goalId}/criteria/{criteriaId}/chat/{messageId}
///
/// with exactly the three fields the manager specified: [senderId],
/// [text], [timestamp]. No attachments, no read receipts, no
/// recipientUid — this is intentionally a much smaller model than
/// [ChatMessage], matching the spec literally.
class CriterionChatMessage {
  final String messageId;
  final String senderId;
  final String text;
  final DateTime timestamp;

  CriterionChatMessage({
    required this.messageId,
    required this.senderId,
    required this.text,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory CriterionChatMessage.fromMap(String messageId, Map<dynamic, dynamic> map) {
    return CriterionChatMessage(
      messageId: messageId,
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now(),
    );
  }
}
