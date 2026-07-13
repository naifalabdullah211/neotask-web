import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/document_model.dart';
import '../../providers/document_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_theme.dart';

/// Shared documents library ("المستندات") — visible to BOTH manager and
/// employee. Files are uploaded directly to Cloudinary (same unsigned
/// mechanism as chat attachments, see CloudinaryService) and indexed here.
class DocumentsScreen extends StatefulWidget {
  const DocumentsScreen({
    super.key,
    required this.currentUserUid,
    required this.currentUserName,
    required this.isManager,
    this.readOnly = false,
  });

  final String currentUserUid;
  final String currentUserName;
  final bool isManager;

  /// True for the read-only `designer` role (see UserRole.designer):
  /// suppresses the upload FAB entirely. Delete is already naturally
  /// hidden for a designer since `canDelete` requires either
  /// `isManager` (always false for a designer) or `doc.uploadedBy ==
  /// currentUserUid` (a designer never uploads, so never matches) — no
  /// further change to that logic was needed, only the FAB.
  final bool readOnly;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String _selectedCategory = 'الكل';
  bool _uploading = false;

  Future<void> _pickAndUpload() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_outlined,
                color: AppColors.deepBlue,
              ),
              title: const Text('صورة'),
              onTap: () => Navigator.pop(context, 'image'),
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file_outlined,
                color: AppColors.deepBlue,
              ),
              title: const Text('ملف'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
          ],
        ),
      ),
    );
    if (choice == null) return;

    List<int>? bytes;
    String? filename;

    if (choice == 'image') {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;
      bytes = await picked.readAsBytes();
      filename = picked.name;
    } else {
      final result = await FilePicker.pickFiles(withData: true);
      if (result == null || result.files.isEmpty) return;
      bytes = result.files.first.bytes;
      filename = result.files.first.name;
    }

    if (bytes == null) return;
    if (!mounted) return;

    final title = await _promptTitle(filename);
    if (title == null) return;

    setState(() => _uploading = true);
    try {
      final url = await CloudinaryService.uploadBytes(
        bytes: bytes,
        filename: filename,
      );
      if (!mounted) return;
      await context.read<DocumentProvider>().addDocument(
        title: title,
        fileUrl: url,
        fileName: filename,
        fileType: choice,
        category: _selectedCategory == 'الكل' ? 'عام' : _selectedCategory,
        uploadedBy: widget.currentUserUid,
        uploadedByName: widget.currentUserName,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم رفع المستند بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذّر رفع المستند: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<String?> _promptTitle(String defaultName) async {
    final controller = TextEditingController(text: defaultName);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('عنوان المستند'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'العنوان'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('رفع'),
          ),
        ],
      ),
    );
  }

  Future<void> _openDocument(DocumentItem doc) async {
    await launchUrl(
      Uri.parse(doc.fileUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _confirmDelete(DocumentItem doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المستند'),
        content: Text('هل تريد حذف "${doc.title}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusRejected,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<DocumentProvider>().deleteDocument(doc.documentId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentProvider>();
    final docs = provider.filterByCategory(_selectedCategory);
    final categories = ['الكل', ...provider.categories];

    return Scaffold(
      appBar: AppBar(title: const Text('المستندات')),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                itemCount: categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  final selected = cat == _selectedCategory;
                  return ChoiceChip(
                    label: Text(cat),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                  );
                },
              ),
            ),
            if (_uploading) const LinearProgressIndicator(),
            Expanded(
              child: docs.isEmpty
                  ? const Center(
                      child: Text(
                        'لا توجد مستندات بعد',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final canDelete =
                            doc.uploadedBy == widget.currentUserUid ||
                            widget.isManager;
                        return Card(
                          child: ListTile(
                            leading: Icon(
                              doc.fileType == 'image'
                                  ? Icons.image_outlined
                                  : Icons.description_outlined,
                              color: AppColors.deepBlue,
                            ),
                            title: Text(
                              doc.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(
                              '${doc.category} · ${doc.uploadedByName} · '
                              '${intl.DateFormat('yyyy/MM/dd').format(doc.createdAt)}',
                            ),
                            onTap: () => _openDocument(doc),
                            trailing: canDelete
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      color: AppColors.statusRejected,
                                    ),
                                    onPressed: () => _confirmDelete(doc),
                                  )
                                : null,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton(
              onPressed: _uploading ? null : _pickAndUpload,
              child: const Icon(Icons.upload_file),
            ),
    );
  }
}
