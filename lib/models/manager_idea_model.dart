import 'package:cloud_firestore/cloud_firestore.dart';

/// A short improvement idea captured directly from the manager workspace.
class ManagerIdea {
  const ManagerIdea({
    required this.ideaId,
    required this.content,
    required this.authorUid,
    required this.authorName,
    required this.createdAt,
    this.status = 'new',
    this.recordType = 'note',
    this.actionType,
    this.recordTitle,
    this.ruleId,
    this.taskId,
    this.taskTitle,
    this.assigneeUid,
    this.assigneeName,
    this.employeeNumber,
    this.dueDate,
    this.priority,
    this.plannedHours,
  });

  final String ideaId;
  final String content;
  final String authorUid;
  final String authorName;
  final DateTime createdAt;
  final String status;
  final String recordType;
  final String? actionType;
  final String? recordTitle;
  final String? ruleId;
  final String? taskId;
  final String? taskTitle;
  final String? assigneeUid;
  final String? assigneeName;
  final String? employeeNumber;
  final DateTime? dueDate;
  final String? priority;
  final double? plannedHours;

  bool get isTaskRecord => recordType == 'task' && taskId?.isNotEmpty == true;

  bool get isInitiativeRecord =>
      isTaskRecord && actionType == 'create_initiative';

  bool get isRuleRecord =>
      recordType == 'rule' ||
      actionType == 'update_agent_rule' ||
      content.trimLeft().startsWith('قاعدة دائمة للوكيل:');

  bool get isAnalysisRecord =>
      recordType == 'analysis' ||
      actionType == 'team_summary' ||
      content.trimLeft().startsWith('ملخص فريق:');

  bool get hasLinkedRule => isRuleRecord && ruleId?.isNotEmpty == true;

  String get displayTitle {
    final explicitTitle = recordTitle?.trim() ?? '';
    if (explicitTitle.isNotEmpty) return explicitTitle;

    final taskRecordTitle = taskTitle?.trim() ?? '';
    if (taskRecordTitle.isNotEmpty) return taskRecordTitle;

    final firstLine = content.trim().split('\n').first.trim();
    for (final prefix in const [
      'قاعدة دائمة للوكيل:',
      'ملخص فريق:',
    ]) {
      if (firstLine.startsWith(prefix)) {
        final withoutPrefix = firstLine.substring(prefix.length).trim();
        if (withoutPrefix.isNotEmpty) return withoutPrefix;
      }
    }
    return firstLine;
  }

  String get displayDetails {
    final lines = content
        .trim()
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) return '';

    final hasLegacyHeading = lines.first.startsWith('قاعدة دائمة للوكيل:') ||
        lines.first.startsWith('ملخص فريق:');
    final detail = (hasLegacyHeading ? lines.skip(1) : lines).join('\n').trim();
    if (detail == displayTitle.trim()) return '';
    return detail;
  }

  Map<String, dynamic> toMap() => {
        'ideaId': ideaId,
        'content': content,
        'authorUid': authorUid,
        'authorName': authorName,
        'createdAt': Timestamp.fromDate(createdAt),
        'status': status,
        'recordType': recordType,
        if (actionType != null) 'actionType': actionType,
        if (recordTitle != null) 'recordTitle': recordTitle,
        if (ruleId != null) 'ruleId': ruleId,
        if (taskId != null) 'taskId': taskId,
        if (taskTitle != null) 'taskTitle': taskTitle,
        if (assigneeUid != null) 'assigneeUid': assigneeUid,
        if (assigneeName != null) 'assigneeName': assigneeName,
        if (employeeNumber != null) 'employeeNumber': employeeNumber,
        if (dueDate != null) 'dueDate': Timestamp.fromDate(dueDate!),
        if (priority != null) 'priority': priority,
        if (plannedHours != null) 'plannedHours': plannedHours,
      };

  factory ManagerIdea.fromMap(Map<String, dynamic> map) {
    final rawCreatedAt = map['createdAt'];
    final rawDueDate = map['dueDate'];
    return ManagerIdea(
      ideaId: map['ideaId'] as String? ?? '',
      content: map['content'] as String? ?? '',
      authorUid: map['authorUid'] as String? ?? '',
      authorName: map['authorName'] as String? ?? '',
      createdAt: rawCreatedAt is Timestamp
          ? rawCreatedAt.toDate()
          : DateTime.tryParse(rawCreatedAt?.toString() ?? '') ?? DateTime.now(),
      status: map['status'] as String? ?? 'new',
      recordType: map['recordType'] as String? ?? 'note',
      actionType: map['actionType'] as String?,
      recordTitle: map['recordTitle'] as String?,
      ruleId: map['ruleId'] as String?,
      taskId: map['taskId'] as String?,
      taskTitle: map['taskTitle'] as String?,
      assigneeUid: map['assigneeUid'] as String?,
      assigneeName: map['assigneeName'] as String?,
      employeeNumber: map['employeeNumber'] as String?,
      dueDate: rawDueDate is Timestamp
          ? rawDueDate.toDate()
          : DateTime.tryParse(rawDueDate?.toString() ?? ''),
      priority: map['priority'] as String?,
      plannedHours: (map['plannedHours'] as num?)?.toDouble(),
    );
  }
}
