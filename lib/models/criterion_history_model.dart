/// Audit-trail entry for a [Criterion] (see criterion_model.dart).
///
/// DESIGN DECISION: this is a PARALLEL model/collection to
/// [TaskHistoryEntry]/`task_history`, rather than a generalization of it —
/// consistent with this codebase's established pattern of one dedicated
/// collection per feature (documents/meetings/contacts/favorites are all
/// separate collections rather than one generic "activity" collection).
/// `TaskHistoryEntry.taskId` is a hardcoded field name or that model would
/// need a breaking rename to become criterion-aware; a small parallel model
/// avoids touching the existing, already-working task history code at all.
enum CriterionHistoryAction { submit, approve, reject, editRequest, statusChange }

class CriterionHistoryEntry {
  final String historyId;
  final String criterionId;
  final CriterionHistoryAction action;
  final String actorUid;
  final String? note;
  final DateTime timestamp;

  CriterionHistoryEntry({
    required this.historyId,
    required this.criterionId,
    required this.action,
    required this.actorUid,
    this.note,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'historyId': historyId,
      'criterionId': criterionId,
      'action': action.name,
      'actorUid': actorUid,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory CriterionHistoryEntry.fromMap(Map<dynamic, dynamic> map) {
    return CriterionHistoryEntry(
      historyId: map['historyId'] as String,
      criterionId: map['criterionId'] as String? ?? '',
      action: CriterionHistoryAction.values.firstWhere(
        (e) => e.name == map['action'],
        orElse: () => CriterionHistoryAction.statusChange,
      ),
      actorUid: map['actorUid'] as String? ?? '',
      note: map['note'] as String?,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now(),
    );
  }
}
