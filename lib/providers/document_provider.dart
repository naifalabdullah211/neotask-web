import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/document_model.dart';
import '../models/notification_model.dart';
import '../services/firestore_service.dart';

class DocumentProvider extends ChangeNotifier {
  static const _uuid = Uuid();

  List<DocumentItem> _documents = [];
  List<DocumentItem> get documents => _documents;

  DocumentProvider() {
    FirestoreService.watchAllDocuments().listen((docs) {
      _documents = docs;
      notifyListeners();
    });
  }

  DocumentItem? byId(String id) {
    for (final document in _documents) {
      if (document.documentId == id) return document;
    }
    return null;
  }

  Future<DocumentItem> addDocument({
    required String title,
    String fileUrl = '',
    String fileName = '',
    String fileType = 'page',
    required String category,
    required String uploadedBy,
    required String uploadedByName,
    String description = '',
    String content = '',
    DocumentKind kind = DocumentKind.knowledgePage,
    String department = 'عام',
    List<String> tags = const [],
    DateTime? reviewDueDate,
  }) async {
    final now = DateTime.now();
    final document = DocumentItem(
      documentId: _uuid.v4(),
      title: title,
      fileUrl: fileUrl,
      fileName: fileName,
      fileType: fileType,
      category: category,
      uploadedBy: uploadedBy,
      uploadedByName: uploadedByName,
      createdAt: now,
      description: description,
      content: content,
      kind: kind,
      department: department,
      tags: tags,
      ownerUid: uploadedBy,
      ownerName: uploadedByName,
      reviewDueDate: reviewDueDate,
      updatedAt: now,
      updatedBy: uploadedBy,
      updatedByName: uploadedByName,
    );
    await _saveVersioned(document, 'إنشاء الإصدار الأول');
    return document;
  }

  Future<DocumentItem> updateContent({
    required DocumentItem document,
    required String title,
    required String description,
    required String content,
    required String category,
    required String department,
    required List<String> tags,
    required DocumentKind kind,
    required String actorUid,
    required String actorName,
    required String changeNote,
    DateTime? reviewDueDate,
  }) async {
    final updated = document.copyWith(
      title: title,
      description: description,
      content: content,
      category: category,
      department: department,
      tags: tags,
      kind: kind,
      status: DocumentWorkflowStatus.draft,
      version: document.version + 1,
      updatedAt: DateTime.now(),
      updatedBy: actorUid,
      updatedByName: actorName,
      reviewDueDate: reviewDueDate,
      clearApproval: true,
      clearReviewReminder: true,
    );
    await _saveVersioned(updated, changeNote.trim().isEmpty ? 'تحديث المحتوى' : changeNote.trim());
    return updated;
  }

  Future<void> submitForReview({
    required DocumentItem document,
    required String actorUid,
    required String actorName,
    String? reviewerUid,
    String? reviewerName,
  }) async {
    final updated = document.copyWith(
      status: DocumentWorkflowStatus.inReview,
      reviewerUid: reviewerUid,
      reviewerName: reviewerName,
      updatedAt: DateTime.now(),
      updatedBy: actorUid,
      updatedByName: actorName,
    );
    await FirestoreService.saveDocument(updated);
    final recipients = reviewerUid == null
        ? FirestoreService.getAllManagers().map((user) => user.uid)
        : [reviewerUid];
    await _notify(
      recipients: recipients,
      document: updated,
      title: 'وثيقة بانتظار المراجعة',
      body: 'أرسل $actorName الوثيقة «${document.title}» للمراجعة',
      type: NotificationType.knowledgeReview,
    );
  }

  Future<void> approve({
    required DocumentItem document,
    required String actorUid,
    required String actorName,
    required DateTime reviewDueDate,
  }) async {
    final now = DateTime.now();
    final updated = document.copyWith(
      status: DocumentWorkflowStatus.approved,
      approvedAt: now,
      approvedBy: actorUid,
      approvedByName: actorName,
      reviewDueDate: reviewDueDate,
      updatedAt: now,
      updatedBy: actorUid,
      updatedByName: actorName,
      clearReviewReminder: true,
    );
    await FirestoreService.saveDocument(updated);
    await _notify(
      recipients: [document.ownerUid],
      document: updated,
      title: 'تم اعتماد الوثيقة',
      body: 'اعتمد $actorName الوثيقة «${document.title}»',
      type: NotificationType.knowledgeReview,
    );
  }

  Future<void> returnToDraft({
    required DocumentItem document,
    required String actorUid,
    required String actorName,
    required String note,
  }) async {
    final updated = document.copyWith(
      status: DocumentWorkflowStatus.draft,
      updatedAt: DateTime.now(),
      updatedBy: actorUid,
      updatedByName: actorName,
      clearApproval: true,
      clearReviewReminder: true,
    );
    await FirestoreService.saveDocument(updated);
    await _notify(
      recipients: [document.ownerUid],
      document: updated,
      title: 'أعيدت الوثيقة للتعديل',
      body: note,
      type: NotificationType.knowledgeReview,
    );
  }

