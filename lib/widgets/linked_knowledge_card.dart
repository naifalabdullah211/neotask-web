import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../models/document_model.dart';
import '../providers/auth_provider.dart';
import '../providers/document_provider.dart';
import '../theme/app_theme.dart';
import '../screens/shared/knowledge_document_detail_screen.dart';

class LinkedKnowledgeCard extends StatelessWidget {
  const LinkedKnowledgeCard({super.key, required this.task});

  final AppTask task;

  @override
  Widget build(BuildContext context) {
    if (task.linkedDocumentIds.isEmpty) return const SizedBox.shrink();
    final provider = context.watch<DocumentProvider>();
    final documents = task.linkedDocumentIds
        .map(provider.byId)
        .whereType<DocumentItem>()
        .toList();
    if (documents.isEmpty) return const SizedBox.shrink();
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    if (user == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_stories_outlined, color: AppColors.gold),
                SizedBox(width: 8),
                Text('المعرفة المرتبطة بالمهمة', style: AppTextStyles.screenTitle),
              ],
            ),
            const Divider(height: 22),
            ...documents.map(
              (document) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFF4D9),
                  child: Icon(Icons.description_outlined, color: AppColors.gold),
                ),
                title: Text(document.title, style: AppTextStyles.cardTitle),
                subtitle: Text('${document.department} · الإصدار ${document.version}'),
                trailing: const Icon(Icons.chevron_left),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => KnowledgeDocumentDetailScreen(
                      initialDocument: document,
                      currentUserUid: user.uid,
                      currentUserName: user.name,
                      isManager: auth.isManager,
                      readOnly: auth.isDesigner,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
