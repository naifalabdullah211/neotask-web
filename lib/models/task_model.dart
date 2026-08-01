enum TaskStatus {
  assigned,
  inProgress,
  submitted,
  approved,
  rejected,
  editRequested,
}

enum TaskPriority { low, medium, high }

// ---------------------------------------------------------------------------
// UNIFIED STATE-MACHINE FIX (data-consistency bug report):
//
// Root cause of the reported bug ("بطاقة مكتملة/قيد الانتظار تختلف عن
// الرسم البياني، ومجموع البطاقات يتجاوز الإجمالي" — completed/pending
// cards disagreeing with their chart bars, and the sum of all cards
// exceeding the grand total): every screen/chart was computing its own
// ad hoc completed/pending/overdue boolean logic independently instead
// of reading from one shared classification. Concretely:
//   - manager_dashboard_tab.dart's chart added `stats['submitted']` on
//     top of `stats['pending']` for its "pending" bar, while the stat
//     CARD showed `stats['pending']` alone — a direct card/chart
//     mismatch.
//   - `overdue` was computed as `dueDate.isBefore(now) && status !=
//     approved`, which OVERLAPS with pending/submitted/rejected (a
//     rejected task past its due date is counted as BOTH rejected AND
//     overdue) — summing all visible cards therefore exceeds `total`.
//   - `TaskStatus.editRequested` was not counted in ANY bucket at all,
//     a silent gap.
//
// Fix: [PrimaryTaskStatus] is now the ONE authoritative, MUTUALLY
// EXCLUSIVE classification (every task maps to exactly one value via
// [AppTaskStatusX.primaryStatus] below), so counting tasks by this enum
// is guaranteed by construction to sum to the task count. "Overdue" is
// kept as a genuinely separate, date-derived flag ([AppTaskStatusX.
// isOverdue]) that can legitimately overlap with any non-completed
// bucket — it is intentionally EXCLUDED from any "must sum to total"
// breakdown. See `TaskProvider.statsForRange` / `lib/utils/task_stats.
// dart` (computeTaskStats) for the single centralized computation every
// dashboard card, chart, and PDF report must read from.
enum PrimaryTaskStatus { pending, inProgress, submitted, completed, rejected }

extension AppTaskStatusX on AppTask {
  /// Maps the persisted 6-value [TaskStatus] down to the 5-value
  /// [PrimaryTaskStatus] — the SINGLE classification every stat card,
  /// chart, and report must use instead of re-deriving its own logic.
  ///
  /// JUDGMENT CALL: [TaskStatus.editRequested] has no direct equivalent
  /// in the 5-value model. It represents "the manager sent this task
  /// back for revision; the employee has not yet pressed 'استئناف
  /// العمل' to resume it" — an action is pending FROM the employee, but
  /// work has not resumed (that only happens once `resumeAfterFeedback`
  /// sets the status to `inProgress`). This is closest to `pending`
  /// (task is sitting, awaiting the employee) — NOT `rejected` (a
  /// terminal decision) and NOT `inProgress` (work hasn't resumed yet).
  /// Previously this status was not counted in ANY dashboard bucket at
  /// all; this mapping closes that gap.
  PrimaryTaskStatus get primaryStatus {
    switch (status) {
      case TaskStatus.assigned:
        return PrimaryTaskStatus.pending;
      case TaskStatus.editRequested:
        return PrimaryTaskStatus.pending;
      case TaskStatus.inProgress:
        return PrimaryTaskStatus.inProgress;
      case TaskStatus.submitted:
        return PrimaryTaskStatus.submitted;
      case TaskStatus.approved:
        return PrimaryTaskStatus.completed;
      case TaskStatus.rejected:
        return PrimaryTaskStatus.rejected;
    }
  }

  /// Date-derived flag, deliberately INDEPENDENT of [primaryStatus] — a
  /// task is "متأخرة" (overdue) once its due date has passed, as long as
  /// it hasn't reached the terminal `completed` bucket. This is NOT one
  /// of the 5 mutually-exclusive [PrimaryTaskStatus] values: it can
  /// coexist with pending/inProgress/submitted/rejected. Any UI that
  /// adds this count into a "must sum to total" breakdown re-introduces
  /// the exact bug reported ("مجموع البطاقات يتجاوز الإجمالي").
  bool get isOverdue =>
      primaryStatus != PrimaryTaskStatus.completed &&
      dueDate.isBefore(DateTime.now());

  /// "لسه قيد الانتظار أو قيد التنفيذ" — the exact two-status gate
  /// required by the automatic-reminders feature (§1 of the spec) for
  /// BOTH the due-soon reminder and the overdue-notification checks.
  /// Deliberately excludes `submitted`/`rejected`/`editRequested`: a
  /// submitted task is no longer "sitting untouched" (the employee acted
  /// on it before the deadline), and a rejected/edit-requested task is
  /// mid-feedback-cycle, not simply neglected — reminding/escalating
  /// those would be noise unrelated to the stated requirement's literal
  /// wording ("لسه 'قيد الانتظار' أو 'قيد التنفيذ'").
  bool get isPendingOrInProgress =>
      status == TaskStatus.assigned || status == TaskStatus.inProgress;

