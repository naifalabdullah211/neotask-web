/// A "Criterion" ("معيار") — a sub-item that lives under a single [Goal]
/// (see goal_model.dart), as a genuine Firestore SUBCOLLECTION document at
/// `goals/{goalId}/criteria/{criteriaId}`.
///
/// REBUILD NOTE (this replaces the earlier Criterion design, which reused
/// [TaskStatus]/[TaskPriority] and a full manager approve/reject/edit-
/// request review workflow): per the manager's explicit, detailed
/// specification, a Criterion now carries ONLY [title], [description],
/// [status] (a dedicated 3-state [CriterionStatus]: notStarted/inProgress/
/// completed — NOT the 6-state [TaskStatus]), and [assignees] (one or more
/// employee uids). There is NO priority field, NO due date, and NO
/// manager-approval gate — status is a simple, freely-settable 3-state
/// value, settable by any assigned employee (or the manager).
///
/// [assignees] is a `List<String>` because a Criterion may be shared by
/// multiple employees at once (per the manager's spec example: "Increase
/// Radiology ratings" vs. "Increase Physical Therapy ratings" — distinct
/// criteria, each potentially assigned to a different set of employees).
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
  final CriterionStatus status;
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
    required this.createdAt,
    required this.updatedAt,
  });

  Criterion copyWith({
    String? title,
    String? description,
    List<String>? assignees,
    CriterionStatus? status,
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
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Criterion.fromMap(Map<dynamic, dynamic> map) {
    return Criterion(
      criterionId: map['criterionId'] as String,
      goalId: map['goalId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      assignees: (map['assignees'] as List?)?.cast<String>() ?? const [],
      assignedBy: map['assignedBy'] as String? ?? '',
      status: CriterionStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CriterionStatus.notStarted,
      ),
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
