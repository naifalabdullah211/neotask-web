/// A "Goal" ("هدف") is a top-level container the manager creates, holding
/// one or more Criteria ("معايير") underneath it — a 3-level hierarchy:
/// Goal → Criterion → Chat (see criterion_model.dart / criterion_chat_model.dart).
///
/// REBUILD NOTE (this replaces the earlier single-flat-collection Goal
/// design): per the manager's explicit, detailed specification, a Goal now
/// carries ONLY [title], [description], [startDate], and [endDate]. There
/// is NO goal-level `isClosed`/manual-closure step anymore — the previous
/// design's "manager must explicitly confirm completion" flag is dropped
/// entirely, since the new spec never mentions goal-level completion, only
/// criterion-level status (see CriterionStatus).
///
/// Firestore layout (per the manager's exact spec):
///   goals/{goalId} → title, description, startDate, endDate
///   goals/{goalId}/criteria/{criteriaId} → ... (see criterion_model.dart)
///   goals/{goalId}/criteria/{criteriaId}/chat/{messageId} → ... (see
///     criterion_chat_model.dart)
///
/// [createdBy] is kept (not explicitly requested, but needed for the
/// Firestore security rule that only a manager may create a Goal, and for
/// basic audit purposes) — this is the one field retained beyond the
/// literal spec, since it carries no UI/behavioral weight on its own.
class Goal {
  final String goalId;
  final String title;
  final String description;
  final String createdBy; // manager uid
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  Goal({
    required this.goalId,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  Goal copyWith({
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? updatedAt,
  }) {
    return Goal(
      goalId: goalId,
      title: title ?? this.title,
      description: description ?? this.description,
      createdBy: createdBy,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
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
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
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
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'] as String)
          : DateTime.now(),
      endDate: map['endDate'] != null
          ? DateTime.parse(map['endDate'] as String)
          : DateTime.now(),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}
