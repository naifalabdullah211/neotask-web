import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';
import 'manager_create_task_screen.dart';

/// Manager personal tasks (المهام الشخصية للمدير) — NEW screen.
///
/// Deliberately NOT built on [TaskListTile]/[TaskReviewDetailScreen]: those
/// widgets carry employee-review semantics (three-way review decision,
/// mandatory rejection/edit-request notes, chat-with-employee) that make no
/// sense for a task the manager assigned to themselves — there is no
/// second party to review or chat with. This screen instead uses a plain
/// checkbox-style tile: ticking it off calls
/// [TaskProvider.markPersonalTaskDone] (reusing the existing
/// approve-decision code path so recurrence auto-creation keeps working
/// for free — see that method's doc comment), un-ticking calls
/// [TaskProvider.reopenPersonalTask].
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
    final tasks = context
        .watch<TaskProvider>()
        .personalTasksFor(effectiveManagerUid);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('مهامي الشخصية')),
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton(
              backgroundColor: AppColors.gold,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      const ManagerCreateTaskScreen(initialIsPersonal: true),
                ),
              ),
              child: const Icon(Icons.add, color: Colors.white),
            ),
      body: SafeArea(
        child: tasks.isEmpty
            ? _EmptyState(readOnly: readOnly)
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
                itemCount: tasks.length,
                itemBuilder: (context, index) => _PersonalTaskTile(
                  task: tasks[index],
                  managerUid: effectiveManagerUid,
                  readOnly: readOnly,
                ),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.readOnly});

  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.checklist_rtl,
              size: 56,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 14),
            const Text(
              'لا توجد مهام شخصية بعد',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              readOnly
                  ? 'لا توجد مهام شخصية مسجلة لدى المدير حاليًا.'
                  : 'اضغط زر الإضافة لإنشاء مهمة أو تذكير خاص بك، متابعة إنجازه لن '
                        'تؤثر على تقارير الفريق.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalTaskTile extends StatelessWidget {
  const _PersonalTaskTile({
    required this.task,
    required this.managerUid,
    required this.readOnly,
  });

  final AppTask task;
  final String managerUid;
  final bool readOnly;

  Future<void> _toggleDone(BuildContext context, bool? checked) async {
    final provider = context.read<TaskProvider>();
    if (checked == true) {
      await provider.markPersonalTaskDone(task.taskId, managerUid);
    } else {
      await provider.reopenPersonalTask(task.taskId, managerUid);
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف المهمة'),
        content: Text('هل تريد حذف "${task.title}" نهائيًا؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusRejected,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<TaskProvider>().deleteTask(
        task.taskId,
        actorUid: managerUid,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDone = task.primaryStatus == PrimaryTaskStatus.completed;
    final isOverdue = !isDone && task.isOverdue;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        side: BorderSide(
          color: isOverdue
              ? AppColors.overdue.withValues(alpha: 0.4)
              : AppColors.divider,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Checkbox(
              value: isDone,
              activeColor: AppColors.gold,
              onChanged: readOnly ? null : (v) => _toggleDone(context, v),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDone
                          ? AppColors.textSecondary
                          : AppColors.textPrimary,
                      decoration: isDone
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      PriorityBadge(
                        priorityName: task.priority.name,
                        compact: true,
                      ),
                      Text(
                        intl.DateFormat('yyyy/MM/dd').format(task.dueDate),
                        style: TextStyle(
                          fontSize: 12,
                          color: isOverdue
                              ? AppColors.overdue
                              : AppColors.textSecondary,
                          fontWeight: isOverdue
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      if (isOverdue)
                        const Text(
                          'متأخرة',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.overdue,
                          ),
                        ),
                      if (task.recurrenceType != RecurrenceType.none)
                        Icon(
                          Icons.repeat,
                          size: 14,
                          color: AppColors.textSecondary,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (!readOnly)
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: AppColors.textSecondary,
                onPressed: () => _confirmDelete(context),
              ),
          ],
        ),
      ),
    );
  }
}
