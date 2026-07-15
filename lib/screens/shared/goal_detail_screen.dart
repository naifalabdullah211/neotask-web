import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/criterion_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/criterion_provider.dart';
import '../../providers/goal_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';
import 'create_criterion_screen.dart';
import 'criterion_detail_screen.dart';
import 'edit_goal_dialog.dart';

/// Detail screen for a single Goal — shows the Goal's info (title,
/// description, start/end dates), the list of its Criteria, and a
/// manager-only "معيار جديد" FAB.
///
/// REBUILD NOTE: per the simplified spec, a Goal has NO manual
/// close/reopen action anymore — `isClosed`/`closedAt` were removed
/// entirely from the Goal model.
class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context) {
    final isManager = context.watch<AuthProvider>().isManager;
    final goalProvider = context.watch<GoalProvider>();
    final criterionProvider = context.watch<CriterionProvider>();
    final goal = goalProvider.getGoal(goalId);

    if (goal == null) {
      return const Scaffold(body: Center(child: Text('الهدف غير موجود')));
    }

    final criteria = criterionProvider.criteriaForGoal(goalId);
    final progress = goalProvider.progressForGoal(goalId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(goal.title),
        actions: isManager
            ? [
                IconButton(
                  tooltip: 'تعديل الهدف',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showEditGoalDialog(context, goal),
                ),
                IconButton(
                  tooltip: 'حذف الهدف',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => confirmAndDeleteGoal(
                    context,
                    goal,
                    onDeleted: () => Navigator.of(context).pop(),
                  ),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (goal.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        goal.description,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.event_outlined,
                          size: 16,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${intl.DateFormat('yyyy/MM/dd').format(goal.startDate)}'
                          ' - ${intl.DateFormat('yyyy/MM/dd').format(goal.endDate)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress.total == 0
                          ? 0
                          : progress.completed / progress.total,
                      backgroundColor: AppColors.background,
                      color: AppColors.statusApproved,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${progress.completed}/${progress.total} معايير مكتملة',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'المعايير',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (criteria.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'لا توجد معايير بعد لهذا الهدف',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ...criteria.map((c) => _CriterionTile(criterion: c)),
            const SizedBox(height: 90),
          ],
        ),
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateCriterionScreen(goalId: goalId),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('معيار جديد'),
            )
          : null,
    );
  }
}

class _CriterionTile extends StatelessWidget {
  const _CriterionTile({required this.criterion});

  final Criterion criterion;

  @override
  Widget build(BuildContext context) {
    final assigneeNames = criterion.assignees
        .map((uid) => FirestoreService.getUser(uid)?.name ?? 'موظف')
        .join('، ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          criterion.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              assigneeNames.isEmpty ? 'بدون موظف' : assigneeNames,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            StatusChip(statusName: criterion.status.name, fontSize: 11),
          ],
        ),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CriterionDetailScreen(
              goalId: criterion.goalId,
              criterionId: criterion.criterionId,
            ),
          ),
        ),
      ),
    );
  }
}
