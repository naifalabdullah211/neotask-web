import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/document_model.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/document_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class KnowledgeDocumentDetailScreen extends StatelessWidget {
  const KnowledgeDocumentDetailScreen({
    super.key,
    required this.initialDocument,
    required this.currentUserUid,
    required this.currentUserName,
    required this.isManager,
    this.readOnly = false,
  });

  final DocumentItem initialDocument;
  final String currentUserUid;
  final String currentUserName;
  final bool isManager;
  final bool readOnly;

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DocumentProvider>();
    final document = provider.byId(initialDocument.documentId) ?? initialDocument;
    final canEdit = !readOnly && document.canEdit(currentUserUid, isManager: isManager);

    return Scaffold(
      appBar: AppBar(
        title: const Text('تفاصيل المعرفة'),
        actions: [
          if (canEdit)
            IconButton(
              tooltip: 'تعديل وإصدار جديد',
              icon: const Icon(Icons.edit_note_outlined),
              onPressed: () => _edit(context, document),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _StatusHeader(document: document),
          const SizedBox(height: AppSpacing.md),
          if (!readOnly)
            _WorkflowActions(
              document: document,
              currentUserUid: currentUserUid,
              currentUserName: currentUserName,
              isManager: isManager,
            ),
          const SizedBox(height: AppSpacing.md),
          _InfoCard(document: document),
          if (document.description.isNotEmpty || document.content.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: 'المحتوى',
              icon: Icons.article_outlined,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (document.description.isNotEmpty)
                    Text(document.description, style: AppTextStyles.bodySecondary),
                  if (document.description.isNotEmpty && document.content.isNotEmpty)
                    const Divider(height: 28),
                  if (document.content.isNotEmpty)
                    SelectableText(document.content, style: AppTextStyles.body),
                ],
              ),
            ),
          ],
          if (document.hasFile) ...[
            const SizedBox(height: AppSpacing.md),
            _SectionCard(
              title: 'الملف المرفق',
              icon: Icons.attach_file,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF2F5F8),
                  child: Icon(Icons.description_outlined, color: AppColors.deepBlue),
                ),
                title: Text(document.fileName.isEmpty ? document.title : document.fileName),
                trailing: const Icon(Icons.open_in_new),
                onTap: () => launchUrl(
                  Uri.parse(document.fileUrl),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _LinkedTasksSection(
            document: document,
            isManager: isManager,
            readOnly: readOnly,
            managerUid: currentUserUid,
            onMessage: (text) => _message(context, text),
          ),
          const SizedBox(height: AppSpacing.md),
          _CommentsSection(
            document: document,
            currentUserUid: currentUserUid,
            currentUserName: currentUserName,
            readOnly: readOnly,
            onMessage: (text) => _message(context, text),
          ),
          const SizedBox(height: AppSpacing.md),
          _VersionsSection(
            document: document,
            canRestore: canEdit,
            currentUserUid: currentUserUid,
            currentUserName: currentUserName,
            onMessage: (text) => _message(context, text),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context, DocumentItem document) async {
    final title = TextEditingController(text: document.title);
    final description = TextEditingController(text: document.description);
    final content = TextEditingController(text: document.content);
    final category = TextEditingController(text: document.category);
    final department = TextEditingController(text: document.department);
    final tags = TextEditingController(text: document.tags.join('، '));
    final note = TextEditingController();
    var kind = document.kind;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('تعديل الإصدار ${document.version + 1}'),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<DocumentKind>(
                    initialValue: kind,
                    decoration: const InputDecoration(labelText: 'نوع المعرفة'),
                    items: DocumentKind.values
                        .map((item) => DropdownMenuItem(
                              value: item,
                              child: Text(documentKindLabelAr(item)),
                            ))
                        .toList(),
                    onChanged: (value) => setDialogState(() => kind = value ?? kind),
                  ),
                  const SizedBox(height: 10),
                  TextField(controller: title, decoration: const InputDecoration(labelText: 'العنوان *')),
                  const SizedBox(height: 10),
                  TextField(controller: description, maxLines: 2, decoration: const InputDecoration(labelText: 'الملخص')),
                  const SizedBox(height: 10),
                  TextField(controller: content, minLines: 5, maxLines: 12, decoration: const InputDecoration(labelText: 'المحتوى')),
                  const SizedBox(height: 10),
                  TextField(controller: category, decoration: const InputDecoration(labelText: 'التصنيف')),
                  const SizedBox(height: 10),
                  TextField(controller: department, decoration: const InputDecoration(labelText: 'القسم')),
                  const SizedBox(height: 10),
                  TextField(controller: tags, decoration: const InputDecoration(labelText: 'الوسوم مفصولة بفاصلة')),
                  const SizedBox(height: 10),
                  TextField(controller: note, decoration: const InputDecoration(labelText: 'ملخص التغيير')),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(
              onPressed: () {
                if (title.text.trim().isNotEmpty) Navigator.pop(context, true);
              },
              child: const Text('حفظ إصدار جديد'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<DocumentProvider>().updateContent(
      document: document,
      title: title.text.trim(),
      description: description.text.trim(),
      content: content.text.trim(),
      category: category.text.trim().isEmpty ? 'عام' : category.text.trim(),
      department: department.text.trim().isEmpty ? 'عام' : department.text.trim(),
      tags: tags.text
          .split(RegExp(r'[,،]'))
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toSet()
          .toList(),
      kind: kind,
      actorUid: currentUserUid,
      actorName: currentUserName,
      changeNote: note.text,
      reviewDueDate: document.reviewDueDate,
    );
    if (context.mounted) _message(context, 'تم حفظ إصدار جديد');
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({required this.document});
  final DocumentItem document;

  @override
  Widget build(BuildContext context) {
    final color = switch (document.status) {
      DocumentWorkflowStatus.draft => AppColors.textSecondary,
      DocumentWorkflowStatus.inReview => AppColors.gold,
      DocumentWorkflowStatus.approved => AppColors.emerald,
      DocumentWorkflowStatus.archived => AppColors.navy,
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppElevation.mediumShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(document.title, style: AppTextStyles.headlineLg.copyWith(fontSize: 24))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(AppRadius.pill)),
                child: Text(documentStatusLabelAr(document.status), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('${documentKindLabelAr(document.kind)} · الإصدار ${document.version}', style: AppTextStyles.bodySm),
        ],
      ),
    );
  }
}

class _WorkflowActions extends StatelessWidget {
  const _WorkflowActions({
    required this.document,
    required this.currentUserUid,
    required this.currentUserName,
    required this.isManager,
  });
  final DocumentItem document;
  final String currentUserUid;
  final String currentUserName;
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<DocumentProvider>();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (document.status == DocumentWorkflowStatus.draft &&
            document.canEdit(currentUserUid, isManager: isManager))
          FilledButton.icon(
            onPressed: () => provider.submitForReview(
              document: document,
              actorUid: currentUserUid,
              actorName: currentUserName,
              reviewerUid: FirestoreService.getManager()?.uid,
              reviewerName: FirestoreService.getManager()?.name,
            ),
            icon: const Icon(Icons.rate_review_outlined),
            label: const Text('إرسال للمراجعة'),
          ),
        if (isManager && document.status == DocumentWorkflowStatus.inReview)
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
            onPressed: () async {
              final due = await showDatePicker(
                context: context,
                initialDate: DateTime.now().add(const Duration(days: 365)),
                firstDate: DateTime.now().add(const Duration(days: 1)),
                lastDate: DateTime.now().add(const Duration(days: 3650)),
                helpText: 'موعد المراجعة القادمة',
              );
              if (due == null || !context.mounted) return;
              await provider.approve(
                document: document,
                actorUid: currentUserUid,
                actorName: currentUserName,
                reviewDueDate: due,
              );
            },
            icon: const Icon(Icons.verified_outlined),
            label: const Text('اعتماد'),
          ),
        if (isManager && document.status == DocumentWorkflowStatus.inReview)
          OutlinedButton.icon(
            onPressed: () async {
              final controller = TextEditingController();
              final note = await showDialog<String>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('إعادة للتعديل'),
                  content: TextField(controller: controller, maxLines: 3, decoration: const InputDecoration(labelText: 'الملاحظة المطلوبة *')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                    FilledButton(onPressed: () {
                      if (controller.text.trim().isNotEmpty) Navigator.pop(context, controller.text.trim());
                    }, child: const Text('إرسال')),
                  ],
                ),
              );
              if (note == null || !context.mounted) return;
              await provider.returnToDraft(
                document: document,
                actorUid: currentUserUid,
                actorName: currentUserName,
                note: note,
              );
            },
            icon: const Icon(Icons.undo),
            label: const Text('إعادة للتعديل'),
          ),
        if (isManager && document.status != DocumentWorkflowStatus.archived)
          TextButton.icon(
            onPressed: () => provider.archive(
              document: document,
              actorUid: currentUserUid,
              actorName: currentUserName,
            ),
            icon: const Icon(Icons.archive_outlined),
            label: const Text('أرشفة'),
          ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.document});
  final DocumentItem document;
  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'بيانات الوثيقة',
    icon: Icons.info_outline,
    child: Wrap(
      spacing: 18,
      runSpacing: 12,
      children: [
        _Meta(label: 'المالك', value: document.ownerName),
        _Meta(label: 'القسم', value: document.department),
        _Meta(label: 'التصنيف', value: document.category),
        _Meta(label: 'آخر تحديث', value: intl.DateFormat('yyyy/MM/dd').format(document.updatedAt)),
        if (document.approvedByName != null) _Meta(label: 'اعتمد بواسطة', value: document.approvedByName!),
        if (document.reviewDueDate != null) _Meta(label: 'المراجعة القادمة', value: intl.DateFormat('yyyy/MM/dd').format(document.reviewDueDate!)),
        if (document.tags.isNotEmpty)
          SizedBox(
            width: double.infinity,
            child: Wrap(spacing: 6, children: document.tags.map((tag) => Chip(label: Text(tag), visualDensity: VisualDensity.compact)).toList()),
          ),
      ],
    ),
  );
}

