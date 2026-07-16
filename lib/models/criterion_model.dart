/// A "Criterion" ("معيار") — a sub-item that lives under a single [Goal]
/// (see goal_model.dart), as a genuine Firestore SUBCOLLECTION document at
/// `goals/{goalId}/criteria/{criteriaId}`.
///
/// REBUILD NOTE (this replaces the earlier Criterion design, which reused
/// [TaskStatus]/[TaskPriority] and a full manager approve/reject/edit-
/// request review workflow): per the manager's explicit, detailed
/// specification, a Criterion now carries ONLY [title], [description],
/// a status (a dedicated 3-state [CriterionStatus]: notStarted/inProgress/
/// completed — NOT the 6-state [TaskStatus]), and [assignees] (one or more
/// employee uids). There is NO priority field, NO due date, and NO
/// manager-approval gate.
///
/// [assignees] is a `List<String>` because a Criterion may be shared by
/// multiple employees at once (per the manager's spec example: "Increase
/// Radiology ratings" vs. "Increase Physical Therapy ratings" — distinct
/// criteria, each potentially assigned to a different set of employees).
///
/// EXTENDED (multi-employee individual status — additive, replaces the
/// single shared `status` field as the SOURCE OF TRUTH): per the explicit
/// requirement that each assigned employee has their OWN individual
/// completion status for the same criterion, completely separate from
/// other assignees' statuses, [employeeStatuses] is now a
/// `Map<String, String>` keyed by employee uid, valued by a
/// [CriterionStatus.name] string. This is genuinely persisted per-employee
/// data (not a derived value), so — unlike `aggregateStatus` below — it
/// DOES live directly on the Firestore document, exactly mirroring how
/// `AppTask.activityLog` is a real array field on its parent document.
///
/// The old single [status] field is KEPT ONLY for backward-compatibility
/// with criteria created before this feature (so `Criterion.fromMap` can
/// migrate a legacy value into an initial `employeeStatuses` entry for
/// every assignee — see [fromMap]) and is no longer written to by any new
/// code path; [aggregateStatus] below is the sole source of truth for any
/// "overall criterion status" UI going forward.
///
/// [aggregateStatus] is a DERIVED/COMPUTED getter — per this codebase's
/// established pattern (see GoalProvider.progressForGoal's doc comment:
/// "Never written back to ... document itself; exists only for UI
/// display") — NEVER persisted to Firestore, to avoid a second source of
/// truth that could desync from the per-employee statuses it is computed
/// from. Three-tier rule, chosen to satisfy the explicit spec example
/// literally ("تصبح مكتمل فقط عندما يكمل جميع الموظفين ... وإلا تبقى قيد
/// التنفيذ"), while still distinguishing the case where NO one has
/// started yet (more useful for the UI than collapsing that into
/// "قيد التنفيذ" too):
///   - completed  : assignees.isNotEmpty AND every assignee's own status
///                  is completed.
///   - notStarted : assignees.isEmpty, OR no assignee has an inProgress/
///                  completed status yet.
///   - inProgress : anything in between (at least one assignee has
///                  started or completed, but not all are completed).
///
/// CHAT: each Criterion has its OWN, wholly separate chat subcollection at
/// `goals/{goalId}/criteria/{criteriaId}/chat/{messageId}` (see
/// criterion_chat_model.dart) — this does NOT share any collection, model,
/// or provider with the existing Task chat system.
enum CriterionStatus { notStarted, inProgress, completed }

class Criterion {
  final String criterionId;
  final String goalId; // parent Goal
  final String title;
  final String description;
  final List<String> assignees; // one or more employee uids
  final String assignedBy; // manager uid
  final CriterionStatus status; // LEGACY — kept for back-compat only.
  final Map<String, String> employeeStatuses; // uid -> CriterionStatus.name
  final DateTime createdAt;
  final DateTime updatedAt;

  Criterion({
    required this.criterionId,
    required this.goalId,
    required this.title,
    required this.description,
    required this.assignees,
    required this.assignedBy,
    required this.status,
    this.employeeStatuses = const {},
    required this.createdAt,
    required this.updatedAt,
  });

  /// The per-employee status for [uid], defaulting to [notStarted] if that
  /// employee has no recorded entry yet (e.g. just added as a new
  /// assignee — see [CriterionProvider.setAssignees]).
  CriterionStatus statusFor(String uid) {
    final raw = employeeStatuses[uid];
    return CriterionStatus.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => CriterionStatus.notStarted,
    );
  }

  /// Derived overall status — see class doc comment. NEVER persisted.
  CriterionStatus get aggregateStatus {
    if (assignees.isEmpty) return CriterionStatus.notStarted;
    final statuses = assignees.map(statusFor).toList();
    final completedCount = statuses
        .where((s) => s == CriterionStatus.completed)
        .length;
    if (completedCount == assignees.length) return CriterionStatus.completed;
    final startedCount = statuses
        .where((s) => s != CriterionStatus.notStarted)
        .length;
    if (startedCount == 0) return CriterionStatus.notStarted;
    return CriterionStatus.inProgress;
  }

  /// e.g. "1 من 2 مكتمل" — the ratio display explicitly offered as an
  /// alternative to a single overall label in the spec.
  ({int completed, int total}) get completionRatio {
    if (assignees.isEmpty) return (completed: 0, total: 0);
    final completed = assignees
        .where((uid) => statusFor(uid) == CriterionStatus.completed)
        .length;
    return (completed: completed, total: assignees.length);
  }

  Criterion copyWith({
    String? title,
    String? description,
    List<String>? assignees,
    CriterionStatus? status,
    Map<String, String>? employeeStatuses,
    DateTime? updatedAt,
  }) {
    return Criterion(
      criterionId: criterionId,
      goalId: goalId,
      title: title ?? this.title,
      description: description ?? this.description,
      assignees: assignees ?? this.assignees,
      assignedBy: assignedBy,
      status: status ?? this.status,
      employeeStatuses: employeeStatuses ?? this.employeeStatuses,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'criterionId': criterionId,
      'goalId': goalId,
      'title': title,
      'description': description,
      'assignees': assignees,
      'assignedBy': assignedBy,
      'status': status.name,
      'employeeStatuses': employeeStatuses,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Criterion.fromMap(Map<dynamic, dynamic> map) {
    final assignees = (map['assignees'] as List?)?.cast<String>() ?? const [];
    final legacyStatus = CriterionStatus.values.firstWhere(
      (e) => e.name == map['status'],
      orElse: () => CriterionStatus.notStarted,
    );

    Map<String, String> employeeStatuses;
    if (map['employeeStatuses'] != null) {
      employeeStatuses = (map['employeeStatuses'] as Map).map(
        (k, v) => MapEntry(k as String, v as String),
      );
    } else {
      // MIGRATION: no per-employee data yet (criterion predates this
      // feature) — seed every current assignee with the legacy shared
      // `status` value so existing criteria still display sensibly
      // instead of silently resetting everyone to notStarted.
      employeeStatuses = {for (final uid in assignees) uid: legacyStatus.name};
    }

    return Criterion(
      criterionId: map['criterionId'] as String,
      goalId: map['goalId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      assignees: assignees,
      assignedBy: map['assignedBy'] as String? ?? '',
      status: legacyStatus,
      employeeStatuses: employeeStatuses,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}

String criterionStatusLabelAr(CriterionStatus status) {
  switch (status) {
    case CriterionStatus.notStarted:
      return 'لم يبدأ';
    case CriterionStatus.inProgress:
      return 'قيد التنفيذ';
    case CriterionStatus.completed:
      return 'مكتمل';
  }
}