  // ---------------------------------------------------------------------
  // Manager personal tasks (المهام الشخصية للمدير) — NEW feature.
  //
  // A "personal task" is simply a task the manager assigned to THEMSELF
  // (`assignedTo == assignedBy`) instead of to an employee — used for the
  // manager's own reminders/to-dos, distinct from delegated team work.
  // Deliberately DERIVED (not a persisted field): it can never drift out
  // of sync with assignedTo/assignedBy, and it requires zero migration
  // for existing tasks or changes to `firestore.rules` (the existing
  // `create` rule only checks `assignedBy == request.auth.uid`, which a
  // self-assigned task already satisfies).
  //
  // Call sites that MUST treat this as exclusionary (never counted into
  // team-wide aggregates) — see TaskProvider.teamTasks and its usages in
  // manager_dashboard_tab.dart / manager_reports_tab.dart. Also see
  // TaskProvider._dispatchOverdueNotification, which must notify ONLY
  // the owning manager for a personal task instead of broadcasting to
  // every manager account.
  bool get isPersonal => assignedTo == assignedBy;
}

// ---------------------------------------------------------------------------
// activityLog — employee-authored update/note entries (NEW feature).
//
// Distinct from `task_history`/`TaskHistoryEntry` (a SEPARATE Firestore
// collection, append-only via security rules, written on every lifecycle
// transition — submit/approve/reject/etc.). `activityLog` is instead an
// ARRAY FIELD embedded directly inside the task document itself, written
// via `FieldValue.arrayUnion` (see FirestoreService.appendTaskActivityLogEntry)
// so the append is atomic at the Firestore layer regardless of client-side
// read-modify-write races. Its purpose: let the task's assignee record a
// free-text status update/note AT ANY TIME — including after the task has
// already been submitted to the manager — without that action itself
// changing the task's `status`. `previousStatus`/`newStatus` are included
// on every entry for a uniform shape; for a pure note (no accompanying
// status change) they are equal, which is an expected/valid case, not an
// error — the manager must see the full log even when the final status
// has not changed.
class ActivityLogEntry {
  final String updatedBy;
  final DateTime updatedAt;
  final String? note;
  final String previousStatus;
  final String newStatus;

  ActivityLogEntry({
    required this.updatedBy,
    required this.updatedAt,
    this.note,
    required this.previousStatus,
    required this.newStatus,
  });

  Map<String, dynamic> toMap() => {
    'updatedBy': updatedBy,
    'updatedAt': updatedAt.toIso8601String(),
    'note': note,
    'previousStatus': previousStatus,
    'newStatus': newStatus,
  };

