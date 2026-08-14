import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:provider/provider.dart';
import '../../models/criterion_model.dart';
import '../../models/goal_model.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/criterion_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_workspace_chrome.dart';
import '../../widgets/status_chip.dart';
import '../designer/designer_task_view_screen.dart';
import '../employee/task_detail_screen.dart';
import '../manager/employee_stats_detail_screen.dart';
import '../manager/task_review_detail_screen.dart';
import 'criterion_detail_screen.dart';
import 'goal_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final goalProvider = context.watch<GoalProvider>();
    final criterionProvider = context.watch<CriterionProvider>();
    final taskProvider = context.watch<TaskProvider>();

    List<AppUser> employees = [];
    List<Goal> goals = [];
    List<Criterion> criteria = [];
    List<AppTask> tasks = [];

    if (q.isNotEmpty) {
      final lower = q.toLowerCase();
      employees = FirestoreService.getAllEmployees()
          .where(
            (user) =>
                user.name.toLowerCase().contains(lower) ||
                user.employeeNumber.toLowerCase().contains(lower),
          )
          .toList();
      final employeeUids = employees.map((user) => user.uid).toSet();
      goals = goalProvider.allGoals
          .where((goal) => goal.title.toLowerCase().contains(lower))
          .toList();
      criteria = criterionProvider.allCriteria
          .where(
            (criterion) =>
                criterion.title.toLowerCase().contains(lower) ||
                criterion.assignees.any(employeeUids.contains),
          )
          .toList();
      tasks = taskProvider.allTasks
          .where(
            (task) =>
                task.title.toLowerCase().contains(lower) ||
                employeeUids.contains(task.assignedTo),
          )
          .toList();
    }

    final total =
        employees.length + goals.length + criteria.length + tasks.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'بحث شامل',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: context.tr(
                    'ابحث عن معيار، هدف، موظف، أو أعمال موظف...',
                  ),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: q.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.tr('مسح البحث'),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            if (q.isNotEmpty)
              NeoWorkspaceMetricsBar(
                items: [
                  NeoWorkspaceMetric(
                    label: 'موظفون',
                    value: '${employees.length}',
                    icon: Icons.people_alt_outlined,
                    color: const Color(0xFF1F6FD2),
                  ),
                  NeoWorkspaceMetric(
                    label: 'أهداف',
                    value: '${goals.length}',
                    icon: Icons.flag_outlined,
                    color: AppColors.gold,
                  ),
                  NeoWorkspaceMetric(
                    label: 'معايير',
                    value: '${criteria.length}',
                    icon: Icons.checklist_rtl_outlined,
                    color: const Color(0xFF7656C8),
                  ),
                  NeoWorkspaceMetric(
                    label: 'مهام',
                    value: '${tasks.length}',
                    icon: Icons.task_alt_outlined,
                    color: AppColors.mintAccent,
                  ),
                ],
              ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: q.isEmpty
                    ? const NeoWorkspaceEmptyState(
                        icon: Icons.manage_search_rounded,
                        title: 'ابحث في NeoTask',
                        message:
                            'اكتب اسم موظف أو رقمًا وظيفيًا أو عنوان هدف أو معيار أو مهمة.',
                      )
                    : total == 0
                    ? const NeoWorkspaceEmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'لا توجد نتائج مطابقة',
                        message: 'جرّب كلمة أقصر أو اسمًا أو رقمًا مختلفًا.',
                      )
                    : ListView(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        children: [
                          if (employees.isNotEmpty)
                            _SearchSection(
                              title: 'موظفون',
                              icon: Icons.people_alt_outlined,
                              children: employees
                                  .map(
                                    (user) => _EmployeeResultTile(user: user),
                                  )
                                  .toList(),
                            ),
                          if (goals.isNotEmpty)
                            _SearchSection(
                              title: 'أهداف',
                              icon: Icons.flag_outlined,
                              children: goals
                                  .map(
                                    (goal) => _ResultTile(
                                      icon: Icons.flag_outlined,
                                      title: goal.title,
                                      onTap: () => Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => GoalDetailScreen(
                                            goalId: goal.goalId,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  .toList(),
                            ),
                          if (criteria.isNotEmpty)
                            _SearchSection(
                              title: 'معايير',
                              icon: Icons.checklist_rtl_outlined,
                              children: criteria
                                  .map(
                                    (criterion) => _CriterionResultTile(
                                      criterion: criterion,
                                    ),
                                  )
                                  .toList(),
                            ),
                          if (tasks.isNotEmpty)
                            _SearchSection(
                              title: 'مهام',
                              icon: Icons.task_alt_outlined,
                              children: tasks
                                  .map((task) => _TaskResultTile(task: task))
                                  .toList(),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          NeoWorkspaceSectionHeader(
            title: title,
            trailing: Icon(icon, color: AppColors.deepBlue, size: 20),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final Widget? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.deepBlue.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: AppColors.deepBlue, size: 20),
      ),
      title: Text(title, style: AppTextStyles.cardTitle),
      subtitle: subtitle,
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 15,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }
}

class _EmployeeResultTile extends StatelessWidget {
  const _EmployeeResultTile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final canOpenStats = auth.isManager || auth.isDesigner;
    final criterionCount = context
        .read<CriterionProvider>()
        .criteriaForEmployee(user.uid)
        .length;
    final taskCount = context
        .read<TaskProvider>()
        .tasksForEmployee(user.uid)
        .length;
    final subtitle =
        '${context.tr('رقم وظيفي')}: ${user.employeeNumber} • '
        '$taskCount ${context.tr('مهام')} • '
        '$criterionCount ${context.tr('معايير')}';

    return _ResultTile(
      icon: Icons.person_outline_rounded,
      title: user.name,
      subtitle: Text(subtitle, style: AppTextStyles.bodySecondary),
      onTap: canOpenStats
          ? () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => EmployeeStatsDetailScreen(employee: user),
              ),
            )
          : () {},
    );
  }
}

class _CriterionResultTile extends StatelessWidget {
  const _CriterionResultTile({required this.criterion});

  final Criterion criterion;

  @override
  Widget build(BuildContext context) {
    return _ResultTile(
      icon: Icons.checklist_rtl_outlined,
      title: criterion.title,
      subtitle: Align(
        alignment: AlignmentDirectional.centerStart,
        child: StatusChip(
          statusName: criterion.aggregateStatus.name,
          fontSize: 10,
        ),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CriterionDetailScreen(
            goalId: criterion.goalId,
            criterionId: criterion.criterionId,
          ),
        ),
      ),
    );
  }
}

class _TaskResultTile extends StatelessWidget {
  const _TaskResultTile({required this.task});

  final AppTask task;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final Widget destination = auth.isDesigner
        ? DesignerTaskViewScreen(task: task)
        : auth.isManager
        ? TaskReviewDetailScreen(task: task)
        : TaskDetailScreen(task: task);
    return _ResultTile(
      icon: Icons.task_outlined,
      title: task.title,
      subtitle: Wrap(
        spacing: 6,
        runSpacing: 5,
        children: [
          StatusChip(statusName: task.status.name, fontSize: 10),
          PriorityBadge(priorityName: task.priority.name, compact: true),
        ],
      ),
      onTap: () => Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (_) => destination)),
    );
  }
}
