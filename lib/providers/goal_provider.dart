import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/goal_model.dart';
import '../models/goal_comment_model.dart';
import '../models/criterion_model.dart';
import '../services/firestore_service.dart';

/// Manages the [Goal] side of the Goal→Criteria→Chat hierarchy (see
/// goal_model.dart doc comment).
///
/// REBUILD NOTE: the previous version of this provider had a manual
/// `closeGoal`/`reopenGoal` pair implementing an explicit manager
/// "confirm completion" step. That feature is REMOVED per the manager's
/// new, literal specification, which defines a Goal as carrying only
/// title/description/startDate/endDate and never mentions goal-level
/// completion — only criterion-level [CriterionStatus].
class GoalProvider extends ChangeNotifier {
  static const _uuid = Uuid();

  List<Goal> _allGoals = [];

  /// Returns a sorted, read-only snapshot of all goals (newest first).
  ///
  /// BUG FIX (retained from the crash-fix pass): the previous
  /// implementation called `.sort()` directly on the result of
  /// `List.unmodifiable(_allGoals)`, which is immutable — `.sort()`
  /// mutates its receiver in place, so every call threw `Unsupported
  /// operation: Cannot modify an unmodifiable list`. Fix: sort a mutable
  /// copy first, then wrap the already-sorted copy as unmodifiable.
  List<Goal> get allGoals {
    final sorted = List<Goal>.of(_allGoals)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(sorted);
  }

  GoalProvider() {
    _listenAll();
  }

  void _listenAll() {
    FirestoreService.watchAllGoals().listen((goals) {
      _allGoals = goals;
      notifyListeners();
    });
  }

  Goal? getGoal(String goalId) {
    for (final g in _allGoals) {
      if (g.goalId == goalId) return g;
    }
    return null;
  }

  Future<Goal> createGoal({
    required String title,
    required String description,
    required String createdBy,
    required DateTime startDate,
    required DateTime endDate,
    // Fixed-palette color name (one of goalColorNames) and fixed icon
    // name (one of goalIconNames) — see goal_style_options.dart. Both
    // optional so any pre-existing call site keeps compiling; the UI
    // dialogs always pass them going forward.
    String? colorName,
    String? iconName,
  }) async {
    final now = DateTime.now();
    final goal = Goal(
      goalId: _uuid.v4(),
      title: title,
      description: description,
      createdBy: createdBy,
      startDate: startDate,
      endDate: endDate,
      createdAt: now,
      updatedAt: now,
      colorName: colorName,
      iconName: iconName,
    );
    await FirestoreService.saveGoal(goal);
    return goal;
  }

  Future<void> updateGoal({
    required String goalId,
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    String? colorName,
    String? iconName,
  }) async {
    final goal = FirestoreService.getGoal(goalId);
    if (goal == null) return;
    final updated = goal.copyWith(
      title: title,
      description: description,
      startDate: startDate,
      endDate: endDate,
      colorName: colorName,
      iconName: iconName,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveGoal(updated);
  }

  Future<void> deleteGoal(String goalId) async {
    // FirestoreService.deleteGoal already cascades to every Criterion (and
    // every criterion's chat messages) under this Goal — see its doc
    // comment for why that cascade is necessary (Firestore does not
    // auto-delete subcollections).
    await FirestoreService.deleteGoal(goalId);
  }

  // =========================================================================
  // GOAL-LEVEL COMMENTS — "تعليقات" (NEW — additive feature)
  // =========================================================================
  // Architecturally SEPARATE from the Criterion chat system (see
  // criterion_chat_model.dart) — this reuses the exact Quick-Comments UX
  // mechanism already built for tasks (TaskProvider.addComment): a plain
  // text box + إرسال button, each entry showing author name + timestamp +
  // text, atomically appended via `FieldValue.arrayUnion`
  // (see FirestoreService.appendGoalComment). See GoalComment's doc
  // comment for why this also serves as the goal's history/event log.
  Future<void> addComment({
    required String goalId,
    required String authorUid,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final goal = FirestoreService.getGoal(goalId);
    if (goal == null) return;

    final comment = GoalComment(
      authorUid: authorUid,
      text: trimmed,
      createdAt: DateTime.now(),
    );
    await FirestoreService.appendGoalComment(goalId, comment);
  }

  /// Derived progress summary for [goalId] — e.g. "3/5 معايير مكتملة" —
  /// computed purely from the live Criteria cache. Never written back to
  /// the Goal document itself; exists only for UI display.
  ///
  /// Uses each criterion's DERIVED [Criterion.aggregateStatus] (per-
  /// employee-status-aware) rather than the legacy shared `status` field,
  /// so a criterion only counts as "completed" once EVERY one of its
  /// assignees has individually completed it.
  ({int total, int completed}) progressForGoal(String goalId) {
    final criteria = FirestoreService.getCriteriaForGoal(goalId);
    final completed = criteria
        .where((c) => c.aggregateStatus == CriterionStatus.completed)
        .length;
    return (total: criteria.length, completed: completed);
  }

  List<Criterion> criteriaForGoal(String goalId) =>
      FirestoreService.getCriteriaForGoal(goalId);
}
