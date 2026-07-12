import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/document_model.dart';
import '../services/firestore_service.dart';

class DocumentProvider extends ChangeNotifier {
  static const _uuid = Uuid();

  List<DocumentItem> _documents = [];
  List<DocumentItem> get documents => _documents;

  DocumentProvider() {
    _listen();
  }

  void _listen() {
    FirestoreService.watchAllDocuments().listen((docs) {
      _documents = docs;
      notifyListeners();
    });
  }

  Future<void> addDocument({
    required String title,
    required String fileUrl,
    required String fileName,
    required String fileType,
    required String category,
    required String uploadedBy,
    required String uploadedByName,
  }) async {
    final doc = DocumentItem(
      documentId: _uuid.v4(),
      title: title,
      fileUrl: fileUrl,
      fileName: fileName,
      fileType: fileType,
      category: category,
      uploadedBy: uploadedBy,
      uploadedByName: uploadedByName,
      createdAt: DateTime.now(),
    );
    await FirestoreService.saveDocument(doc);
  }

  Future<void> deleteDocument(String documentId) async {
    await FirestoreService.deleteDocument(documentId);
  }

  List<DocumentItem> filterByCategory(String category) {
    if (category == 'الكل') return _documents;
    return _documents.where((d) => d.category == category).toList();
  }

  List<String> get categories {
    final set = <String>{'عام'};
    for (final d in _documents) {
      set.add(d.category);
    }
    return set.toList()..sort();
  }
}
