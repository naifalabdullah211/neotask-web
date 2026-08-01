import 'package:file_picker/file_picker.dart' as fp;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/document_model.dart';
import '../../providers/document_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_theme.dart';
import 'knowledge_document_detail_screen.dart';

/// NeoTask knowledge centre: pages, SOPs, policies, files, approvals and
/// lifecycle management. The constructor remains compatible with the former
/// DocumentsScreen so every manager/employee/designer navigation path stays
/// intact while the feature is upgraded in place.
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
  final bool readOnly;

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  String _category = 'الكل';
  DocumentWorkflowStatus? _status;
  String _query = '';
  bool _busy = false;

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentProvider>();
    final documents = provider.filter(
      category: _category,
      status: _status,
      query: _query,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('مركز المعرفة'),
        actions: [
          Center(
            child: Container(
              margin: const EdgeInsetsDirectional.only(end: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.gold,
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Text('${provider.documents.length} وثيقة', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _KnowledgeHero(documents: provider.documents),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'ابحث في العنوان والمحتوى والوسوم',
                  prefixIcon: Icon(Icons.search),
                ),
              ),
            ),
            SizedBox(
              height: 46,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  ChoiceChip(
                    label: const Text('كل الحالات'),
                    selected: _status == null,
                    onSelected: (_) => setState(() => _status = null),
                  ),
                  const SizedBox(width: 6),
                  ...DocumentWorkflowStatus.values.expand((status) => [
                    ChoiceChip(
                      label: Text(documentStatusLabelAr(status)),
                      selected: _status == status,
                      onSelected: (_) => setState(() => _status = status),
                    ),
                    const SizedBox(width: 6),
                  ]),
                ],
              ),
            ),
            SizedBox(
              height: 42,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                itemCount: provider.categories.length + 1,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final category = index == 0 ? 'الكل' : provider.categories[index - 1];
                  return FilterChip(
                    label: Text(category),
                    selected: category == _category,
                    onSelected: (_) => setState(() => _category = category),
                  );
                },
              ),
            ),
            if (_busy) const LinearProgressIndicator(minHeight: 2),
            Expanded(
              child: documents.isEmpty
                  ? const _EmptyKnowledge()
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1050
                            ? 3
                            : constraints.maxWidth >= 680
                            ? 2
                            : 1;
                        if (columns == 1) {
                          return ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: documents.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) => _DocumentCard(
                              document: documents[index],
                              onOpen: () => _open(documents[index]),
                              onDelete: _canDelete(documents[index]) ? () => _delete(documents[index]) : null,
                            ),
                          );
                        }
                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 2.2,
                          ),
                          itemCount: documents.length,
                          itemBuilder: (context, index) => _DocumentCard(
                            document: documents[index],
                            onOpen: () => _open(documents[index]),
                            onDelete: _canDelete(documents[index]) ? () => _delete(documents[index]) : null,
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
          : FloatingActionButton.extended(
              onPressed: _busy ? null : _showCreateMenu,
              icon: const Icon(Icons.add),
              label: const Text('إضافة معرفة'),
            ),
    );
  }

  bool _canDelete(DocumentItem document) =>
      !widget.readOnly &&
      (widget.isManager || document.ownerUid == widget.currentUserUid || document.uploadedBy == widget.currentUserUid);

  void _open(DocumentItem document) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KnowledgeDocumentDetailScreen(
          initialDocument: document,
          currentUserUid: widget.currentUserUid,
          currentUserName: widget.currentUserName,
          isManager: widget.isManager,
          readOnly: widget.readOnly,
        ),
      ),
    );
  }

  Future<void> _showCreateMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          const ListTile(title: Text('إضافة إلى مركز المعرفة', style: AppTextStyles.screenTitle)),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFEAF0F5), child: Icon(Icons.article_outlined, color: AppColors.deepBlue)),
            title: const Text('إنشاء صفحة معرفة'),
            subtitle: const Text('سياسة أو إجراء أو دليل مكتوب داخل NeoTask'),
            onTap: () => Navigator.pop(context, 'page'),
          ),
          ListTile(
            leading: const CircleAvatar(backgroundColor: Color(0xFFFFF4D9), child: Icon(Icons.upload_file_outlined, color: AppColors.gold)),
            title: const Text('رفع ملف'),
            subtitle: const Text('PDF أو Word أو Excel أو صورة'),
            onTap: () => Navigator.pop(context, 'file'),
          ),
        ]),
      ),
    );
    if (choice == 'page') await _createPage();
    if (choice == 'file') await _uploadFile();
  }

  Future<void> _createPage() async {
    final data = await _showKnowledgeEditor(defaultKind: DocumentKind.knowledgePage);
    if (data == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final document = await context.read<DocumentProvider>().addDocument(
        title: data.title,
        category: data.category,
        uploadedBy: widget.currentUserUid,
        uploadedByName: widget.currentUserName,
        description: data.description,
        content: data.content,
        kind: data.kind,
        department: data.department,
        tags: data.tags,
      );
      _message('تم إنشاء صفحة المعرفة');
      if (mounted) _open(document);
    } catch (error) {
      _message('تعذّر إنشاء الصفحة: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadFile() async {
    final result = await fp.FilePicker.platform.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || !mounted) {
      _message('تعذّرت قراءة الملف');
      return;
    }
    final data = await _showKnowledgeEditor(
      defaultKind: DocumentKind.file,
      defaultTitle: file.name,
      contentOptional: true,
    );
    if (data == null || !mounted) return;
    setState(() => _busy = true);
    try {
      final url = await CloudinaryService.uploadBytes(bytes: bytes, filename: file.name);
      if (!mounted) return;
      final document = await context.read<DocumentProvider>().addDocument(
        title: data.title,
        fileUrl: url,
        fileName: file.name,
        fileType: 'file',
        category: data.category,
        uploadedBy: widget.currentUserUid,
        uploadedByName: widget.currentUserName,
        description: data.description,
        content: data.content,
        kind: data.kind,
        department: data.department,
        tags: data.tags,
      );
      _message('تم رفع الملف وإضافته إلى مركز المعرفة');
      if (mounted) _open(document);
    } catch (error) {
      _message('تعذّر رفع الملف: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_KnowledgeDraft?> _showKnowledgeEditor({
    required DocumentKind defaultKind,
    String defaultTitle = '',
    bool contentOptional = false,
  }) async {
    final title = TextEditingController(text: defaultTitle);
    final description = TextEditingController();
    final content = TextEditingController();
    final category = TextEditingController(text: _category == 'الكل' ? 'عام' : _category);
    final department = TextEditingController(text: 'عام');
    final tags = TextEditingController();
    var kind = defaultKind;
    return showDialog<_KnowledgeDraft>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('بيانات المعرفة'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                DropdownButtonFormField<DocumentKind>(
                  initialValue: kind,
                  decoration: const InputDecoration(labelText: 'النوع'),
                  items: DocumentKind.values.map((item) => DropdownMenuItem(value: item, child: Text(documentKindLabelAr(item)))).toList(),
                  onChanged: (value) => setState(() => kind = value ?? kind),
                ),
                const SizedBox(height: 10),
                TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان *')),
                const SizedBox(height: 10),
                TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'ملخص قصير')),
                const SizedBox(height: 10),
                TextField(controller: content, minLines: contentOptional ? 2 : 5, maxLines: 10, decoration: InputDecoration(labelText: contentOptional ? 'ملاحظات أو محتوى إضافي' : 'المحتوى *')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextField(controller: category, decoration: const InputDecoration(labelText: 'التصنيف'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: department, decoration: const InputDecoration(labelText: 'القسم'))),
                ]),
                const SizedBox(height: 10),
                TextField(controller: tags, decoration: const InputDecoration(labelText: 'الوسوم مفصولة بفاصلة', hintText: 'جودة، JCI، صيدلية')),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isEmpty || (!contentOptional && content.text.trim().isEmpty)) return;
                Navigator.pop(context, _KnowledgeDraft(
                  title: title.text.trim(),
                  description: description.text.trim(),
                  content: content.text.trim(),
                  category: category.text.trim().isEmpty ? 'عام' : category.text.trim(),
                  department: department.text.trim().isEmpty ? 'عام' : department.text.trim(),
                  tags: tags.text.split(RegExp(r'[,،]')).map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toSet().toList(),
                  kind: kind,
                ));
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(DocumentItem document) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف نهائي'),
        content: Text('سيُحذف «${document.title}» مع سجل إصداراته وتعليقاته. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
          FilledButton(style: FilledButton.styleFrom(backgroundColor: AppColors.statusRejected), onPressed: () => Navigator.pop(context, true), child: const Text('حذف')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.read<DocumentProvider>().deleteDocument(document.documentId);
    _message('تم حذف الوثيقة');
  }
}

