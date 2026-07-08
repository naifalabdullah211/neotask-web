import 'package:hive_flutter/hive_flutter.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/invitation_model.dart';
import '../models/task_history_model.dart';
import '../models/calendar_event_model.dart';

/// LocalDbService — CURRENT TEMPORARY BACKEND (Hive, browser-local only).
///
/// ⚠️ IMPORTANT ARCHITECTURAL NOTE (documented per project decision log):
/// This app REQUIRES a shared cloud database (Firestore) for its core purpose:
/// live sync between a manager's device and an employee's device.
/// Hive stores data ONLY in the current browser's local storage (IndexedDB
/// on web) — it does NOT sync across devices or browsers.
///
/// This service exists so the full UI/workflow (manager + employee views,
/// task lifecycle, invitations, approvals) can be built, tested, and
/// demonstrated end-to-end RIGHT NOW within a single browser/session.
///
/// Once a Firebase Admin SDK key is provided, this entire service will be
/// swapped for a FirestoreService with an IDENTICAL method signature
/// (see docs/FIREBASE_MIGRATION.md), so screens/providers will not need
/// to change — only the data layer underneath.
class LocalDbService {
  static const String usersBox = 'users_box';
  static const String tasksBox = 'tasks_box';
  static const String invitationsBox = 'invitations_box';
  static const String historyBox = 'history_box';
  static const String calendarBox = 'calendar_box';
  static const String sessionBox = 'session_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(usersBox);
    await Hive.openBox(tasksBox);
    await Hive.openBox(invitationsBox);
    await Hive.openBox(historyBox);
    await Hive.openBox(calendarBox);
    await Hive.openBox(sessionBox);
  }

  // ---------------- USERS ----------------
  static Box get _users => Hive.box(usersBox);

  static Future<void> saveUser(AppUser user) async {
    await _users.put(user.uid, user.toMap());
  }

  static AppUser? getUser(String uid) {
    final map = _users.get(uid);
    if (map == null) return null;
    return AppUser.fromMap(map);
  }

  static AppUser? getUserByEmail(String email) {
    for (final key in _users.keys) {
      final map = _users.get(key);
      if (map != null && map['email'] == email) {
        return AppUser.fromMap(map);
      }
    }
    return null;
  }

  static List<AppUser> getAllEmployees() {
    return _users.values
        .map((m) => AppUser.fromMap(m))
        .where((u) => u.role == UserRole.employee)
        .toList();
  }

  static List<AppUser> getPendingEmployees() {
    return getAllEmployees()
        .where((u) => u.accountStatus == AccountStatus.pendingApproval)
        .toList();
  }

  static AppUser? getManager() {
    for (final key in _users.keys) {
      final map = _users.get(key);
      if (map != null && map['role'] == 'manager') {
        return AppUser.fromMap(map);
      }
    }
    return null;
  }

  static Stream<List<AppUser>> watchEmployees() async* {
    yield getAllEmployees();
    yield* _users.watch().map((_) => getAllEmployees());
  }

  // ---------------- TASKS ----------------
  static Box get _tasks => Hive.box(tasksBox);

  static Future<void> saveTask(AppTask task) async {
    await _tasks.put(task.taskId, task.toMap());
  }

  static Future<void> deleteTask(String taskId) async {
    await _tasks.delete(taskId);
  }

  static AppTask? getTask(String taskId) {
    final map = _tasks.get(taskId);
    if (map == null) return null;
    return AppTask.fromMap(map);
  }

  static List<AppTask> getAllTasks() {
    return _tasks.values.map((m) => AppTask.fromMap(m)).toList();
  }

  static List<AppTask> getTasksForEmployee(String uid) {
    return getAllTasks().where((t) => t.assignedTo == uid).toList();
  }

  static List<AppTask> getSubmittedTasks() {
    return getAllTasks()
        .where((t) => t.status == TaskStatus.submitted)
        .toList()
      ..sort((a, b) => (a.submittedAt ?? a.updatedAt)
          .compareTo(b.submittedAt ?? b.updatedAt));
  }

  static Stream<List<AppTask>> watchAllTasks() async* {
    yield getAllTasks();
    yield* _tasks.watch().map((_) => getAllTasks());
  }

  static Stream<List<AppTask>> watchTasksForEmployee(String uid) async* {
    yield getTasksForEmployee(uid);
    yield* _tasks.watch().map((_) => getTasksForEmployee(uid));
  }

  static Stream<List<AppTask>> watchSubmittedTasks() async* {
    yield getSubmittedTasks();
    yield* _tasks.watch().map((_) => getSubmittedTasks());
  }

  // ---------------- INVITATIONS ----------------
  static Box get _invitations => Hive.box(invitationsBox);

  static Future<void> saveInvitation(Invitation invite) async {
    await _invitations.put(invite.inviteId, invite.toMap());
  }

  static Invitation? getInvitationByToken(String token) {
    for (final key in _invitations.keys) {
      final map = _invitations.get(key);
      if (map != null && map['token'] == token) {
        return Invitation.fromMap(map);
      }
    }
    return null;
  }

  static List<Invitation> getAllInvitations() {
    return _invitations.values.map((m) => Invitation.fromMap(m)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Stream<List<Invitation>> watchInvitations() async* {
    yield getAllInvitations();
    yield* _invitations.watch().map((_) => getAllInvitations());
  }

  // ---------------- TASK HISTORY ----------------
  static Box get _history => Hive.box(historyBox);

  static Future<void> addHistoryEntry(TaskHistoryEntry entry) async {
    await _history.put(entry.historyId, entry.toMap());
  }

  static List<TaskHistoryEntry> getHistoryForTask(String taskId) {
    return _history.values
        .map((m) => TaskHistoryEntry.fromMap(m))
        .where((h) => h.taskId == taskId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  // ---------------- CALENDAR EVENTS (imported, read-only) ----------------
  static Box get _calendar => Hive.box(calendarBox);

  static Future<void> saveCalendarEvent(
      String userUid, CalendarEventItem event) async {
    await _calendar.put('${userUid}_${event.uid}', {
      'userUid': userUid,
      ...event.toMap(),
    });
  }

  static Future<void> clearCalendarEventsForUser(String userUid) async {
    final keysToDelete = _calendar.keys
        .where((k) => k.toString().startsWith('${userUid}_'))
        .toList();
    for (final k in keysToDelete) {
      await _calendar.delete(k);
    }
  }

  static List<CalendarEventItem> getCalendarEventsForUser(String userUid) {
    return _calendar.values
        .where((m) => m['userUid'] == userUid)
        .map((m) => CalendarEventItem.fromMap(m))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  // ---------------- SESSION ----------------
  static Box get _session => Hive.box(sessionBox);

  static Future<void> setCurrentUid(String? uid) async {
    if (uid == null) {
      await _session.delete('currentUid');
    } else {
      await _session.put('currentUid', uid);
    }
  }

  static String? getCurrentUid() {
    return _session.get('currentUid') as String?;
  }

  static Box getSessionBoxForIcs() => _session;
}
