import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart' show TaskStatus, TaskPriority;
import '../models/criterion_model.dart';
import '../models/criterion_history_model.dart';
import '../services/firestore_service.dart';

/// Manages the [Criterion] side of the new Goal→Criteria hierarchy.
///
/// Deliberately mirrors [TaskProvider] almost method-for-method (per the
/// manager's explicit answer "٢- نفس سير العمل" — the review workflow
/// must be IDENTICAL to the existing task review workflow), with exactly
/// two structural differences:
///   1. `assignedTo` is a `List<String>` (multiple employees may share one
///      criterion, per answer "٤"), so every employee-scoped query uses
///      `.contains(uid)` instead of `==` equality.
///   2. History is logged to the parallel `criterion_history` collection
///      via [CriterionHistoryEntry], not `task_history`.
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
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  /// List-membership check (NOT `==`) — a Criterion may be shared by
  /// several employees at once (answer "٤").
  List<Criterion> criteriaForEmployee(String uid) =>
      _allCriteria.where((c) => c.assignedTo.contains(uid)).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<Criterion> get submittedForReview =>
      _allCriteria.where((c) => c.status == TaskStatus.submitted).toList()
        ..sort(
          (a, b) => (a.submittedAt ?? a.updatedAt).compareTo(
            b.submittedAt ?? b.updatedAt,
          ),
        );

  Future<Criterion> createCriterion({
    required String goalId,
    required String title,
    required String description,
    required List<String> assignedTo,
    required String assignedBy,
    required DateTime dueDate,
    required TaskPriority priority,
  }) async {
    final now = DateTime.now();
    final criterion = Criterion(
      criterionId: _uuid.v4(),
      goalId: goalId,
      title: title,
      description: description,
      assignedTo: assignedTo,
      assignedBy: assignedBy,
      dueDate: dueDate,
      priority: priority,
      status: TaskStatus.assigned,
      createdAt: now,
      updatedAt: now,
    );
    await FirestoreService.saveCriterion(criterion);
    await _logHistory(
      criterion.criterionId,
      CriterionHistoryAction.statusChange,
      assignedBy,
      note: 'تم إنشاء المعيار وإسناده',
    );
    return criterion;
  }

  Future<void> updateStatus(
    String criterionId,
    TaskStatus status,
    String actorUid,
  ) async {
    final criterion = FirestoreService.getCriterion(criterionId);
    if (criterion == null) return;
    final updated = criterion.copyWith(
      status: status,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveCriterion(updated);
    await _logHistory(
      criterionId,
      CriterionHistoryAction.statusChange,
      actorUid,
      note: 'تغيير الحالة إلى ${status.name}',
    );
  }

  Future<void> submitForReview(
    String criterionId,
    String employeeUid,
    String? note,
  ) async {
    final criterion = FirestoreService.getCriterion(criterionId);
    if (criterion == null) return;
    final updated = criterion.copyWith(
      status: TaskStatus.submitted,
      submittedAt: DateTime.now(),
      submissionNote: note,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveCriterion(updated);
    await _logHistory(
      criterionId,
      CriterionHistoryAction.submit,
      employeeUid,
      note: note,
    );
  }

  /// The manager's three-way review decision — IDENTICAL semantics and
  /// mandatory-note enforcement to `TaskProvider.reviewDecision` (answer
  /// "٢- نفس سير العمل"). Note this does NOT touch the parent Goal at
  /// all: Goal closure is always a separate, explicit manager action (see
  /// GoalProvider.closeGoal).
  Future<void> reviewDecision({
    required String criterionId,
    required String managerUid,
    required String decision, // 'approve' | 'reject' | 'edit_request'
    String? note,
  }) async {
    if (decision != 'approve' && (note == null || note.trim().isEmpty)) {
      throw ArgumentError('يجب إدخال سبب أو ملاحظة عند الرفض أو طلب التعديل');
    }

    final criterion = FirestoreService.getCriterion(criterionId);
    if (criterion == null) return;

    TaskStatus newStatus;
    CriterionHistoryAction action;
    switch (decision) {
      case 'approve':
        newStatus = TaskStatus.approved;
        action = CriterionHistoryAction.approve;
        break;
      case 'reject':
        newStatus = TaskStatus.rejected;
        action = CriterionHistoryAction.reject;
        break;
      case 'edit_request':
        newStatus = TaskStatus.editRequested;
        action = CriterionHistoryAction.editRequest;
        break;
      default:
        throw ArgumentError('قرار غير معروف: $decision');
    }

    final updated = criterion.copyWith(
      status: newStatus,
      reviewedAt: DateTime.now(),
      reviewedBy: managerUid,
      reviewDecision: decision,
      reviewNote: note,
      revisionCount: decision == 'approve'
          ? criterion.revisionCount
          : criterion.revisionCount + 1,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveCriterion(updated);
    await _logHistory(criterionId, action, managerUid, note: note);
  }

  /// After rejection/edit-request, employee resumes work — status returns
  /// to inProgress so the cycle can repeat (mirrors
  /// `TaskProvider.resumeAfterFeedback`).
  Future<void> resumeAfterFeedback(
    String criterionId,
    String employeeUid,
  ) async {
    final criterion = FirestoreService.getCriterion(criterionId);
    if (criterion == null) return;
    final updated = criterion.copyWith(
      status: TaskStatus.inProgress,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveCriterion(updated);
    await _logHistory(
      criterionId,
      CriterionHistoryAction.statusChange,
      employeeUid,
      note: 'استئناف العمل بعد ملاحظات المدير',
    );
  }

  Future<void> deleteCriterion(String criterionId) async {
    await FirestoreService.deleteCriterion(criterionId);
  }

  List<CriterionHistoryEntry> historyForCriterion(String criterionId) {
    return FirestoreService.getHistoryForCriterion(criterionId);
  }

  Future<void> _logHistory(
    String criterionId,
    CriterionHistoryAction action,
    String actorUid, {
    String? note,
  }) async {
    final entry = CriterionHistoryEntry(
      historyId: _uuid.v4(),
      criterionId: criterionId,
      action: action,
      actorUid: actorUid,
      note: note,
      timestamp: DateTime.now(),
    );
    await FirestoreService.addCriterionHistoryEntry(entry);
  }
}