  factory ActivityLogEntry.fromMap(Map<dynamic, dynamic> map) {
    return ActivityLogEntry(
      updatedBy: map['updatedBy'] as String? ?? '',
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : DateTime.now(),
      note: map['note'] as String?,
      previousStatus: map['previousStatus'] as String? ?? '',
      newStatus: map['newStatus'] as String? ?? '',
    );
  }
}

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

  /// Planned start of the work. Older task documents did not have this
  /// field, so [fromMap] falls back to their creation date.
  final DateTime startDate;

  /// Manager-entered effort estimate used by the workload view.
  final double plannedHours;

  /// Employee-reported completion, independent from the review state. A task
  /// may be at 100% and still be `submitted` until the manager approves it.
  final int progressPercent;

  /// Optional hierarchy and finish-to-start dependencies.
  final String? parentTaskId;
  final List<String> predecessorTaskIds;
  final List<String> linkedDocumentIds;
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

  /// Employee-authored update/note entries — see [ActivityLogEntry] doc
  /// comment above. Append-only in practice (enforced by writing via
  /// `FieldValue.arrayUnion` at the Firestore layer, never by replacing
  /// this list wholesale) but modeled here as a plain immutable list, kept
  /// in `dueDate`-independent chronological (insertion) order.
  final List<ActivityLogEntry> activityLog;

  // ---- Automatic reminders feature (التذكيرات التلقائية) — NEW ----
  // Idempotency guards so each of the two notification types below is
  // dispatched AT MOST ONCE per task, regardless of how many times the
  // client-side lazy check (see TaskProvider._maybeDispatchReminders) runs
  // against the same task while it remains in a still-eligible state.
  // Mirrors the exact "set a persisted timestamp the first time an event
  // fires, then gate on `== null` before firing again" pattern already
  // used by `viewedByEmployee` (boolean form) and PollProvider's
  // `status == 'open'` guard (auto-close form) elsewhere in this
  // codebase — no new architectural pattern is introduced.
  //
  //   remindedAt: set the first time the "due within 24h, still
  //   pending/inProgress" in-app reminder is sent to the assignee.
  //   overdueNotifiedAt: set the first time the "task is now overdue"
  //   in-app notification is sent to the manager(s).
  final DateTime? remindedAt;
  final DateTime? overdueNotifiedAt;

  AppTask({
    required this.taskId,
    required this.title,
    required this.description,
    required this.assignedTo,
    required this.assignedBy,
    required this.dueDate,
    DateTime? startDate,
    this.plannedHours = 1,
    this.progressPercent = 0,
    this.parentTaskId,
    this.predecessorTaskIds = const [],
    this.linkedDocumentIds = const [],
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
    this.activityLog = const [],
    this.remindedAt,
    this.overdueNotifiedAt,
    required this.createdAt,
    required this.updatedAt,
  }) : startDate = startDate ?? createdAt;

  AppTask copyWith({
    String? title,
    String? description,
    String? assignedTo,
    DateTime? dueDate,
    DateTime? startDate,
    double? plannedHours,
    int? progressPercent,
    String? parentTaskId,
    List<String>? predecessorTaskIds,
    List<String>? linkedDocumentIds,
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
    // NOTE: this is a plain replace-if-provided param, NOT an append —
    // actual appends to activityLog must go through
    // `FirestoreService.appendTaskActivityLogEntry` (atomic
    // `FieldValue.arrayUnion` write), never through this copyWith, since
    // `copyWith`'s in-memory list has no visibility into concurrent writes
    // from other clients.
    List<ActivityLogEntry>? activityLog,
    // Standard `??` fallback-to-existing-value semantics cannot express
    // "explicitly set this nullable field back to null" — needed when a
    // reassignment request is rejected or finally confirmed (all 4
    // reassignRequest* fields must be wiped in one write). This flag
    // overrides the 4 fields above to null regardless of what was passed.
    bool clearReassignRequest = false,
    bool clearParentTask = false,
    DateTime? remindedAt,
    DateTime? overdueNotifiedAt,
    DateTime? updatedAt,
  }) {
    return AppTask(
      taskId: taskId,
      title: title ?? this.title,
      description: description ?? this.description,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedBy: assignedBy,
      dueDate: dueDate ?? this.dueDate,
      startDate: startDate ?? this.startDate,
      plannedHours: plannedHours ?? this.plannedHours,
      progressPercent: progressPercent ?? this.progressPercent,
      parentTaskId: clearParentTask
          ? null
          : (parentTaskId ?? this.parentTaskId),
      predecessorTaskIds: predecessorTaskIds ?? this.predecessorTaskIds,
      linkedDocumentIds: linkedDocumentIds ?? this.linkedDocumentIds,
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
      activityLog: activityLog ?? this.activityLog,
      remindedAt: remindedAt ?? this.remindedAt,
      overdueNotifiedAt: overdueNotifiedAt ?? this.overdueNotifiedAt,
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
      'startDate': startDate.toIso8601String(),
      'plannedHours': plannedHours,
      'progressPercent': progressPercent,
      'parentTaskId': parentTaskId,
      'predecessorTaskIds': predecessorTaskIds,
      'linkedDocumentIds': linkedDocumentIds,
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
      'activityLog': activityLog.map((e) => e.toMap()).toList(),
      'remindedAt': remindedAt?.toIso8601String(),
      'overdueNotifiedAt': overdueNotifiedAt?.toIso8601String(),
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
      startDate: map['startDate'] != null
          ? DateTime.parse(map['startDate'] as String)
          : map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : map['dueDate'] != null
          ? DateTime.parse(map['dueDate'] as String)
          : DateTime.now(),
      plannedHours: (map['plannedHours'] as num?)?.toDouble() ?? 1,
      progressPercent:
          ((map['progressPercent'] as num?)?.toInt() ??
                  (map['status'] == TaskStatus.approved.name ? 100 : 0))
              .clamp(0, 100)
              .toInt(),
      parentTaskId: map['parentTaskId'] as String?,
      predecessorTaskIds: map['predecessorTaskIds'] != null
          ? List<String>.from(map['predecessorTaskIds'] as List)
          : const [],
      linkedDocumentIds: map['linkedDocumentIds'] != null
          ? List<String>.from(map['linkedDocumentIds'] as List)
          : const [],
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
      activityLog: map['activityLog'] != null
          ? (map['activityLog'] as List)
                .map(
                  (e) => ActivityLogEntry.fromMap(e as Map<dynamic, dynamic>),
                )
                .toList()
          : const [],
      remindedAt: map['remindedAt'] != null
          ? DateTime.parse(map['remindedAt'] as String)
          : null,
      overdueNotifiedAt: map['overdueNotifiedAt'] != null
          ? DateTime.parse(map['overdueNotifiedAt'] as String)
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
