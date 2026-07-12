enum TaskStatus {
  assigned,
  inProgress,
  submitted,
  approved,
  rejected,
  editRequested,
}

enum TaskPriority { low, medium, high }

enum RecurrenceType {
  none,
  daily,
  weekly,
  monthlyFixedDate,
  monthlyWeekdayPattern,
}

enum WeekOrdinal { first, second, third, fourth, last }

enum Weekday { monday, tuesday, wednesday, thursday, friday, saturday, sunday }

class AppTask {
  final String taskId;
  final String title;
  final String description;
  final String assignedTo; // employee uid
  final String assignedBy; // manager uid
  final DateTime dueDate;
  final TaskPriority priority;
  final TaskStatus status;
  final String category;

  final RecurrenceType recurrenceType;
  final int? recurrenceDayOfMonth; // for monthlyFixedDate
  final WeekOrdinal? recurrenceWeekOrdinal; // for monthlyWeekdayPattern
  final Weekday? recurrenceWeekday; // for monthlyWeekdayPattern
  final DateTime? recurrenceEndDate;

  final DateTime? submittedAt;
  final String? submissionNote;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewDecision; // approve | reject | edit_request
  final String? reviewNote;
  final int revisionCount;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// In-app "new task" indicator (see the notifications feature). True once
  /// the assigned employee has opened [TaskDetailScreen] for this task at
  /// least once since it was last (re)flagged. Reset to `false` whenever a
  /// manager action targets this employee (new assignment, or a review
  /// decision on a previously-submitted task) so the employee sees an
  /// unread-style badge on the "مهامي" tab until they open it.
  final bool viewedByEmployee;

  // ---- Employee-initiated reassignment request (NEW — additive feature)
  // ----
  // Per the manager's explicit design answers:
  //   ٢- الموظف الأول يستمر بالعمل على المهمة لحين رد المدير (task status/
  //      fields are NOT frozen while a request is pending — only these 4
  //      fields below are added on top).
  //   ٣- عند الموافقة تنتقل المهمة بكل ما فيها (كل الحقول الأخرى، بما فيها
  //      status/history) إلى الموظف الجديد؛ فقط assignedTo يتغيّر.
  //   ٤- عند الرفض لا يتطلب سبب، وتبقى المهمة كاملة عند الموظف الأول (فقط
  //      حقول الطلب تُعاد إلى null).
  //   ٦- الموظف الجديد يحتاج لتأكيد استلام المهمة بعد موافقة المدير — لذلك
  //      حالة الموافقة ('approved') وحدها لا تكفي لنقل [assignedTo] فعليًا؛
  //      انظر [reassignAcceptedByNewEmployee] أدناه.
  //
  // `reassignRequestedStatus` values actually persisted on the task:
  //   'pending'             — awaiting the manager's decision.
  //   'awaitingNewEmployee' — manager approved; awaiting the NEW employee's
  //                           confirmation (per answer ٦).
  // On rejection OR on the new employee's confirmation, all 4 fields below
  // are cleared back to null in the SAME write that either restores the
  // original employee's exclusive ownership (reject) or transfers
  // `assignedTo` to the new employee (confirm) — so 'rejected'/'approved'
  // are never themselves persisted values; they only appear as
  // ReassignHistoryAction entries in the audit trail.
  final String? reassignRequestedTo; // uid of the proposed new employee
  final String?
  reassignRequestedBy; // uid of the current employee who requested it
  final DateTime? reassignRequestedAt;
  final String? reassignRequestedStatus;

  AppTask({
    required this.taskId,
    required this.title,
    required this.description,
    required this.assignedTo,
    required this.assignedBy,
    required this.dueDate,
    required this.priority,
    required this.status,
    required this.category,
    this.recurrenceType = RecurrenceType.none,
    this.recurrenceDayOfMonth,
    this.recurrenceWeekOrdinal,
    this.recurrenceWeekday,
    this.recurrenceEndDate,
    this.submittedAt,
    this.submissionNote,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewDecision,
    this.reviewNote,
    this.revisionCount = 0,
    this.viewedByEmployee = false,
    this.reassignRequestedTo,
    this.reassignRequestedBy,
    this.reassignRequestedAt,
    this.reassignRequestedStatus,
    required this.createdAt,
    required this.updatedAt,
  });

