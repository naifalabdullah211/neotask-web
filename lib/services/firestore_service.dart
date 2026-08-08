import 'dart:async';
import 'package:flutter/foundation.dart';
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
import '../models/goal_comment_model.dart';
import '../models/criterion_model.dart';
import '../models/criterion_chat_model.dart';
import '../models/poll_model.dart';
import '../models/poll_vote_model.dart';
import '../models/poll_report_model.dart';
import '../models/notification_model.dart';
import '../models/manager_digest_model.dart';
import '../models/manager_idea_model.dart';

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
  // Goal/Criteria feature — added ALONGSIDE the existing task system.
  // REBUILT (3-level Goal→Criterion→Chat hierarchy — see goal_model.dart /
  // criterion_model.dart / criterion_chat_model.dart doc comments):
  // `_criteriaCache` is now populated via a Firestore COLLECTION-GROUP
  // listener (`collectionGroup('criteria')`), since Criteria are genuine
  // subcollection documents at `goals/{goalId}/criteria/{criteriaId}`, not
  // a single flat top-level collection any more. This lets
  // `getCriteriaForEmployee`/`getAllCriteria` keep working as simple
  // in-memory filters over one unified cache, exactly as before, without
  // requiring N separate per-goal listeners.
  //
  // Criterion CHAT (goals/{goalId}/criteria/{criteriaId}/chat/{messageId})
  // is deliberately NOT cached here at all — unlike every other
  // collection in this service, it is read directly via a per-criterion
  // Firestore stream opened only while that criterion's chat screen is
  // visible (see watchCriterionChat/sendCriterionChatMessage below). This
  // avoids an unbounded global listener across every chat subcollection in
  // the database, and is safe because the chat UI is never used as a
  // "list all conversations" screen the way tasks/messages are.
  static List<Goal> _goalsCache = [];
  static List<Criterion> _criteriaCache = [];
  // Poll feature ("تصويت") — added ALONGSIDE the existing task/goal system.
  // `_pollsCache` is the top-level `polls` collection. Votes are
  // DELIBERATELY NOT cached the same way (see poll_model.dart doc comment
  // on why they are a per-employee-readable subcollection, not a flat
  // cache every signed-in client would need permission to read in full —
  // that would defeat the secrecy requirement). Votes are read directly
  // per-poll via `watchVotesForPoll`/`watchMyVote`, mirroring the
  // Criterion-chat "not globally cached" precedent above.
  static List<AppPoll> _pollsCache = [];
  static List<AppNotification> _notificationsCache = [];

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
  static final _pollsChanges = StreamController<void>.broadcast();
  static final _notificationsChanges = StreamController<void>.broadcast();

  // NOTE: session/identity is now handled entirely by FirebaseAuth
  // (see AuthProvider + FirebaseAuth.instance.authStateChanges()) — this
  // service no longer tracks a locally-cached "currentUid" itself.

  // ---- "manager exists?" signal, readable BEFORE any sign-in ----
  //
  // Under the locked-down Firestore security rules, the `users` collection
  // requires `request.auth != null` to read — but SplashRouter/AuthProvider
  // need to know whether a manager account exists at all *before* anyone is
  // signed in (to decide: show ManagerSetupScreen vs. LoginScreen). This is
  // answered by the tiny public `system/manager_lock` sentinel document.
  // The one-time Spark bootstrap transaction creates it atomically with the
  // manager profile and consumes the hidden setup proof.
  // Fail closed: until Firestore positively confirms that the lock is
  // absent, signed-out users are routed to LoginScreen rather than being
  // offered manager bootstrap.
  static bool _managerLockExists = true;
  static bool get managerLockExists => _managerLockExists;

  static Future<void>? _managerStatusInit;
  static bool _publicInitialized = false;
  static bool _authInitialized = false;
  static final List<StreamSubscription> _authSubscriptions = [];

  /// Reads and watches the public manager sentinel without initializing the
  /// invitation listener. This keeps first-run routing fast while retaining
  /// a fail-closed default if Firestore is unreachable.
  static Future<void> initManagerStatus() {
    return _managerStatusInit ??= _startManagerStatusListener();
  }

  static Future<void> _startManagerStatusListener() async {
    final lockDone = Completer<void>();

    _db
        .collection('system')
        .doc('manager_lock')
        .snapshots()
        .listen(
          (snap) {
            _managerLockExists = snap.exists;
            if (!lockDone.isCompleted) lockDone.complete();
          },
          onError: (Object error, StackTrace stackTrace) {
            if (!lockDone.isCompleted) {
              lockDone.completeError(error, stackTrace);
            }
          },
        );

    await lockDone.future.timeout(const Duration(seconds: 8));
  }

  /// Repairs legacy installations where a valid manager profile predates the
  /// public manager sentinel. The transaction is idempotent and the security
  /// rules require the authenticated caller's existing profile to be an
  /// active manager, so an employee cannot claim or manufacture this lock.
  static Future<void> ensureManagerLockForExistingManager(
    String managerUid,
  ) async {
    final lockRef = _db.collection('system').doc('manager_lock');
    await _db.runTransaction((transaction) async {
      final current = await transaction.get(lockRef);
      if (current.exists) return;
      transaction.set(lockRef, {
        'createdBy': managerUid,
        'createdAt': DateTime.now().toIso8601String(),
      });
    });
    _managerLockExists = true;
  }

  /// Creates the first manager without a paid server runtime.
  ///
  /// Firestore Rules, not this client method, are the security boundary:
  /// they compare [setupProof] with the hidden one-time bootstrap document
  /// and require these three writes to succeed atomically.
  static Future<void> bootstrapManagerOnSpark({
    required String uid,
    required String name,
    required String email,
    required String employeeNumber,
    required String setupProof,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final lockRef = _db.collection('system').doc('manager_lock');
    final bootstrapRef = _db.collection('system').doc('manager_bootstrap');
    final now = DateTime.now().toIso8601String();

    await _db.runTransaction((transaction) async {
      final lock = await transaction.get(lockRef);
      if (lock.exists) {
        throw StateError('Manager already exists');
      }

      transaction.set(userRef, {
        'uid': uid,
        'name': name,
        'email': email,
        'employeeNumber': employeeNumber,
        'role': 'manager',
        'accountStatus': 'active',
        'createdAt': now,
        'soundMessagesEnabled': true,
        'soundTasksEnabled': true,
        'remindersEnabled': true,
        'weeklyCapacityHours': 40,
        'managerWelcomeVersion': 0,
        'bootstrapProof': setupProof,
      });
      transaction.set(lockRef, {
        'createdAt': now,
        'createdBy': uid,
      });
      transaction.delete(bootstrapRef);
    });
    _managerLockExists = true;
  }

  /// Removes the consumed capability digest from the manager profile after
  /// the atomic bootstrap transaction. The matching Firestore rule permits
  /// only this single-field deletion by that manager.
  static Future<void> clearManagerBootstrapProof(String uid) async {
    await _db.collection('users').doc(uid).update({
      'bootstrapProof': FieldValue.delete(),
    });
  }

  /// Sets up ONLY the listeners that are safe to run before any user is
  /// signed in (per the security rules: `system/manager_lock` and
  /// `invitations` are both public-read — see firestore.rules). Call this
  /// once at app startup, before FirebaseAuth's session is even checked.
  static Future<void> initPublic() async {
    if (_publicInitialized) return;

    final invitationsDone = Completer<void>();

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
      initManagerStatus(),
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
    final pollsDone = Completer<void>();
    final notificationsDone = Completer<void>();

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

    // Criteria are now genuine Firestore SUBCOLLECTION documents at
    // `goals/{goalId}/criteria/{criteriaId}` (see criterion_model.dart doc
    // comment) rather than a single flat top-level collection. A
    // `collectionGroup('criteria')` query is the correct Firestore
    // mechanism to listen to every criterion document across every goal
    // at once, regardless of which goal it's nested under — required so
    // `getCriteriaForEmployee(uid)` can still scan one unified in-memory
    // cache exactly as before.
    _authSubscriptions.add(
      _db
          .collectionGroup('criteria')
          .snapshots()
          .listen(
            (snap) {
              _criteriaCache = snap.docs
                  .map((d) => Criterion.fromMap(d.data()))
                  .toList();
              if (!criteriaDone.isCompleted) criteriaDone.complete();
              _criteriaChanges.add(null);
            },
            onError: (Object error) {
              // CRITICAL: previously this handler silently discarded the
              // error with no logging — if this collectionGroup query was
              // ever rejected by Firestore Security Rules (as it genuinely
              // WAS until the top-level `match /{path=**}/criteria/{..}`
              // rule was added — see firestore.rules), `_criteriaCache`
              // would permanently stay empty with ZERO indication to the
              // developer or user that anything had failed. Now logged
              // loudly in debug builds so a future rules regression is
              // immediately visible instead of silently invisible.
              if (kDebugMode) {
                debugPrint(
                  'FirestoreService: collectionGroup("criteria") listener '
                  'error — criteria will NOT load. This usually means '
                  'Firestore Security Rules are rejecting the query '
                  '(check for a top-level `match /{path=**}/criteria/{id}` '
                  'rule). Error: $error',
                );
              }
              if (!criteriaDone.isCompleted) criteriaDone.complete();
            },
          ),
    );

    // ---- polls (top-level; votes deliberately NOT cached here — see
    //      poll_model.dart doc comment) ----
    _authSubscriptions.add(
      _db
          .collection('polls')
          .snapshots()
          .listen(
            (snap) {
              _pollsCache = snap.docs
                  .map((d) => AppPoll.fromMap(d.data()))
                  .toList();
              if (!pollsDone.isCompleted) pollsDone.complete();
              _pollsChanges.add(null);
            },
            onError: (_) {
              if (!pollsDone.isCompleted) pollsDone.complete();
            },
          ),
    );

    // ---- notifications (top-level; every signed-in user's own
    //      notifications are filtered client-side by `recipientUid` — same
    //      unfiltered-listen + client-side-filter pattern as every other
    //      collection in this service, see the class-level security-rules
    //      doc comment) ----
    _authSubscriptions.add(
      _db
          .collection('notifications')
          .snapshots()
          .listen(
            (snap) {
              _notificationsCache = snap.docs
                  .map((d) => AppNotification.fromMap(d.data()))
                  .toList();
              if (!notificationsDone.isCompleted) {
                notificationsDone.complete();
              }
              _notificationsChanges.add(null);
            },
            onError: (_) {
              if (!notificationsDone.isCompleted) {
                notificationsDone.complete();
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
      pollsDone.future,
      notificationsDone.future,
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
    _pollsCache = [];
    _notificationsCache = [];
    _authInitialized = false;
  }

  // ---------------- MANAGER IDEAS ----------------

  /// Ideas are intentionally streamed directly instead of joining the
  /// global cache: only the manager and the read-only observer open this
  /// small, dedicated surface.
  static Stream<List<ManagerIdea>> watchManagerIdeas() {
    return _db
        .collection('manager_ideas')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ManagerIdea.fromMap(doc.data()))
              .toList(),
        );
  }

  static Future<void> addManagerIdea({
    required String content,
    required AppUser manager,
  }) async {
    final document = _db.collection('manager_ideas').doc();
    final idea = ManagerIdea(
      ideaId: document.id,
      content: content.trim(),
      authorUid: manager.uid,
      authorName: manager.name,
      createdAt: DateTime.now(),
    );
    await document.set(idea.toMap());
  }

  static Future<void> deleteManagerIdea(String ideaId) async {
    await _db.collection('manager_ideas').doc(ideaId).delete();
  }

  /// Stores a manager-approved instruction that is supplied to the AI agent
  /// on later requests. These rules are intentionally separate from the
  /// human-readable action history so deleting a history row cannot silently
  /// change the agent's behaviour.
  static Future<void> addManagerAgentRule({
    required String instruction,
    required AppUser manager,
  }) async {
    final normalized = instruction.trim();
    if (normalized.length < 3 || normalized.length > 500) {
      throw ArgumentError('تعليمات الوكيل غير صالحة');
    }
    final document = _db.collection('manager_agent_rules').doc();
    await document.set({
      'ruleId': document.id,
      'instruction': normalized,
      'createdBy': manager.uid,
      'createdByName': manager.name,
      'createdAt': FieldValue.serverTimestamp(),
      'active': true,
    });
  }

  static Future<List<String>> loadManagerAgentRules() async {
    final snapshot = await _db
        .collection('manager_agent_rules')
        .where('active', isEqualTo: true)
        .limit(20)
        .get();
    return snapshot.docs
        .map((document) => document.data()['instruction']?.toString().trim() ?? '')
        .where((instruction) => instruction.isNotEmpty)
        .toList(growable: false);
  }

  // ---------------- USERS ----------------
  static Future<void> saveUser(AppUser user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
  }

  /// Persists only the one-time manager welcome acknowledgement. A partial
  /// update avoids rewriting profile, role, approval, or preference fields.
  static Future<void> updateManagerWelcomeVersion(
    String managerUid,
    int version,
  ) async {
    await _db.collection('users').doc(managerUid).update({
      'managerWelcomeVersion': version,
    });
  }

  /// Appends an audit entry to `password_change_audit` (Part 1 — manager-
  /// driven password reset). Append-only, admin-internal log: WHO changed
  /// the password, FOR WHOM, and WHEN. The password value itself is NEVER
  /// passed to or stored by this method. Not cached/streamed anywhere in
  /// this service — it is a write-only audit trail, not app-facing data.
  static Future<void> logPasswordChange({
    required String changedByUid,
    required String changedByName,
    required String changedForUid,
    required String changedForName,
  }) async {
    await _db.collection('password_change_audit').add({
      'changedByUid': changedByUid,
      'changedByName': changedByName,
      'changedForUid': changedForUid,
      'changedForName': changedForName,
      'timestamp': FieldValue.serverTimestamp(),
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
    return _usersCache
        .where((u) => u.role == UserRole.employee && !u.hasManagerAccess)
        .toList();
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

  /// All accounts with `role == manager`. The app currently enforces a
  /// single-manager invariant at signup time (see `system/manager_lock`
  /// sentinel in firestore.rules), so today this returns at most one
  /// entry — implemented as a list regardless (rather than reusing
  /// [getManager] alone) so the automatic-reminders feature's "notify
  /// everyone with 'مدير' privilege" requirement is correct-by-construction
  /// even if that invariant is ever relaxed in the future.
  static List<AppUser> getAllManagers() {
    return _usersCache.where((u) => u.hasManagerAccess).toList();
  }

  static Stream<List<AppUser>> watchEmployees() async* {
    yield getAllEmployees();
    yield* _usersChanges.stream.map((_) => getAllEmployees());
  }

  // ---------------- TASKS ----------------
  static Future<void> saveTask(AppTask task) async {
    await _db.collection('tasks').doc(task.taskId).set(task.toMap());
  }

  /// Field-level task update used by employee actions. Keeping these writes
  /// partial prevents an old task document from being silently migrated with
  /// manager-only planning fields during an unrelated employee status change.
  static Future<void> updateTaskFields(
    String taskId,
    Map<String, dynamic> fields,
  ) async {
    await _db.collection('tasks').doc(taskId).update(fields);
  }

  /// Manager-configured weekly capacity used by the workload planner.
  /// Kept as a field-level update so no unrelated profile field is rewritten.
  static Future<void> updateEmployeeWeeklyCapacity(
    String employeeUid,
    double weeklyCapacityHours,
  ) async {
    await _db.collection('users').doc(employeeUid).update({
      'weeklyCapacityHours': weeklyCapacityHours,
    });
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

  /// Automatic reminders feature — sets the one-way `remindedAt` guard so
  /// the "due within 24h" employee reminder is never dispatched twice for
  /// the same task. See firestore.rules `tasks/{taskId}` update rule's
  /// dedicated branch for this exact field-pair write.
  static Future<void> markTaskReminded(String taskId) async {
    await _db.collection('tasks').doc(taskId).update({
      'remindedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Automatic reminders feature — sets the one-way `overdueNotifiedAt`
  /// guard so the "task became overdue" manager notification is never
  /// dispatched twice for the same task.
  static Future<void> markTaskOverdueNotified(String taskId) async {
    await _db.collection('tasks').doc(taskId).update({
      'overdueNotifiedAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });
  }

  /// Atomically appends one [ActivityLogEntry] to a task's `activityLog`
  /// array field, via `FieldValue.arrayUnion` — this is a raw single-field
  /// `.update()`, NOT a full-document `.set()` via [saveTask], specifically
  /// so the append is safe under concurrent writes (two clients appending
  /// at nearly the same moment both land, instead of one read-modify-write
  /// silently clobbering the other's entry). Allowed by the employee at
  /// ANY task status per the Part-2 requirement — see the `tasks/{taskId}`
  /// update rule's normal-lifecycle employee branch in firestore.rules,
  /// which allows `activityLog` in its `hasOnly()` field allowlist
  /// unconditionally (not gated on `status`).
  static Future<void> appendTaskActivityLogEntry(
    String taskId,
    ActivityLogEntry entry,
  ) async {
    await _db.collection('tasks').doc(taskId).update({
      'activityLog': FieldValue.arrayUnion([entry.toMap()]),
      'updatedAt': DateTime.now().toIso8601String(),
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

  /// Reads one invitation directly from Firestore instead of relying only
  /// on the public listener cache. This closes the short synchronization
  /// window immediately after a manager creates and shares a link, where a
  /// newly opened browser could render before its first cache snapshot.
  static Future<Invitation?> getInvitationByTokenFresh(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) return null;
    try {
      final query = await _db
          .collection('invitations')
          .where('token', isEqualTo: normalized)
          .limit(1)
          .get(const GetOptions(source: Source.server));
      if (query.docs.isEmpty) return null;
      return Invitation.fromMap(query.docs.first.data());
    } catch (_) {
      // The live cache remains a safe fallback for transient connectivity
      // failures after initPublic has already completed.
      return getInvitationByToken(normalized);
    }
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

  // ---------------- GOALS (3-level Goal→Criterion→Chat hierarchy, see
  //      goal_model.dart) ----------------
  static Future<void> saveGoal(Goal goal) async {
    await _db.collection('goals').doc(goal.goalId).set(goal.toMap());
  }

  /// Deletes [goalId] AND cascades to every Criterion subcollection
  /// document under it, AND every chat message subcollection document
  /// under each of those criteria. Firestore does NOT cascade-delete
  /// subcollections automatically when a parent document is deleted — an
  /// orphaned `goals/{goalId}/criteria/*` subtree would otherwise remain
  /// permanently inaccessible (no rule allows reading a criteria
  /// subcollection of a nonexistent goal via the app's normal navigation,
  /// but the documents/storage would still exist).
  static Future<void> deleteGoal(String goalId) async {
    final criteriaSnap = await _db
        .collection('goals')
        .doc(goalId)
        .collection('criteria')
        .get();
    for (final c in criteriaSnap.docs) {
      final chatSnap = await c.reference.collection('chat').get();
      for (final m in chatSnap.docs) {
        await m.reference.delete();
      }
      await c.reference.delete();
    }
    await _db.collection('goals').doc(goalId).delete();
  }

  /// Atomically appends a goal-level comment (see GoalComment doc comment
  /// on why `comments` doubles as this Goal's only event/history log) —
  /// mirrors [appendTaskActivityLogEntry]'s `FieldValue.arrayUnion`
  /// pattern so concurrent commenters never race a read-modify-write.
  static Future<void> appendGoalComment(
    String goalId,
    GoalComment comment,
  ) async {
    await _db.collection('goals').doc(goalId).update({
      'comments': FieldValue.arrayUnion([comment.toMap()]),
      'updatedAt': DateTime.now().toIso8601String(),
    });
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

  // ---------------- CRITERIA (genuine Firestore SUBCOLLECTION of a Goal,
  //      see criterion_model.dart — `goals/{goalId}/criteria/{criteriaId}`,
  //      NOT a flat top-level collection any more) ----------------
  static Future<void> saveCriterion(Criterion criterion) async {
    await _db
        .collection('goals')
        .doc(criterion.goalId)
        .collection('criteria')
        .doc(criterion.criterionId)
        .set(criterion.toMap());
  }

  /// Writes ONLY [employeeUid]'s own entry inside the `employeeStatuses`
  /// map, via a dotted-field update (`employeeStatuses.<uid>`) — this is
  /// what lets firestore.rules validate that a given write touched EXACTLY
  /// one map key, and that key equals the writer's own uid (see
  /// firestore.rules' criteria `allow update` employee branch), and it is
  /// also what makes two employees updating their own status concurrently
  /// non-racing (each write only ever touches its own dotted-field path,
  /// never the whole map).
  static Future<void> updateCriterionEmployeeStatus(
    String goalId,
    String criterionId,
    String employeeUid,
    CriterionStatus status,
  ) async {
    await _db
        .collection('goals')
        .doc(goalId)
        .collection('criteria')
        .doc(criterionId)
        .update({
          'employeeStatuses.$employeeUid': status.name,
          'updatedAt': DateTime.now().toIso8601String(),
        });
  }

  /// Deletes a Criterion AND cascades to every chat message document under
  /// its `chat` subcollection (see [deleteGoal] doc comment — same
  /// orphaned-subcollection concern applies at this level too).
  static Future<void> deleteCriterion(String goalId, String criterionId) async {
    final criterionRef = _db
        .collection('goals')
        .doc(goalId)
        .collection('criteria')
        .doc(criterionId);
    final chatSnap = await criterionRef.collection('chat').get();
    for (final m in chatSnap.docs) {
      await m.reference.delete();
    }
    await criterionRef.delete();
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
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Criteria can have MULTIPLE assignees — hence list-membership
  /// (`contains`), never `==` equality like the single-assignee
  /// `AppTask.assignedTo` check in `getTasksForEmployee`. This is what
  /// makes "an employee sees ONLY the criteria assigned to them" work,
  /// regardless of which Goal each matching criterion happens to live
  /// under (the underlying cache is populated via a collectionGroup
  /// listener — see initAuthenticated — so this scans across ALL goals).
  static List<Criterion> getCriteriaForEmployee(String uid) {
    return _criteriaCache.where((c) => c.assignees.contains(uid)).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
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

  // ---------------- CRITERION CHAT (genuine Firestore SUBCOLLECTION of a
  //      Criterion — `goals/{goalId}/criteria/{criteriaId}/chat/{messageId}`,
  //      see criterion_chat_model.dart doc comment for why this is a
  //      WHOLLY SEPARATE system from `messages`/ChatMessage) ----------------
  //
  // Deliberately NOT cached in the usual `_xCache` pattern (see the class-
  // level doc comment above `_goalsCache`) — reads/writes here always go
  // straight to Firestore, scoped to a single criterionId's chat screen.
  static CollectionReference<Map<String, dynamic>> _criterionChatRef(
    String goalId,
    String criterionId,
  ) {
    return _db
        .collection('goals')
        .doc(goalId)
        .collection('criteria')
        .doc(criterionId)
        .collection('chat');
  }

  static Future<void> sendCriterionChatMessage({
    required String goalId,
    required String criterionId,
    required CriterionChatMessage message,
  }) async {
    await _criterionChatRef(
      goalId,
      criterionId,
    ).doc(message.messageId).set(message.toMap());
  }

  static Stream<List<CriterionChatMessage>> watchCriterionChat({
    required String goalId,
    required String criterionId,
  }) {
    return _criterionChatRef(goalId, criterionId)
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => CriterionChatMessage.fromMap(d.id, d.data()))
              .toList(),
        );
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

  static Future<void> saveDocumentWithRevision(
    DocumentItem document,
    DocumentRevision revision,
  ) async {
    final documentRef = _db.collection('documents').doc(document.documentId);
    final revisionRef = documentRef
        .collection('versions')
        .doc(revision.revisionId);
    final batch = _db.batch();
    batch.set(documentRef, document.toMap());
    batch.set(revisionRef, revision.toMap());
    await batch.commit();
  }

  static Stream<List<DocumentRevision>> watchDocumentRevisions(
    String documentId,
  ) {
    return _db
        .collection('documents')
        .doc(documentId)
        .collection('versions')
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => DocumentRevision.fromMap(doc.data()))
              .toList();
          items.sort((a, b) => b.version.compareTo(a.version));
          return items;
        });
  }

  static Future<void> saveDocumentComment(DocumentComment comment) async {
    await _db
        .collection('documents')
        .doc(comment.documentId)
        .collection('comments')
        .doc(comment.commentId)
        .set(comment.toMap());
  }

  static Stream<List<DocumentComment>> watchDocumentComments(
    String documentId,
  ) {
    return _db
        .collection('documents')
        .doc(documentId)
        .collection('comments')
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => DocumentComment.fromMap(doc.data()))
              .toList();
          items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
          return items;
        });
  }

  static Future<void> deleteDocument(String documentId) async {
    final ref = _db.collection('documents').doc(documentId);
    final snapshots = await Future.wait([
      ref.collection('versions').get(),
      ref.collection('comments').get(),
    ]);
    final batch = _db.batch();
    for (final snapshot in snapshots) {
      for (final child in snapshot.docs) {
        batch.delete(child.reference);
      }
    }
    batch.delete(ref);
    await batch.commit();
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

  // ---------------- POLLS ("تصويت") ----------------
  static Future<void> savePoll(AppPoll poll) async {
    await _db.collection('polls').doc(poll.pollId).set(poll.toMap());
  }

  /// Manager edit of an ACTIVE (or draft) poll — title/description/
  /// deadline/eligible-employees/choices, per the editing requirement.
  /// [resetVotes], when true, ALSO deletes every existing vote document
  /// (used when the manager confirms "changing choices after votes exist
  /// requires an explicit reset") — done as a best-effort batch delete
  /// rather than inside the same call as the poll field update, since
  /// Firestore has no cross-collection atomic "update doc + wipe
  /// subcollection" primitive; the poll update itself remains a single
  /// atomic write regardless.
  static Future<void> updatePoll(
    String pollId,
    Map<String, dynamic> fields, {
    bool resetVotes = false,
  }) async {
    if (resetVotes) {
      await _deleteAllVotes(pollId);
    }
    await _db.collection('polls').doc(pollId).update(fields);
  }

  static Future<void> _deleteAllVotes(String pollId) async {
    final snap = await _pollVotesRef(pollId).get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    if (snap.docs.isNotEmpty) await batch.commit();
  }

  static Future<void> cancelPoll(String pollId, String managerUid) async {
    await _db.collection('polls').doc(pollId).update({
      'status': PollStatus.cancelled.name,
      'cancelledBy': managerUid,
      'cancelledAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> deletePoll(String pollId) async {
    await _db.collection('polls').doc(pollId).delete();
  }

  static AppPoll? getPoll(String pollId) {
    for (final p in _pollsCache) {
      if (p.pollId == pollId) return p;
    }
    return null;
  }

  static List<AppPoll> getAllPolls() => List.unmodifiable(_pollsCache);

  /// Polls where [employeeUid] is a selected participant — used by the
  /// employee-side "تصويت" tab. Simple `.contains()` filter over the
  /// already-live cache (no composite Firestore index needed — mirrors
  /// `getCriteriaForEmployee`'s list-membership pattern). Draft polls are
  /// EXCLUDED here — an employee must never see a poll the manager has
  /// not yet published (see PollStatus.draft doc comment).
  static List<AppPoll> getPollsForEmployee(String employeeUid) {
    return _pollsCache
        .where(
          (p) =>
              p.participantUids.contains(employeeUid) &&
              p.status != PollStatus.draft,
        )
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static Stream<List<AppPoll>> watchAllPolls() async* {
    yield getAllPolls();
    yield* _pollsChanges.stream.map((_) => getAllPolls());
  }

  static Stream<List<AppPoll>> watchPollsForEmployee(
    String employeeUid,
  ) async* {
    yield getPollsForEmployee(employeeUid);
    yield* _pollsChanges.stream.map((_) => getPollsForEmployee(employeeUid));
  }

  // ---------------- POLL VOTES (subcollection `polls/{pollId}/votes`,
  //      deliberately NOT globally cached — see poll_model.dart doc
  //      comment on why full-vote visibility must be scoped per-poll and
  //      per-role rather than a single flat client-side cache every
  //      signed-in user could read from) ----------------
  static CollectionReference<Map<String, dynamic>> _pollVotesRef(
    String pollId,
  ) {
    return _db.collection('polls').doc(pollId).collection('votes');
  }

  /// Casts OR changes [employeeUid]'s vote on [pollId] — a plain `.set()`
  /// upsert keyed by the deterministic employeeUid document ID, so
  /// "change my vote" never needs a query-then-update round trip (mirrors
  /// `favoriteIdFor`'s deterministic-ID rationale). Deadline/status
  /// enforcement (no voting after close) is done by the CALLER
  /// (PollProvider.castVote) checking the live poll before calling this,
  /// AND independently by the Firestore security rule (see firestore.rules
  /// `polls/{pollId}/votes/{uid}` create/update rule, which re-checks
  /// `resource.data.deadline`/`status` server-side so a stale client can
  /// never bypass the deadline by racing a local check).
  static Future<void> castOrChangeVote(String pollId, PollVote vote) async {
    await _pollVotesRef(pollId).doc(vote.employeeUid).set(vote.toMap());
  }

  /// One-time read of every vote on [pollId] — used ONLY by the manager's
  /// live poll-detail view and by the auto-close result computation, both
  /// of which need the FULL set of votes at a point in time rather than a
  /// live per-vote stream. A `.snapshots()` stream variant
  /// ([watchVotesForPoll]) is provided separately for the manager's
  /// "live while open" detail screen.
  static Future<List<PollVote>> getVotesForPoll(String pollId) async {
    final snap = await _pollVotesRef(pollId).get();
    return snap.docs.map((d) => PollVote.fromMap(d.data())).toList();
  }

  /// Live stream of every vote on [pollId] — manager-only in practice
  /// (see firestore.rules: only the poll's `createdBy` manager may list
  /// this subcollection in full; an employee's read is restricted to
  /// their OWN vote document only, via [watchMyVote] below).
  static Stream<List<PollVote>> watchVotesForPoll(String pollId) {
    return _pollVotesRef(pollId).snapshots().map(
      (snap) => snap.docs.map((d) => PollVote.fromMap(d.data())).toList(),
    );
  }

  /// A single employee's own vote on [pollId] — this is the ONLY vote
  /// read path available to a participating employee (enforced by the
  /// security rule restricting `get`/`list` on this subcollection to
  /// `request.auth.uid == voteDocId` for non-managers), which is precisely
  /// what makes "the employee never sees anyone else's vote" hold even
  /// though the app has no separate backend server.
  static Stream<PollVote?> watchMyVote(String pollId, String employeeUid) {
    return _pollVotesRef(pollId)
        .doc(employeeUid)
        .snapshots()
        .map((snap) => snap.exists ? PollVote.fromMap(snap.data()!) : null);
  }

  /// Atomically ends [pollId] and creates its permanent [PollReport] in a
  /// SINGLE Firestore transaction — this is the exactly-once guarantee
  /// behind the whole auto-close/report pipeline (see poll_model.dart's
  /// AUTO-CLOSE ARCHITECTURE note): the transaction reads
  /// `polls/{pollId}.reportGenerated` first; if it is already `true`
  /// (another client won the race), the transaction is a no-op and
  /// returns `false`. Otherwise it writes BOTH the poll's ending fields
  /// (`status: ended`, `reportGenerated: true`, aggregate result fields)
  /// AND the `poll_reports/{pollId}` document in the same atomic
  /// operation, then returns `true` so the CALLER (PollProvider) knows it
  /// is the one that should also send the manager's "انتهى التصويت"
  /// notification (a notification write cannot itself be inside this
  /// Firestore transaction as a hard requirement, but gating it on this
  /// transaction's `true` return value means it is still sent exactly
  /// once — a client that loses the race gets `false` and sends nothing).
  static Future<bool> endPollAndGenerateReport({
    required AppPoll poll,
    required PollReport report,
  }) async {
    final pollRef = _db.collection('polls').doc(poll.pollId);
    final reportRef = _db.collection('poll_reports').doc(poll.pollId);
    return _db.runTransaction<bool>((tx) async {
      final freshSnap = await tx.get(pollRef);
      final alreadyGenerated =
          (freshSnap.data()?['reportGenerated'] as bool?) ?? false;
      if (alreadyGenerated) return false;

      tx.update(pollRef, {
        'status': PollStatus.ended.name,
        'reportGenerated': true,
        'endedAt': DateTime.now().toIso8601String(),
        'choiceCounts': report.choiceCounts,
        'winningChoiceIndex': report.winningChoiceIndex,
        'isTie': report.isTie,
        'tiedChoiceIndexes': report.tiedChoiceIndexes,
      });
      tx.set(reportRef, report.toMap());
      return true;
    });
  }

  static Future<PollReport?> getPollReport(String pollId) async {
    final snap = await _db.collection('poll_reports').doc(pollId).get();
    if (!snap.exists) return null;
    return PollReport.fromMap(snap.data()!);
  }

  static Stream<PollReport?> watchPollReport(String pollId) {
    return _db
        .collection('poll_reports')
        .doc(pollId)
        .snapshots()
        .map((snap) => snap.exists ? PollReport.fromMap(snap.data()!) : null);
  }

  /// Applies the manager's manual decision on a tied poll — the ONLY
  /// write allowed to change the winning choice on an ALREADY-ended poll
  /// (per requirement #3's tie-handling clause, carried over from the
  /// original binary design). `status` remains `ended` throughout; only
  /// the poll's `winningChoiceIndex`/`isTie`/`managerDecisionBy`/
  /// `managerDecisionAt` change, and the permanent [PollReport] document
  /// is separately updated to keep both records consistent (the report is
  /// the "permanent for every ended topic" artifact per requirement #6,
  /// so it must reflect the final, manager-resolved winner too).
  static Future<void> applyManagerTieDecision({
    required String pollId,
    required int decisionChoiceIndex,
    required String managerUid,
  }) async {
    await _db.collection('polls').doc(pollId).update({
      'winningChoiceIndex': decisionChoiceIndex,
      'isTie': false,
      'managerDecisionBy': managerUid,
      'managerDecisionAt': DateTime.now().toIso8601String(),
    });
    await _db.collection('poll_reports').doc(pollId).update({
      'winningChoiceIndex': decisionChoiceIndex,
      'isTie': false,
    });
  }

  /// "حث الموظفين على التصويت" — persists the cooldown timestamp on the
  /// poll document; the actual per-employee reminder notifications are
  /// written by the caller (PollProvider.remindNotYetVoted) via
  /// [saveNotification], one per not-yet-voted eligible employee.
  static Future<void> recordReminderSent(String pollId) async {
    await _db.collection('polls').doc(pollId).update({
      'lastReminderSentAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> updatePollAdminNotes(String pollId, String notes) async {
    await _db.collection('polls').doc(pollId).update({'adminNotes': notes});
  }

  // ---------------- NOTIFICATIONS (NEW system — see notification_model.dart
  //      doc comment for why this did not previously exist in this
  //      codebase and is being introduced specifically for the Poll
  //      feature's §3 requirement) ----------------
  static Future<void> saveNotification(AppNotification notif) async {
    await _db
        .collection('notifications')
        .doc(notif.notificationId)
        .set(notif.toMap());
  }

  static List<AppNotification> getNotificationsForUser(String uid) {
    return _notificationsCache.where((n) => n.recipientUid == uid).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  static int getUnreadNotificationCountForUser(String uid) {
    return _notificationsCache
        .where((n) => n.recipientUid == uid && n.readAt == null)
        .length;
  }

  static Stream<List<AppNotification>> watchNotificationsForUser(
    String uid,
  ) async* {
    yield getNotificationsForUser(uid);
    yield* _notificationsChanges.stream.map(
      (_) => getNotificationsForUser(uid),
    );
  }

  static Stream<int> watchUnreadNotificationCountForUser(String uid) async* {
    yield getUnreadNotificationCountForUser(uid);
    yield* _notificationsChanges.stream.map(
      (_) => getUnreadNotificationCountForUser(uid),
    );
  }

  static Future<void> markNotificationRead(String notificationId) async {
    await _db.collection('notifications').doc(notificationId).update({
      'readAt': DateTime.now().toIso8601String(),
    });
  }

  // ---------------- MANAGER DAILY/WEEKLY DIGEST ("ملخص المدير") — NEW.
  //      Deliberately NOT added to the global-cache pattern used by every
  //      other collection in this service (users/tasks/goals/etc.) — a
  //      digest is read exactly once per dashboard-open (existence check +
  //      today's doc fetch), not via a live list UI, so a dedicated
  //      one-shot get + a single doc stream (for the card itself) are
  //      simpler and avoid an unbounded global listener for a collection
  //      that will accumulate one document per manager per day forever. ----

  /// Direct, one-shot existence+fetch of today's digest for [managerUid] —
  /// used by DigestProvider's lazy "already generated?" check. Returns
  /// null if no digest exists yet for [dateKey].
  static Future<ManagerDigest?> getDigest(
    String managerUid,
    String dateKey,
  ) async {
    final id = '${managerUid}_$dateKey';
    final snap = await _db.collection('manager_digests').doc(id).get();
    if (!snap.exists) return null;
    return ManagerDigest.fromMap(snap.data()!);
  }

  /// Persists a freshly-computed digest. Per the model's doc comment, this
  /// document is never updated afterward — deterministic ID
  /// (`managerUid_dateKey`) means a second call for the same day simply
  /// overwrites, but DigestProvider's lazy check prevents that from ever
  /// happening in normal operation.
  static Future<void> saveDigest(ManagerDigest digest) async {
    await _db.collection('manager_digests').doc(digest.id).set(digest.toMap());
  }

  /// Live stream of today's digest document (used by the dashboard card so
  /// it appears the instant DigestProvider finishes generating/saving it,
  /// without requiring a manual refresh).
  static Stream<ManagerDigest?> watchDigest(String managerUid, String dateKey) {
    final id = '${managerUid}_$dateKey';
    return _db.collection('manager_digests').doc(id).snapshots().map((snap) {
      if (!snap.exists) return null;
      return ManagerDigest.fromMap(snap.data()!);
    });
  }

  /// Historical digests for [managerUid], newest first — feeds a future
  /// "تصفح الملخصات السابقة" browsing screen (per the explicit persistence
  /// requirement). Capped at 60 (~2 months of daily digests) to bound the
  /// read size.
  static Future<List<ManagerDigest>> getDigestHistory(String managerUid) async {
    final snap = await _db
        .collection('manager_digests')
        .where('managerUid', isEqualTo: managerUid)
        .get();
    final digests = snap.docs
        .map((d) => ManagerDigest.fromMap(d.data()))
        .toList();
    // Sorted in memory (NOT via .orderBy()) — deliberately avoids requiring
    // a composite Firestore index, per this project's established
    // "simple where() + sort in memory" query pattern (see doc comment on
    // Firestore query best practices elsewhere in this codebase).
    digests.sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return digests.take(60).toList();
  }
}