class _Meta extends StatelessWidget {
  const _Meta({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: AppTextStyles.sectionLabel),
      const SizedBox(height: 3),
      Text(value, style: AppTextStyles.cardTitle),
    ]),
  );
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.icon, required this.child});
  final String title;
  final IconData icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Icon(icon, color: AppColors.deepBlue), const SizedBox(width: 8), Text(title, style: AppTextStyles.screenTitle)]),
        const Divider(height: 24),
        child,
      ]),
    ),
  );
}

class _LinkedTasksSection extends StatelessWidget {
  const _LinkedTasksSection({
    required this.document,
    required this.isManager,
    required this.readOnly,
    required this.managerUid,
    required this.onMessage,
  });
  final DocumentItem document;
  final bool isManager;
  final bool readOnly;
  final String managerUid;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final linked = taskProvider.allTasks.where((task) => document.linkedTaskIds.contains(task.taskId)).toList();
    return _SectionCard(
      title: 'المهام المرتبطة',
      icon: Icons.task_alt,
      child: Column(
        children: [
          if (linked.isEmpty) const Align(alignment: Alignment.centerRight, child: Text('لا توجد مهام مرتبطة', style: AppTextStyles.bodySecondary)),
          ...linked.map((task) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.check_circle_outline, color: AppColors.deepBlue),
                title: Text(task.title),
                subtitle: Text('الاستحقاق: ${intl.DateFormat('yyyy/MM/dd').format(task.dueDate)}'),
              )),
          if (isManager && !readOnly)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _createTask(context),
                icon: const Icon(Icons.add_task),
                label: const Text('إنشاء مهمة مرتبطة'),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _createTask(BuildContext context) async {
    final employees = FirestoreService.getAllEmployees().where((user) => user.accountStatus == AccountStatus.active).toList();
    if (employees.isEmpty) {
      onMessage('لا يوجد موظف نشط لإسناد المهمة');
      return;
    }
    var employee = employees.first;
    var priority = TaskPriority.medium;
    var dueDate = DateTime.now().add(const Duration(days: 7));
    final title = TextEditingController(text: 'تطبيق: ${document.title}');
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('مهمة مرتبطة بالوثيقة'),
          content: SizedBox(
            width: 480,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان المهمة')),
              const SizedBox(height: 10),
              DropdownButtonFormField<AppUser>(
                initialValue: employee,
                decoration: const InputDecoration(labelText: 'المسؤول'),
                items: employees.map((user) => DropdownMenuItem(value: user, child: Text(user.name))).toList(),
                onChanged: (value) => setState(() => employee = value ?? employee),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<TaskPriority>(
                initialValue: priority,
                decoration: const InputDecoration(labelText: 'الأولوية'),
                items: const [
                  DropdownMenuItem(value: TaskPriority.low, child: Text('منخفضة')),
                  DropdownMenuItem(value: TaskPriority.medium, child: Text('متوسطة')),
                  DropdownMenuItem(value: TaskPriority.high, child: Text('عالية')),
                ],
                onChanged: (value) => setState(() => priority = value ?? priority),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('الاستحقاق: ${intl.DateFormat('yyyy/MM/dd').format(dueDate)}'),
                trailing: const Icon(Icons.calendar_month_outlined),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: dueDate, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 730)));
                  if (picked != null) setState(() => dueDate = picked);
                },
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('إنشاء')),
          ],
        ),
      ),
    );
    if (result != true || !context.mounted) return;
    final task = await context.read<TaskProvider>().createTask(
      title: title.text.trim(),
      description: 'مهمة مرتبطة بمركز المعرفة: ${document.title}\n${document.description}',
      assignedTo: employee.uid,
      assignedBy: managerUid,
      dueDate: dueDate,
      priority: priority,
      category: document.category,
      linkedDocumentIds: [document.documentId],
    );
    if (!context.mounted) return;
    await context.read<DocumentProvider>().linkTask(document, task.taskId);
    onMessage('تم إنشاء المهمة وربطها بالوثيقة');
  }
}

