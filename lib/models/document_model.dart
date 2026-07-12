/// A file/document uploaded by a manager or employee, stored via
/// Cloudinary (same unsigned-upload mechanism used for chat attachments —
/// see CloudinaryService) and indexed here in Firestore for the shared
/// "المستندات" (Documents) library visible to both roles.
class DocumentItem {
  final String documentId;
  final String title;
  final String fileUrl;
  final String fileName;
  final String fileType; // 'image' | 'file'
  final String category;
  final String uploadedBy; // uid
  final String uploadedByName; // denormalized for display without a join
  final DateTime createdAt;

  DocumentItem({
    required this.documentId,
    required this.title,
    required this.fileUrl,
    required this.fileName,
    required this.fileType,
    required this.category,
    required this.uploadedBy,
    required this.uploadedByName,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'documentId': documentId,
      'title': title,
      'fileUrl': fileUrl,
      'fileName': fileName,
      'fileType': fileType,
      'category': category,
      'uploadedBy': uploadedBy,
      'uploadedByName': uploadedByName,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory DocumentItem.fromMap(Map<dynamic, dynamic> map) {
    return DocumentItem(
      documentId: map['documentId'] as String,
      title: map['title'] as String? ?? '',
      fileUrl: map['fileUrl'] as String? ?? '',
      fileName: map['fileName'] as String? ?? '',
      fileType: map['fileType'] as String? ?? 'file',
      category: map['category'] as String? ?? 'عام',
      uploadedBy: map['uploadedBy'] as String? ?? '',
      uploadedByName: map['uploadedByName'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
