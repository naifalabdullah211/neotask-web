import 'task_model.dart' show TaskStatus, TaskPriority;

/// A "Criterion" ("معيار") — a sub-item that lives under a single [Goal],
/// analogous to a Smartsheet sub-row. This is the item that actually gets
/// worked on: it carries a due date, priority, status, and one or more
/// assigned employees.
///
/// KEY DESIGN DECISIONS (all explicitly confirmed by the manager):
/// - Multiple assignees per criterion ARE supported (answer ٤: "يمكن لعدة
///   موظفين المشاركة بحسب رغبة المدير") — hence [assignedTo] is a
///   `List<String>`, not a single uid like `AppTask.assignedTo`.
/// - Review workflow is IDENTICAL to the existing task system (answer ٢:
///   "نفس سير العمل") — reuses [TaskStatus] and [TaskPriority] from
///   task_model.dart so the same three-way manager decision
///   (approve/reject/edit_request) and the same mandatory-note-on-reject
///   rule apply here too (see GoalProvider.reviewCriterion).
/// - A Criterion does NOT auto-complete its parent Goal — see
///   goal_model.dart's doc comment: the manager must explicitly close the
///   Goal once satisfied that all criteria are done (answer ٣).
///
/// CHAT: each Criterion has its OWN chat thread between the manager and
/// its assigned employee(s) — mirrors the existing per-task chat pattern
/// (`ChatMessage.taskConversationId`), using an analogous deterministic
/// id `'criterion_<criterionId>'` (see ChatMessage in message_model.dart,
/// extended with `criterionConversationId`).
class Criterion {
  final String criterionId;
  final String goalId; // parent Goal
  final String title;
  final String description;
  final List<String> assignedTo; // one or more employee uids
  final String assignedBy; // manager uid
  final DateTime dueDate;
  final TaskPriority priority;
  final TaskStatus status;

  final DateTime? submittedAt;
  final String? submissionNote;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewDecision; // approve | reject | edit_request
  final String? reviewNote;
  final int revisionCount;

  final DateTime createdAt;
  final DateTime updatedAt;

  Criterion({
    required this.criterionId,
    required this.goalId,
    required this.title,
    required this.description,
    required this.assignedTo,
    required this.assignedBy,
    required this.dueDate,
    required this.priority,
    required this.status,
    this.submittedAt,
    this.submissionNote,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewDecision,
    this.reviewNote,
    this.revisionCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  Criterion copyWith({
    String? title,
    String? description,
    List<String>? assignedTo,
    DateTime? dueDate,
    TaskPriority? priority,
    TaskStatus? status,
    DateTime? submittedAt,
    String? submissionNote,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? reviewDecision,
    String? reviewNote,
    int? revisionCount,
    DateTime? updatedAt,
  }) {
    return Criterion(
      criterionId: criterionId,
      goalId: goalId,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedBy: assignedBy,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      submittedAt: submittedAt ?? this.submittedAt,
      submissionNote: submissionNote ?? this.submissionNote,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewDecision: reviewDecision ?? this.reviewDecision,
      reviewNote: reviewNote ?? this.reviewNote,
      revisionCount: revisionCount ?? this.revisionCount,
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
      'assignedTo': assignedTo,
      'assignedBy': assignedBy,
      'dueDate': dueDate.toIso8601String(),
      'priority': priority.name,
      'status': status.name,
      'submittedAt': submittedAt?.toIso8601String(),
      'submissionNote': submissionNote,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewedBy': reviewedBy,
      'reviewDecision': reviewDecision,
      'reviewNote': reviewNote,
      'revisionCount': revisionCount,
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
      assignedTo: (map['assignedTo'] as List?)?.cast<String>() ?? const [],
      assignedBy: map['assignedBy'] as String? ?? '',
      dueDate: map['dueDate'] != null
          ? DateTime.parse(map['dueDate'] as String)
          : DateTime.now(),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => TaskPriority.medium,
      ),
      status: TaskStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => TaskStatus.assigned,
      ),
      submittedAt: map['submittedAt'] != null
          ? DateTime.parse(map['submittedAt'] as String)
          : null,
      submissionNote: map['submissionNote'] as String?,
      reviewedAt: map['reviewedAt'] != null
          ? DateTime.parse(map['reviewedAt'] as String)
          : null,
      reviewedBy: map['reviewedBy'] as String?,
      reviewDecision: map['reviewDecision'] as String?,
      reviewNote: map['reviewNote'] as String?,
      revisionCount: map['revisionCount'] as int? ?? 0,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}
