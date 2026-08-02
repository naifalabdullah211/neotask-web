import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';
import '../models/task_model.dart';
import '../models/task_history_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart' show statusLabelAr;
import '../utils/recurrence_utils.dart';
import '../utils/task_stats.dart';
import '../utils/project_planning.dart';

class TaskProvider extends ChangeNotifier {
  static const _uuid = Uuid();

  List<AppTask> _allTasks = [];
  List<AppTask> get allTasks => _allTasks;

  TaskProvider() {
    _listenAll();
  }

  void _listenAll() {
    FirestoreService.watchAllTasks().listen((tasks) {
      _allTasks = tasks;
      notifyListeners();
      // Fire-and-forget: same lazy client-side reconciliation pattern as
      // PollProvider._maybeAutoCloseOverduePolls (no Cloud Functions/cron
      // exists in this project — see doc comment on
      // _maybeDispatchReminders below for the full rationale). Errors are
      // caught internally so a transient Firestore failure here never
      // crashes the task-list subscription.
      _maybeDispatchReminders(tasks);
    });
  }

  // =========================================================================
  // AUTOMATIC REMINDERS — التذكيرات التلقائية (NEW feature)
  // =========================================================================
  // ARCHITECTURE (explicitly flagged — same class of trade-off as
  // PollProvider's auto-close, documented there in detail): this project
  // has no Cloud Functions / scheduled-backend infrastructure (confirmed
  // by inspecting the project for a `functions/` directory and the
  // `cloud_functions` package — neither exists). A genuine "runs once a
  // day server-side regardless of whether anyone has the app open" check
  // is therefore NOT achievable here. The mechanism actually implemented
  // is CLIENT-SIDE LAZY EVALUATION: [_maybeDispatchReminders] runs every
  // time the live `tasks` stream emits a new snapshot (i.e. whenever ANY
  // signed-in user's app has the task list loaded — which in practice
  // happens on every login/app-open/task-mutation for both managers and
  // employees, giving effective near-real-time coverage while the app is
  // in use, though not a true background cron).
  //
  // KNOWN LIMITATION (not glossed over): if NO one opens the app at all
  // during the 24h window before a task's due date, the "due soon"
  // reminder is skipped entirely for that task (it will never again be
  // "exactly <=24h and >0h away" once missed) — this mirrors the exact
  // same acknowledged gap already documented for polls in this codebase.
  // The overdue-notification check has no such gap: it fires the first
  // time any client observes `dueDate` has passed, whenever that occurs.
  //
  // IDEMPOTENCY: each of the two notification types is gated on a
  // one-way, null -> non-null Firestore field (`remindedAt` /
  // `overdueNotifiedAt` — see AppTask doc comments), enforced not just
  // client-side here but at the Firestore rules layer too (see
  // firestore.rules `tasks/{taskId}` update rule's dedicated branches),
  // so even a race between two clients observing the same eligible task
  // simultaneously results in at most one notification being persisted.
  Future<void> _maybeDispatchReminders(List<AppTask> tasks) async {
    final now = DateTime.now();
    for (final task in tasks) {
      if (!task.isPendingOrInProgress) continue;

      // ---- (a) Due-soon reminder to the assignee — §1 first bullet ----
      // "باقي 24 ساعة بالضبط (أو أقل)" — i.e. 0h < remaining <= 24h. A
      // task already past due is handled exclusively by branch (b) below
      // (overdue notification), not this one — the two are mutually
      // exclusive by construction via this window check.
      if (task.remindedAt == null) {
        final remaining = task.dueDate.difference(now);
        if (remaining <= const Duration(hours: 24) && !remaining.isNegative) {
          try {
            await _dispatchDueSoonReminder(task);
            await FirestoreService.markTaskReminded(task.taskId);
          } catch (e) {
            if (kDebugMode) {
              debugPrint(
                'TaskProvider: due-soon reminder failed for '
                '${task.taskId}: $e',
              );
            }
          }
        }
      }

      // ---- (b) Overdue notification to every manager — §1 second bullet
      // ----
      if (task.overdueNotifiedAt == null && task.dueDate.isBefore(now)) {
        try {
          await _dispatchOverdueNotification(task);
          await FirestoreService.markTaskOverdueNotified(task.taskId);
        } catch (e) {
          if (kDebugMode) {
            debugPrint(
              'TaskProvider: overdue notification failed for '
              '${task.taskId}: $e',
            );
          }
        }
      }
    }
  }

