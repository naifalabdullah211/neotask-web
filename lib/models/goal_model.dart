import 'goal_comment_model.dart';

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
/// EXTENDED (Goals-tab comprehensive improvements — additive, no removal
/// of the above): a Goal now ALSO carries:
///   - [colorName]: one of exactly 5 fixed RCJY brand colors (see
///     goal_style_options.dart's `goalColorNames`) — NOT a free color
///     picker. Nullable for backward compatibility with goals created
///     before this feature; [goalColorFromName] supplies the 'navy'
///     fallback wherever this is rendered.
///   - [iconName]: one of a fixed, bounded icon set (see
///     goal_style_options.dart's `goalIconNames`) — NOT a free icon
///     search. Nullable for the same backward-compatibility reason;
///     [goalIconFromName] supplies the 'flag' fallback (the previous
///     hardcoded icon) wherever this is rendered.
///   - [comments]: goal-level "تعليقات" — architecturally separate from
///     the Criterion chat system, reusing the exact Quick-Comments UX
///     mechanism already built for tasks. See [GoalComment]'s doc comment
///     for why this list also doubles as the goal's only event/history
///     log (no other goal-level event type currently exists).
///
/// Firestore layout (per the manager's exact spec, extended above):
///   goals/{goalId} → title, description, startDate, endDate, colorName,
///                    iconName, comments: [ {authorUid,text,createdAt}, ... ]
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
  final String? colorName; // one of goalColorNames, or null (legacy)
  final String? iconName; // one of goalIconNames, or null (legacy)
  final List<GoalComment> comments;

  Goal({
    required this.goalId,
    required this.title,
    required this.description,
    required this.createdBy,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.updatedAt,
    this.colorName,
    this.iconName,
    this.comments = const [],
  });

  Goal copyWith({
    String? title,
    String? description,
    DateTime? startDate,
    DateTime? endDate,
    DateTime? updatedAt,
    String? colorName,
    String? iconName,
    // Deliberately NOT a `List<GoalComment>? comments` param here — actual
    // appends to `comments` must go through
    // `FirestoreService.appendGoalComment` (atomic `FieldValue.arrayUnion`),
    // exactly mirroring the `ActivityLogEntry`/`activityLog` convention on
    // AppTask, to avoid read-modify-write races between concurrent
    // commenters.
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
      colorName: colorName ?? this.colorName,
      iconName: iconName ?? this.iconName,
      comments: comments,
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
      'colorName': colorName,
      'iconName': iconName,
      'comments': comments.map((c) => c.toMap()).toList(),
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
      colorName: map['colorName'] as String?,
      iconName: map['iconName'] as String?,
      comments: map['comments'] != null
          ? (map['comments'] as List)
                .map((e) => GoalComment.fromMap(e as Map))
                .toList()
          : const [],
    );
  }
}
