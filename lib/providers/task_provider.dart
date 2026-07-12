import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/task_model.dart';
import '../models/task_history_model.dart';
import '../services/firestore_service.dart';
import '../utils/recurrence_utils.dart';

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
    });
  }

  List<AppTask> tasksForEmployee(String uid) =>
      _allTasks.where((t) => t.assignedTo == uid).toList()
        ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

  List<AppTask> get submittedForReview =>
      _allTasks.where((t) => t.status == TaskStatus.submitted).toList()..sort(
        (a, b) => (a.submittedAt ?? a.updatedAt).compareTo(
          b.submittedAt ?? b.updatedAt,
        ),
      );

  List<AppTask> tasksForDay(DateTime day, {String? employeeUid}) {
    return _allTasks.where((t) {
      final matchesDay =
          t.dueDate.year == day.year &&
          t.dueDate.month == day.month &&
          t.dueDate.day == day.day;
      final matchesEmployee =
          employeeUid == null || t.assignedTo == employeeUid;
      return matchesDay && matchesEmployee;
    }).toList();
  }

  List<AppTask> tasksForMonth(DateTime month, {String? employeeUid}) {
    return _allTasks.where((t) {
      final matchesMonth =
          t.dueDate.year == month.year && t.dueDate.month == month.month;
      final matchesEmployee =
          employeeUid == null || t.assignedTo == employeeUid;
      return matchesMonth && matchesEmployee;
    }).toList();
  }

  List<AppTask> tasksForWeek(DateTime anyDayInWeek, {String? employeeUid}) {
    final weekday = anyDayInWeek.weekday;
    final start = anyDayInWeek.subtract(Duration(days: weekday - 1));
    final end = start.add(const Duration(days: 6));
    return _allTasks.where((t) {
      final inRange =
          !t.dueDate.isBefore(DateTime(start.year, start.month, start.day)) &&
          !t.dueDate.isAfter(
            DateTime(end.year, end.month, end.day, 23, 59, 59),
          );
      final matchesEmployee =
          employeeUid == null || t.assignedTo == employeeUid;
      return inRange && matchesEmployee;
    }).toList();
  }

  Future<AppTask> createTask({
    required String title,
    required String description,
    required String assignedTo,
    required String assignedBy,
    required DateTime dueDate,
    required TaskPriority priority,
    required String category,
    RecurrenceType recurrenceType = RecurrenceType.none,
    int? recurrenceDayOfMonth,
    WeekOrdinal? recurrenceWeekOrdinal,
    Weekday? recurrenceWeekday,
    DateTime? recurrenceEndDate,
  }) async {
    final now = DateTime.now();
    final task = AppTask(
      taskId: _uuid.v4(),
      title: title,
      description: description,
      assignedTo: assignedTo,
      assignedBy: assignedBy,
      dueDate: dueDate,
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
    final updated = task.copyWith(status: status, updatedAt: DateTime.now());
    await FirestoreService.saveTask(updated);
    await _logHistory(
      taskId,
      HistoryAction.statusChange,
      actorUid,
      note: 'تغيير الحالة إلى ${status.name}',
    );
  }

  Future<void> submitForReview(
    String taskId,
    String employeeUid,
    String? note,
  ) async {
    final task = FirestoreService.getTask(taskId);
    if (task == null) return;
    final updated = task.copyWith(
      status: TaskStatus.submitted,
      submittedAt: DateTime.now(),
      submissionNote: note,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveTask(updated);
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
    final updated = task.copyWith(
      status: TaskStatus.inProgress,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveTask(updated);
    await _logHistory(
      taskId,
      HistoryAction.statusChange,
      employeeUid,
      note: 'استئناف العمل بعد ملاحظات المدير',
    );
  }

  Future<void> deleteTask(String taskId) async {
    await FirestoreService.deleteTask(taskId);
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
    final updated = task.copyWith(
      reassignRequestedTo: requestedTo,
      reassignRequestedBy: requestedBy,
      reassignRequestedAt: DateTime.now(),
      reassignRequestedStatus: 'pending',
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveTask(updated);
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
    final updated = task.copyWith(
      assignedTo: newEmployeeUid,
      clearReassignRequest: true,
      // A new assignee should see this as a fresh/unread item, mirroring
      // the "new task" notification badge semantics used elsewhere.
      viewedByEmployee: false,
      updatedAt: DateTime.now(),
    );
    await FirestoreService.saveTask(updated);
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
  List<AppTask> get reassignmentRequestsForManager => _allTasks
      .where((t) => t.reassignRequestedStatus == 'pending')
      .toList()
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

  // ---- Simple stats helpers for manager dashboard/reports ----
  Map<String, int> statsForRange(List<AppTask> tasks) {
    return {
      'total': tasks.length,
      'approved': tasks.where((t) => t.status == TaskStatus.approved).length,
      'pending': tasks
          .where(
            (t) =>
                t.status == TaskStatus.assigned ||
                t.status == TaskStatus.inProgress,
          )
          .length,
      'submitted': tasks.where((t) => t.status == TaskStatus.submitted).length,
      'rejected': tasks.where((t) => t.status == TaskStatus.rejected).length,
      'overdue': tasks
          .where(
            (t) =>
                t.dueDate.isBefore(DateTime.now()) &&
                t.status != TaskStatus.approved,
          )
          .length,
    };
  }
}
