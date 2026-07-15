import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/criterion_model.dart';
import '../services/firestore_service.dart';

/// Manages the [Criterion] side of the Goal→Criteria→Chat hierarchy.
///
/// REBUILD NOTE: per the manager's literal, simplified specification (no
/// answer was given to confirm keeping the old review workflow, so the
/// minimal/literal reading of the spec was applied): there is NO manager
/// approve/reject/edit-request review workflow anymore, NO due date, NO
/// priority, and NO history log for criteria. A criterion only has
/// [Criterion.status] — a plain 3-state [CriterionStatus] — which any
/// assigned employee OR the manager may change freely via [updateStatus].
class CriterionProvider extends ChangeNotifier {
  static const _uuid = Uuid();

  List<Criterion> _allCriteria = [];
  List<Criterion> get allCriteria => _allCriteria;

  CriterionProvider() {
    _listenAll();
  }

  void _listenAll() {
    FirestoreService.watchAllCriteria().listen((criteria) {
      _allCriteria = criteria;
      notifyListeners();
    });
  }

  Criterion? getCriterion(String criterionId) {
    for (final c in _allCriteria) {
      if (c.criterionId == criterionId) return c;
    }
    return null;
  }

  List<Criterion> criteriaForGoal(String goalId) =>
      _allCriteria.where((c) => c.goalId == goalId).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  /// List-membership check (NOT `==`) — a Criterion may be shared by
  /// several employees at once.
  List<Criterion> criteriaForEmployee(String uid) =>
      _allCriteria.where((c) => c.assignees.contains(uid)).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  Future<Criterion> createCriterion({
    required String goalId,
    required String title,
    required String description,
    required List<String> assignees,
    required String assignedBy,
  }) async {
    final now = DateTime.now();
    final criterion = Criterion(
      criterionId: _uuid.v4(),
      goalId: goalId,
      title: title,
      description: description,
      assignees: assignees,
      assignedBy: assignedBy,
      status: CriterionStatus.notStarted,
      createdAt: now,
      updatedAt: now,
    );
    await FirestoreService.saveCriterion(criterion);
    return criterion;
  }

  Future<void> updateCriterion({
    required String criterionId,
    String? title,
    String? description,
    List<String>? assignees,
  }) async {
    final criterion = FirestoreService.getCriterion(criterionId);
    if (criterion == null) return;
    final updated = criterion.copyWith(
      title: title,
      description: description,
      assignees: assignees,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveCriterion(updated);
  }

  /// The sole status-mutation method. No approval gate: any assigned
  /// employee or the manager may set the status directly.
  Future<void> updateStatus(
    String criterionId,
    CriterionStatus status,
    String actorUid,
  ) async {
    final criterion = FirestoreService.getCriterion(criterionId);
    if (criterion == null) return;
    final updated = criterion.copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveCriterion(updated);
  }

  Future<void> deleteCriterion(String goalId, String criterionId) async {
    await FirestoreService.deleteCriterion(goalId, criterionId);
  }
}