class _CommentsSection extends StatelessWidget {
  const _CommentsSection({
    required this.document,
    required this.currentUserUid,
    required this.currentUserName,
    required this.readOnly,
    required this.onMessage,
  });
  final DocumentItem document;
  final String currentUserUid;
  final String currentUserName;
  final bool readOnly;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'التعليقات والمنشن',
    icon: Icons.alternate_email,
    child: StreamBuilder<List<DocumentComment>>(
      stream: context.read<DocumentProvider>().commentsFor(document.documentId),
      builder: (context, snapshot) {
        final comments = snapshot.data ?? const [];
        return Column(children: [
          if (comments.isEmpty) const Align(alignment: Alignment.centerRight, child: Text('لا توجد تعليقات بعد', style: AppTextStyles.bodySecondary)),
          ...comments.map((comment) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  child: Text(
                    comment.authorName.isEmpty
                        ? '?'
                        : comment.authorName.substring(0, 1),
                  ),
                ),
                title: Text(comment.authorName, style: AppTextStyles.cardTitle),
                subtitle: Text(
                  '${comment.anchorText.isEmpty ? '' : 'على: «${comment.anchorText}»\n'}'
                  '${comment.body}\n'
                  '${intl.DateFormat('yyyy/MM/dd HH:mm').format(comment.createdAt)}',
                ),
                isThreeLine: true,
              )),
          if (!readOnly)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(onPressed: () => _add(context), icon: const Icon(Icons.add_comment_outlined), label: const Text('إضافة تعليق')),
            ),
        ]);
      },
    ),
  );

  Future<void> _add(BuildContext context) async {
    final body = TextEditingController();
    final anchor = TextEditingController();
    final users = [...FirestoreService.getAllManagers(), ...FirestoreService.getAllEmployees()];
    final mentions = <String>{};
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('تعليق جديد'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: 'التعليق *')),
                const SizedBox(height: 10),
                TextField(
                  controller: anchor,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'الفقرة أو النص المقصود (اختياري)',
                  ),
                ),
                const SizedBox(height: 12),
                const Text('إشعار أشخاص محددين', style: AppTextStyles.cardTitle),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: users.where((user) => user.uid != currentUserUid).map((user) => FilterChip(
                  label: Text('@${user.name}'),
                  selected: mentions.contains(user.uid),
                  onSelected: (selected) => setState(() => selected ? mentions.add(user.uid) : mentions.remove(user.uid)),
                )).toList()),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
            FilledButton(onPressed: () {
              if (body.text.trim().isNotEmpty) Navigator.pop(context, true);
            }, child: const Text('نشر')),
          ],
        ),
      ),
    );
    if (result != true || !context.mounted) return;
    await context.read<DocumentProvider>().addComment(
      document: document,
      authorUid: currentUserUid,
      authorName: currentUserName,
      body: body.text,
      anchorText: anchor.text,
      mentionUids: mentions.toList(),
    );
    onMessage('تم نشر التعليق');
  }
}

