import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_theme.dart';
import 'create_goal_dialog.dart';
import 'goal_detail_screen.dart';

/// Top-level list of all Goals ("أهداف") — visible to BOTH manager
/// (create via FAB) and employee (read-only browse of goals whose
/// criteria they participate in, plus all goals since criteria assignment
/// is many-to-many). This is a NEW, ADDITIVE screen — it does not replace
/// or alter any existing task screen (per answer "١- اضافه").
class GoalsListScreen extends StatelessWidget {
  const GoalsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isManager = context.watch<AuthProvider>().isManager;
    final goalProvider = context.watch<GoalProvider>();
    final goals = goalProvider.allGoals;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('الأهداف')),
      body: SafeArea(
        child: goals.isEmpty
            ? const Center(
                child: Text(
                  'لا توجد أهداف بعد',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: goals.length,
                itemBuilder: (context, index) {
                  final goal = goals[index];
                  final progress = goalProvider.progressForGoal(goal.goalId);
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.deepBlue.withValues(
                          alpha: 0.12,
                        ),
                        child: const Icon(
                          Icons.flag_outlined,
                          color: AppColors.deepBlue,
                        ),
                      ),
                      title: Text(
                        goal.title,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${progress.completed}/${progress.total} معايير مكتملة • '
                        '${DateFormat('yyyy/MM/dd').format(goal.startDate)} - '
                        '${DateFormat('yyyy/MM/dd').format(goal.endDate)}',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_left),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => GoalDetailScreen(goalId: goal.goalId),
                        ),
                      ),
                    ),
                  );
                },
              ),
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: () => showCreateGoalDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('هدف جديد'),
            )
          : null,
    );
  }
}
