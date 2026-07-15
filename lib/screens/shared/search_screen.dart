import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/criterion_model.dart';
import '../../models/goal_model.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/criterion_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';
import '../employee/task_detail_screen.dart';
import 'criterion_detail_screen.dart';
import 'goal_detail_screen.dart';

/// External/global search screen — per the manager's explicit answer
/// "٦- يستطيع البحث عن معيار او عن هدف او عن اعمال موظف او عن موظف":
/// search covers FOUR entity types at once:
///   1. A Criterion (by title)
///   2. A Goal (by title)
///   3. An Employee's collection of assigned work (tasks + criteria)
///   4. An Employee (by name/employee number)
///
/// JUDGMENT CALL (flagged — the manager did not answer this question,
/// "Q7", about icon placement/result presentation): this screen is
/// reached via a search icon placed in the AppBar of BOTH manager and
/// employee home screens (see manager_home_screen.dart /
/// employee_home_screen.dart). Results are grouped into labeled sections
/// (موظفون / أهداف / معايير / مهام) rather than a single flat list, since
/// the query can plausibly match more than one entity type at once (e.g.
/// searching an employee's name should surface both that employee's
/// profile AND everything assigned to them).
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

    List<AppUser> matchedEmployees = [];
    List<Goal> matchedGoals = [];
    List<Criterion> matchedCriteria = [];
    List<AppTask> matchedTasks = [];

    if (q.isNotEmpty) {
      final lower = q.toLowerCase();

      matchedEmployees = FirestoreService.getAllEmployees()
          .where(
            (u) =>
                u.name.toLowerCase().contains(lower) ||
                u.employeeNumber.toLowerCase().contains(lower),
          )
          .toList();

      // If the query matches an employee, also surface everything
      // assigned to them ("أعمال موظف") even if the task/criterion title
      // itself doesn't contain the search text.
      final matchedEmployeeUids = matchedEmployees.map((u) => u.uid).toSet();

      matchedGoals = goalProvider.allGoals
          .where((g) => g.title.toLowerCase().contains(lower))
          .toList();

      matchedCriteria = criterionProvider.allCriteria
          .where(
            (c) =>
                c.title.toLowerCase().contains(lower) ||
                c.assignees.any((uid) => matchedEmployeeUids.contains(uid)),
          )
          .toList();

      matchedTasks = taskProvider.allTasks
          .where(
            (t) =>
                t.title.toLowerCase().contains(lower) ||
                matchedEmployeeUids.contains(t.assignedTo),
          )
          .toList();
    }

    final hasResults =
        matchedEmployees.isNotEmpty ||
        matchedGoals.isNotEmpty ||
        matchedCriteria.isNotEmpty ||
        matchedTasks.isNotEmpty;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: true,
          onChanged: (v) => setState(() => _query = v),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'ابحث عن معيار، هدف، موظف، أو أعمال موظف...',
            hintStyle: TextStyle(color: Colors.white70),
            border: InputBorder.none,
          ),
        ),
      ),
      body: SafeArea(
        child: q.isEmpty
            ? const Center(
                child: Text(
                  'ابحث عن معيار، هدف، موظف، أو أعمال موظف',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            : !hasResults
            ? const Center(
                child: Text(
                  'لا توجد نتائج مطابقة',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (matchedEmployees.isNotEmpty)
                    _SearchSection(
                      title: 'موظفون',
                      children: matchedEmployees
                          .map((u) => _EmployeeResultTile(user: u))
                          .toList(),
                    ),
                  if (matchedGoals.isNotEmpty)
                    _SearchSection(
                      title: 'أهداف',
                      children: matchedGoals
                          .map(
                            (g) => ListTile(
                              leading: const Icon(Icons.flag_outlined),
                              title: Text(g.title),
                              trailing: const Icon(Icons.chevron_left),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      GoalDetailScreen(goalId: g.goalId),
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  if (matchedCriteria.isNotEmpty)
                    _SearchSection(
                      title: 'معايير',
                      children: matchedCriteria
                          .map((c) => _CriterionResultTile(criterion: c))
                          .toList(),
                    ),
                  if (matchedTasks.isNotEmpty)
                    _SearchSection(
                      title: 'مهام',
                      children: matchedTasks
                          .map((t) => _TaskResultTile(task: t))
                          .toList(),
                    ),
                ],
              ),
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, top: 8),
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        Card(child: Column(children: children)),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _EmployeeResultTile extends StatelessWidget {
  const _EmployeeResultTile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final criterionCount = context
        .read<CriterionProvider>()
        .criteriaForEmployee(user.uid)
        .length;
    final taskCount = context
        .read<TaskProvider>()
        .tasksForEmployee(user.uid)
        .length;

    return ListTile(
      leading: CircleAvatar(
        child: Text(user.name.isNotEmpty ? user.name[0] : '؟'),
      ),
      title: Text(user.name),
      subtitle: Text('$taskCount مهمة • $criterionCount معيار'),
    );
  }
}

class _CriterionResultTile extends StatelessWidget {
  const _CriterionResultTile({required this.criterion});

  final Criterion criterion;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.checklist_rtl_outlined),
      title: Text(criterion.title),
      subtitle: StatusChip(statusName: criterion.status.name, fontSize: 10),
      trailing: const Icon(Icons.chevron_left),
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
    return ListTile(
      leading: const Icon(Icons.task_outlined),
      title: Text(task.title),
      subtitle: Row(
        children: [
          StatusChip(statusName: task.status.name, fontSize: 10),
          const SizedBox(width: 6),
          PriorityBadge(priorityName: task.priority.name, compact: true),
        ],
      ),
      trailing: const Icon(Icons.chevron_left),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TaskDetailScreen(task: task)),
      ),
    );
  }
}
