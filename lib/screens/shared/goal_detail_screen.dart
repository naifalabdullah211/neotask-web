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

/// Detail screen for a single Goal — shows the Goal's info, its derived
/// progress (never auto-closes the Goal — see GoalProvider.closeGoal doc
/// comment), the list of its Criteria (each a Smartsheet-style sub-row),
/// a manager-only "معيار جديد" FAB, and a manager-only close/reopen
/// action requiring EXPLICIT confirmation (per answer "٣- يحتاج تأكيد").
class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  Future<void> _confirmClose(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد إغلاق الهدف'),
        content: const Text(
          'هل أنت متأكد من إغلاق هذا الهدف؟ هذا إجراء يدوي ولا يتم تلقائيًا '
          'حتى لو تمت الموافقة على جميع المعايير.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('تأكيد الإغلاق'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<GoalProvider>().closeGoal(goalId);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إغلاق الهدف')));
      }
    }
  }

  Future<void> _reopen(BuildContext context) async {
    await context.read<GoalProvider>().reopenGoal(goalId);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تمت إعادة فتح الهدف')));
    }
  }

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
        actions: [
          if (isManager)
            IconButton(
              tooltip: goal.isClosed ? 'إعادة فتح الهدف' : 'إغلاق الهدف',
              icon: Icon(
                goal.isClosed ? Icons.lock_open_outlined : Icons.lock_outline,
              ),
              onPressed: () =>
                  goal.isClosed ? _reopen(context) : _confirmClose(context),
            ),
        ],
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            goal.title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (goal.isClosed)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.statusApproved.withValues(
                                alpha: 0.12,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'مغلق',
                              style: TextStyle(
                                color: AppColors.statusApproved,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                    if (goal.description.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        goal.description,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                    const SizedBox(height: 12),
                    LinearProgressIndicator(
                      value: progress.total == 0
                          ? 0
                          : progress.approved / progress.total,
                      backgroundColor: AppColors.background,
                      color: AppColors.statusApproved,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${progress.approved}/${progress.total} معايير مكتملة',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    if (goal.isClosed && goal.closedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'أُغلق بتاريخ ${intl.DateFormat('yyyy/MM/dd').format(goal.closedAt!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
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
    final assigneeNames = criterion.assignedTo
        .map((uid) => FirestoreService.getUser(uid)?.name ?? 'موظف')
        .join('، ');

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
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
            const SizedBox(height: 4),
            Text(
              'الاستحقاق: ${intl.DateFormat('yyyy/MM/dd').format(criterion.dueDate)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                StatusChip(statusName: criterion.status.name, fontSize: 11),
                PriorityBadge(priorityName: criterion.priority.name, compact: true),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_left),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                CriterionDetailScreen(criterionId: criterion.criterionId),
          ),
        ),
      ),
    );
  }
}
