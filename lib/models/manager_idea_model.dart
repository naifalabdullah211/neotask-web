import 'package:cloud_firestore/cloud_firestore.dart';

/// A short improvement idea captured directly from the manager workspace.
class ManagerIdea {
  const ManagerIdea({
    required this.ideaId,
    required this.content,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
    this.status = 'new',
  });

  final String ideaId;
  final String content;
  final String authorUid;
  final String authorName;
  final DateTime createdAt;
  final String status;

  Map<String, dynamic> toMap() => {
    'ideaId': ideaId,
    'content': content,
    'authorUid': authorUid,
    'authorName': authorName,
    'createdAt': Timestamp.fromDate(createdAt),
    'status': status,
  };

  factory ManagerIdea.fromMap(Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    return ManagerIdea(
      ideaId: map['ideaId'] as String? ?? '',
      content: map['content'] as String? ?? '',
      authorUid: map['authorUid'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      createdAt: rawCreatedAt is Timestamp
          ? rawCreatedAt.toDate()
          : DateTime.tryParse(rawCreatedAt?.toString() ?? '') ?? DateTime.now(),
      status: map['status'] as String? ?? 'new',
    );
  }
}
