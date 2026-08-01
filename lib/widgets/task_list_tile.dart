import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../screens/manager/task_review_detail_screen.dart';
import '../theme/app_theme.dart';
import 'status_chip.dart';
import 'task_urgency_indicator.dart';
import 'favorite_star_button.dart';
import '../utils/project_planning.dart';

/// SHARED standard task-list row (Card + ListTile with urgency dot,
/// status/priority chips, category/due-date line, favorite star) —
/// extracted unchanged from the manager dashboard's inline task list
/// (`_ListView` in manager_dashboard_tab.dart) so the new employee stats
/// detail page's task list uses the EXACT SAME task-card design, per
/// explicit requirement ("بنفس تصميم بطاقة المهمة المعتاد"), instead of a
/// separately-styled lookalike.
///
/// Tapping opens [TaskReviewDetailScreen] — the same manager-facing detail
/// screen used everywhere else a manager taps a task.
class TaskListTile extends StatelessWidget {
  const TaskListTile({super.key, required this.task, required this.managerUid});

  final AppTask task;
  final String managerUid;

  @override
  Widget build(BuildContext context) {
    final allTasks = context.watch<TaskProvider>().allTasks;
    final blocked = ProjectPlanning.isBlocked(task, allTasks);
    return Card(
      child: ListTile(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TaskReviewDetailScreen(task: task),
            ),
          );
        },
        leading: TaskUrgencyDot(task: task),
        title: Row(
          children: [
            Expanded(child: Text(task.title, style: AppTextStyles.cardTitle)),
            FavoriteStarButton(
              userUid: managerUid,
              taskId: task.taskId,
              size: AppIconSize.md,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: AppSpacing.sm - 2),
            Wrap(
              spacing: AppSpacing.sm - 2,
              runSpacing: 4,
              children: [
                StatusChip(statusName: task.status.name),
                PriorityBadge(priorityName: task.priority.name, compact: true),
                if (blocked)
                  const Chip(
                    avatar: Icon(Icons.lock_clock, size: 15),
                    label: Text('متوقفة بتبعية'),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm - 2),
            Text(
              '${task.category} · ${intl.DateFormat('yyyy/MM/dd').format(task.dueDate)}',
              style: AppTextStyles.bodySecondary,
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: task.progressPercent / 100,
                      minHeight: 6,
                      backgroundColor: AppColors.divider,
                      color: AppColors.deepBlue,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${task.progressPercent}%'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
