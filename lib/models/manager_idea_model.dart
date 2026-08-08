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
  final String? taskId;
  final String? taskTitle;
  final String? assigneeUid;
  final String? assigneeName;
  final String? employeeNumber;
  final DateTime? dueDate;
  final String? priority;
  final double? plannedHours;

  bool get isTaskRecord => recordType == 'task' && taskId?.isNotEmpty == true;

  Map<String, dynamic> toMap() => {
        'ideaId': ideaId,
        'content': content,
        'authorUid': authorUid,
        'authorName': authorName,
        'createdAt': Timestamp.fromDate(createdAt),
        'status': status,
        'recordType': recordType,
        if (actionType != null) 'actionType': actionType,
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
