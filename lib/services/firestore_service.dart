import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/task_model.dart';
import '../models/invitation_model.dart';
import '../models/task_history_model.dart';
import '../models/calendar_event_model.dart';
import '../models/message_model.dart';
import '../models/document_model.dart';
import '../models/meeting_model.dart';
import '../models/contact_model.dart';
import '../models/favorite_model.dart';
import '../models/goal_model.dart';
import '../models/criterion_model.dart';
import '../models/criterion_history_model.dart';

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
  static List<DocumentItem> _documentsCache = [];
  static List<MeetingItem> _meetingsCache = [];
  static List<ContactItem> _contactsCache = [];
  static List<FavoriteTask> _favoritesCache = [];
  // NEW (Goal/Criteria feature — added ALONGSIDE the existing task system,
  // per the manager's explicit answer "١- اضافه" — see goal_model.dart /
  // criterion_model.dart doc comments for the full feature rationale).
  static List<Goal> _goalsCache = [];
  static List<Criterion> _criteriaCache = [];
  static List<CriterionHistoryEntry> _criterionHistoryCache = [];

  // ---- Change signal controllers (mirror Hive's box.watch() pattern) ----
  static final _usersChanges = StreamController<void>.broadcast();
  static final _tasksChanges = StreamController<void>.broadcast();
  static final _invitationsChanges = StreamController<void>.broadcast();
  static final _calendarChanges = StreamController<void>.broadcast();
  static final _messagesChanges = StreamController<void>.broadcast();
  static final _documentsChanges = StreamController<void>.broadcast();
  static final _meetingsChanges = StreamController<void>.broadcast();
  static final _contactsChanges = StreamController<void>.broadcast();
  static final _favoritesChanges = StreamController<void>.broadcast();
  static final _goalsChanges = StreamController<void>.broadcast();
  static final _criteriaChanges = StreamController<void>.broadcast();

  // NOTE: session/identity is now handled entirely by FirebaseAuth
  // (see AuthProvider + FirebaseAuth.instance.authStateChanges()) — this
  // service no longer tracks a locally-cached "currentUid" itself.

  // ---- "manager exists?" signal, readable BEFORE any sign-in ----
  //
  // Under the locked-down Firestore security rules, the `users` collection
  // requires `request.auth != null` to read — but SplashRouter/AuthProvider
  // need to know whether a manager account exists at all *before* anyone is
  // signed in (to decide: show ManagerSetupScreen vs. LoginScreen). This is
  // answered by the tiny public `system/manager_lock` sentinel document
  // (created atomically alongside the manager's `users` doc — see
  // `createManagerProfile` below) instead of querying `users` directly.
  static bool _managerLockExists = false;
  static bool get managerLockExists => _managerLockExists;

  static bool _publicInitialized = false;
  static bool _authInitialized = false;
  static final List<StreamSubscription> _authSubscriptions = [];

  /// Sets up ONLY the listeners that are safe to run before any user is
  /// signed in (per the security rules: `system/manager_lock` and
  /// `invitations` are both public-read — see firestore.rules). Call this
  /// once at app startup, before FirebaseAuth's session is even checked.
  static Future<void> initPublic() async {
    if (_publicInitialized) return;

    final lockDone = Completer<void>();
    final invitationsDone = Completer<void>();

    _db
        .collection('system')
        .doc('manager_lock')
        .snapshots()
        .listen(
          (snap) {
            _managerLockExists = snap.exists;
            if (!lockDone.isCompleted) lockDone.complete();
          },
          onError: (_) {
            if (!lockDone.isCompleted) lockDone.complete();
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

    await Future.wait([
      lockDone.future,
      invitationsDone.future,
    ]).timeout(const Duration(seconds: 15), onTimeout: () => []);

    _publicInitialized = true;
  }

  /// Sets up every listener that requires an authenticated session (per the
  /// security rules). Must be called AFTER Firebase Auth sign-in succeeds
  /// (see AuthProvider.login / restoreSession / registerViaInvite) and
  /// BEFORE any UI renders authenticated screens, so synchronous cache
  /// reads (getAllTasks, getAllEmployees, etc.) are warm by then — mirrors
  /// the original single-init() design's guarantee.
  ///
  /// Idempotent within a single signed-in session (returns immediately if
  /// already initialized); call `resetAuthenticatedState()` on sign-out so
  /// the NEXT sign-in (potentially a different account) gets a clean cache
  /// and fresh listeners scoped to the new session.
  static Future<void> initAuthenticated() async {
    if (_authInitialized) return;

    final usersDone = Completer<void>();
    final tasksDone = Completer<void>();
    final historyDone = Completer<void>();
    final calendarDone = Completer<void>();
    final icsDone = Completer<void>();
    final messagesDone = Completer<void>();
    final documentsDone = Completer<void>();
    final meetingsDone = Completer<void>();
    final contactsDone = Completer<void>();
    final favoritesDone = Completer<void>();
    final goalsDone = Completer<void>();
    final criteriaDone = Completer<void>();
    final criterionHistoryDone = Completer<void>();

    _authSubscriptions.add(
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
          ),
    );

    _authSubscriptions.add(
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
          ),
    );

    _authSubscriptions.add(
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
          ),
    );

    _authSubscriptions.add(
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
          ),
    );

    _authSubscriptions.add(
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
          ),
    );

    _authSubscriptions.add(
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
          ),
    );

    _authSubscriptions.add(
      _db
          .collection('documents')
          .snapshots()
          .listen(
            (snap) {
              _documentsCache = snap.docs
                  .map((d) => DocumentItem.fromMap(d.data()))
                  .toList();
              if (!documentsDone.isCompleted) documentsDone.complete();
              _documentsChanges.add(null);
            },
            onError: (_) {
              if (!documentsDone.isCompleted) documentsDone.complete();
            },
          ),
    );

    _authSubscriptions.add(
      _db
          .collection('meetings')
          .snapshots()
          .listen(
            (snap) {
              _meetingsCache = snap.docs
                  .map((d) => MeetingItem.fromMap(d.data()))
                  .toList();
              if (!meetingsDone.isCompleted) meetingsDone.complete();
              _meetingsChanges.add(null);
            },
            onError: (_) {
              if (!meetingsDone.isCompleted) meetingsDone.complete();
            },
          ),
    );

    _authSubscriptions.add(
      _db
          .collection('contacts')
          .snapshots()
          .listen(
            (snap) {
              _contactsCache = snap.docs
                  .map((d) => ContactItem.fromMap(d.data()))
                  .toList();
              if (!contactsDone.isCompleted) contactsDone.complete();
              _contactsChanges.add(null);
            },
            onError: (_) {
              if (!contactsDone.isCompleted) contactsDone.complete();
            },
          ),
    );

    _authSubscriptions.add(
      _db
          .collection('favorites')
          .snapshots()
          .listen(
            (snap) {
              _favoritesCache = snap.docs
                  .map((d) => FavoriteTask.fromMap(d.data()))
                  .toList();
              if (!favoritesDone.isCompleted) favoritesDone.complete();
              _favoritesChanges.add(null);
            },
            onError: (_) {
              if (!favoritesDone.isCompleted) favoritesDone.complete();
            },
          ),
    );

    _authSubscriptions.add(
      _db
          .collection('goals')
          .snapshots()
          .listen(
            (snap) {
              _goalsCache = snap.docs
                  .map((d) => Goal.fromMap(d.data()))
                  .toList();
              if (!goalsDone.isCompleted) goalsDone.complete();
              _goalsChanges.add(null);
            },
            onError: (_) {
              if (!goalsDone.isCompleted) goalsDone.complete();
            },
          ),
    );

    _authSubscriptions.add(
      _db
          .collection('criteria')
          .snapshots()
          .listen(
            (snap) {
              _criteriaCache = snap.docs
                  .map((d) => Criterion.fromMap(d.data()))
                  .toList();
              if (!criteriaDone.isCompleted) criteriaDone.complete();
              _criteriaChanges.add(null);
            },
            onError: (_) {
              if (!criteriaDone.isCompleted) criteriaDone.complete();
            },
          ),
    );

    _authSubscriptions.add(
      _db
          .collection('criterion_history')
          .snapshots()
          .listen(
            (snap) {
              _criterionHistoryCache = snap.docs
                  .map((d) => CriterionHistoryEntry.fromMap(d.data()))
                  .toList();
              if (!criterionHistoryDone.isCompleted) {
                criterionHistoryDone.complete();
              }
            },
            onError: (_) {
              if (!criterionHistoryDone.isCompleted) {
                criterionHistoryDone.complete();
              }
            },
          ),
    );

    await Future.wait([
      usersDone.future,
      tasksDone.future,
      historyDone.future,
      calendarDone.future,
      icsDone.future,
      messagesDone.future,
      documentsDone.future,
      meetingsDone.future,
      contactsDone.future,
      favoritesDone.future,
      goalsDone.future,
      criteriaDone.future,
      criterionHistoryDone.future,
    ]).timeout(const Duration(seconds: 15), onTimeout: () => []);

    _authInitialized = true;
  }

  /// Tears down every authenticated-session listener and clears the
  /// corresponding caches. Call on sign-out so a subsequent sign-in (by the
  /// same or a different account) starts from a clean, correctly-scoped
  /// state rather than accumulating duplicate listeners or briefly showing
  /// the previous account's cached data.
  static Future<void> resetAuthenticatedState() async {
    for (final sub in _authSubscriptions) {
      await sub.cancel();
    }
    _authSubscriptions.clear();
    _usersCache = [];
    _tasksCache = [];
    _historyCache = [];
    _calendarRawCache = [];
    _icsUrlCache.clear();
    _messagesCache = [];
    _documentsCache = [];
    _meetingsCache = [];
    _contactsCache = [];
    _favoritesCache = [];
    _goalsCache = [];
    _criteriaCache = [];
    _criterionHistoryCache = [];
    _authInitialized = false;
  }

  // ---------------- USERS ----------------
  static Future<void> saveUser(AppUser user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  /// Atomically creates the single manager profile document together with
  /// the `system/manager_lock` sentinel document, in the SAME Firestore
  /// transaction. This mirrors `consumeInviteAndRegister`'s
  /// read-then-write-atomically pattern and is what makes the Firestore
  /// security rule `!exists(/system/manager_lock)` gate on manager-role
  /// user-doc creation actually race-safe: two concurrent manager-bootstrap
  /// attempts cannot both succeed, because the second transaction's read of
  /// `system/manager_lock` will see the first transaction's write once it
  /// has committed (Firestore transactions guarantee serializability).
  ///
  /// Returns `true` if the manager profile was created, `false` if a
  /// manager (lock) already existed — in which case the caller MUST roll
  /// back the just-created Firebase Auth credential.
  static Future<bool> createManagerProfile(AppUser manager) async {
    return _db.runTransaction<bool>((tx) async {
      final lockRef = _db.collection('system').doc('manager_lock');
      final lockSnap = await tx.get(lockRef);
      if (lockSnap.exists) return false;

      tx.set(_db.collection('users').doc(manager.uid), manager.toMap());
      tx.set(lockRef, {
        'createdAt': DateTime.now().toIso8601String(),
        'createdBy': manager.uid,
      });
      return true;
    });
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

  // ---------------- GOALS (new — additive feature, see goal_model.dart) ----------------
  static Future<void> saveGoal(Goal goal) async {
    await _db.collection('goals').doc(goal.goalId).set(goal.toMap());
  }

  static Future<void> deleteGoal(String goalId) async {
    await _db.collection('goals').doc(goalId).delete();
  }

  static Goal? getGoal(String goalId) {
    for (final g in _goalsCache) {
      if (g.goalId == goalId) return g;
    }
    return null;
  }

  static List<Goal> getAllGoals() => List.unmodifiable(_goalsCache);

  static Stream<List<Goal>> watchAllGoals() async* {
    yield getAllGoals();
    yield* _goalsChanges.stream.map((_) => getAllGoals());
  }

  // ---------------- CRITERIA (new — additive feature, see criterion_model.dart) ----------------
  static Future<void> saveCriterion(Criterion criterion) async {
    await _db
        .collection('criteria')
        .doc(criterion.criterionId)
        .set(criterion.toMap());
  }

  static Future<void> deleteCriterion(String criterionId) async {
    await _db.collection('criteria').doc(criterionId).delete();
  }

  static Criterion? getCriterion(String criterionId) {
    for (final c in _criteriaCache) {
      if (c.criterionId == criterionId) return c;
    }
    return null;
  }

  static List<Criterion> getAllCriteria() => List.unmodifiable(_criteriaCache);

  static List<Criterion> getCriteriaForGoal(String goalId) {
    return _criteriaCache.where((c) => c.goalId == goalId).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  /// Criteria can have MULTIPLE assignees (per the manager's explicit
  /// answer "٤- يمكن لعدة موظفين المشاركة بحسب رغبة المدير") — hence
  /// list-membership (`contains`), never `==` equality like the single-
  /// assignee `AppTask.assignedTo` check in `getTasksForEmployee`.
  static List<Criterion> getCriteriaForEmployee(String uid) {
    return _criteriaCache.where((c) => c.assignedTo.contains(uid)).toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  }

  static Stream<List<Criterion>> watchAllCriteria() async* {
    yield getAllCriteria();
    yield* _criteriaChanges.stream.map((_) => getAllCriteria());
  }

  static Stream<List<Criterion>> watchCriteriaForGoal(String goalId) async* {
    yield getCriteriaForGoal(goalId);
    yield* _criteriaChanges.stream.map((_) => getCriteriaForGoal(goalId));
  }

  static Stream<List<Criterion>> watchCriteriaForEmployee(String uid) async* {
    yield getCriteriaForEmployee(uid);
    yield* _criteriaChanges.stream.map((_) => getCriteriaForEmployee(uid));
  }

  // ---------------- CRITERION HISTORY (new, parallel to TASK HISTORY) ----------------
  static Future<void> addCriterionHistoryEntry(
    CriterionHistoryEntry entry,
  ) async {
    await _db
        .collection('criterion_history')
        .doc(entry.historyId)
        .set(entry.toMap());
  }

  static List<CriterionHistoryEntry> getHistoryForCriterion(
    String criterionId,
  ) {
    return _criterionHistoryCache
        .where((h) => h.criterionId == criterionId)
        .toList()
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

  /// UNSCOPED — every message in every conversation, regardless of sender/
  /// recipient. Added specifically for the read-only `designer` role's
  /// "1-a" requirement (read literally everything, chat content included)
  /// — no other existing call site needs this, since every other screen
  /// is scoped to a specific participant's own conversations. Safe to add
  /// with no query cost: `_messagesCache` already holds every message in
  /// memory (see the unfiltered `.collection('messages').snapshots()`
  /// listener in `initSession()` above) — this simply exposes it without
  /// the sender/recipient filter `getLatestMessagesForUser` applies.
  static List<ChatMessage> getAllLatestConversations() {
    final byConversation = <String, ChatMessage>{};
    for (final m in _messagesCache) {
      final existing = byConversation[m.conversationId];
      if (existing == null || m.timestamp.isAfter(existing.timestamp)) {
        byConversation[m.conversationId] = m;
      }
    }
    return byConversation.values.toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  static Stream<List<ChatMessage>> watchAllLatestConversations() async* {
    yield getAllLatestConversations();
    yield* _messagesChanges.stream.map((_) => getAllLatestConversations());
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

  // ---------------- DOCUMENTS (shared library, manager + employee) ----------------
  static Future<void> saveDocument(DocumentItem doc) async {
    await _db.collection('documents').doc(doc.documentId).set(doc.toMap());
  }

  static Future<void> deleteDocument(String documentId) async {
    await _db.collection('documents').doc(documentId).delete();
  }

  static List<DocumentItem> getAllDocuments() {
    return List<DocumentItem>.from(_documentsCache)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Stream<List<DocumentItem>> watchAllDocuments() async* {
    yield getAllDocuments();
    yield* _documentsChanges.stream.map((_) => getAllDocuments());
  }

  // ---------------- MEETINGS (schedule only, no live call integration) ----------------
  static Future<void> saveMeeting(MeetingItem meeting) async {
    await _db
        .collection('meetings')
        .doc(meeting.meetingId)
        .set(meeting.toMap());
  }

  static Future<void> deleteMeeting(String meetingId) async {
    await _db.collection('meetings').doc(meetingId).delete();
  }

  static List<MeetingItem> getAllMeetings() {
    return List<MeetingItem>.from(_meetingsCache)
      ..sort((a, b) => a.startTime.compareTo(b.startTime));
  }

  static Stream<List<MeetingItem>> watchAllMeetings() async* {
    yield getAllMeetings();
    yield* _meetingsChanges.stream.map((_) => getAllMeetings());
  }

  // ---------------- CONTACTS ----------------
  static Future<void> saveContact(ContactItem contact) async {
    await _db
        .collection('contacts')
        .doc(contact.contactId)
        .set(contact.toMap());
  }

  static Future<void> deleteContact(String contactId) async {
    await _db.collection('contacts').doc(contactId).delete();
  }

  static List<ContactItem> getAllContacts() {
    return List<ContactItem>.from(_contactsCache)
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  static Stream<List<ContactItem>> watchAllContacts() async* {
    yield getAllContacts();
    yield* _contactsChanges.stream.map((_) => getAllContacts());
  }

  // ---------------- FAVORITES (per-user starred tasks) ----------------
  static Future<void> saveFavorite(FavoriteTask favorite) async {
    await _db
        .collection('favorites')
        .doc(favorite.favoriteId)
        .set(favorite.toMap());
  }

  static Future<void> removeFavorite(String favoriteId) async {
    await _db.collection('favorites').doc(favoriteId).delete();
  }

  /// Deterministic favoriteId so create/remove is idempotent per
  /// (userUid, taskId) pair without needing a query-then-delete round trip.
  static String favoriteIdFor(String userUid, String taskId) =>
      '${userUid}_$taskId';

  static bool isFavorite(String userUid, String taskId) {
    final id = favoriteIdFor(userUid, taskId);
    return _favoritesCache.any((f) => f.favoriteId == id);
  }

  static List<FavoriteTask> getFavoritesForUser(String userUid) {
    return _favoritesCache.where((f) => f.userUid == userUid).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Stream<List<FavoriteTask>> watchFavoritesForUser(
    String userUid,
  ) async* {
    yield getFavoritesForUser(userUid);
    yield* _favoritesChanges.stream.map((_) => getFavoritesForUser(userUid));
  }
}
