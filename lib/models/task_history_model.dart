enum HistoryAction { submit, approve, reject, editRequest, statusChange }

class TaskHistoryEntry {
  final String historyId;
  final String taskId;
  final HistoryAction action;
  final String actorUid;
  final String? note;
  final DateTime timestamp;

  TaskHistoryEntry({
    required this.historyId,
    required this.taskId,
    required this.action,
    required this.actorUid,
    this.note,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'historyId': historyId,
      'taskId': taskId,
      'action': action.name,
      'actorUid': actorUid,
      'note': note,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory TaskHistoryEntry.fromMap(Map<dynamic, dynamic> map) {
    return TaskHistoryEntry(
      historyId: map['historyId'] as String,
      taskId: map['taskId'] as String,
      action: HistoryAction.values.firstWhere(
        (e) => e.name == map['action'],
        orElse: () => HistoryAction.statusChange,
      ),
      actorUid: map['actorUid'] as String? ?? '',
      note: map['note'] as String?,
      timestamp: map['timestamp'] != null
          ? DateTime.parse(map['timestamp'] as String)
          : DateTime.now(),
    );
  }
}
