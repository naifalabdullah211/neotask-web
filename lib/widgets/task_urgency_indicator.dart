import 'package:flutter/material.dart';
import '../models/task_model.dart';
import '../theme/app_theme.dart';

/// Traffic-light urgency classification for a task, based on its due date
/// ([AppTask.dueDate]) relative to "now".
///
/// Design decision (per manager's explicit choice — "١" = interpretation 1
/// from the clarifying question): urgency is computed from the EXISTING
/// `dueDate` field. No separate "target date" field was added — there is
/// only one date per task, and this indicator reflects how close/overdue
/// the task is relative to it.
///
/// Rules (documented here since no exact thresholds were specified by the
/// user — reasonable defaults chosen and applied consistently):
/// - Approved tasks are always green (already successfully completed,
///   regardless of when they were finished).
/// - Any other task whose dueDate has already passed is red (overdue).
/// - Any other task due within the next 2 days (48 hours) is yellow
///   (approaching deadline).
/// - Otherwise green (on track, plenty of time left).
enum TaskUrgency { onTrack, dueSoon, overdue }

TaskUrgency taskUrgency(AppTask task) {
  if (task.status == TaskStatus.approved) return TaskUrgency.onTrack;

  // Overdue check delegates to the single centralized [AppTask.isOverdue]
  // getter (task_model.dart) instead of re-deriving it independently here.
  // This closes the duplicate-calculation gap flagged in the data-consistency
  // bug report (requirement #3: "امسح أي حساب مستقل مكرر").
  if (task.isOverdue) return TaskUrgency.overdue;

  final remaining = task.dueDate.difference(DateTime.now());
  if (remaining.inHours <= 48) return TaskUrgency.dueSoon;

  return TaskUrgency.onTrack;
}

Color taskUrgencyColor(TaskUrgency urgency) {
  switch (urgency) {
    case TaskUrgency.overdue:
      return AppColors.statusRejected; // red
    case TaskUrgency.dueSoon:
      return AppColors.statusPending; // yellow/amber
    case TaskUrgency.onTrack:
      return AppColors.statusApproved; // green
  }
}

String taskUrgencyLabel(TaskUrgency urgency) {
  switch (urgency) {
    case TaskUrgency.overdue:
      return 'متأخرة';
    case TaskUrgency.dueSoon:
      return 'قريبة من الاستحقاق';
    case TaskUrgency.onTrack:
      return 'في الموعد';
  }
}

/// Small colored dot (traffic-light style) reflecting [taskUrgency] for
/// the given [task]. Meant to be used as a `leading` widget in task list
/// tiles across manager and employee screens.
class TaskUrgencyDot extends StatelessWidget {
  const TaskUrgencyDot({super.key, required this.task, this.size = 14});

  final AppTask task;
  final double size;

  @override
  Widget build(BuildContext context) {
    final urgency = taskUrgency(task);
    final color = taskUrgencyColor(urgency);
    return Tooltip(
      message: taskUrgencyLabel(urgency),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: color.withValues(alpha: 0.4), width: 2),
        ),
      ),
    );
  }
}
