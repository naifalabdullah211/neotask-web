import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/goal_model.dart';
import '../models/criterion_model.dart';
import '../models/task_model.dart' show TaskStatus;
import '../services/firestore_service.dart';

/// Manages the [Goal] side of the new Goal→Criteria hierarchy (see
/// goal_model.dart doc comment). Goals themselves carry very little
/// mutable state — the interesting logic here is `closeGoal()`, which
/// implements the manager's explicit requirement ("٣- يحتاج تأكيد") that
/// goal completion is NEVER auto-derived from its criteria's statuses; it
/// must always be an explicit manager action.
class GoalProvider extends ChangeNotifier {
  static const _uuid = Uuid();

  List<Goal> _allGoals = [];
  List<Goal> get allGoals => List.unmodifiable(_allGoals)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

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
  }) async {
    final now = DateTime.now();
    final goal = Goal(
      goalId: _uuid.v4(),
      title: title,
      description: description,
      createdBy: createdBy,
      isClosed: false,
      createdAt: now,
      updatedAt: now,
    );
    await FirestoreService.saveGoal(goal);
    return goal;
  }

  Future<void> updateGoal({
    required String goalId,
    String? title,
    String? description,
  }) async {
    final goal = FirestoreService.getGoal(goalId);
    if (goal == null) return;
    final updated = goal.copyWith(
      title: title,
      description: description,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveGoal(updated);
  }

  /// Explicitly closes [goalId] — the ONLY way a Goal is ever marked
  /// complete. This is a deliberate manager confirmation step, per answer
  /// "٣- يحتاج تاكيد": completion is never inferred automatically just
  /// because every Criterion under the Goal happens to be approved.
  Future<void> closeGoal(String goalId) async {
    final goal = FirestoreService.getGoal(goalId);
    if (goal == null) return;
    final updated = goal.copyWith(
      isClosed: true,
      closedAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveGoal(updated);
  }

  /// Reopens a previously-closed Goal (e.g. the manager closed it by
  /// mistake, or new criteria were added afterward).
  Future<void> reopenGoal(String goalId) async {
    final goal = FirestoreService.getGoal(goalId);
    if (goal == null) return;
    final updated = Goal(
      goalId: goal.goalId,
      title: goal.title,
      description: goal.description,
      createdBy: goal.createdBy,
      isClosed: false,
      closedAt: null,
      createdAt: goal.createdAt,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveGoal(updated);
  }

  Future<void> deleteGoal(String goalId) async {
    // Cascade-delete every Criterion under this Goal so no orphaned
    // criteria remain — mirrors the intent of `deleteAllTasksForEmployee`
    // (bulk cleanup) but scoped to a single parent Goal instead.
    final criteria = FirestoreService.getCriteriaForGoal(goalId);
    for (final c in criteria) {
      await FirestoreService.deleteCriterion(c.criterionId);
    }
    await FirestoreService.deleteGoal(goalId);
  }

  /// Derived progress summary for [goalId] — e.g. "3/5 معايير مكتملة" —
  /// computed purely from the live Criteria cache. This value is NEVER
  /// written back to the Goal document itself (see `closeGoal` doc
  /// comment above); it exists only for UI display.
  ({int total, int approved}) progressForGoal(String goalId) {
    final criteria = FirestoreService.getCriteriaForGoal(goalId);
    final approved = criteria
        .where((c) => c.status == TaskStatus.approved)
        .length;
    return (total: criteria.length, approved: approved);
  }

  List<Criterion> criteriaForGoal(String goalId) =>
      FirestoreService.getCriteriaForGoal(goalId);
}
