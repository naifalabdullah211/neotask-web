import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/favorite_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';
import '../employee/task_detail_screen.dart';
import '../manager/task_review_detail_screen.dart';

/// Starred/favorite tasks ("المفضلة") — scoped to the current user's own
/// stars (see favorite_model.dart: favorites are a per-user relationship,
/// not a shared task property). Works for both manager and employee;
/// tapping a task opens the role-appropriate detail screen.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    super.key,
    required this.currentUserUid,
    required this.isManager,
  });

  final String currentUserUid;
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    final favoriteProvider = context.watch<FavoriteProvider>();
    final favorites = favoriteProvider.favoritesForUser(currentUserUid);
    final tasks = favorites
        .map((f) => FirestoreService.getTask(f.taskId))
        .where((t) => t != null)
        .cast<AppTask>()
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('المفضلة')),
      body: SafeArea(
        child: tasks.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star_border,
                        size: 56,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'لا توجد مهام مفضّلة حتى الآن',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final t = tasks[index];
                  return Card(
                    child: ListTile(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => isManager
                              ? TaskReviewDetailScreen(task: t)
                              : TaskDetailScreen(task: t),
                        ),
                      ),
                      title: Text(
                        t.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${t.category} · ${intl.DateFormat('yyyy/MM/dd').format(t.dueDate)}',
                      ),
                      leading: IconButton(
                        icon: const Icon(Icons.star, color: AppColors.statusPending),
                        onPressed: () => context
                            .read<FavoriteProvider>()
                            .toggleFavorite(currentUserUid, t.taskId),
                      ),
                      trailing: StatusChip(statusName: t.status.name),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
