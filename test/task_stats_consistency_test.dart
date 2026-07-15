// Verification test required by the data-consistency bug report
// (requirement #4): the sum of the 5 mutually-exclusive primary-status
// buckets (pending + inProgress + submitted + completed + rejected) must
// ALWAYS equal the total task count — "الإجمالي" — regardless of which
// date-range filter (day/week/month) produced the task list being
// summarized. This test exercises [computeTaskStats] directly (the single
// centralized function every dashboard card, chart, and PDF report now
// reads from) against synthetic task lists that:
//   - cover all 6 persisted [TaskStatus] values (including the previously
//     uncounted `editRequested`),
//   - mix overdue and non-overdue due dates, including cases where a task
//     is BOTH overdue AND in a non-completed bucket (the exact overlap
//     that used to make the old card-sum exceed the total),
//   - are filtered using the SAME day/week/month range logic as
//     [TaskProvider.tasksForDay]/[tasksForWeek]/[tasksForMonth], so the
//     invariant is checked "في كل الفلاتر" (across every filter) as
//     explicitly requested.
import 'package:flutter_test/flutter_test.dart';
import 'package:neotask_pro/models/task_model.dart';
import 'package:neotask_pro/utils/task_stats.dart';

AppTask _task({
  required String id,
  required TaskStatus status,
  required DateTime dueDate,
}) {
  final now = DateTime.now();
  return AppTask(
    taskId: id,
    title: 'Task $id',
    description: '',
    assignedTo: 'employee_1',
    assignedBy: 'manager_1',
    dueDate: dueDate,
    priority: TaskPriority.medium,
    status: status,
    category: 'عام',
    createdAt: now,
    updatedAt: now,
  );
}

/// Mirrors [TaskProvider.tasksForDay] exactly (kept independent of
/// Firestore so this test has no backend dependency).
List<AppTask> _tasksForDay(List<AppTask> all, DateTime day) {
  return all
      .where(
        (t) =>
            t.dueDate.year == day.year &&
            t.dueDate.month == day.month &&
            t.dueDate.day == day.day,
      )
      .toList();
}

/// Mirrors [TaskProvider.tasksForWeek] exactly.
List<AppTask> _tasksForWeek(List<AppTask> all, DateTime anyDayInWeek) {
  final weekday = anyDayInWeek.weekday;
  final start = anyDayInWeek.subtract(Duration(days: weekday - 1));
  final end = start.add(const Duration(days: 6));
  return all
      .where(
        (t) =>
            !t.dueDate.isBefore(DateTime(start.year, start.month, start.day)) &&
            !t.dueDate.isAfter(
              DateTime(end.year, end.month, end.day, 23, 59, 59),
            ),
      )
      .toList();
}

/// Mirrors [TaskProvider.tasksForMonth] exactly.
List<AppTask> _tasksForMonth(List<AppTask> all, DateTime month) {
  return all
      .where(
        (t) => t.dueDate.year == month.year && t.dueDate.month == month.month,
      )
      .toList();
}

void _expectBreakdownMatchesTotal(TaskStats stats, {required String label}) {
  expect(
    stats.breakdownSum,
    stats.total,
    reason:
        '[$label] pending+inProgress+submitted+completed+rejected '
        '(${stats.pending}+${stats.inProgress}+${stats.submitted}+'
        '${stats.completed}+${stats.rejected}=${stats.breakdownSum}) '
        'must equal total (${stats.total})',
  );
}