class _KnowledgeHero extends StatelessWidget {
  const _KnowledgeHero({required this.documents});
  final List<DocumentItem> documents;
  @override
  Widget build(BuildContext context) {
    final approved = documents.where((item) => item.status == DocumentWorkflowStatus.approved).length;
    final review = documents.where((item) => item.status == DocumentWorkflowStatus.inReview).length;
    final due = documents.where((item) => item.reviewDueDate != null && item.reviewDueDate!.isBefore(DateTime.now().add(const Duration(days: 30)))).length;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(AppRadius.lg)),
      child: Wrap(spacing: 24, runSpacing: 10, children: [
        _HeroStat(value: '$approved', label: 'معتمدة', icon: Icons.verified_outlined),
        _HeroStat(value: '$review', label: 'للمراجعة', icon: Icons.rate_review_outlined),
        _HeroStat(value: '$due', label: 'مراجعة قريبة', icon: Icons.event_repeat_outlined),
      ]),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.value, required this.label, required this.icon});
  final String value;
  final String label;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Icon(icon, color: AppColors.goldLight),
    const SizedBox(width: 8),
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
    const SizedBox(width: 5),
    Text(label, style: AppTextStyles.bodySm),
  ]);
}

class _DocumentCard extends StatelessWidget {
  const _DocumentCard({required this.document, required this.onOpen, this.onDelete});
  final DocumentItem document;
  final VoidCallback onOpen;
  final VoidCallback? onDelete;
  @override
  Widget build(BuildContext context) {
    final statusColor = switch (document.status) {
      DocumentWorkflowStatus.draft => AppColors.textSecondary,
      DocumentWorkflowStatus.inReview => AppColors.gold,
      DocumentWorkflowStatus.approved => AppColors.emerald,
      DocumentWorkflowStatus.archived => AppColors.navy,
    };
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: const Color(0xFFF1F5F8), borderRadius: BorderRadius.circular(12)),
              child: Icon(document.kind == DocumentKind.file ? Icons.description_outlined : Icons.menu_book_outlined, color: AppColors.deepBlue),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Row(children: [
                Expanded(child: Text(document.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.cardTitle)),
                Container(width: 8, height: 8, decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle)),
              ]),
              const SizedBox(height: 5),
              Text('${documentStatusLabelAr(document.status)} · ${document.department} · v${document.version}', style: AppTextStyles.bodySecondary),
              const SizedBox(height: 4),
              Text('آخر تحديث ${intl.DateFormat('yyyy/MM/dd').format(document.updatedAt)} · ${document.updatedByName}', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySecondary),
            ])),
            if (onDelete != null)
              PopupMenuButton<String>(
                onSelected: (_) => onDelete!(),
                itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('حذف'))],
              )
            else
              const Icon(Icons.chevron_left, color: AppColors.textSecondary),
          ]),
        ),
      ),
    );
  }
}

class _EmptyKnowledge extends StatelessWidget {
  const _EmptyKnowledge();
  @override
  Widget build(BuildContext context) => const Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.auto_stories_outlined, size: 54, color: AppColors.textSecondary),
      SizedBox(height: 12),
      Text('لا توجد نتائج في مركز المعرفة', style: AppTextStyles.screenTitle),
      SizedBox(height: 5),
      Text('أنشئ سياسة أو إجراء أو ارفع ملفًا', style: AppTextStyles.bodySecondary),
    ]),
  );
}

class _KnowledgeDraft {
  const _KnowledgeDraft({required this.title, required this.description, required this.content, required this.category, required this.department, required this.tags, required this.kind});
  final String title;
  final String description;
  final String content;
  final String category;
  final String department;
  final List<String> tags;
  final DocumentKind kind;
}