  Future<void> _dispatchDueSoonReminder(AppTask task) async {
    if (task.assignedTo.isEmpty) return;
    // Part 3(ب) — التذكيرات: respect the assignee's own per-user
    // reminders-enabled preference (Settings screen toggle, persisted on
    // their `users/{uid}` document — see AppUser.remindersEnabled). If the
    // recipient has opted out, the reminder is skipped entirely — but
    // `markTaskReminded` is still called by the caller afterwards so this
    // is NOT retried on every subsequent snapshot.
    final recipient = FirestoreService.getUser(task.assignedTo);
    if (recipient != null && !recipient.remindersEnabled) return;
    await FirestoreService.saveNotification(
      AppNotification(
        notificationId: _uuid.v4(),
        recipientUid: task.assignedTo,
        type: NotificationType.taskDueSoon,
        title: 'تذكير: مهمة "${task.title}" تستحق غدًا',
        body:
            'تاريخ الاستحقاق: '
            '${task.dueDate.year}/'
            '${task.dueDate.month.toString().padLeft(2, '0')}/'
            '${task.dueDate.day.toString().padLeft(2, '0')} — '
            'الحالة الحالية: ${statusLabelAr(task.status.name)}',
        relatedTaskId: task.taskId,
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<void> _dispatchOverdueNotification(AppTask task) async {
    // ---------------------------------------------------------------------
    // Manager personal tasks (المهام الشخصية للمدير) — branch added.
    //
    // A personal task (`task.isPersonal`, i.e. assignedTo == assignedBy)
    // has no "employee" to name and no "other managers" who should be
    // informed — broadcasting via the unconditional getAllManagers() loop
    // below would leak a manager's private reminder to every other manager
    // account (a real risk: UserRole.manager is not a singleton role in
    // this codebase — see user_model.dart). Route it as a single
    // self-notification to the owning manager instead, with wording that
    // does not reference a non-existent "assigned to" employee.
    if (task.isPersonal) {
      final manager = FirestoreService.getUser(task.assignedBy);
      if (manager != null && !manager.remindersEnabled) return;
      await FirestoreService.saveNotification(
        AppNotification(
          notificationId: _uuid.v4(),
          recipientUid: task.assignedBy,
          type: NotificationType.taskOverdue,
          title: 'مهمتك الشخصية "${task.title}" أصبحت متأخرة',
          body:
              'تاريخ الاستحقاق: '
              '${task.dueDate.year}/'
              '${task.dueDate.month.toString().padLeft(2, '0')}/'
              '${task.dueDate.day.toString().padLeft(2, '0')} — '
              'الحالة الحالية: ${statusLabelAr(task.status.name)}',
          relatedTaskId: task.taskId,
          createdAt: DateTime.now(),
        ),
      );
      return;
    }

    final employee = FirestoreService.getUser(task.assignedTo);
    final employeeName = employee?.name ?? 'موظف غير معروف';
    final managers = FirestoreService.getAllManagers();
    for (final manager in managers) {
      // Same per-user opt-out check as the due-soon branch above, applied
      // per-recipient (each manager individually), not globally.
      if (!manager.remindersEnabled) continue;
      await FirestoreService.saveNotification(
        AppNotification(
          notificationId: _uuid.v4(),
          recipientUid: manager.uid,
          type: NotificationType.taskOverdue,
          title: 'مهمة "${task.title}" المسندة لـ$employeeName أصبحت متأخرة',
          body:
              'تاريخ الاستحقاق: '
              '${task.dueDate.year}/'
              '${task.dueDate.month.toString().padLeft(2, '0')}/'
              '${task.dueDate.day.toString().padLeft(2, '0')} — '
              'الحالة الحالية: ${statusLabelAr(task.status.name)}',
          relatedTaskId: task.taskId,
          payload: {
            'employeeUid': task.assignedTo,
            'employeeName': employeeName,
          },
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  /// SINGLE SOURCE OF TRUTH for the "completed tasks always last" ordering
  /// rule. Applied by every task-list getter below (`tasksForEmployee`,
  /// `tasksForDay`, `tasksForWeek`, `tasksForMonth`) so the manager
  /// dashboard, the employee tasks tab, the manager reports tab (and, as a
  /// side effect of sharing these same methods, the designer dashboard)
  /// all order tasks identically without duplicating this logic per screen.
  ///
  /// Primary key: `dueDate` ascending (matches the prior behavior of
  /// `tasksForEmployee`, extended here to the 3 methods that previously had
  /// no sort at all). Secondary key: completed tasks (`PrimaryTaskStatus.
  /// completed`, i.e. `TaskStatus.approved`) are always pushed to the end
  /// of the list, regardless of their due date — implemented by sorting by
  /// due date first, then partitioning into "not completed" / "completed"
  /// groups and concatenating, which preserves the due-date order within
  /// each group. This is purely a display-order concern and must NOT be
  /// confused with [computeTaskStats]'s classification (see
  /// `lib/utils/task_stats.dart`), which this function does not alter.
  List<AppTask> _sortedWithCompletedLast(List<AppTask> tasks) {
    final sorted = [...tasks]..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    final notCompleted = <AppTask>[];
    final completed = <AppTask>[];
    for (final t in sorted) {
      if (t.primaryStatus == PrimaryTaskStatus.completed) {
        completed.add(t);
      } else {
        notCompleted.add(t);
      }
    }
    return [...notCompleted, ...completed];
  }

  List<AppTask> tasksForEmployee(String uid) => _sortedWithCompletedLast(
    _allTasks.where((t) => t.assignedTo == uid).toList(),
  );

  // ---------------------------------------------------------------------
  // Manager personal tasks (المهام الشخصية للمدير) — NEW feature.
  //
  // [teamTasks] is the REQUIRED substitute for raw [allTasks] everywhere
  // a screen computes team-wide aggregates (dashboard stat cards/chart,
  // reports, the daily digest, the Kanban board): it excludes every
  // `isPersonal` task so a manager's own reminder can never inflate
  // team-performance numbers. This mirrors the exact discipline already
  // established for [PrimaryTaskStatus] (see task_model.dart's
  // "UNIFIED STATE-MACHINE FIX" comment) — one authoritative filtered
  // list every aggregate call site must read from, instead of each
  // screen re-deriving its own ad hoc exclusion.
  List<AppTask> get teamTasks => _allTasks.where((t) => !t.isPersonal).toList();

  /// The given manager's own personal tasks, sorted with completed last
  /// (same ordering convention as every other task list in this class).
  List<AppTask> personalTasksFor(String managerUid) => _sortedWithCompletedLast(
    _allTasks.where((t) => t.isPersonal && t.assignedTo == managerUid).toList(),
  );

  /// Marks a personal task as done. Deliberately reuses [reviewDecision]
  /// with decision `'approve'` rather than introducing a parallel
  /// completion code path — a personal task's `assignedTo` IS its
  /// `assignedBy`, so "the manager approves their own task" is not a
  /// meaningless ceremony here, it is simply the existing terminal state
  /// (`TaskStatus.approved` / [PrimaryTaskStatus.completed]) reached
  /// through the one mutation method that already knows how to set
  /// `reviewedAt`/`reviewedBy`/`reviewDecision` AND auto-create the next
  /// recurring instance (see [reviewDecision]'s tail) — recurring
  /// personal reminders (e.g. "راجع المخزون كل يوم اثنين") therefore work
  /// with zero extra code. Skips the `submitted` status entirely on
  /// purpose: there is no second party to submit work to.
  Future<void> markPersonalTaskDone(String taskId, String managerUid) =>
      reviewDecision(
        taskId: taskId,
        managerUid: managerUid,
        decision: 'approve',
      );

  /// Reopens a completed personal task back to `assigned` — the personal
  /// counterpart of a checkbox un-tick. Does not touch reviewedAt/
  /// reviewedBy/reviewDecision (left as the historical record of the
  /// last completion) since there is no review-audit requirement for a
  /// self-assigned task.
  Future<void> reopenPersonalTask(String taskId, String managerUid) =>
      updateStatus(taskId, TaskStatus.assigned, managerUid);

  List<AppTask> get submittedForReview =>
      _allTasks.where((t) => t.status == TaskStatus.submitted).toList()..sort(
        (a, b) => (a.submittedAt ?? a.updatedAt).compareTo(
          b.submittedAt ?? b.updatedAt,
        ),
      );

  List<AppTask> tasksForDay(DateTime day, {String? employeeUid}) {
    final filtered = _allTasks.where((t) {
      final matchesDay =
          t.dueDate.year == day.year &&
          t.dueDate.month == day.month &&
          t.dueDate.day == day.day;
      final matchesEmployee =
          employeeUid == null || t.assignedTo == employeeUid;
      return matchesDay && matchesEmployee;
    }).toList();
    return _sortedWithCompletedLast(filtered);
  }

  List<AppTask> tasksForMonth(DateTime month, {String? employeeUid}) {
    final filtered = _allTasks.where((t) {
      final matchesMonth =
          t.dueDate.year == month.year && t.dueDate.month == month.month;
      final matchesEmployee =
          employeeUid == null || t.assignedTo == employeeUid;
      return matchesMonth && matchesEmployee;
    }).toList();
    return _sortedWithCompletedLast(filtered);
  }

  List<AppTask> tasksForWeek(DateTime anyDayInWeek, {String? employeeUid}) {
    final weekday = anyDayInWeek.weekday;
    final start = anyDayInWeek.subtract(Duration(days: weekday - 1));
    final end = start.add(const Duration(days: 6));
    final filtered = _allTasks.where((t) {
      final inRange =
          !t.dueDate.isBefore(DateTime(start.year, start.month, start.day)) &&
          !t.dueDate.isAfter(
            DateTime(end.year, end.month, end.day, 23, 59, 59),
          );
      final matchesEmployee =
          employeeUid == null || t.assignedTo == employeeUid;
      return inRange && matchesEmployee;
    }).toList();
    return _sortedWithCompletedLast(filtered);
  }

  Future<AppTask> createTask({
    required String title,
    required String description,
    required String assignedTo,
    required String assignedBy,
    required DateTime dueDate,
    DateTime? startDate,
    double plannedHours = 1,
    String? parentTaskId,
    List<String> predecessorTaskIds = const [],
    List<String> linkedDocumentIds = const [],
    required TaskPriority priority,
    required String category,
    RecurrenceType recurrenceType = RecurrenceType.none,
    int? recurrenceDayOfMonth,
    WeekOrdinal? recurrenceWeekOrdinal,
    Weekday? recurrenceWeekday,
    DateTime? recurrenceEndDate,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final effectiveStartDate =
        startDate ?? (dueDate.isBefore(today) ? dueDate : today);
    if (dueDate.isBefore(effectiveStartDate)) {
      throw ArgumentError('تاريخ الاستحقاق يجب أن يكون بعد تاريخ البداية');
    }
    if (plannedHours <= 0) {
      throw ArgumentError('الساعات المخططة يجب أن تكون أكبر من صفر');
    }
    final validTaskIds = _allTasks.map((task) => task.taskId).toSet();
    if (parentTaskId != null && !validTaskIds.contains(parentTaskId)) {
      throw ArgumentError('المهمة الرئيسية المحددة غير موجودة');
    }
    if (predecessorTaskIds.any((id) => !validTaskIds.contains(id))) {
      throw ArgumentError('إحدى المهام السابقة المحددة غير موجودة');
    }
    final task = AppTask(
      taskId: _uuid.v4(),
      title: title,
      description: description,
      assignedTo: assignedTo,
      assignedBy: assignedBy,
      dueDate: dueDate,
      startDate: effectiveStartDate,
      plannedHours: plannedHours,
      parentTaskId: parentTaskId,
      predecessorTaskIds: predecessorTaskIds.toSet().toList(),
      linkedDocumentIds: linkedDocumentIds.toSet().toList(),
      priority: priority,
      status: TaskStatus.assigned,
      category: category,
      recurrenceType: recurrenceType,
      recurrenceDayOfMonth: recurrenceDayOfMonth,
      recurrenceWeekOrdinal: recurrenceWeekOrdinal,
      recurrenceWeekday: recurrenceWeekday,
      recurrenceEndDate: recurrenceEndDate,
      viewedByEmployee: false,
      createdAt: now,
      updatedAt: now,
    );
    await FirestoreService.saveTask(task);
    await _logHistory(
      task.taskId,
      HistoryAction.statusChange,
      assignedBy,
      note: 'تم إنشاء المهمة وإسنادها',
    );
    return task;
  }

  Future<void> updateStatus(
    String taskId,
    TaskStatus status,
    String actorUid,
  ) async {
    final task = FirestoreService.getTask(taskId);
    if (task == null) return;
    if (status == TaskStatus.inProgress &&
        actorUid == task.assignedTo &&
        ProjectPlanning.isBlocked(task, _allTasks)) {
      final names = ProjectPlanning.unresolvedPredecessors(
        task,
        _allTasks,
      ).map((item) => item.title).join('، ');
      throw StateError('لا يمكن بدء المهمة قبل اكتمال: $names');
    }
    final now = DateTime.now();
    await FirestoreService.updateTaskFields(taskId, {
      'status': status.name,
      'updatedAt': now.toIso8601String(),
    });
    await _logHistory(
      taskId,
      HistoryAction.statusChange,
      actorUid,
      note: 'تغيير الحالة إلى ${statusLabelAr(status.name)}',
    );
  }

  Future<void> submitForReview(
    String taskId,
    String employeeUid,
    String? note,
  ) async {
    final task = FirestoreService.getTask(taskId);
    if (task == null) return;
    if (ProjectPlanning.isBlocked(task, _allTasks)) {
      final names = ProjectPlanning.unresolvedPredecessors(
        task,
        _allTasks,
      ).map((item) => item.title).join('، ');
      throw StateError('لا يمكن إرسال المهمة قبل اكتمال: $names');
    }
    final now = DateTime.now();
    await FirestoreService.updateTaskFields(taskId, {
      'status': TaskStatus.submitted.name,
      'progressPercent': 100,
      'submittedAt': now.toIso8601String(),
      'submissionNote': note,
      'updatedAt': now.toIso8601String(),
    });
    await _logHistory(taskId, HistoryAction.submit, employeeUid, note: note);
  }

  /// The manager's three-way review decision. Reject and editRequest
  /// REQUIRE a note per the mandatory-feedback design decision.
  Future<void> reviewDecision({
    required String taskId,
    required String managerUid,
    required String decision, // 'approve' | 'reject' | 'edit_request'
    String? note,
  }) async {
    if (decision != 'approve' && (note == null || note.trim().isEmpty)) {
      throw ArgumentError('يجب إدخال سبب أو ملاحظة عند الرفض أو طلب التعديل');
    }

    final task = FirestoreService.getTask(taskId);
    if (task == null) return;

    if (decision == 'approve') {
      final openChildren = ProjectPlanning.openChildren(taskId, _allTasks);
      if (openChildren.isNotEmpty) {
        throw StateError(
          'لا يمكن اعتماد المهمة الرئيسية قبل إكمال المهام الفرعية: '
          '${openChildren.map((item) => item.title).join('، ')}',
        );
      }
    }

    TaskStatus newStatus;
    HistoryAction action;
    switch (decision) {
      case 'approve':
        newStatus = TaskStatus.approved;
        action = HistoryAction.approve;
        break;
      case 'reject':
        newStatus = TaskStatus.rejected;
        action = HistoryAction.reject;
        break;
      case 'edit_request':
        newStatus = TaskStatus.editRequested;
        action = HistoryAction.editRequest;
        break;
      default:
        throw ArgumentError('قرار غير معروف: $decision');
    }

    final updated = task.copyWith(
      status: newStatus,
      progressPercent: decision == 'approve' ? 100 : task.progressPercent,
      reviewedAt: DateTime.now(),
      reviewedBy: managerUid,
      reviewDecision: decision,
      reviewNote: note,
      revisionCount: decision == 'approve'
          ? task.revisionCount
          : task.revisionCount + 1,
      // A review decision (approve/reject/edit_request) is new information
      // for the employee — re-flag the task as unviewed so the "مهامي" tab
      // badge appears again until they open it.
      viewedByEmployee: false,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveTask(updated);
    await _logHistory(taskId, action, managerUid, note: note);

    // Auto-create the next recurring instance once approved.
    if (decision == 'approve' && task.recurrenceType != RecurrenceType.none) {
      final nextDate = RecurrenceUtils.computeNextOccurrence(task);
      if (nextDate != null) {
        await createTask(
          title: task.title,
          description: task.description,
          assignedTo: task.assignedTo,
          assignedBy: task.assignedBy,
          dueDate: nextDate,
          startDate: nextDate.subtract(task.dueDate.difference(task.startDate)),
          plannedHours: task.plannedHours,
          priority: task.priority,
          category: task.category,
          recurrenceType: task.recurrenceType,
          recurrenceDayOfMonth: task.recurrenceDayOfMonth,
          recurrenceWeekOrdinal: task.recurrenceWeekOrdinal,
          recurrenceWeekday: task.recurrenceWeekday,
          recurrenceEndDate: task.recurrenceEndDate,
        );
      }
    }
  }

  /// After rejection/edit-request, employee resumes work — status returns
  /// to inProgress so the cycle can repeat.
  Future<void> resumeAfterFeedback(String taskId, String employeeUid) async {
    final task = FirestoreService.getTask(taskId);
    if (task == null) return;
    if (ProjectPlanning.isBlocked(task, _allTasks)) {
      throw StateError('لا يمكن استئناف المهمة قبل اكتمال مهامها السابقة');
    }
    final now = DateTime.now();
    await FirestoreService.updateTaskFields(taskId, {
      'status': TaskStatus.inProgress.name,
      'updatedAt': now.toIso8601String(),
    });
    await _logHistory(
      taskId,
      HistoryAction.statusChange,
      employeeUid,
      note: 'استئناف العمل بعد ملاحظات المدير',
    );
  }

  // =========================================================================
  // PART 4 — MANAGER-ONLY priority/dueDate EDITING (NEW — additive feature)
  // =========================================================================
  // `priority` and `dueDate` are editable ONLY by the manager, at ANY task
  // status (per the explicit requirement: "بغض النظر عن حالة المهمة" — this
  // restriction is unconditional, not just post-submission). This is the
  // ONLY method in this provider that may change either field after
  // creation. Enforced structurally at TWO layers:
  //   1. Caller layer (UI): only rendered/reachable from manager-only
  //      screens (see TaskReviewDetailScreen's edit button) — no employee
  //      screen calls this method or exposes editable priority/dueDate
  //      fields (see task_detail_screen.dart, which only ever displays
  //      dueDate read-only).
  //   2. Firestore rules layer: none of the THREE employee-write branches
  //      on `tasks/{taskId}` list `priority`/`dueDate` in their `hasOnly()`
  //      allowlists — only the unrestricted `isManager()` branch can ever
  //      write these fields, so even a maliciously modified client cannot
  //      bypass this restriction. See firestore.rules doc comment on the
  //      `tasks` update rule for the full rationale.
  Future<void> updatePriorityAndDueDate({
    required String taskId,
    required String managerUid,
    required TaskPriority priority,
    required DateTime dueDate,
  }) async {
    final task = FirestoreService.getTask(taskId);
    if (task == null) return;
    if (dueDate.isBefore(task.startDate)) {
      throw ArgumentError('تاريخ الاستحقاق يجب أن يكون بعد تاريخ البداية');
    }
    final updated = task.copyWith(
      priority: priority,
      dueDate: dueDate,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveTask(updated);
    await _logHistory(
      taskId,
      HistoryAction.statusChange,
      managerUid,
      note:
          'تعديل الأولوية/تاريخ الاستحقاق من المدير '
          '(الأولوية: ${priority.name}، الاستحقاق: '
          '${dueDate.year}/${dueDate.month.toString().padLeft(2, '0')}/'
          '${dueDate.day.toString().padLeft(2, '0')})',
    );
  }

  /// Manager-only edit for the task's core details. Personal tasks use the
  /// same persisted model as delegated work, so keeping this mutation in the
  /// shared provider lets a personal task remain fully editable before or
  /// after it is transferred to an employee.
  Future<void> updateManagerTaskDetails({
    required String taskId,
    required String managerUid,
    required String title,
    required String description,
    required String category,
    required TaskPriority priority,
    required DateTime startDate,
    required DateTime dueDate,
    required double plannedHours,
  }) async {
    final task = FirestoreService.getTask(taskId);
    if (task == null) return;
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError('عنوان المهمة مطلوب');
    }
    if (dueDate.isBefore(startDate)) {
      throw ArgumentError('تاريخ الاستحقاق يجب أن يكون بعد تاريخ البداية');
    }
    if (plannedHours <= 0) {
      throw ArgumentError('الساعات المخططة يجب أن تكون أكبر من صفر');
    }

    final updated = task.copyWith(
      title: normalizedTitle,
      description: description.trim(),
      category: category.trim().isEmpty ? 'عام' : category.trim(),
      priority: priority,
      startDate: startDate,
      dueDate: dueDate,
      plannedHours: plannedHours,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveTask(updated);
    await _logHistory(
      taskId,
      HistoryAction.statusChange,
      managerUid,
      note: 'تم تعديل بيانات المهمة',
    );
  }

  /// Employee progress is a genuine persisted planning value. It never skips
  /// the manager review step: 100% means the work is ready to submit, while
  /// `approved` remains the only completed state used by reports.
  Future<void> updateProgress({
    required String taskId,
    required String employeeUid,
    required int progressPercent,
  }) async {
    final task = FirestoreService.getTask(taskId);
    if (task == null || task.assignedTo != employeeUid) return;
    final value = progressPercent.clamp(0, 100).toInt();
    if (value > 0 && ProjectPlanning.isBlocked(task, _allTasks)) {
      throw StateError('هذه المهمة مرتبطة بمهام سابقة لم تكتمل بعد');
    }
    final shouldStart = value > 0 && task.status == TaskStatus.assigned;
    final now = DateTime.now();
    await FirestoreService.updateTaskFields(taskId, {
      'progressPercent': value,
      if (shouldStart) 'status': TaskStatus.inProgress.name,
      'updatedAt': now.toIso8601String(),
    });
    await _logHistory(
      taskId,
      HistoryAction.statusChange,
      employeeUid,
      note: 'تحديث نسبة الإنجاز إلى $value%',
    );
  }

  /// Manager-only editing for the schedule, hierarchy and finish-to-start
  /// dependencies. Cycle checks happen before the Firestore write.
  Future<void> updatePlanning({
    required String taskId,
    required String managerUid,
    required DateTime startDate,
    required DateTime dueDate,
    required double plannedHours,
    String? parentTaskId,
    List<String> predecessorTaskIds = const [],
  }) async {
    final task = FirestoreService.getTask(taskId);
    if (task == null) return;
    if (dueDate.isBefore(startDate)) {
      throw ArgumentError('تاريخ الاستحقاق يجب أن يكون بعد تاريخ البداية');
    }
    if (plannedHours <= 0) {
      throw ArgumentError('الساعات المخططة يجب أن تكون أكبر من صفر');
    }
    if (parentTaskId == taskId) {
      throw ArgumentError('لا يمكن أن تكون المهمة رئيسية لنفسها');
    }
    final validTaskIds = _allTasks.map((item) => item.taskId).toSet();
    if (parentTaskId != null && !validTaskIds.contains(parentTaskId)) {
      throw ArgumentError('المهمة الرئيسية المحددة لم تعد موجودة');
    }
    if (predecessorTaskIds.any((id) => !validTaskIds.contains(id))) {
      throw ArgumentError('إحدى المهام السابقة المحددة لم تعد موجودة');
    }
    if (parentTaskId != null &&
        ProjectPlanning.wouldCreateHierarchyCycle(
          taskId: taskId,
          candidateParentId: parentTaskId,
          allTasks: _allTasks,
        )) {
      throw ArgumentError('المهمة الرئيسية المحددة تنشئ تسلسلاً دائريًا');
    }
    for (final predecessorId in predecessorTaskIds) {
      if (ProjectPlanning.wouldCreateCycle(
        taskId: taskId,
        candidatePredecessorId: predecessorId,
        allTasks: _allTasks,
      )) {
        throw ArgumentError('التبعية المحددة تنشئ مسارًا دائريًا');
      }
    }
    final updated = task.copyWith(
      startDate: startDate,
      dueDate: dueDate,
      plannedHours: plannedHours,
      parentTaskId: parentTaskId,
      clearParentTask: parentTaskId == null,
      predecessorTaskIds: predecessorTaskIds.toSet().toList(),
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveTask(updated);
    await _logHistory(
      taskId,
      HistoryAction.statusChange,
      managerUid,
      note: 'تحديث الخطة الزمنية والتبعيات للمهمة',
    );
  }

  /// Manager-only task deletion. Logs a history entry BEFORE the task
  /// document is removed (per the explicit requirement that any
  /// delete/transfer/status-change must be recorded in the timeline) —
  /// this entry persists in the independent `task_history` collection
  /// (keyed by `taskId` string) even after the task document itself is
  /// gone. Logging must happen first: once the task doc is deleted,
  /// nothing else reads `FirestoreService.getTask(taskId)` for it again,
  /// so ordering here only matters for audit completeness, not for
  /// correctness of the delete itself.
  Future<void> deleteTask(String taskId, {String? actorUid}) async {
    if (actorUid != null) {
      await _logHistory(
        taskId,
        HistoryAction.statusChange,
        actorUid,
        note: 'تم حذف المهمة',
      );
    }
    // Preserve graph integrity: remove the deleted task from every successor
    // and detach its direct children before deleting the document itself.
    for (final related in _allTasks.where(
      (task) =>
          task.parentTaskId == taskId ||
          task.predecessorTaskIds.contains(taskId),
    )) {
      await FirestoreService.saveTask(
        related.copyWith(
          clearParentTask: related.parentTaskId == taskId,
          predecessorTaskIds: related.predecessorTaskIds
              .where((id) => id != taskId)
              .toList(),
          updatedAt: DateTime.now(),
        ),
      );
    }
    await FirestoreService.deleteTask(taskId);
  }

  // =========================================================================
  // MANAGER-DIRECT SINGLE-TASK REASSIGNMENT (NEW — additive feature)
  // =========================================================================
  // Deliberately DISTINCT from the employee-initiated 3-step reassignment
  // workflow above (requestReassignment → decideReassignmentRequest →
  // confirmReassignmentByNewEmployee), which requires proposal + manager
  // approval + new-employee confirmation. This method is an IMMEDIATE,
  // unconditional manager action — no approval/confirmation steps — per
  // the explicit requirement ("تحويل لموظف آخر" button available directly
  // on the manager's task detail screen, changes assignedTo right away).
  // Reuses `HistoryAction.statusChange` with a descriptive note, matching
  // the existing precedent in `reassignAllTasksForEmployee` above, rather
  // than adding a new enum value — avoids touching the 4 duplicated
  // `HistoryAction` switch-statements (task_provider.dart itself plus the
  // 3 detail-screen `_HistoryTile` widgets) for a case that is fully
  // describable via a note string.
  Future<void> reassignTaskDirect({
    required String taskId,
    required String managerUid,
    required String newAssigneeUid,
  }) async {
    final task = FirestoreService.getTask(taskId);
    if (task == null) return;
    if (task.assignedTo == newAssigneeUid) return;
    final updated = task.copyWith(
      assignedTo: newAssigneeUid,
      // Fresh assignee should see this as a new/unread item, mirroring the
      // same semantics used by confirmReassignmentByNewEmployee above.
      viewedByEmployee: false,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveTask(updated);
    await _logHistory(
      taskId,
      HistoryAction.statusChange,
      managerUid,
      note: 'تحويل المهمة مباشرة إلى موظف آخر من قبل المدير',
    );
  }

  /// Delegates one manager task to every active member selected by the
  /// caller. The original task becomes the first employee's assignment;
  /// additional employees receive independent copies so each person can
  /// progress and submit their own work without overwriting teammates.
  Future<int> reassignTaskToTeam({
    required String taskId,
    required String managerUid,
    required List<String> teamMemberUids,
  }) async {
    final task = FirestoreService.getTask(taskId);
    if (task == null) return 0;
    final assignees = teamMemberUids
        .map((uid) => uid.trim())
        .where((uid) => uid.isNotEmpty && uid != managerUid)
        .toSet()
        .toList();
    if (assignees.isEmpty) return 0;

    final firstAssignee = assignees.first;
    await FirestoreService.saveTask(
      task.copyWith(
        assignedTo: firstAssignee,
        viewedByEmployee: false,
        updatedAt: DateTime.now(),
      ),
    );
    await _logHistory(
      taskId,
      HistoryAction.statusChange,
      managerUid,
      note: 'تحويل المهمة إلى الفريق (${assignees.length} موظف)',
    );

    for (final employeeUid in assignees.skip(1)) {
      final copy = await createTask(
        title: task.title,
        description: task.description,
        assignedTo: employeeUid,
        assignedBy: managerUid,
        dueDate: task.dueDate,
        startDate: task.startDate,
        plannedHours: task.plannedHours,
        parentTaskId: task.parentTaskId,
        predecessorTaskIds: task.predecessorTaskIds,
        linkedDocumentIds: task.linkedDocumentIds,
        priority: task.priority,
        category: task.category,
        recurrenceType: task.recurrenceType,
        recurrenceDayOfMonth: task.recurrenceDayOfMonth,
        recurrenceWeekOrdinal: task.recurrenceWeekOrdinal,
        recurrenceWeekday: task.recurrenceWeekday,
        recurrenceEndDate: task.recurrenceEndDate,
      );
      if (task.activityLog.isNotEmpty) {
        await FirestoreService.saveTask(
          copy.copyWith(
            activityLog: task.activityLog,
            updatedAt: DateTime.now(),
          ),
        );
      }
    }
    return assignees.length;
  }

  /// Marks [taskId] as viewed by its assigned employee (in-app notification
  /// pattern mirroring `MessageProvider.markConversationRead`). Called when
  /// the employee opens `TaskDetailScreen`. No-op if already viewed.
  Future<void> markTaskViewedByEmployee(String taskId) async {
    final task = FirestoreService.getTask(taskId);
    if (task == null || task.viewedByEmployee) return;
    await FirestoreService.markTaskViewed(taskId);
  }

  /// Count of tasks assigned to [employeeUid] that the employee has not
  /// yet opened since the last manager action (new assignment or review
  /// decision). Drives the "مهامي" bottom-nav badge. Computed in memory
  /// from the already-live `_allTasks` stream — no extra Firestore query.
  int unviewedTaskCountForEmployee(String employeeUid) => _allTasks
      .where((t) => t.assignedTo == employeeUid && !t.viewedByEmployee)
      .length;

  /// Number of tasks currently assigned to [employeeUid] — used by the
  /// manager's employee-deletion dialog to decide whether task-fate
  /// resolution (delete vs. reassign) is even necessary.
  int taskCountForEmployee(String employeeUid) =>
      _allTasks.where((t) => t.assignedTo == employeeUid).length;

  /// Deletes ALL tasks currently assigned to [employeeUid] (bulk operation).
  ///
  /// Called as part of the manager's employee soft-delete flow when the
  /// manager chooses to discard the employee's tasks. A single history
  /// entry per task is NOT written here (the tasks themselves are removed,
  /// making a per-task history note moot); the action is recorded once at
  /// the caller level if needed.
  Future<void> deleteAllTasksForEmployee(String employeeUid) async {
    await FirestoreService.deleteAllTasksForEmployee(employeeUid);
  }

  /// Reassigns ALL tasks currently assigned to [fromEmployeeUid] over to
  /// [toEmployeeUid] (bulk operation).
  ///
  /// Called as part of the manager's employee soft-delete flow when the
  /// manager chooses to transfer the employee's tasks to another active
  /// employee. Each transferred task gets one history entry recording the
  /// reassignment and the actor (manager) who performed it.
  Future<void> reassignAllTasksForEmployee(
    String fromEmployeeUid,
    String toEmployeeUid,
    String managerUid,
  ) async {
    final affected = _allTasks
        .where((t) => t.assignedTo == fromEmployeeUid)
        .toList();
    await FirestoreService.reassignAllTasksForEmployee(
      fromEmployeeUid,
      toEmployeeUid,
    );
    for (final t in affected) {
      await _logHistory(
        t.taskId,
        HistoryAction.statusChange,
        managerUid,
        note: 'تم نقل المهمة إلى موظف آخر بعد حذف الموظف السابق',
      );
    }
  }

  List<TaskHistoryEntry> historyForTask(String taskId) {
    return FirestoreService.getHistoryForTask(taskId);
  }

  // =========================================================================
  // PART 2 — EMPLOYEE-AUTHORED ACTIVITY LOG (NEW — additive feature)
  // =========================================================================
  // Lets the task's assignee append a free-text status update/note AT ANY
  // TIME, including after the task has already been submitted to the
  // manager (`status == submitted`) or even after a terminal decision
  // (`approved`/`rejected`) — deliberately NOT gated on `current.status`,
  // per the explicit requirement. Each call appends exactly one entry via
  // an atomic Firestore `FieldValue.arrayUnion` (see
  // `FirestoreService.appendTaskActivityLogEntry`) — never a replace of
  // the previous entry. `previousStatus`/`newStatus` both record the
  // task's CURRENT status at the time of the note (this call never itself
  // changes `status`) — they are intentionally equal for a pure note. The
  // manager sees the full log (see `TaskReviewDetailScreen`) regardless of
  // whether the task's final status has changed since.
  Future<void> addActivityLogEntry({
    required String taskId,
    required String updatedBy,
    String? note,
  }) async {
    final task = FirestoreService.getTask(taskId);
    if (task == null) return;
    final entry = ActivityLogEntry(
      updatedBy: updatedBy,
      updatedAt: DateTime.now(),
      note: note,
      previousStatus: task.status.name,
      newStatus: task.status.name,
    );
    await FirestoreService.appendTaskActivityLogEntry(taskId, entry);
  }

  // =========================================================================
  // QUICK COMMENTS — "تعليقات سريعة" (NEW — additive feature)
  // =========================================================================
  // Deliberately MERGED into the existing `activityLog`/`ActivityLogEntry`
  // storage above rather than introducing a parallel `Comment` model or
  // Firestore field, per the explicit instruction to check for functional
  // overlap and merge instead of duplicating. This is safe/legal under the
  // CURRENT (already-live) firestore.rules with NO rules edit or redeploy
  // required, because:
  //   - The employee's normal-lifecycle update branch already allows
  //     `activityLog` unconditionally in its `hasOnly()` allowlist.
  //   - The manager's update branch (`allow update: if isManager();`) has
  //     no field restriction at all, so it was already able to write
  //     `activityLog` too — it simply never had UI to do so before now.
  // On top of the `activityLog` append (for the "التعليقات" list UI), this
  // ALSO writes a `TaskHistoryEntry` (HistoryAction.comment) so the
  // comment shows up in "سجل المهمة الكامل" exactly like submit/approve/
  // reject events (requirement #4) — and dispatches an `AppNotification`
  // to the OTHER party (manager<->employee), reusing the exact
  // save-notification pattern already used by PollProvider (requirement
  // #3). "Any other participant" beyond manager/employee does not
  // currently exist on AppTask (no participants list), so the notified
  // "other party" is determined purely from assignedBy/assignedTo.
  Future<void> addComment({
    required String taskId,
    required String authorUid,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final task = FirestoreService.getTask(taskId);
    if (task == null) return;

    final entry = ActivityLogEntry(
      updatedBy: authorUid,
      updatedAt: DateTime.now(),
      note: trimmed,
      previousStatus: task.status.name,
      newStatus: task.status.name,
    );
    await FirestoreService.appendTaskActivityLogEntry(taskId, entry);
    await _logHistory(taskId, HistoryAction.comment, authorUid, note: trimmed);
    await _notifyOtherPartyOfComment(task, authorUid, trimmed);
  }

  /// Notifies whichever of manager/employee did NOT author the comment.
  Future<void> _notifyOtherPartyOfComment(
    AppTask task,
    String authorUid,
    String text,
  ) async {
    final recipientUid = authorUid == task.assignedBy
        ? task.assignedTo
        : task.assignedBy;
    if (recipientUid.isEmpty || recipientUid == authorUid) return;

    final author = FirestoreService.getUser(authorUid);
    final authorName = author?.name ?? 'مستخدم';
    final preview = text.length > 80 ? '${text.substring(0, 80)}...' : text;

    await FirestoreService.saveNotification(
      AppNotification(
        notificationId: _uuid.v4(),
        recipientUid: recipientUid,
        type: NotificationType.taskComment,
        title: 'تعليق جديد على مهمة: ${task.title}',
        body: '$authorName: $preview',
        relatedTaskId: task.taskId,
        payload: {'authorUid': authorUid, 'authorName': authorName},
        createdAt: DateTime.now(),
      ),
    );
  }

  // =========================================================================
  // EMPLOYEE-INITIATED TASK REASSIGNMENT (NEW — additive feature)
  // =========================================================================
  // Design answers from the manager (verbatim, translated):
  //   ١- أي مهمة (any task, any status — no restriction).
  //   ٢- الموظف الأول يستمر بالعمل لحين موافقة المدير (current employee is
  //      NOT blocked from continuing normal task actions while a request is
  //      pending — deliberately does NOT gate updateStatus/submitForReview/
  //      resumeAfterFeedback on reassignRequestedStatus).
  //   ٣- بعد الموافقة تنتقل المهمة بكل مافيها (كل الحقول الأخرى) للموظف
  //      الجديد — only `assignedTo` changes; status/history/reviewNote/etc.
  //      are carried over unmodified.
  //   ٤- الرفض لا يتطلب سبب، وتبقى المهمة عند الموظف الأول بالكامل.
  //   ٥- أي موظف (نشط) يمكن اختياره كموظف جديد — enforced at the UI layer
  //      (screen only lists AccountStatus.active employees), not re-checked
  //      here since TaskProvider has no direct dependency on AuthProvider's
  //      user list by design (see FirestoreService.getAllEmployees()).
  //   ٦- الموظف الجديد يحتاج لتأكيد استلامها — approval alone does NOT move
  //      `assignedTo`; see confirmReassignmentByNewEmployee().
  //
  // JUDGMENT CALL (flagged, not covered by the manager's answers): what if
  // the NEW employee does not want to accept after the manager approves?
  // No "decline by new employee" action was requested, so none is
  // implemented — the task simply remains in 'awaitingNewEmployee' limbo
  // (still fully usable/visible to the ORIGINAL employee, since assignedTo
  // has not changed yet) until the new employee confirms. A future
  // extension point, not built here.

  /// Employee-initiated: propose handing [taskId] over to [requestedTo].
  /// Does NOT alter task status/fields other than the 4 reassignRequest*
  /// fields — the current employee keeps working on the task normally.
  Future<void> requestReassignment({
    required String taskId,
    required String requestedBy, // current (first) employee's uid
    required String requestedTo, // proposed new employee's uid
  }) async {
    final task = FirestoreService.getTask(taskId);
    if (task == null) return;
    if (requestedBy == requestedTo) {
      throw ArgumentError('لا يمكن إسناد المهمة لنفس الموظف');
    }
    final now = DateTime.now();
    await FirestoreService.updateTaskFields(taskId, {
      'reassignRequestedTo': requestedTo,
      'reassignRequestedBy': requestedBy,
      'reassignRequestedAt': now.toIso8601String(),
      'reassignRequestedStatus': 'pending',
      'updatedAt': now.toIso8601String(),
    });
    await _logHistory(
      taskId,
      HistoryAction.reassignRequested,
      requestedBy,
      note: 'طلب إسناد المهمة إلى موظف آخر (uid: $requestedTo)',
    );
  }

  /// Manager's binary decision on a pending reassignment request.
  /// Reject: per answer ٤, requires NO note — task's reassign* fields are
  /// simply cleared and the task remains fully with the original employee.
  /// Approve: moves to 'awaitingNewEmployee' — assignedTo is UNCHANGED
  /// until the new employee explicitly confirms (answer ٦).
  Future<void> decideReassignmentRequest({
    required String taskId,
    required String managerUid,
    required bool approve,
  }) async {
    final task = FirestoreService.getTask(taskId);
    if (task == null) return;
    if (task.reassignRequestedStatus != 'pending') return;

    if (!approve) {
      final updated = task.copyWith(
        clearReassignRequest: true,
        updatedAt: DateTime.now(),
      );
      await FirestoreService.saveTask(updated);
      await _logHistory(
        taskId,
        HistoryAction.reassignRejected,
        managerUid,
        note: 'رفض المدير طلب إسناد المهمة',
      );
      return;
    }

    final updated = task.copyWith(
      reassignRequestedStatus: 'awaitingNewEmployee',
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveTask(updated);
    await _logHistory(
      taskId,
      HistoryAction.reassignApproved,
      managerUid,
      note: 'وافق المدير على طلب الإسناد؛ بانتظار تأكيد الموظف الجديد',
    );
  }

  /// The NEW employee's confirmation of receipt (answer ٦). Only now does
  /// `assignedTo` actually change — the task moves "بكل مافيها" (with all
  /// its current fields/status/history untouched) per answer ٣.
  Future<void> confirmReassignmentByNewEmployee({
    required String taskId,
    required String newEmployeeUid,
  }) async {
    final task = FirestoreService.getTask(taskId);
    if (task == null) return;
    if (task.reassignRequestedStatus != 'awaitingNewEmployee' ||
        task.reassignRequestedTo != newEmployeeUid) {
      return;
    }
    final now = DateTime.now();
    await FirestoreService.updateTaskFields(taskId, {
      'assignedTo': newEmployeeUid,
      'reassignRequestedTo': null,
      'reassignRequestedBy': null,
      'reassignRequestedAt': null,
      'reassignRequestedStatus': null,
      // A new assignee should see this as a fresh/unread item, mirroring
      // the "new task" notification badge semantics used elsewhere.
      'viewedByEmployee': false,
      'updatedAt': now.toIso8601String(),
    });
    await _logHistory(
      taskId,
      HistoryAction.reassignConfirmed,
      newEmployeeUid,
      note: 'أكّد الموظف الجديد استلام المهمة',
    );
  }

  /// Tasks with a reassignment request awaiting the MANAGER's decision.
  /// Feeds the "طلبات الإسناد" section inside the existing manager review
  /// tab (per answer ٧: shown in the current review tab, not a new one).
  List<AppTask> get reassignmentRequestsForManager =>
      _allTasks.where((t) => t.reassignRequestedStatus == 'pending').toList()
        ..sort(
          (a, b) => (a.reassignRequestedAt ?? a.updatedAt).compareTo(
            b.reassignRequestedAt ?? b.updatedAt,
          ),
        );

  /// Tasks approved by the manager and awaiting THIS employee's
  /// confirmation of receipt (answer ٦).
  List<AppTask> reassignmentsAwaitingConfirmation(String employeeUid) =>
      _allTasks
          .where(
            (t) =>
                t.reassignRequestedStatus == 'awaitingNewEmployee' &&
                t.reassignRequestedTo == employeeUid,
          )
          .toList();

  Future<void> _logHistory(
    String taskId,
    HistoryAction action,
    String actorUid, {
    String? note,
  }) async {
    final entry = TaskHistoryEntry(
      historyId: _uuid.v4(),
      taskId: taskId,
      action: action,
      actorUid: actorUid,
      note: note,
      timestamp: DateTime.now(),
    );
    await FirestoreService.addHistoryEntry(entry);
  }

  /// Completed vs. pending counts for [employeeUid] within the calendar
  /// week containing [anchor]. Feeds the employee tasks tab's mini weekly
  /// stat summary (screen-filler widget shown when the task list is
  /// short). Reuses [tasksForWeek] for the date-range filter AND
  /// [computeTaskStats] for the classification — NOT an independent
  /// approved/not-approved check — so this widget's numbers are
  /// guaranteed to match every other dashboard reading the same week's
  /// tasks (see task_stats.dart doc comment for the single-source-of-
  /// truth rationale).
  Map<String, int> weeklyStatsForEmployee(String employeeUid, DateTime anchor) {
    final weekTasks = tasksForWeek(anchor, employeeUid: employeeUid);
    final stats = computeTaskStats(weekTasks);
    return {
      'completed': stats.completed,
      'pending': stats.pendingDisplay + stats.submitted + stats.rejected,
    };
  }

  /// SINGLE SOURCE OF TRUTH for every dashboard's stat cards + completion
  /// chart (manager dashboard, designer dashboard) and the PDF report.
  /// Delegates entirely to [computeTaskStats] — this method must NEVER
  /// re-derive completed/pending/overdue with its own inline logic again
  /// (that duplication across screens was the documented root cause of
  /// cards/charts disagreeing and the card sum exceeding the total).
  TaskStats statsForRange(List<AppTask> tasks) => computeTaskStats(tasks);
}
