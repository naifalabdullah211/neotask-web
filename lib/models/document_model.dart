enum DocumentWorkflowStatus { draft, inReview, approved, archived }

enum DocumentKind { knowledgePage, policy, procedure, guide, form, file }

String documentStatusLabelAr(DocumentWorkflowStatus status) => switch (status) {
  DocumentWorkflowStatus.draft => 'مسودة',
  DocumentWorkflowStatus.inReview => 'تحت المراجعة',
  DocumentWorkflowStatus.approved => 'معتمد',
  DocumentWorkflowStatus.archived => 'مؤرشف',
};

String documentKindLabelAr(DocumentKind kind) => switch (kind) {
  DocumentKind.knowledgePage => 'صفحة معرفة',
  DocumentKind.policy => 'سياسة',
  DocumentKind.procedure => 'إجراء تشغيلي',
  DocumentKind.guide => 'دليل',
  DocumentKind.form => 'نموذج',
  DocumentKind.file => 'ملف',
};

/// A managed knowledge item. Older records from the original shared file
/// library remain readable because every new field has a safe default.
class DocumentItem {
  final String documentId;
  final String title;
  final String fileUrl;
  final String fileName;
  final String fileType;
  final String category;
  final String uploadedBy;
  final String uploadedByName;
  final DateTime createdAt;
  final String description;
  final String content;
  final DocumentKind kind;
  final String department;
  final List<String> tags;
  final String ownerUid;
  final String ownerName;
  final String? reviewerUid;
  final String? reviewerName;
  final DocumentWorkflowStatus status;
  final int version;
  final DateTime updatedAt;
  final String updatedBy;
  final String updatedByName;
  final DateTime? reviewDueDate;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? approvedByName;
  final DateTime? reviewReminderSentAt;
  final String? reviewReminderForDate;
  final List<String> linkedTaskIds;

  DocumentItem({
    required this.documentId,
    required this.title,
    this.fileUrl = '',
    this.fileName = '',
    this.fileType = 'page',
    required this.category,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.createdAt,
    this.description = '',
    this.content = '',
    this.kind = DocumentKind.file,
    this.department = 'عام',
    this.tags = const [],
    String? ownerUid,
    String? ownerName,
    this.reviewerUid,
    this.reviewerName,
    this.status = DocumentWorkflowStatus.draft,
    this.version = 1,
    DateTime? updatedAt,
    String? updatedBy,
    String? updatedByName,
    this.reviewDueDate,
    this.approvedAt,
    this.approvedBy,
    this.approvedByName,
    this.reviewReminderSentAt,
    this.reviewReminderForDate,
    this.linkedTaskIds = const [],
  }) : ownerUid = ownerUid ?? uploadedBy,
       ownerName = ownerName ?? uploadedByName,
       updatedAt = updatedAt ?? createdAt,
       updatedBy = updatedBy ?? uploadedBy,
       updatedByName = updatedByName ?? uploadedByName;

  bool get hasFile => fileUrl.trim().isNotEmpty;

  bool canEdit(String uid, {required bool isManager}) =>
      isManager || ownerUid == uid || uploadedBy == uid;

