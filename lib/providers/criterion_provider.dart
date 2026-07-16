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
/// priority, and NO history log for criteria.
///
/// EXTENDED (multi-employee individual status — additive): the single
/// shared [Criterion.status] mutation method (`updateStatus`) is REPLACED
/// by [setEmployeeStatus] — each assigned employee updates ONLY their own
/// entry in [Criterion.employeeStatuses], atomically, via a dotted-field
/// Firestore update (see [FirestoreService.updateCriterionEmployeeStatus])
/// so two employees updating their own status concurrently never race
/// each other's write. The overall/aggregate status is NEVER written here
/// — it is always read via the derived [Criterion.aggregateStatus] getter.
///
/// [setAssignees] lets the manager add/remove employees from a criterion's
/// responsible list at any time. New employees are seeded with a fresh
/// `notStarted` entry; removed employees' entries are dropped; every
/// REMAINING previously-assigned employee's own recorded status is left
/// completely untouched — per the explicit requirement.
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
      employeeStatuses: {
        for (final uid in assignees) uid: CriterionStatus.notStarted.name,
      },
      createdAt: now,
      updatedAt: now,
    );
    await FirestoreService.saveCriterion(criterion);
    return criterion;
  }

  /// Title/description-only edit — assignees are edited exclusively via
  /// [setAssignees] and per-employee status via [setEmployeeStatus].
  Future<void> updateCriterion({
    required String criterionId,
    String? title,
    String? description,
  }) async {
    final criterion = FirestoreService.getCriterion(criterionId);
    if (criterion == null) return;
    final updated = criterion.copyWith(
      title: title,
      description: description,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveCriterion(updated);
  }

  /// Manager-only: add/remove employees from a criterion's responsible
  /// list at any time. See class doc comment for the exact
  /// preserve/seed/drop semantics.
  Future<void> setAssignees({
    required String criterionId,
    required List<String> assignees,
  }) async {
    final criterion = FirestoreService.getCriterion(criterionId);
    if (criterion == null) return;

    final newStatuses = <String, String>{
      for (final uid in assignees)
        uid: criterion.employeeStatuses[uid] ?? CriterionStatus.notStarted.name,
    };

    final updated = criterion.copyWith(
      assignees: assignees,
      employeeStatuses: newStatuses,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveCriterion(updated);
  }

  /// The sole per-employee status-mutation method. [employeeUid] updates
  /// ONLY their own entry — enforced both by the UI (a colleague's row is
  /// rendered non-interactive) AND by firestore.rules (a per-key map diff
  /// check), so this is defense-in-depth, not the only barrier.
  Future<void> setEmployeeStatus({
    required String criterionId,
    required String employeeUid,
    required CriterionStatus status,
  }) async {
    final criterion = FirestoreService.getCriterion(criterionId);
    if (criterion == null) return;
    await FirestoreService.updateCriterionEmployeeStatus(
      criterion.goalId,
      criterionId,
      employeeUid,
      status,
    );
  }

  Future<void> deleteCriterion(String goalId, String criterionId) async {
    await FirestoreService.deleteCriterion(goalId, criterionId);
  }
}
