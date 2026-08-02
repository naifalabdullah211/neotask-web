import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/personal_tasks_workspace.dart';
import 'manager_create_task_screen.dart';
import 'task_review_detail_screen.dart';

/// Manager-only focus space for personal tasks. Personal tasks remain
/// excluded from every team metric/report by TaskProvider.teamTasks; this
/// screen changes their presentation only and keeps the existing lifecycle,
/// recurrence, comments, editing and transfer behaviour.
class ManagerMyTasksScreen extends StatelessWidget {
  const ManagerMyTasksScreen({
    super.key,
    this.readOnly = false,
    this.managerUid,
  });

  final bool readOnly;
  final String? managerUid;

  @override
  Widget build(BuildContext context) {
    final effectiveManagerUid =
        managerUid ?? context.watch<AuthProvider>().currentUser!.uid;
    final taskProvider = context.watch<TaskProvider>();
    final tasks = taskProvider.personalTasksFor(effectiveManagerUid);

    Future<void> toggleDone(AppTask task, bool completed) async {
      if (completed) {
        await context.read<TaskProvider>().markPersonalTaskDone(
          task.taskId,
          effectiveManagerUid,
        );
      } else {
        await context.read<TaskProvider>().reopenPersonalTask(
          task.taskId,
          effectiveManagerUid,
        );
      }
    }

    void openTask(AppTask task) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TaskReviewDetailScreen(task: task)),
      );
    }

    Future<void> confirmDelete(AppTask task) async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('حذف المهمة'),
          content: Text('هل تريد حذف «${task.title}» نهائيًا؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.statusRejected,
              ),
              child: const Text('حذف'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
      await context.read<TaskProvider>().deleteTask(
        task.taskId,
        actorUid: effectiveManagerUid,
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'مهامي الشخصية',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (!readOnly)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: MediaQuery.sizeOf(context).width < 620
                  ? IconButton.filled(
                      tooltip: 'مهمة شخصية جديدة',
                      onPressed: () => _createTask(context),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.mintAccent,
                        foregroundColor: AppColors.navy,
                      ),
                      icon: const Icon(Icons.add_rounded),
                    )
                  : FilledButton.icon(
                      onPressed: () => _createTask(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.mintAccent,
                        foregroundColor: AppColors.navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'مهمة شخصية جديدة',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            PersonalTasksMetricsBar(tasks: tasks),
            Expanded(
              child: PersonalTasksWorkspace(
                tasks: tasks,
                readOnly: readOnly,
                onToggleDone: toggleDone,
                onOpen: openTask,
                onDelete: confirmDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _createTask(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            const ManagerCreateTaskScreen(initialIsPersonal: true),
      ),
    );
  }
}