  DocumentItem copyWith({
    String? title,
    String? fileUrl,
    String? fileName,
    String? fileType,
    String? category,
    String? description,
    String? content,
    DocumentKind? kind,
    String? department,
    List<String>? tags,
    String? ownerUid,
    String? ownerName,
    String? reviewerUid,
    String? reviewerName,
    DocumentWorkflowStatus? status,
    int? version,
    DateTime? updatedAt,
    String? updatedBy,
    String? updatedByName,
    DateTime? reviewDueDate,
    bool clearReviewDueDate = false,
    DateTime? approvedAt,
    bool clearApproval = false,
    String? approvedBy,
    String? approvedByName,
    DateTime? reviewReminderSentAt,
    String? reviewReminderForDate,
    bool clearReviewReminder = false,
    List<String>? linkedTaskIds,
  }) {
    return DocumentItem(
      documentId: documentId,
      title: title ?? this.title,
      fileUrl: fileUrl ?? this.fileUrl,
      fileName: fileName ?? this.fileName,
      fileType: fileType ?? this.fileType,
      category: category ?? this.category,
      uploadedBy: uploadedBy,
      uploadedByName: uploadedByName,
      createdAt: createdAt,
      description: description ?? this.description,
      content: content ?? this.content,
      kind: kind ?? this.kind,
      department: department ?? this.department,
      tags: tags ?? this.tags,
      ownerUid: ownerUid ?? this.ownerUid,
      ownerName: ownerName ?? this.ownerName,
      reviewerUid: reviewerUid ?? this.reviewerUid,
      reviewerName: reviewerName ?? this.reviewerName,
      status: status ?? this.status,
      version: version ?? this.version,
      updatedAt: updatedAt ?? this.updatedAt,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByName: updatedByName ?? this.updatedByName,
      reviewDueDate: clearReviewDueDate
          ? null
          : (reviewDueDate ?? this.reviewDueDate),
      approvedAt: clearApproval ? null : (approvedAt ?? this.approvedAt),
      approvedBy: clearApproval ? null : (approvedBy ?? this.approvedBy),
      approvedByName: clearApproval
          ? null
          : (approvedByName ?? this.approvedByName),
      reviewReminderSentAt: clearReviewReminder
          ? null
          : (reviewReminderSentAt ?? this.reviewReminderSentAt),
      reviewReminderForDate: clearReviewReminder
          ? null
          : (reviewReminderForDate ?? this.reviewReminderForDate),
      linkedTaskIds: linkedTaskIds ?? this.linkedTaskIds,
    );
  }

  Map<String, dynamic> toMap() => {
    'documentId': documentId,
    'title': title,
    'fileUrl': fileUrl,
    'fileName': fileName,
    'fileType': fileType,
    'category': category,
    'uploadedBy': uploadedBy,
    'uploadedByName': uploadedByName,
    'createdAt': createdAt.toIso8601String(),
    'description': description,
    'content': content,
    'kind': kind.name,
    'department': department,
    'tags': tags,
    'ownerUid': ownerUid,
    'ownerName': ownerName,
    'reviewerUid': reviewerUid,
    'reviewerName': reviewerName,
    'status': status.name,
    'version': version,
    'updatedAt': updatedAt.toIso8601String(),
    'updatedBy': updatedBy,
    'updatedByName': updatedByName,
    'reviewDueDate': reviewDueDate?.toIso8601String(),
    'approvedAt': approvedAt?.toIso8601String(),
    'approvedBy': approvedBy,
    'approvedByName': approvedByName,
    'reviewReminderSentAt': reviewReminderSentAt?.toIso8601String(),
    'reviewReminderForDate': reviewReminderForDate,
    'linkedTaskIds': linkedTaskIds,
  };

  factory DocumentItem.fromMap(Map<dynamic, dynamic> map) {
    final created = _date(map['createdAt']) ?? DateTime.now();
    final uploader = map['uploadedBy'] as String? ?? '';
    final uploaderName = map['uploadedByName'] as String? ?? '';
    return DocumentItem(
      documentId: map['documentId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      fileUrl: map['fileUrl'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      fileType: map['fileType'] as String? ?? 'file',
      category: map['category'] as String? ?? 'عام',
      uploadedBy: uploader,
      uploadedByName: uploaderName,
      createdAt: created,
      description: map['description'] as String? ?? '',
      content: map['content'] as String? ?? '',
      kind: DocumentKind.values.firstWhere(
        (e) => e.name == map['kind'],
        orElse: () => (map['fileUrl'] as String? ?? '').isEmpty
            ? DocumentKind.knowledgePage
            : DocumentKind.file,
      ),
      department: map['department'] as String? ?? 'عام',
      tags: List<String>.from(map['tags'] as List? ?? const []),
      ownerUid: map['ownerUid'] as String? ?? uploader,
      ownerName: map['ownerName'] as String? ?? uploaderName,
      reviewerUid: map['reviewerUid'] as String?,
      reviewerName: map['reviewerName'] as String?,
      status: DocumentWorkflowStatus.values.firstWhere(
        (e) => e.name == map['status'],
        // Legacy shared files were already published to the whole team.
        orElse: () => DocumentWorkflowStatus.approved,
      ),
      version: (map['version'] as num?)?.toInt() ?? 1,
      updatedAt: _date(map['updatedAt']) ?? created,
      updatedBy: map['updatedBy'] as String? ?? uploader,
      updatedByName: map['updatedByName'] as String? ?? uploaderName,
      reviewDueDate: _date(map['reviewDueDate']),
      approvedAt: _date(map['approvedAt']),
      approvedBy: map['approvedBy'] as String?,
      approvedByName: map['approvedByName'] as String?,
      reviewReminderSentAt: _date(map['reviewReminderSentAt']),
      reviewReminderForDate: map['reviewReminderForDate'] as String?,
      linkedTaskIds: List<String>.from(
        map['linkedTaskIds'] as List? ?? const [],
      ),
    );
  }
}

class DocumentRevision {
  final String revisionId;
  final String documentId;
  final int version;
  final String title;
  final String description;
  final String content;
  final String category;
  final String department;
  final List<String> tags;
  final DocumentKind kind;
  final String fileUrl;
  final String fileName;
  final String changedByUid;
  final String changedByName;
  final String changeNote;
  final DateTime createdAt;

