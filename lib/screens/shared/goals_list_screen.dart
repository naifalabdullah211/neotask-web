import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/goal_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/goals_workspace.dart';
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

    void openGoal(Goal goal) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GoalDetailScreen(goalId: goal.goalId),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'الأهداف',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (isManager)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: MediaQuery.sizeOf(context).width < 620
                  ? IconButton.filled(
                      tooltip: 'هدف جديد',
                      onPressed: () => showCreateGoalDialog(context),
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.mintAccent,
                        foregroundColor: AppColors.navy,
                      ),
                      icon: const Icon(Icons.add_rounded),
                    )
                  : FilledButton.icon(
                      onPressed: () => showCreateGoalDialog(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.mintAccent,
                        foregroundColor: AppColors.navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'هدف جديد',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            GoalsMetricsBar(goals: goals, provider: goalProvider),
            Expanded(
              child: GoalsWorkspace(
                goals: goals,
                provider: goalProvider,
                onOpenGoal: openGoal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
