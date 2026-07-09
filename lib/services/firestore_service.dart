import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/invitation_model.dart';
import '../models/task_history_model.dart';
import '../models/calendar_event_model.dart';
import '../models/message_model.dart';

/// FirestoreService — REPLACES LocalDbService (Hive) as of this commit.
///
/// This provides an IDENTICAL static method-signature API to the previous
/// LocalDbService, so providers/screens did not need logic rewrites — only
/// the import + class name were swapped.
///
/// Architecture: Firestore's `.snapshots()` are asynchronous streams, but a
/// large amount of existing UI code reads data SYNCHRONOUSLY (e.g.
/// `getAllEmployees()` called directly inside a `build()` method). To
/// preserve that synchronous read pattern while gaining real Firestore
/// cross-device sync, this service keeps an in-memory cache per collection
/// that is kept live via a `.snapshots()` listener. All reads hit the cache
/// (instant, synchronous); all writes go straight to Firestore (the cache
/// then updates itself automatically on the next snapshot event, typically
/// within tens of milliseconds).
///
/// `init()` awaits the FIRST snapshot of every collection before returning,
/// so the app never renders against an empty/uninitialized cache on cold
/// start (mirrors the previous Hive-box-opened-before-runApp guarantee).
///
/// Firestore collections used: users, tasks, invitations, task_history,
/// calendar_imports, calendar_settings (per the documented schema plan).
class FirestoreService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---- In-memory caches (kept live via snapshot listeners) ----
  static List<AppUser> _usersCache = [];
  static List<AppTask> _tasksCache = [];
  static List<Invitation> _invitationsCache = [];
  static List<TaskHistoryEntry> _historyCache = [];
  static List<Map<String, dynamic>> _calendarRawCache = []; // includes userUid
  static final Map<String, String> _icsUrlCache = {};
  static List<ChatMessage> _messagesCache = [];

  // ---- Change signal controllers (mirror Hive's box.watch() pattern) ----
  static final _usersChanges = StreamController<void>.broadcast();
  static final _tasksChanges = StreamController<void>.broadcast();
  static final _invitationsChanges = StreamController<void>.broadcast();
  static final _calendarChanges = StreamController<void>.broadcast();
  static final _messagesChanges = StreamController<void>.broadcast();

  // ---- Session (kept local per-device via SharedPreferences — session
  // identity is intentionally NOT synced across devices/browsers) ----
  static String? _cachedCurrentUid;
  static SharedPreferences? _prefs;

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    _prefs = await SharedPreferences.getInstance();
    _cachedCurrentUid = _prefs!.getString('currentUid');

    final usersDone = Completer<void>();
    final tasksDone = Completer<void>();
    final invitationsDone = Completer<void>();
    final historyDone = Completer<void>();
    final calendarDone = Completer<void>();
    final icsDone = Completer<void>();
    final messagesDone = Completer<void>();

    _db
        .collection('users')
        .snapshots()
        .listen(
          (snap) {
            _usersCache = snap.docs
                .map((d) => AppUser.fromMap(d.data()))
                .toList();
            if (!usersDone.isCompleted) usersDone.complete();
            _usersChanges.add(null);
          },
          onError: (_) {
            if (!usersDone.isCompleted) usersDone.complete();
          },
        );

    _db
        .collection('tasks')
        .snapshots()
        .listen(
          (snap) {
            _tasksCache = snap.docs
                .map((d) => AppTask.fromMap(d.data()))
                .toList();
            if (!tasksDone.isCompleted) tasksDone.complete();
            _tasksChanges.add(null);
          },
          onError: (_) {
            if (!tasksDone.isCompleted) tasksDone.complete();
          },
        );

    _db
        .collection('invitations')
        .snapshots()
        .listen(
          (snap) {
            _invitationsCache = snap.docs
                .map((d) => Invitation.fromMap(d.data()))
                .toList();
            if (!invitationsDone.isCompleted) invitationsDone.complete();
            _invitationsChanges.add(null);
          },
          onError: (_) {
            if (!invitationsDone.isCompleted) invitationsDone.complete();
          },
        );

    _db
        .collection('task_history')
        .snapshots()
        .listen(
          (snap) {
            _historyCache = snap.docs
                .map((d) => TaskHistoryEntry.fromMap(d.data()))
                .toList();
            if (!historyDone.isCompleted) historyDone.complete();
          },
          onError: (_) {
            if (!historyDone.isCompleted) historyDone.complete();
          },
        );

    _db
        .collection('calendar_imports')
        .snapshots()
        .listen(
          (snap) {
            _calendarRawCache = snap.docs.map((d) => d.data()).toList();
            if (!calendarDone.isCompleted) calendarDone.complete();
            _calendarChanges.add(null);
          },
          onError: (_) {
            if (!calendarDone.isCompleted) calendarDone.complete();
          },
        );

    _db
        .collection('calendar_settings')
        .snapshots()
        .listen(
          (snap) {
            _icsUrlCache.clear();
            for (final d in snap.docs) {
              final url = d.data()['icsUrl'] as String?;
              if (url != null) _icsUrlCache[d.id] = url;
            }
            if (!icsDone.isCompleted) icsDone.complete();
          },
          onError: (_) {
            if (!icsDone.isCompleted) icsDone.complete();
          },
        );

    _db
        .collection('messages')
        .snapshots()
        .listen(
          (snap) {
            _messagesCache = snap.docs
                .map((d) => ChatMessage.fromMap(d.data()))
                .toList();
            if (!messagesDone.isCompleted) messagesDone.complete();
            _messagesChanges.add(null);
          },
          onError: (_) {
            if (!messagesDone.isCompleted) messagesDone.complete();
          },
        );

    await Future.wait([
      usersDone.future,
      tasksDone.future,
      invitationsDone.future,
      historyDone.future,
      calendarDone.future,
      icsDone.future,
      messagesDone.future,
    ]).timeout(const Duration(seconds: 15), onTimeout: () => []);

    _initialized = true;
  }

  // ---------------- USERS ----------------
  static Future<void> saveUser(AppUser user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  static AppUser? getUser(String uid) {
    for (final u in _usersCache) {
      if (u.uid == uid) return u;
    }
    return null;
  }

  static AppUser? getUserByEmail(String email) {
    for (final u in _usersCache) {
      if (u.email == email) return u;
    }
    return null;
  }

  static List<AppUser> getAllEmployees() {
    return _usersCache.where((u) => u.role == UserRole.employee).toList();
  }

  static List<AppUser> getPendingEmployees() {
    return getAllEmployees()
        .where((u) => u.accountStatus == AccountStatus.pendingApproval)
        .toList();
  }

  static AppUser? getManager() {
    for (final u in _usersCache) {
      if (u.role == UserRole.manager) return u;
    }
    return null;
  }

  static Stream<List<AppUser>> watchEmployees() async* {
    yield getAllEmployees();
    yield* _usersChanges.stream.map((_) => getAllEmployees());
  }

  // ---------------- TASKS ----------------
  static Future<void> saveTask(AppTask task) async {
    await _db.collection('tasks').doc(task.taskId).set(task.toMap());
  }

  static Future<void> deleteTask(String taskId) async {
    await _db.collection('tasks').doc(taskId).delete();
  }

  /// Marks a single task as viewed by its assigned employee — sets
  /// `viewedByEmployee: true` on the Firestore doc. Mirrors
  /// `markConversationRead` below (single-field update, no composite
  /// index needed).
  static Future<void> markTaskViewed(String taskId) async {
    await _db.collection('tasks').doc(taskId).update({
      'viewedByEmployee': true,
    });
  }

  static AppTask? getTask(String taskId) {
    for (final t in _tasksCache) {
      if (t.taskId == taskId) return t;
    }
    return null;
  }

  static List<AppTask> getAllTasks() => List.unmodifiable(_tasksCache);

  static List<AppTask> getTasksForEmployee(String uid) {
    return _tasksCache.where((t) => t.assignedTo == uid).toList();
  }

  static List<AppTask> getSubmittedTasks() {
    return _tasksCache.where((t) => t.status == TaskStatus.submitted).toList()
      ..sort(
        (a, b) => (a.submittedAt ?? a.updatedAt).compareTo(
          b.submittedAt ?? b.updatedAt,
        ),
      );
  }

  static Stream<List<AppTask>> watchAllTasks() async* {
    yield getAllTasks();
    yield* _tasksChanges.stream.map((_) => getAllTasks());
  }

  static Stream<List<AppTask>> watchTasksForEmployee(String uid) async* {
    yield getTasksForEmployee(uid);
    yield* _tasksChanges.stream.map((_) => getTasksForEmployee(uid));
  }

  static Stream<List<AppTask>> watchSubmittedTasks() async* {
    yield getSubmittedTasks();
    yield* _tasksChanges.stream.map((_) => getSubmittedTasks());
  }

  /// Batch-deletes every task currently assigned to [employeeUid].
  ///
  /// Used when a manager soft-deletes an employee and chooses to discard
  /// that employee's tasks rather than reassign them.
  static Future<void> deleteAllTasksForEmployee(String employeeUid) async {
    final toDelete = _tasksCache
        .where((t) => t.assignedTo == employeeUid)
        .toList();
    if (toDelete.isEmpty) return;
    final batch = _db.batch();
    for (final t in toDelete) {
      batch.delete(_db.collection('tasks').doc(t.taskId));
    }
    await batch.commit();
  }

  /// Batch-reassigns every task currently assigned to [fromEmployeeUid] over
  /// to [toEmployeeUid], preserving each task's full history/status.
  ///
  /// Used when a manager soft-deletes an employee and chooses to transfer
  /// that employee's tasks to another active employee instead of deleting
  /// them.
  static Future<void> reassignAllTasksForEmployee(
    String fromEmployeeUid,
    String toEmployeeUid,
  ) async {
    final toReassign = _tasksCache
        .where((t) => t.assignedTo == fromEmployeeUid)
        .toList();
    if (toReassign.isEmpty) return;
    final batch = _db.batch();
    for (final t in toReassign) {
      batch.update(_db.collection('tasks').doc(t.taskId), {
        'assignedTo': toEmployeeUid,
        'updatedAt': DateTime.now().toIso8601String(),
      });
    }
    await batch.commit();
  }

  // ---------------- INVITATIONS ----------------
  static Future<void> saveInvitation(Invitation invite) async {
    await _db
        .collection('invitations')
        .doc(invite.inviteId)
        .set(invite.toMap());
  }

  static Invitation? getInvitationByToken(String token) {
    for (final i in _invitationsCache) {
      if (i.token == token) return i;
    }
    return null;
  }

  /// Atomically validates and consumes a single-use invite token, then
  /// creates the new employee user in the SAME Firestore transaction.
  ///
  /// This prevents the race condition where two concurrent registration
  /// attempts against the same invite link could otherwise both succeed
  /// (read-then-write without a transaction is not safe for a single-use
  /// token guarantee). Returns null if the token is invalid/already used
  /// or if the email is already registered; otherwise returns the new user.
  static Future<AppUser?> consumeInviteAndRegister({
    required String token,
    required AppUser newUser,
  }) async {
    try {
      return await _db.runTransaction<AppUser?>((tx) async {
        final inviteQuery = await _db
            .collection('invitations')
            .where('token', isEqualTo: token)
            .limit(1)
            .get();

        if (inviteQuery.docs.isEmpty) return null;
        final inviteDoc = inviteQuery.docs.first;
        final inviteData = inviteDoc.data();
        if (inviteData['status'] != InvitationStatus.pending.name) {
          return null; // already used or invalid
        }

        final emailQuery = await _db
            .collection('users')
            .where('email', isEqualTo: newUser.email)
            .limit(1)
            .get();
        if (emailQuery.docs.isNotEmpty) {
          return null; // email already registered
        }

        tx.set(_db.collection('users').doc(newUser.uid), newUser.toMap());
        tx.update(inviteDoc.reference, {
          'status': InvitationStatus.used.name,
          'usedAt': DateTime.now().toIso8601String(),
          'usedByUid': newUser.uid,
        });

        return newUser;
      });
    } catch (_) {
      return null;
    }
  }

  static List<Invitation> getAllInvitations() {
    return List<Invitation>.from(_invitationsCache)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Stream<List<Invitation>> watchInvitations() async* {
    yield getAllInvitations();
    yield* _invitationsChanges.stream.map((_) => getAllInvitations());
  }

  // ---------------- TASK HISTORY ----------------
  static Future<void> addHistoryEntry(TaskHistoryEntry entry) async {
    await _db
        .collection('task_history')
        .doc(entry.historyId)
        .set(entry.toMap());
  }

  static List<TaskHistoryEntry> getHistoryForTask(String taskId) {
    return _historyCache.where((h) => h.taskId == taskId).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  // ---------------- CALENDAR EVENTS (imported, read-only) ----------------
  static Future<void> saveCalendarEvent(
    String userUid,
    CalendarEventItem event,
  ) async {
    await _db.collection('calendar_imports').doc('${userUid}_${event.uid}').set(
      {'userUid': userUid, ...event.toMap()},
    );
  }

  static Future<void> clearCalendarEventsForUser(String userUid) async {
    final batch = _db.batch();
    final toDelete = _calendarRawCache
        .where((m) => m['userUid'] == userUid)
        .toList();
    for (final m in toDelete) {
      final docId = '${userUid}_${m['uid']}';
      batch.delete(_db.collection('calendar_imports').doc(docId));
    }
    if (toDelete.isNotEmpty) {
      await batch.commit();
    }
  }

  static List<CalendarEventItem> getCalendarEventsForUser(String userUid) {
    return _calendarRawCache
        .where((m) => m['userUid'] == userUid)
        .map((m) => CalendarEventItem.fromMap(m))
        .toList()
      ..sort((a, b) => a.start.compareTo(b.start));
  }

  // ---------------- ICS URL PER USER (calendar_settings collection) ----------------
  static Future<void> saveIcsUrl(String userUid, String url) async {
    _icsUrlCache[userUid] = url;
    await _db.collection('calendar_settings').doc(userUid).set({'icsUrl': url});
  }

  static String? getIcsUrl(String userUid) => _icsUrlCache[userUid];

  // ---------------- MESSAGES (chat: general DM + per-task threads) ----------------
  static Future<void> saveMessage(ChatMessage message) async {
    await _db
        .collection('messages')
        .doc(message.messageId)
        .set(message.toMap());
  }

  /// All messages belonging to [conversationId] (either a
  /// `ChatMessage.generalConversationId(...)` or
  /// `ChatMessage.taskConversationId(...)` value), sorted by time.
  ///
  /// Deliberately a single-field `==` filter (no `orderBy`) to avoid any
  /// Firestore composite-index requirement — sorting is done in memory,
  /// consistent with `getHistoryForTask` / `getAllInvitations` above.
  static List<ChatMessage> getMessagesForConversation(String conversationId) {
    return _messagesCache
        .where((m) => m.conversationId == conversationId)
        .toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
  }

  static Stream<List<ChatMessage>> watchMessagesForConversation(
    String conversationId,
  ) async* {
    yield getMessagesForConversation(conversationId);
    yield* _messagesChanges.stream.map(
      (_) => getMessagesForConversation(conversationId),
    );
  }

  /// Latest message per conversation the given [userUid] participates in
  /// (as sender or recipient) — used to build conversation-list previews
  /// (e.g. the manager's per-employee chat list).
  static List<ChatMessage> getLatestMessagesForUser(String userUid) {
    final byConversation = <String, ChatMessage>{};
    for (final m in _messagesCache) {
      if (m.senderUid != userUid && m.recipientUid != userUid) continue;
      final existing = byConversation[m.conversationId];
      if (existing == null || m.timestamp.isAfter(existing.timestamp)) {
        byConversation[m.conversationId] = m;
      }
    }
    return byConversation.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  static Stream<List<ChatMessage>> watchLatestMessagesForUser(
    String userUid,
  ) async* {
    yield getLatestMessagesForUser(userUid);
    yield* _messagesChanges.stream.map(
      (_) => getLatestMessagesForUser(userUid),
    );
  }

  /// Number of unread messages in [conversationId] addressed to [userUid]
  /// (i.e. `recipientUid == userUid && readAt == null`).
  static int getUnreadCountForConversation(
    String conversationId,
    String userUid,
  ) {
    return _messagesCache
        .where(
          (m) =>
              m.conversationId == conversationId &&
              m.recipientUid == userUid &&
              m.readAt == null,
        )
        .length;
  }

  /// Total unread messages across ALL of [userUid]'s conversations — used
  /// for the bottom-nav badge.
  static int getTotalUnreadCountForUser(String userUid) {
    return _messagesCache
        .where((m) => m.recipientUid == userUid && m.readAt == null)
        .length;
  }

  static Stream<int> watchTotalUnreadCountForUser(String userUid) async* {
    yield getTotalUnreadCountForUser(userUid);
    yield* _messagesChanges.stream.map(
      (_) => getTotalUnreadCountForUser(userUid),
    );
  }

  /// Marks every unread message in [conversationId] addressed to [userUid]
  /// as read.
  static Future<void> markConversationRead(
    String conversationId,
    String userUid,
  ) async {
    final unread = _messagesCache
        .where(
          (m) =>
              m.conversationId == conversationId &&
              m.recipientUid == userUid &&
              m.readAt == null,
        )
        .toList();
    if (unread.isEmpty) return;
    final batch = _db.batch();
    final now = DateTime.now();
    for (final m in unread) {
      batch.update(_db.collection('messages').doc(m.messageId), {
        'readAt': now.toIso8601String(),
      });
    }
    await batch.commit();
  }

  // ---------------- SESSION (local device only — SharedPreferences) ----------------
  static Future<void> setCurrentUid(String? uid) async {
    _cachedCurrentUid = uid;
    if (uid == null) {
      await _prefs?.remove('currentUid');
    } else {
      await _prefs?.setString('currentUid', uid);
    }
  }

  static String? getCurrentUid() => _cachedCurrentUid;
}