  const DocumentRevision({
    required this.revisionId,
    required this.documentId,
    required this.version,
    required this.title,
    required this.description,
    required this.content,
    required this.category,
    required this.department,
    required this.tags,
    required this.kind,
    required this.fileUrl,
    required this.fileName,
    required this.changedByUid,
    required this.changedByName,
    required this.changeNote,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'revisionId': revisionId,
    'documentId': documentId,
    'version': version,
    'title': title,
    'description': description,
    'content': content,
    'category': category,
    'department': department,
    'tags': tags,
    'kind': kind.name,
    'fileUrl': fileUrl,
    'fileName': fileName,
    'changedByUid': changedByUid,
    'changedByName': changedByName,
    'changeNote': changeNote,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DocumentRevision.fromMap(Map<dynamic, dynamic> map) =>
      DocumentRevision(
        revisionId: map['revisionId'] as String? ?? '',
        documentId: map['documentId'] as String? ?? '',
        version: (map['version'] as num?)?.toInt() ?? 1,
        title: map['title'] as String? ?? '',
        description: map['description'] as String? ?? '',
        content: map['content'] as String? ?? '',
        category: map['category'] as String? ?? 'عام',
        department: map['department'] as String? ?? 'عام',
        tags: List<String>.from(map['tags'] as List? ?? const []),
        kind: DocumentKind.values.firstWhere(
          (e) => e.name == map['kind'],
          orElse: () => DocumentKind.knowledgePage,
        ),
        fileUrl: map['fileUrl'] as String? ?? '',
        fileName: map['fileName'] as String? ?? '',
        changedByUid: map['changedByUid'] as String? ?? '',
        changedByName: map['changedByName'] as String? ?? '',
        changeNote: map['changeNote'] as String? ?? '',
        createdAt: _date(map['createdAt']) ?? DateTime.now(),
      );
}

class DocumentComment {
  final String commentId;
  final String documentId;
  final String authorUid;
  final String authorName;
  final String body;
  final String anchorText;
  final List<String> mentionUids;
  final DateTime createdAt;

  const DocumentComment({
    required this.commentId,
    required this.documentId,
    required this.authorUid,
    required this.authorName,
    required this.body,
    this.anchorText = '',
    required this.mentionUids,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'commentId': commentId,
    'documentId': documentId,
    'authorUid': authorUid,
    'authorName': authorName,
    'body': body,
    'anchorText': anchorText,
    'mentionUids': mentionUids,
    'createdAt': createdAt.toIso8601String(),
  };

  factory DocumentComment.fromMap(Map<dynamic, dynamic> map) =>
      DocumentComment(
        commentId: map['commentId'] as String? ?? '',
        documentId: map['documentId'] as String? ?? '',
        authorUid: map['authorUid'] as String? ?? '',
        authorName: map['authorName'] as String? ?? '',
        body: map['body'] as String? ?? '',
        anchorText: map['anchorText'] as String? ?? '',
        mentionUids: List<String>.from(
          map['mentionUids'] as List? ?? const [],
        ),
        createdAt: _date(map['createdAt']) ?? DateTime.now(),
      );
}

DateTime? _date(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString());
}