  AppTask copyWith({
    String? title,
    String? description,
    String? assignedTo,
    DateTime? dueDate,
    TaskPriority? priority,
    TaskStatus? status,
    String? category,
    RecurrenceType? recurrenceType,
    int? recurrenceDayOfMonth,
    WeekOrdinal? recurrenceWeekOrdinal,
    Weekday? recurrenceWeekday,
    DateTime? recurrenceEndDate,
    DateTime? submittedAt,
    String? submissionNote,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? reviewDecision,
    String? reviewNote,
    int? revisionCount,
    bool? viewedByEmployee,
    String? reassignRequestedTo,
    String? reassignRequestedBy,
    DateTime? reassignRequestedAt,
    String? reassignRequestedStatus,
    // Standard `??` fallback-to-existing-value semantics cannot express
    // "explicitly set this nullable field back to null" — needed when a
    // reassignment request is rejected or finally confirmed (all 4
    // reassignRequest* fields must be wiped in one write). This flag
    // overrides the 4 fields above to null regardless of what was passed.
    bool clearReassignRequest = false,
    DateTime? updatedAt,
  }) {
    return AppTask(
      taskId: taskId,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedBy: assignedBy,
      dueDate: dueDate ?? this.dueDate,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      category: category ?? this.category,
      recurrenceType: recurrenceType ?? this.recurrenceType,
      recurrenceDayOfMonth: recurrenceDayOfMonth ?? this.recurrenceDayOfMonth,
      recurrenceWeekOrdinal:
          recurrenceWeekOrdinal ?? this.recurrenceWeekOrdinal,
      recurrenceWeekday: recurrenceWeekday ?? this.recurrenceWeekday,
      recurrenceEndDate: recurrenceEndDate ?? this.recurrenceEndDate,
      submittedAt: submittedAt ?? this.submittedAt,
      submissionNote: submissionNote ?? this.submissionNote,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewDecision: reviewDecision ?? this.reviewDecision,
      reviewNote: reviewNote ?? this.reviewNote,
      revisionCount: revisionCount ?? this.revisionCount,
      viewedByEmployee: viewedByEmployee ?? this.viewedByEmployee,
      reassignRequestedTo: clearReassignRequest
          ? null
          : (reassignRequestedTo ?? this.reassignRequestedTo),
      reassignRequestedBy: clearReassignRequest
          ? null
          : (reassignRequestedBy ?? this.reassignRequestedBy),
      reassignRequestedAt: clearReassignRequest
          ? null
          : (reassignRequestedAt ?? this.reassignRequestedAt),
      reassignRequestedStatus: clearReassignRequest
          ? null
          : (reassignRequestedStatus ?? this.reassignRequestedStatus),
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'taskId': taskId,
      'title': title,
      'description': description,
      'assignedTo': assignedTo,
      'assignedBy': assignedBy,
      'dueDate': dueDate.toIso8601String(),
      'priority': priority.name,
      'status': status.name,
      'category': category,
      'recurrenceType': recurrenceType.name,
      'recurrenceDayOfMonth': recurrenceDayOfMonth,
      'recurrenceWeekOrdinal': recurrenceWeekOrdinal?.name,
      'recurrenceWeekday': recurrenceWeekday?.name,
      'recurrenceEndDate': recurrenceEndDate?.toIso8601String(),
      'submittedAt': submittedAt?.toIso8601String(),
      'submissionNote': submissionNote,
      'reviewedAt': reviewedAt?.toIso8601String(),
      'reviewedBy': reviewedBy,
      'reviewDecision': reviewDecision,
      'reviewNote': reviewNote,
      'revisionCount': revisionCount,
      'viewedByEmployee': viewedByEmployee,
      'reassignRequestedTo': reassignRequestedTo,
      'reassignRequestedBy': reassignRequestedBy,
      'reassignRequestedAt': reassignRequestedAt?.toIso8601String(),
      'reassignRequestedStatus': reassignRequestedStatus,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory AppTask.fromMap(Map<dynamic, dynamic> map) {
    return AppTask(
      taskId: map['taskId'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      assignedTo: map['assignedTo'] as String? ?? '',
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
      category: map['category'] as String? ?? 'عام',
      recurrenceType: RecurrenceType.values.firstWhere(
        (e) => e.name == map['recurrenceType'],
        orElse: () => RecurrenceType.none,
      ),
      recurrenceDayOfMonth: map['recurrenceDayOfMonth'] as int?,
      recurrenceWeekOrdinal: map['recurrenceWeekOrdinal'] != null
          ? WeekOrdinal.values.firstWhere(
              (e) => e.name == map['recurrenceWeekOrdinal'],
              orElse: () => WeekOrdinal.first,
            )
          : null,
      recurrenceWeekday: map['recurrenceWeekday'] != null
          ? Weekday.values.firstWhere(
              (e) => e.name == map['recurrenceWeekday'],
              orElse: () => Weekday.monday,
            )
          : null,
      recurrenceEndDate: map['recurrenceEndDate'] != null
          ? DateTime.parse(map['recurrenceEndDate'] as String)
          : null,
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
      viewedByEmployee: map['viewedByEmployee'] as bool? ?? false,
      reassignRequestedTo: map['reassignRequestedTo'] as String?,
      reassignRequestedBy: map['reassignRequestedBy'] as String?,
      reassignRequestedAt: map['reassignRequestedAt'] != null
          ? DateTime.parse(map['reassignRequestedAt'] as String)
          : null,
      reassignRequestedStatus: map['reassignRequestedStatus'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : DateTime.now(),
    );
  }
}
