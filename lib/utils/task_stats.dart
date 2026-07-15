import '../models/task_model.dart';

/// SINGLE SOURCE OF TRUTH for all task-count aggregates shown anywhere in
/// the app (manager dashboard cards + chart, designer dashboard cards +
/// chart, employee weekly mini-summary, PDF reports). Every one of those
/// call sites MUST call [computeTaskStats] instead of re-deriving its own
/// completed/pending/overdue logic — that duplication is the documented
/// root cause of the reported bug (cards disagreeing with their charts,
/// and the sum of all cards exceeding the "الإجمالي" total).
///
/// Guarantee (see the verification test in
/// `test/task_stats_consistency_test.dart`): for ANY list of tasks,
///   pending + inProgress + submitted + completed + rejected == total
/// ALWAYS holds, because these 5 buckets come directly from the single
/// mutually-exclusive [PrimaryTaskStatus] classification (see
/// `AppTaskStatusX.primaryStatus` in task_model.dart) — there is no
/// separate/independent logic per bucket that could drift out of sync.
///
/// `overdue` is reported separately and is INTENTIONALLY EXCLUDED from
/// that sum-to-total guarantee — it is a date-derived flag
/// ([AppTaskStatusX.isOverdue]) that can legitimately overlap with any
/// non-completed bucket (e.g. a rejected task whose due date has also
/// passed is counted in BOTH `rejected` and `overdue`). Never add
/// `overdue` into a total/breakdown sum.
class TaskStats {
  const TaskStats({
    required this.total,
    required this.pending,
    required this.inProgress,
    required this.submitted,
    required this.completed,
    required this.rejected,
    required this.overdue,
  });

  final int total;
  final int pending;
  final int inProgress;
  final int submitted;
  final int completed;
  final int rejected;

  /// Date-derived, NOT part of the pending/inProgress/submitted/
  /// completed/rejected breakdown — see class doc comment.
  final int overdue;

  /// Sum of the 5 mutually-exclusive primary-status buckets. Must always
  /// equal [total] by construction — verified by the widget/unit test.
  int get breakdownSum => pending + inProgress + submitted + completed + rejected;

  /// UI-facing merged bucket: "قيد الانتظار" as shown on the existing
  /// dashboard stat card historically covers BOTH not-yet-started
  /// ([PrimaryTaskStatus.pending]) and actively-being-worked-on
  /// ([PrimaryTaskStatus.inProgress]) tasks — there is no separate
  /// "قيد التنفيذ" card in the current dashboard layout. This getter is
  /// the ONE place that merges the two so the "قيد الانتظار" stat card
  /// AND its corresponding completion-chart bar always display the
  /// IDENTICAL number (the exact card-vs-chart drift reported: the
  /// chart previously added `submitted` instead of `inProgress` on top
  /// of the card's `pending` value). Use this — never re-add `submitted`
  /// or hand-roll `pending + inProgress` at a call site.
  int get pendingDisplay => pending + inProgress;
}

/// Computes [TaskStats] for [tasks] — the ONLY function in the codebase
/// permitted to classify tasks into completed/pending/overdue buckets for
/// display purposes. See [TaskStats] doc comment for the consistency
/// guarantee this centralization exists to provide.
TaskStats computeTaskStats(List<AppTask> tasks) {
  var pending = 0;
  var inProgress = 0;
  var submitted = 0;
  var completed = 0;
  var rejected = 0;
  var overdue = 0;

  for (final t in tasks) {
    switch (t.primaryStatus) {
      case PrimaryTaskStatus.pending:
        pending++;
        break;
      case PrimaryTaskStatus.inProgress:
        inProgress++;
        break;
      case PrimaryTaskStatus.submitted:
        submitted++;
        break;
      case PrimaryTaskStatus.completed:
        completed++;
        break;
      case PrimaryTaskStatus.rejected:
        rejected++;
        break;
    }
    if (t.isOverdue) overdue++;
  }

  return TaskStats(
    total: tasks.length,
    pending: pending,
    inProgress: inProgress,
    submitted: submitted,
    completed: completed,
    rejected: rejected,
    overdue: overdue,
  );
}
