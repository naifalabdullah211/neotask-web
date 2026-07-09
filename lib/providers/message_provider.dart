import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/message_model.dart';
import '../services/firestore_service.dart';

/// Reads/writes are intentionally always SCOPED to a conversationId or a
/// userUid (never a global "all messages" query) — this mirrors the rest
/// of the codebase's query-avoids-composite-index discipline (see
/// FirestoreService.getHistoryForTask / getAllInvitations) and keeps every
/// screen's data volume proportional to what it actually displays.
class MessageProvider extends ChangeNotifier {
  static const _uuid = Uuid();

  /// Generic scoped read/watch by an already-resolved conversationId (used
  /// by ChatThreadScreen, which is agnostic to general-vs-per-task scope).
  List<ChatMessage> conversation(String conversationId) {
    return FirestoreService.getMessagesForConversation(conversationId);
  }

  Stream<List<ChatMessage>> watchConversation(String conversationId) {
    return FirestoreService.watchMessagesForConversation(conversationId);
  }

  /// Messages for the general (task-independent) DM between [employeeUid]
  /// and the manager.
  List<ChatMessage> generalConversation(String employeeUid) {
    return FirestoreService.getMessagesForConversation(
      ChatMessage.generalConversationId(employeeUid),
    );
  }

  Stream<List<ChatMessage>> watchGeneralConversation(String employeeUid) {
    return FirestoreService.watchMessagesForConversation(
      ChatMessage.generalConversationId(employeeUid),
    );
  }

  /// Messages for the per-task thread of [taskId].
  List<ChatMessage> taskConversation(String taskId) {
    return FirestoreService.getMessagesForConversation(
      ChatMessage.taskConversationId(taskId),
    );
  }

  Stream<List<ChatMessage>> watchTaskConversation(String taskId) {
    return FirestoreService.watchMessagesForConversation(
      ChatMessage.taskConversationId(taskId),
    );
  }

  /// Latest message per conversation [userUid] participates in — used to
  /// render a conversation list (e.g. manager's per-employee chat list).
  List<ChatMessage> latestMessagesForUser(String userUid) {
    return FirestoreService.getLatestMessagesForUser(userUid);
  }

  Stream<List<ChatMessage>> watchLatestMessagesForUser(String userUid) {
    return FirestoreService.watchLatestMessagesForUser(userUid);
  }

  int unreadCountForConversation(String conversationId, String userUid) {
    return FirestoreService.getUnreadCountForConversation(
      conversationId,
      userUid,
    );
  }

  Stream<int> watchTotalUnreadCountForUser(String userUid) {
    return FirestoreService.watchTotalUnreadCountForUser(userUid);
  }

  int totalUnreadCountForUser(String userUid) {
    return FirestoreService.getTotalUnreadCountForUser(userUid);
  }

  /// Sends a text-only message. [attachmentUrl] is intentionally not
  /// exposed as a parameter here — no calling UI in this release collects
  /// an attachment, so there is nothing to pass. The model field itself
  /// still exists for future-proofing (see message_model.dart doc comment).
  Future<void> sendMessage({
    required String conversationId,
    String? taskId,
    required String senderUid,
    required String recipientUid,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final message = ChatMessage(
      messageId: _uuid.v4(),
      conversationId: conversationId,
      taskId: taskId,
      senderUid: senderUid,
      recipientUid: recipientUid,
      text: trimmed,
      timestamp: DateTime.now(),
    );
    await FirestoreService.saveMessage(message);
  }

  Future<void> sendGeneralMessage({
    required String employeeUid,
    required String senderUid,
    required String recipientUid,
    required String text,
  }) {
    return sendMessage(
      conversationId: ChatMessage.generalConversationId(employeeUid),
      senderUid: senderUid,
      recipientUid: recipientUid,
      text: text,
    );
  }

  Future<void> sendTaskMessage({
    required String taskId,
    required String senderUid,
    required String recipientUid,
    required String text,
  }) {
    return sendMessage(
      conversationId: ChatMessage.taskConversationId(taskId),
      taskId: taskId,
      senderUid: senderUid,
      recipientUid: recipientUid,
      text: text,
    );
  }

  Future<void> markConversationRead(String conversationId, String userUid) {
    return FirestoreService.markConversationRead(conversationId, userUid);
  }
}
