/// A "Goal" ("هدف") is a top-level container the manager creates, holding
/// one or more Criteria ("معايير") underneath it — the Smartsheet-style
/// row/sub-item hierarchy explicitly requested by the manager.
///
/// IMPORTANT ARCHITECTURAL NOTE: per the manager's explicit answer (١ —
/// "إضافة", i.e. ADDITION not replacement), this is a completely SEPARATE
/// feature that lives ALONGSIDE the existing flat `AppTask` system. The
/// existing Dashboard / Review / "مهامي" / Calendar screens are entirely
/// unaffected and continue to operate on standalone `AppTask` records
/// exactly as before. A Goal's Criteria are a NEW, independent object type
/// (see criterion_model.dart) — they do NOT reuse `AppTask` internally,
/// because a Criterion has different semantics (can be assigned to
/// MULTIPLE employees, per answer ٤) and a different completion model
/// (manager must give a final confirmation once all criteria are done,
/// per answer ٣ — see GoalProvider.closeGoal).
///
/// The Goal itself has no due date or assignee of its own — it is purely
/// a named grouping. Its effective "status" is always derived at read
/// time from its Criteria (see GoalProvider.goalStatus), except for the
/// final `isClosed` flag, which is the one piece of state that must be
/// explicitly set by the manager (per answer ٣).
class Goal {
  final String goalId;
  final String title;
  final String description;
  final String createdBy; // manager uid
  final bool isClosed; // true once the manager manually confirms completion
  final DateTime? closedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Goal({
    required this.goalId,
    required this.title,
    required this.description,
    required this.createdBy,
    this.isClosed = false,
    this.closedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Goal copyWith({
    String? title,
    String? description,
    bool? isClosed,
    DateTime? closedAt,
    DateTime? updatedAt,
  }) {
    return Goal(
      goalId: goalId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdBy: createdBy,
      isClosed: isClosed ?? this.isClosed,
      closedAt: closedAt ?? this.closedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'goalId': goalId,
      'title': title,
      'description': description,
      'createdBy': createdBy,
      'isClosed': isClosed,
      'closedAt': closedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Goal.fromMap(Map<dynamic, dynamic> map) {
    return Goal(
      goalId: map['goalId'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      isClosed: map['isClosed'] as bool? ?? false,
      closedAt: map['closedAt'] != null
          ? DateTime.parse(map['closedAt'] as String)
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}
