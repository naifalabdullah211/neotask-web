import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/favorite_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/favorite_star_button.dart';
import '../../widgets/neo_workspace_chrome.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/task_urgency_indicator.dart';
import '../designer/designer_task_view_screen.dart';
import '../employee/task_detail_screen.dart';
import '../manager/task_review_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    super.key,
    required this.currentUserUid,
    required this.isManager,
    this.readOnly = false,
  });

  final String currentUserUid;
  final bool isManager;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final favorites = context.watch<FavoriteProvider>().favoritesForUser(
      currentUserUid,
    );
    final tasks =
        favorites
            .map((favorite) => FirestoreService.getTask(favorite.taskId))
            .whereType<AppTask>()
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final completed = tasks
        .where((task) => task.status == TaskStatus.approved)
        .length;
    final overdue = tasks.where((task) => task.isOverdue).length;
    final active = tasks.length - completed;

    void openTask(AppTask task) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => readOnly
              ? DesignerTaskViewScreen(task: task)
              : isManager
              ? TaskReviewDetailScreen(task: task)
              : TaskDetailScreen(task: task),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'المفضلة',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            NeoWorkspaceMetricsBar(
              items: [
                NeoWorkspaceMetric(
                  label: 'إجمالي المفضلة',
                  value: '${tasks.length}',
                  icon: Icons.star_rounded,
                  color: AppColors.favoriteGold,
                ),
                NeoWorkspaceMetric(
                  label: 'مهام نشطة',
                  value: '$active',
                  icon: Icons.play_circle_outline_rounded,
                  color: AppColors.mintAccent,
                ),
                NeoWorkspaceMetric(
                  label: 'مكتملة',
                  value: '$completed',
                  icon: Icons.task_alt_rounded,
                  color: AppColors.steel,
                ),
                NeoWorkspaceMetric(
                  label: 'متأخرة',
                  value: '$overdue',
                  icon: Icons.schedule_rounded,
                  color: AppColors.overdue,
                ),
              ],
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: tasks.isEmpty
                    ? const NeoWorkspaceEmptyState(
                        icon: Icons.star_border_rounded,
                        title: 'لا توجد مهام مفضّلة حتى الآن',
                        message:
                            'استخدم النجمة في أي مهمة لتضيفها إلى مساحة التركيز السريع.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const NeoWorkspaceSectionHeader(
                            title: 'قائمة التركيز',
                            subtitle: 'المهام التي اخترت الرجوع إليها بسرعة',
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              itemCount: tasks.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) =>
                                  _FavoriteTaskCard(
                                    task: tasks[index],
                                    currentUserUid: currentUserUid,
                                    readOnly: readOnly,
                                    onTap: () => openTask(tasks[index]),
                                  ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteTaskCard extends StatelessWidget {
  const _FavoriteTaskCard({
    required this.task,
    required this.currentUserUid,
    required this.readOnly,
    required this.onTap,
  });

  final AppTask task;
  final String currentUserUid;
  final bool readOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF9FBFD),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TaskUrgencyDot(task: task),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: AppTextStyles.cardTitle.copyWith(
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (readOnly)
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.favoriteGold,
                          )
                        else
                          FavoriteStarButton(
                            userUid: currentUserUid,
                            taskId: task.taskId,
                            size: 21,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        StatusChip(statusName: task.status.name),
                        PriorityBadge(
                          priorityName: task.priority.name,
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '${task.category} · ${intl.DateFormat('yyyy/MM/dd').format(task.dueDate)}',
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: LinearProgressIndicator(
                              value: task.progressPercent / 100,
                              minHeight: 6,
                              backgroundColor: AppColors.divider,
                              color: AppColors.deepBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          '${task.progressPercent}%',
                          style: AppTextStyles.bodySecondary.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
