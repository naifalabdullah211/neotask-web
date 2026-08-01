import 'package:flutter_test/flutter_test.dart';
import 'package:neotask_pro/models/task_model.dart';
import 'package:neotask_pro/utils/project_planning.dart';

AppTask task(
  String id, {
  List<String> predecessors = const [],
  String? parent,
  TaskStatus status = TaskStatus.assigned,
  DateTime? start,
  DateTime? due,
  double hours = 8,
  String employee = 'employee-1',
}) {
  final now = DateTime(2026, 8, 3);
  return AppTask(
    taskId: id,
    title: id,
    description: '',
    assignedTo: employee,
    assignedBy: 'manager',
    startDate: start ?? now,
    dueDate: due ?? now.add(const Duration(days: 1)),
    plannedHours: hours,
    parentTaskId: parent,
    predecessorTaskIds: predecessors,
    priority: TaskPriority.medium,
    status: status,
    category: 'عام',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('dependency blocks until every predecessor is approved', () {
    final predecessor = task('a');
    final successor = task('b', predecessors: const ['a']);
    expect(
      ProjectPlanning.isBlocked(successor, [predecessor, successor]),
      isTrue,
    );

    final approved = predecessor.copyWith(status: TaskStatus.approved);
    expect(
      ProjectPlanning.isBlocked(successor, [approved, successor]),
      isFalse,
    );
  });

  test('open children prevent parent completion checks', () {
    final parent = task('parent');
    final child = task('child', parent: 'parent');
    expect(ProjectPlanning.openChildren('parent', [parent, child]), [child]);
    expect(
      ProjectPlanning.openChildren('parent', [
        parent,
        child.copyWith(status: TaskStatus.approved),
      ]),
      isEmpty,
    );
  });

  test(
    'planning scope excludes unrelated history but keeps linked history',
    () {
      final active = task('active', predecessors: const ['approved-link']);
      final linked = task('approved-link', status: TaskStatus.approved);
      final unrelated = task('approved-old', status: TaskStatus.approved);
      expect(ProjectPlanning.planningScope([active, linked, unrelated]), [
        active,
        linked,
      ]);
    },
  );

  test('critical path selects the longest dependency chain', () {
    final a = task('a', start: DateTime(2026, 8, 1), due: DateTime(2026, 8, 5));
    final b = task(
      'b',
      predecessors: const ['a'],
      start: DateTime(2026, 8, 6),
      due: DateTime(2026, 8, 10),
    );
    final short = task(
      'short',
      start: DateTime(2026, 8, 1),
      due: DateTime(2026, 8, 2),
    );
    expect(ProjectPlanning.criticalPath([a, b, short]), {'a', 'b'});
  });

  test(
    'cycle detection rejects a predecessor that already depends on task',
    () {
      final a = task('a', predecessors: const ['b']);
      final b = task('b');
      expect(
        ProjectPlanning.wouldCreateCycle(
          taskId: 'b',
          candidatePredecessorId: 'a',
          allTasks: [a, b],
        ),
        isTrue,
      );
    },
  );

  test('hierarchy cycle detection rejects parenting under a descendant', () {
    final parent = task('parent');
    final child = task('child', parent: 'parent');
    expect(
      ProjectPlanning.wouldCreateHierarchyCycle(
        taskId: 'parent',
        candidateParentId: 'child',
        allTasks: [parent, child],
      ),
      isTrue,
    );
  });

  test('weekly workload prorates planned hours over task duration', () {
    final item = task(
      'a',
      start: DateTime(2026, 8, 3),
      due: DateTime(2026, 8, 9),
      hours: 35,
    );
    final result = ProjectPlanning.workloadForWeek([
      item,
    ], DateTime(2026, 8, 5));
    expect(result.single.plannedHours, 35);
    expect(result.single.utilization, closeTo(.875, .001));
  });

  test('weekly workload uses the employee-specific capacity', () {
    final item = task(
      'a',
      start: DateTime(2026, 8, 3),
      due: DateTime(2026, 8, 9),
      hours: 24,
      employee: 'part-time',
    );
    final result = ProjectPlanning.workloadForWeek(
      [item],
      DateTime(2026, 8, 5),
      capacityByEmployee: const {'part-time': 20},
    );
    expect(result.single.capacityHours, 20);
    expect(result.single.isOverCapacity, isTrue);
    expect(result.single.utilization, closeTo(1.2, .001));
  });
}
