import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import '../models/task_model.dart';
import '../screens/manager/task_review_detail_screen.dart';
import 'status_chip.dart';
import 'task_urgency_indicator.dart';
import 'favorite_star_button.dart';

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
            Expanded(
              child: Text(
                task.title,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            FavoriteStarButton(
              userUid: managerUid,
              taskId: task.taskId,
              size: 20,
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                StatusChip(statusName: task.status.name),
                PriorityBadge(priorityName: task.priority.name, compact: true),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '${task.category} · ${intl.DateFormat('yyyy/MM/dd').format(task.dueDate)}',
            ),
          ],
        ),
      ),
    );
  }
}
