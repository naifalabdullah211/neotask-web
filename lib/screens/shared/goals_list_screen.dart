import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_theme.dart';
import '../../theme/goal_style_options.dart';
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
                  final goalColor = goalColorFromName(goal.colorName);
                  final goalIcon = goalIconFromName(goal.iconName);
                  final percent = progress.total == 0
                      ? 0
                      : ((progress.completed / progress.total) * 100).round();
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(color: goalColor, width: 1.5),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: goalColor.withValues(alpha: 0.15),
                          child: Icon(goalIcon, color: goalColor),
                        ),
                        title: Text(
                          goal.title,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${progress.completed}/${progress.total} معايير مكتملة ($percent%) • '
                            '${DateFormat('yyyy/MM/dd').format(goal.startDate)} - '
                            '${DateFormat('yyyy/MM/dd').format(goal.endDate)}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_left),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                GoalDetailScreen(goalId: goal.goalId),
                          ),
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
