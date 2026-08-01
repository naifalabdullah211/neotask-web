import '../models/task_model.dart';

class WorkloadEntry {
  const WorkloadEntry({
    required this.employeeUid,
    required this.plannedHours,
    this.capacityHours = 40,
  });

  final String employeeUid;
  final double plannedHours;
  final double capacityHours;

  double get utilization =>
      capacityHours == 0 ? 0 : plannedHours / capacityHours;
  bool get isOverCapacity => plannedHours > capacityHours;
}

/// Pure planning calculations shared by the timeline, task details and tests.
/// Dependencies use a finish-to-start rule: every predecessor must be
/// approved before its successor may start.
class ProjectPlanning {
  const ProjectPlanning._();

  static Map<String, AppTask> index(Iterable<AppTask> tasks) => {
    for (final task in tasks) task.taskId: task,
  };

  /// Keeps the plan focused on unfinished work while retaining every linked
  /// parent, child and predecessor needed to understand that work. Unrelated
  /// historical tasks stay in reports instead of stretching the timeline.
  static List<AppTask> planningScope(Iterable<AppTask> allTasks) {
    final tasks = allTasks.toList();
    final byId = index(tasks);
    final included = tasks
        .where((task) => task.status != TaskStatus.approved)
        .map((task) => task.taskId)
        .toSet();

    var changed = true;
    while (changed) {
      changed = false;
      for (final taskId in included.toList()) {
        final task = byId[taskId];
        if (task == null) continue;
        final relatedIds = <String>{
          if (task.parentTaskId != null) task.parentTaskId!,
          ...task.predecessorTaskIds,
        };
        for (final relatedId in relatedIds) {
          if (byId.containsKey(relatedId) && included.add(relatedId)) {
            changed = true;
          }
        }
      }
      for (final task in tasks) {
        if (task.parentTaskId != null &&
            included.contains(task.parentTaskId) &&
            included.add(task.taskId)) {
          changed = true;
        }
      }
    }

    return tasks.where((task) => included.contains(task.taskId)).toList();
  }

  static List<AppTask> unresolvedPredecessors(
    AppTask task,
    Iterable<AppTask> allTasks,
  ) {
    final byId = index(allTasks);
    return task.predecessorTaskIds
        .map((id) => byId[id])
        .whereType<AppTask>()
        .where((item) => item.status != TaskStatus.approved)
        .toList();
  }

  static bool isBlocked(AppTask task, Iterable<AppTask> allTasks) =>
      unresolvedPredecessors(task, allTasks).isNotEmpty;

  static List<AppTask> childrenOf(
    String parentTaskId,
    Iterable<AppTask> allTasks,
  ) => allTasks.where((task) => task.parentTaskId == parentTaskId).toList();

  static List<AppTask> openChildren(
    String parentTaskId,
    Iterable<AppTask> allTasks,
  ) => childrenOf(
    parentTaskId,
    allTasks,
  ).where((task) => task.status != TaskStatus.approved).toList();

  /// Returns true when adding [candidatePredecessorId] to [taskId] would
  /// make the dependency graph cyclic.
  static bool wouldCreateCycle({
    required String taskId,
    required String candidatePredecessorId,
    required Iterable<AppTask> allTasks,
  }) {
    if (taskId == candidatePredecessorId) return true;
    final byId = index(allTasks);
    final visited = <String>{};

    bool reachesTask(String currentId) {
      if (currentId == taskId) return true;
      if (!visited.add(currentId)) return false;
      final current = byId[currentId];
      if (current == null) return false;
      return current.predecessorTaskIds.any(reachesTask);
    }

    return reachesTask(candidatePredecessorId);
  }

  /// Returns true when assigning [candidateParentId] as [taskId]'s parent
  /// would place a task under one of its own descendants.
  static bool wouldCreateHierarchyCycle({
    required String taskId,
    required String candidateParentId,
    required Iterable<AppTask> allTasks,
  }) {
    if (taskId == candidateParentId) return true;
    final byId = index(allTasks);
    final visited = <String>{};
    String? currentId = candidateParentId;
    while (currentId != null && visited.add(currentId)) {
      if (currentId == taskId) return true;
      currentId = byId[currentId]?.parentTaskId;
    }
    return false;
  }

  /// Finds the longest dependency chain by planned calendar duration. This
  /// is the planning screen's critical path. If the graph has no dependency
  /// edges, there is no meaningful critical path and an empty set is returned.
  static Set<String> criticalPath(Iterable<AppTask> tasks) {
    final list = tasks.toList();
    if (!list.any((task) => task.predecessorTaskIds.isNotEmpty)) return {};
    final byId = index(list);
    final memo = <String, ({double weight, List<String> path})>{};
    final visiting = <String>{};

    ({double weight, List<String> path}) longestTo(String taskId) {
      final cached = memo[taskId];
      if (cached != null) return cached;
      final task = byId[taskId];
      if (task == null || !visiting.add(taskId)) {
        return (weight: 0, path: const <String>[]);
      }

      ({double weight, List<String> path}) best = (
        weight: 0,
        path: const <String>[],
      );
      for (final predecessorId in task.predecessorTaskIds) {
        final candidate = longestTo(predecessorId);
        if (candidate.weight > best.weight) best = candidate;
      }
      visiting.remove(taskId);

      final days = task.dueDate.difference(task.startDate).inHours / 24;
      final result = (
        weight: best.weight + (days < 1 ? 1 : days),
        path: [...best.path, taskId],
      );
      memo[taskId] = result;
      return result;
    }

    ({double weight, List<String> path}) critical = (
      weight: 0,
      path: const <String>[],
    );
    for (final task in list) {
      final candidate = longestTo(task.taskId);
      if (candidate.weight > critical.weight) critical = candidate;
    }
    return critical.path.toSet();
  }

  static DateTime weekStart(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// Prorates each unfinished task's planned hours across its planned days,
  /// then sums only the portion that overlaps the selected week.
  static List<WorkloadEntry> workloadForWeek(
    Iterable<AppTask> tasks,
    DateTime anyDayInWeek, {
    Map<String, double> capacityByEmployee = const {},
  }) {
    final start = weekStart(anyDayInWeek);
    final end = start.add(const Duration(days: 7));
    final totals = <String, double>{};

    for (final task in tasks) {
      if (task.status == TaskStatus.approved || task.assignedTo.isEmpty)
        continue;
      final taskStart = DateTime(
        task.startDate.year,
        task.startDate.month,
        task.startDate.day,
      );
      final taskEnd = DateTime(
        task.dueDate.year,
        task.dueDate.month,
        task.dueDate.day,
      ).add(const Duration(days: 1));
      final overlapStart = taskStart.isAfter(start) ? taskStart : start;
      final overlapEnd = taskEnd.isBefore(end) ? taskEnd : end;
      if (!overlapEnd.isAfter(overlapStart)) continue;

      final totalDays = taskEnd
          .difference(taskStart)
          .inDays
          .clamp(1, 100000)
          .toInt();
      final overlapDays = overlapEnd.difference(overlapStart).inDays;
      final hours = task.plannedHours * overlapDays / totalDays;
      totals.update(
        task.assignedTo,
        (value) => value + hours,
        ifAbsent: () => hours,
      );
    }

    final result =
        totals.entries
            .map(
              (entry) => WorkloadEntry(
                employeeUid: entry.key,
                plannedHours: entry.value,
                capacityHours: capacityByEmployee[entry.key] ?? 40,
              ),
            )
            .toList()
          ..sort((a, b) => b.utilization.compareTo(a.utilization));
    return result;
  }
}