  Future<void> archive({
    required DocumentItem document,
    required String actorUid,
    required String actorName,
  }) => FirestoreService.saveDocument(
    document.copyWith(
      status: DocumentWorkflowStatus.archived,
      updatedAt: DateTime.now(),
      updatedBy: actorUid,
      updatedByName: actorName,
    ),
  );

  Future<void> linkTask(DocumentItem document, String taskId) async {
    if (document.linkedTaskIds.contains(taskId)) return;
    await FirestoreService.saveDocument(
      document.copyWith(linkedTaskIds: [...document.linkedTaskIds, taskId]),
    );
  }

  Future<void> restoreRevision({
    required DocumentItem document,
    required DocumentRevision revision,
    required String actorUid,
    required String actorName,
  }) async {
    final restored = document.copyWith(
      title: revision.title,
      description: revision.description,
      content: revision.content,
      category: revision.category,
      department: revision.department,
      tags: revision.tags,
      kind: revision.kind,
      fileUrl: revision.fileUrl,
      fileName: revision.fileName,
      status: DocumentWorkflowStatus.draft,
      version: document.version + 1,
      updatedAt: DateTime.now(),
      updatedBy: actorUid,
      updatedByName: actorName,
      clearApproval: true,
      clearReviewReminder: true,
    );
    await _saveVersioned(restored, 'استعادة محتوى الإصدار ${revision.version}');
  }

  Stream<List<DocumentRevision>> revisionsFor(String documentId) =>
      FirestoreService.watchDocumentRevisions(documentId);

  Stream<List<DocumentComment>> commentsFor(String documentId) =>
      FirestoreService.watchDocumentComments(documentId);

  Future<void> addComment({
    required DocumentItem document,
    required String authorUid,
    required String authorName,
    required String body,
    String anchorText = '',
    required List<String> mentionUids,
  }) async {
    final comment = DocumentComment(
      commentId: _uuid.v4(),
      documentId: document.documentId,
      authorUid: authorUid,
      authorName: authorName,
      body: body.trim(),
      anchorText: anchorText.trim(),
      mentionUids: mentionUids.toSet().where((uid) => uid != authorUid).toList(),
      createdAt: DateTime.now(),
    );
    await FirestoreService.saveDocumentComment(comment);
    await _notify(
      recipients: comment.mentionUids,
      document: document,
      title: 'ذُكرت في تعليق',
      body: '$authorName: ${comment.body}',
      type: NotificationType.knowledgeMention,
    );
  }

  Future<void> deleteDocument(String documentId) =>
      FirestoreService.deleteDocument(documentId);

  List<DocumentItem> filter({
    String category = 'الكل',
    DocumentWorkflowStatus? status,
    String query = '',
  }) {
    final needle = query.trim().toLowerCase();
    return _documents.where((document) {
      final categoryMatch = category == 'الكل' || document.category == category;
      final statusMatch = status == null || document.status == status;
      final text = '${document.title} ${document.description} ${document.content} '
          '${document.department} ${document.tags.join(' ')}'.toLowerCase();
      return categoryMatch && statusMatch &&
          (needle.isEmpty || text.contains(needle));
    }).toList();
  }

  List<String> get categories {
    final values = <String>{'عام'};
    for (final item in _documents) {
      values.add(item.category);
    }
    return values.toList()..sort();
  }

  Future<void> _saveVersioned(DocumentItem document, String note) async {
    final revision = DocumentRevision(
      revisionId: _uuid.v4(),
      documentId: document.documentId,
      version: document.version,
      title: document.title,
      description: document.description,
      content: document.content,
      category: document.category,
      department: document.department,
      tags: document.tags,
      kind: document.kind,
      fileUrl: document.fileUrl,
      fileName: document.fileName,
      changedByUid: document.updatedBy,
      changedByName: document.updatedByName,
      changeNote: note,
      createdAt: document.updatedAt,
    );
    await FirestoreService.saveDocumentWithRevision(document, revision);
  }

  Future<void> _notify({
    required Iterable<String> recipients,
    required DocumentItem document,
    required String title,
    required String body,
    required NotificationType type,
  }) async {
    for (final uid in recipients.toSet().where((uid) => uid.isNotEmpty)) {
      await FirestoreService.saveNotification(
        AppNotification(
          notificationId: _uuid.v4(),
          recipientUid: uid,
          type: type,
          title: title,
          body: body,
          relatedDocumentId: document.documentId,
          createdAt: DateTime.now(),
        ),
      );
    }
  }
}