void main() {
  group('computeTaskStats — single source of truth invariant', () {
    test('breakdownSum always equals total for a mixed synthetic task set '
        'covering all 6 TaskStatus values and both overdue and non-overdue '
        'due dates', () {
      final now = DateTime.now();
      final past = now.subtract(const Duration(days: 3)); // overdue
      final future = now.add(const Duration(days: 3)); // not overdue

      final tasks = <AppTask>[
        _task(id: '1', status: TaskStatus.assigned, dueDate: future),
        _task(id: '2', status: TaskStatus.assigned, dueDate: past), // overdue
        _task(id: '3', status: TaskStatus.inProgress, dueDate: future),
        _task(id: '4', status: TaskStatus.inProgress, dueDate: past), // overdue
        _task(id: '5', status: TaskStatus.submitted, dueDate: future),
        _task(id: '6', status: TaskStatus.submitted, dueDate: past), // overdue
        _task(
          id: '7',
          status: TaskStatus.approved,
          dueDate: past,
        ), // NOT overdue (completed)
        _task(id: '8', status: TaskStatus.approved, dueDate: future),
        _task(id: '9', status: TaskStatus.rejected, dueDate: future),
        _task(
          id: '10',
          status: TaskStatus.rejected,
          dueDate: past,
        ), // overdue AND rejected
        _task(id: '11', status: TaskStatus.editRequested, dueDate: future),
        _task(
          id: '12',
          status: TaskStatus.editRequested,
          dueDate: past,
        ), // overdue
      ];

      final stats = computeTaskStats(tasks);

      expect(stats.total, tasks.length);
      _expectBreakdownMatchesTotal(stats, label: 'full mixed set');

      // Explicit bucket expectations (confirms primaryStatus mapping,
      // including the editRequested -> pending judgment call).
      expect(stats.pending, 4); // assigned x2 + editRequested x2
      expect(stats.inProgress, 2);
      expect(stats.submitted, 2);
      expect(stats.completed, 2);
      expect(stats.rejected, 2);

      // Overdue is a separate flag: it must NOT be counted inside
      // breakdownSum, and it legitimately overlaps with non-completed
      // buckets (task '10' is both rejected AND overdue).
      expect(stats.overdue, 5); // tasks 2,4,6,10,12
      expect(
        stats.breakdownSum,
        stats.total,
        reason: 'overdue count must not distort breakdownSum==total',
      );

      // pendingDisplay merges pending+inProgress for the single
      // "قيد الانتظار" card/chart-bar shown on screen.
      expect(stats.pendingDisplay, stats.pending + stats.inProgress);
    });

    test('editRequested tasks are counted (previously a silent gap)', () {
      final tasks = [
        _task(
          id: 'e1',
          status: TaskStatus.editRequested,
          dueDate: DateTime.now().add(const Duration(days: 1)),
        ),
      ];
      final stats = computeTaskStats(tasks);
      expect(stats.total, 1);
      expect(stats.breakdownSum, 1);
      expect(stats.pending, 1);
    });

    test(
      'empty task list produces all-zero stats with breakdownSum==total',
      () {
        final stats = computeTaskStats(const []);
        expect(stats.total, 0);
        expect(stats.breakdownSum, 0);
        expect(stats.overdue, 0);
      },
    );

    test('invariant holds across the DAY filter (mirrors '
        'TaskProvider.tasksForDay)', () {
      final day = DateTime(2025, 6, 15);
      final otherDay = DateTime(2025, 6, 16);
      final all = <AppTask>[
        _task(id: 'd1', status: TaskStatus.assigned, dueDate: day),
        _task(id: 'd2', status: TaskStatus.inProgress, dueDate: day),
        _task(id: 'd3', status: TaskStatus.submitted, dueDate: day),
        _task(id: 'd4', status: TaskStatus.approved, dueDate: day),
        _task(id: 'd5', status: TaskStatus.rejected, dueDate: day),
        _task(id: 'd6', status: TaskStatus.editRequested, dueDate: day),
        // Noise belonging to a different day — must NOT be included.
        _task(id: 'd7', status: TaskStatus.approved, dueDate: otherDay),
      ];

      final dayTasks = _tasksForDay(all, day);
      expect(dayTasks.length, 6);

      final stats = computeTaskStats(dayTasks);
      expect(stats.total, 6);
      _expectBreakdownMatchesTotal(stats, label: 'day filter');
    });

    test('invariant holds across the WEEK filter (mirrors '
        'TaskProvider.tasksForWeek)', () {
      // Monday 2025-06-09 .. Sunday 2025-06-15
      final monday = DateTime(2025, 6, 9);
      final wednesday = DateTime(2025, 6, 11);
      final sunday = DateTime(2025, 6, 15);
      final nextMonday = DateTime(2025, 6, 16); // outside the week

      final all = <AppTask>[
        _task(id: 'w1', status: TaskStatus.assigned, dueDate: monday),
        _task(id: 'w2', status: TaskStatus.inProgress, dueDate: wednesday),
        _task(id: 'w3', status: TaskStatus.submitted, dueDate: wednesday),
        _task(id: 'w4', status: TaskStatus.approved, dueDate: sunday),
        _task(id: 'w5', status: TaskStatus.rejected, dueDate: sunday),
        _task(id: 'w6', status: TaskStatus.editRequested, dueDate: monday),
        // Noise belonging to the following week — must NOT be included.
        _task(id: 'w7', status: TaskStatus.approved, dueDate: nextMonday),
      ];

      final weekTasks = _tasksForWeek(all, wednesday);
      expect(weekTasks.length, 6);

      final stats = computeTaskStats(weekTasks);
      expect(stats.total, 6);
      _expectBreakdownMatchesTotal(stats, label: 'week filter');
    });

    test(
      'invariant holds across the MONTH filter (mirrors '
      'TaskProvider.tasksForMonth) — the explicitly requested الفلتر الشهري',
      () {
        final juneEarly = DateTime(2025, 6, 3);
        final juneMid = DateTime(2025, 6, 15);
        final juneLate = DateTime(2025, 6, 28);
        final july = DateTime(2025, 7, 1); // outside the month

        final all = <AppTask>[
          _task(id: 'm1', status: TaskStatus.assigned, dueDate: juneEarly),
          _task(id: 'm2', status: TaskStatus.inProgress, dueDate: juneMid),
          _task(id: 'm3', status: TaskStatus.submitted, dueDate: juneMid),
          _task(id: 'm4', status: TaskStatus.approved, dueDate: juneLate),
          _task(id: 'm5', status: TaskStatus.rejected, dueDate: juneLate),
          _task(id: 'm6', status: TaskStatus.editRequested, dueDate: juneEarly),
          // Noise belonging to a different month — must NOT be included.
          _task(id: 'm7', status: TaskStatus.approved, dueDate: july),
        ];

        final monthTasks = _tasksForMonth(all, juneMid);
        expect(monthTasks.length, 6);

        final stats = computeTaskStats(monthTasks);
        expect(stats.total, 6);
        _expectBreakdownMatchesTotal(stats, label: 'month filter');
      },
    );

    test('a rejected AND overdue task is counted exactly once in breakdownSum '
        '(regression guard for the reported "sum exceeds total" bug)', () {
      final overdueRejected = _task(
        id: 'r1',
        status: TaskStatus.rejected,
        dueDate: DateTime.now().subtract(const Duration(days: 10)),
      );
      final stats = computeTaskStats([overdueRejected]);

      expect(stats.total, 1);
      expect(stats.rejected, 1);
      expect(stats.overdue, 1); // flag is independently true
      expect(
        stats.breakdownSum,
        1,
        reason:
            'must not be double-counted in both rejected AND an overdue '
            'bucket — overdue is excluded from breakdownSum by design',
      );
    });
  });
}
