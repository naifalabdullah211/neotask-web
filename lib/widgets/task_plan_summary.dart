import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../models/task_model.dart';
import '../providers/task_provider.dart';
import '../theme/app_theme.dart';
import '../utils/project_planning.dart';

class TaskPlanSummary extends StatelessWidget {
  const TaskPlanSummary({super.key, required this.task});

  final AppTask task;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final allTasks = provider.allTasks;
    final byId = ProjectPlanning.index(allTasks);
    final unresolved = ProjectPlanning.unresolvedPredecessors(task, allTasks);
    final parent = task.parentTaskId == null ? null : byId[task.parentTaskId];
    final children = ProjectPlanning.childrenOf(task.taskId, allTasks);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.account_tree_outlined,
                  color: AppColors.deepBlue,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'الخطة والتنفيذ',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
                Text(
                  '${task.progressPercent}%',
                  style: const TextStyle(
                    color: AppColors.deepBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: (task.progressPercent / 100).clamp(0, 1).toDouble(),
                minHeight: 9,
                backgroundColor: AppColors.divider,
                color: task.progressPercent == 100
                    ? AppColors.statusApproved
                    : AppColors.deepBlue,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoChip(
                  icon: Icons.play_circle_outline,
                  label:
                      'البداية ${intl.DateFormat('yyyy/MM/dd').format(task.startDate)}',
                ),
                _InfoChip(
                  icon: Icons.flag_outlined,
                  label:
                      'النهاية ${intl.DateFormat('yyyy/MM/dd').format(task.dueDate)}',
                ),
                _InfoChip(
                  icon: Icons.schedule_outlined,
                  label:
                      '${task.plannedHours.toStringAsFixed(task.plannedHours % 1 == 0 ? 0 : 1)} ساعة',
                ),
              ],
            ),
            if (parent != null) ...[
              const SizedBox(height: 12),
              Text(
                'المهمة الرئيسية: ${parent.title}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            if (task.predecessorTaskIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'المهام السابقة',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              ...task.predecessorTaskIds.map((id) {
                final predecessor = byId[id];
                if (predecessor == null) return const SizedBox.shrink();
                final complete = predecessor.status == TaskStatus.approved;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    children: [
                      Icon(
                        complete ? Icons.check_circle : Icons.lock_clock,
                        size: 18,
                        color: complete
                            ? AppColors.statusApproved
                            : AppColors.statusPending,
                      ),
                      const SizedBox(width: 7),
                      Expanded(child: Text(predecessor.title)),
                    ],
                  ),
                );
              }),
            ],
            if (children.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'المهام الفرعية: ${children.where((item) => item.status == TaskStatus.approved).length}/${children.length} مكتملة',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            if (unresolved.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusPending.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.statusPending.withValues(alpha: 0.25),
                  ),
                ),
                child: Text(
                  'التنفيذ متوقف حتى اعتماد: ${unresolved.map((item) => item.title).join('، ')}',
                  style: const TextStyle(
                    color: AppColors.statusPending,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.deepBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.deepBlue),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
