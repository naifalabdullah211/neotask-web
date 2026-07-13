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

  /// Messages for the per-criterion thread of [criterionId] — the chat
  /// panel required alongside every Criterion (manager's answer
  /// "٥- نص و مرفقات"). Reuses the exact same messages collection/rules
  /// infrastructure as tasks; only the conversationId pattern differs
  /// (see ChatMessage.criterionConversationId).
  List<ChatMessage> criterionConversation(String criterionId) {
    return FirestoreService.getMessagesForConversation(
      ChatMessage.criterionConversationId(criterionId),
    );
  }

  Stream<List<ChatMessage>> watchCriterionConversation(String criterionId) {
    return FirestoreService.watchMessagesForConversation(
      ChatMessage.criterionConversationId(criterionId),
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

  /// Sends a message with optional text and/or attachment. At least one of
  /// [text] or [attachmentUrl] must be non-empty (an attachment-only
  /// message with empty text is valid — e.g. sending just a photo).
  Future<void> sendMessage({
    required String conversationId,
    String? taskId,
    required String senderUid,
    required String recipientUid,
    required String text,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && attachmentUrl == null) return;
    final message = ChatMessage(
      messageId: _uuid.v4(),
      conversationId: conversationId,
      taskId: taskId,
      senderUid: senderUid,
      recipientUid: recipientUid,
      text: trimmed,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      attachmentType: attachmentType,
      timestamp: DateTime.now(),
    );
    await FirestoreService.saveMessage(message);
  }

  Future<void> sendGeneralMessage({
    required String employeeUid,
    required String senderUid,
    required String recipientUid,
    required String text,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
  }) {
    return sendMessage(
      conversationId: ChatMessage.generalConversationId(employeeUid),
      senderUid: senderUid,
      recipientUid: recipientUid,
      text: text,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      attachmentType: attachmentType,
    );
  }

  Future<void> sendTaskMessage({
    required String taskId,
    required String senderUid,
    required String recipientUid,
    required String text,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
  }) {
    return sendMessage(
      conversationId: ChatMessage.taskConversationId(taskId),
      taskId: taskId,
      senderUid: senderUid,
      recipientUid: recipientUid,
      text: text,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      attachmentType: attachmentType,
    );
  }

  /// Sends a message on a Criterion's chat thread — mirrors
  /// [sendTaskMessage] exactly, using the criterion-scoped conversationId.
  /// NOTE: unlike tasks (single `assignedTo` uid), a Criterion may have
  /// MULTIPLE assignees; [recipientUid] here identifies which single
  /// counterpart this particular message is addressed to/from (the caller
  /// — e.g. CriterionDetailScreen — decides that per the current chat
  /// participant pair being displayed).
  Future<void> sendCriterionMessage({
    required String criterionId,
    required String senderUid,
    required String recipientUid,
    required String text,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
  }) {
    return sendMessage(
      conversationId: ChatMessage.criterionConversationId(criterionId),
      senderUid: senderUid,
      recipientUid: recipientUid,
      text: text,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      attachmentType: attachmentType,
    );
  }

  Future<void> markConversationRead(String conversationId, String userUid) {
    return FirestoreService.markConversationRead(conversationId, userUid);
  }

  /// UNSCOPED read of every conversation in the system (general DMs +
  /// per-task + per-criterion threads) — used ONLY by the read-only
  /// `designer` role's chat-browsing screen (see UserRole.designer /
  /// FirestoreService.getAllLatestConversations doc comment). No other
  /// provider consumer should call this; every manager/employee screen
  /// remains correctly scoped to its own participant-based methods above.
  List<ChatMessage> allLatestConversations() {
    return FirestoreService.getAllLatestConversations();
  }

  Stream<List<ChatMessage>> watchAllLatestConversations() {
    return FirestoreService.watchAllLatestConversations();
  }
}