class _VersionsSection extends StatelessWidget {
  const _VersionsSection({
    required this.document,
    required this.canRestore,
    required this.currentUserUid,
    required this.currentUserName,
    required this.onMessage,
  });
  final DocumentItem document;
  final bool canRestore;
  final String currentUserUid;
  final String currentUserName;
  final ValueChanged<String> onMessage;

  @override
  Widget build(BuildContext context) => _SectionCard(
    title: 'سجل الإصدارات',
    icon: Icons.history,
    child: StreamBuilder<List<DocumentRevision>>(
      stream: context.read<DocumentProvider>().revisionsFor(document.documentId),
      builder: (context, snapshot) {
        final revisions = snapshot.data ?? const [];
        return Column(children: revisions.map((revision) => ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(backgroundColor: const Color(0xFFF2F5F8), child: Text('${revision.version}', style: const TextStyle(color: AppColors.deepBlue, fontWeight: FontWeight.bold))),
          title: Text('الإصدار ${revision.version} · ${revision.changedByName}'),
          subtitle: Text('${revision.changeNote}\n${intl.DateFormat('yyyy/MM/dd HH:mm').format(revision.createdAt)}'),
          isThreeLine: true,
          trailing: canRestore && revision.version != document.version
              ? TextButton(onPressed: () async {
                  await context.read<DocumentProvider>().restoreRevision(
                    document: document,
                    revision: revision,
                    actorUid: currentUserUid,
                    actorName: currentUserName,
                  );
                  onMessage('تمت استعادة الإصدار ${revision.version} كإصدار جديد');
                }, child: const Text('استعادة'))
              : null,
        )).toList());
      },
    ),
  );
}
