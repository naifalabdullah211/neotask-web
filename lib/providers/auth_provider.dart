import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/invitation_model.dart';
import '../services/firestore_service.dart';

/// AuthProvider — backed by real Firebase Authentication (email/password
/// UNDER THE HOOD ONLY). Per explicit product requirement, the app never
/// collects or shows a real email address anywhere: every account signs in
/// with الرقم الوظيفي (employee number) + الرقم السري (password). Firebase
/// Auth's email/password provider still requires an email-shaped
/// identifier internally, so every account's Auth "email" is a
/// deterministic SYNTHETIC value derived from its employeeNumber (see
/// [_syntheticEmail]) — never a real address, never entered/seen by a
/// human. Employee-number uniqueness is enforced for free by Firebase
/// Auth's own email-uniqueness constraint on that synthetic value.
///
/// SECURITY NOTE: passwords are not stored or compared in Firestore.
/// `FirebaseAuth.instance` owns credential storage/verification entirely;
/// the Firestore `users` document (`AppUser`) holds ONLY non-secret profile
/// fields (name, email [synthetic], employeeNumber, role, accountStatus,
/// ...), keyed by the Firebase Auth `uid`.
class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;
  String? _authError;
  bool _isLoading = false;

  final fb_auth.FirebaseAuth _fbAuth = fb_auth.FirebaseAuth.instance;

  AppUser? get currentUser => _currentUser;
  String? get authError => _authError;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  bool get isManager => _currentUser?.hasManagerAccess ?? false;
  bool get isEmployee => _currentUser?.role == UserRole.employee && !isManager;
  // Read-only observer role — see UserRole.designer doc comment
  // (user_model.dart) for the full 1-a/2-a/3-no design rationale.
  bool get isDesigner => _currentUser?.role == UserRole.designer && !isManager;

  static const _uuid = Uuid();

  /// Deterministic synthetic Firebase-Auth email for a given employee
  /// number. NEVER shown to a user, NEVER collected as real contact info —
  /// purely an internal identifier so Firebase Auth's email/password
  /// provider can be reused without asking anyone for an email address.
  /// Sanitization strips everything except letters/digits and lower-cases,
  /// so employee numbers containing spaces/dashes still produce a valid
  /// email local-part; this also means two employee numbers that differ
  /// only by such formatting collide on purpose (both are "the same"
  /// number for login purposes).
  static String _syntheticEmail(String employeeNumber) {
    final cleaned = employeeNumber.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return '$cleaned@neotask.local';
  }

  /// Restores the session from Firebase Auth's own persisted state (it keeps
  /// the user signed in across reloads on Web/Android by itself — no manual
  /// SharedPreferences caching is needed anymore).
  Future<void> restoreSession() async {
    // On Web, especially iOS Safari, Firebase Auth may still be hydrating its
    // IndexedDB-backed session when this provider is created. Waiting for the
    // first auth-state event avoids incorrectly treating that short window as
    // a signed-out session. SplashRouter applies the UI timeout, so this work
    // may safely finish in the background on a slow connection.
    final fbUser = await _fbAuth.authStateChanges().first;
    if (fbUser == null) {
      _currentUser = null;
      notifyListeners();
      return;
    }

    // The `users`/`tasks`/`messages`/... listeners require an authenticated
    // session under the security rules — must be started (and awaited for
    // their first snapshot) before any synchronous cache read below.
    await FirestoreService.initAuthenticated();

    final user = FirestoreService.getUser(fbUser.uid);
    // A previously-active session must not be honored if the manager has
    // since soft-deleted this account — force it back to the login screen.
    if (user == null || user.accountStatus == AccountStatus.deleted) {
      await _fbAuth.signOut();
      await FirestoreService.resetAuthenticatedState();
      _currentUser = null;
    } else {
      _currentUser = user;
      await _repairMissingManagerLock(user);
    }
    notifyListeners();
  }

  /// Bootstraps the single manager account on Firebase's no-cost Spark plan.
  ///
  /// The plaintext setup key is hashed locally and never persisted. Firestore
  /// Rules compare the digest with a hidden, one-time bootstrap document and
  /// require one atomic transaction to create the manager profile + lock and
  /// consume that document. This preserves the one-time setup experience
  /// without Cloud Functions or Secret Manager.
  Future<bool> ensureManagerExists({
    required String setupKey,
    required String name,
    required String employeeNumber,
    String password = '',
  }) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    if (FirestoreService.managerLockExists) {
      _authError = 'تم إنشاء حساب المدير بالفعل من جهاز آخر';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    fb_auth.UserCredential? credential;
    var bootstrapCommitted = false;
    try {
      final normalizedName = name.trim();
      final normalizedEmployeeNumber = employeeNumber.trim();
      if (normalizedName.length < 2 || normalizedName.length > 120 ||
          !RegExp(r'^[A-Za-z0-9\- ]{1,40}$').hasMatch(normalizedEmployeeNumber) ||
          password.length < 6 || password.length > 128) {
        _authError = 'بيانات المدير غير صالحة';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final email = _syntheticEmail(normalizedEmployeeNumber);
      final setupProof = sha256.convert(utf8.encode(setupKey)).toString();
      credential = await _fbAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      await FirestoreService.bootstrapManagerOnSpark(
        uid: credential.user!.uid,
        name: normalizedName,
        email: email,
        employeeNumber: normalizedEmployeeNumber,
        setupProof: setupProof,
      );
      bootstrapCommitted = true;
      try {
        await FirestoreService.clearManagerBootstrapProof(
          credential.user!.uid,
        );
      } catch (error) {
        // The proof has already been consumed and is unusable. Cleanup is
        // privacy hygiene, not part of the successful bootstrap boundary.
        if (kDebugMode) {
          debugPrint('Manager bootstrap proof cleanup deferred: $error');
        }
      }
      await FirestoreService.initAuthenticated();
      final manager = FirestoreService.getUser(credential.user!.uid);
      if (manager == null || !manager.hasManagerAccess) {
        await FirestoreService.resetAuthenticatedState();
        await _fbAuth.signOut();
        throw StateError('Missing manager profile');
      }
      _currentUser = manager;
    } on fb_auth.FirebaseAuthException catch (e) {
      _authError = _mapAuthError(e);
      await FirestoreService.resetAuthenticatedState();
      await _fbAuth.signOut();
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (error) {
      // A wrong/expired proof must not leave an orphan Auth account that
      // blocks the official manager from reusing their employee number.
      if (!bootstrapCommitted) {
        final createdUser = credential?.user;
        if (createdUser != null) {
          try {
            await createdUser.delete();
          } catch (_) {
            // Firebase may already have invalidated the partial account.
          }
        }
        await FirestoreService.resetAuthenticatedState();
        await _fbAuth.signOut();
        final text = error.toString();
        _authError = text.contains('permission-denied')
            ? 'مفتاح التأسيس غير صحيح أو تم استخدامه سابقًا'
            : 'تعذّر إنشاء الحساب، حاول مرة أخرى';
      } else {
        _authError = 'تم إنشاء حساب المدير، أعد تحميل الصفحة للدخول';
      }
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Whether a manager account exists yet — readable BEFORE sign-in via the
  /// public `system/manager_lock` sentinel (see
  /// `FirestoreService.managerLockExists`), since the `users` collection
  /// itself requires authentication to read under the security rules.
  bool get managerExists => FirestoreService.managerLockExists;

  /// Signs in using الرقم الوظيفي (employee number) + password. Internally maps the
  /// employee number to its deterministic synthetic Firebase-Auth email
  /// (see [_syntheticEmail]) — the caller/UI never deals with email at all.
  Future<bool> login(String employeeNumber, String password) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    fb_auth.UserCredential cred;
    try {
      cred = await _fbAuth.signInWithEmailAndPassword(
        email: _syntheticEmail(employeeNumber),
        password: password,
      );
    } on fb_auth.FirebaseAuthException catch (e) {
      _authError = _mapAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final fbUid = cred.user!.uid;

    // Authenticated listeners (users/tasks/messages/...) require a signed-in
    // session under the security rules — start them now, before any
    // synchronous cache read.
    await FirestoreService.initAuthenticated();

    final user = FirestoreService.getUser(fbUid);
    if (user == null) {
      // Auth credential exists but no Firestore profile — treat as invalid
      // account state and sign back out.
      await FirestoreService.resetAuthenticatedState();
      await _fbAuth.signOut();
      _authError = 'الحساب غير مكتمل، يرجى التواصل مع المدير';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (user.accountStatus == AccountStatus.pendingApproval) {
      _currentUser = user;
      _isLoading = false;
      notifyListeners();
      return true; // login succeeds but UI will route to pending screen
    }

    if (user.accountStatus == AccountStatus.rejected) {
      await FirestoreService.resetAuthenticatedState();
      await _fbAuth.signOut();
      _authError = 'تم رفض طلب انضمامك من قِبل المدير';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (user.accountStatus == AccountStatus.deleted) {
      await FirestoreService.resetAuthenticatedState();
      await _fbAuth.signOut();
      _authError = 'هذا الحساب تم حذفه من قِبل المدير';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _currentUser = user;
    await _repairMissingManagerLock(user);
    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Generates a single-use invite link token (manager action, employee
  /// invites only — manager invites are seeded directly via the Admin SDK,
  /// see [Invitation] doc comment).
  Future<Invitation> generateInvitation({
    required String managerUid,
    String? expectedName,
  }) async {
    final creator = _currentUser;
    if (creator == null ||
        creator.uid != managerUid ||
        !creator.hasManagerAccess) {
      throw StateError('لا يملك هذا الحساب صلاحية إنشاء روابط الدعوة');
    }

    final invite = Invitation(
      inviteId: _uuid.v4(),
      token: _uuid.v4(),
      createdBy: managerUid,
      createdAt: DateTime.now(),
      status: InvitationStatus.pending,
      expectedEmployeeName: expectedName,
    );
    await FirestoreService.saveInvitation(invite);

    // Do not hand a link to the manager until Firestore confirms that the
    // exact invitation is readable, still pending, and attributed to the
    // account that created it. This covers both the official manager account
    // and the owner's full-access operational account (400161).
    final stored = await FirestoreService.getInvitationByTokenFresh(
      invite.token,
    );
    if (stored == null ||
        stored.status != InvitationStatus.pending ||
        stored.createdBy != managerUid) {
      throw StateError('تعذّر التحقق من صلاحية رابط الدعوة');
    }
    return stored;
  }

  Invitation? validateInviteToken(String token) {
    final invite = FirestoreService.getInvitationByToken(token);
    if (invite == null) return null;
    if (invite.status == InvitationStatus.used) return null;
    return invite;
  }

  Future<Invitation?> validateInviteTokenFresh(String token) async {
    final invite = await FirestoreService.getInvitationByTokenFresh(token);
    if (invite == null || invite.status == InvitationStatus.used) return null;
    return invite;
  }

  /// Employee self-registration via a valid single-use invite token.
  ///
  /// Creates the Firebase Auth account first, then runs the atomic
  /// Firestore transaction (see FirestoreService.consumeInviteAndRegister)
  /// using the Auth-issued uid as the profile document id — this guarantees
  /// the token cannot be consumed twice under concurrent registration
  /// attempts. If the Firestore transaction fails/rejects AFTER the Auth
  /// account was created (e.g. token already burned by a concurrent
  /// request), the Auth account is rolled back (deleted) so the email is
  /// not left "stuck" on an orphaned credential.
  Future<bool> registerViaInvite({
    required String token,
    required String name,
    required String employeeNumber,
    String password = '',
  }) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    final syntheticEmail = _syntheticEmail(employeeNumber);

    fb_auth.UserCredential cred;
    try {
      cred = await _fbAuth.createUserWithEmailAndPassword(
        email: syntheticEmail,
        password: password,
      );
    } on fb_auth.FirebaseAuthException catch (e) {
      _authError = _mapAuthError(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final fbUid = cred.user!.uid;
    final newUser = AppUser(
      uid: fbUid,
      name: name,
      email: syntheticEmail,
      employeeNumber: employeeNumber,
      role: UserRole.employee,
      accountStatus: AccountStatus.pendingApproval,
      createdAt: DateTime.now(),
    );

    // createUserWithEmailAndPassword() above already signs the new account
    // in — the transaction below writes to `users` as that now-authenticated
    // uid, which the security rules require.
    final result = await FirestoreService.consumeInviteAndRegister(
      token: token,
      newUser: newUser,
    );

    if (result == null) {
      // Roll back the orphaned Auth account — the invite/email checks below
      // are only used to select the correct user-facing error message.
      // `getUserByEmail` needs the authenticated `users` listener; start it
      // (best-effort — a failure here just falls back to the generic
      // "invalid invite" message) before signing back out.
      String? existingUid;
      try {
        await FirestoreService.initAuthenticated();
        existingUid = FirestoreService.getUserByEmail(syntheticEmail)?.uid;
      } catch (_) {
        // ignore — fall back to generic message below
      }
      await FirestoreService.resetAuthenticatedState();
      await cred.user!.delete();
      _authError = existingUid != null
          ? 'هذا الرقم الوظيفي مسجّل بالفعل'
          : 'رابط الدعوة غير صالح أو مُستخدم مسبقًا';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    await FirestoreService.initAuthenticated();
    _currentUser = result;
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> approveEmployee(String employeeUid, String managerUid) async {
    final user = FirestoreService.getUser(employeeUid);
    if (user == null) return;
    final updated = user.copyWith(
      accountStatus: AccountStatus.active,
      approvedBy: managerUid,
      approvedAt: DateTime.now(),
    );
    await FirestoreService.saveUser(updated);
    if (_currentUser?.uid == employeeUid) {
      _currentUser = updated;
    }
    notifyListeners();
  }

  Future<void> rejectEmployee(String employeeUid, String managerUid) async {
    final user = FirestoreService.getUser(employeeUid);
    if (user == null) return;
    final updated = user.copyWith(
      accountStatus: AccountStatus.rejected,
      approvedBy: managerUid,
      approvedAt: DateTime.now(),
    );
    await FirestoreService.saveUser(updated);
    notifyListeners();
  }

  /// Soft-deletes an employee account (manager-only action).
  ///
  /// The Firestore user document is NOT removed — only the account status
  /// is flipped to [AccountStatus.deleted]. This preserves audit history
  /// (task_history entries referencing this uid remain valid) while fully
  /// excluding the employee from all active-facing views (login, task
  /// assignment dropdowns, reports, employee list) since those all filter
  /// on `accountStatus == AccountStatus.active`.
  ///
  /// NOTE: this does NOT delete the underlying Firebase Auth credential —
  /// only Firestore-side status is flipped, consistent with the pre-existing
  /// soft-delete semantics. The `login()` flow above already checks
  /// `accountStatus == AccountStatus.deleted` and force-signs the account
  /// back out even if the Auth credential itself still verifies correctly.
  ///
  /// Task-fate handling (delete vs. reassign the employee's existing tasks)
  /// must be resolved by the caller BEFORE invoking this method — see
  /// `TaskProvider.deleteAllTasksForEmployee` /
  /// `TaskProvider.reassignAllTasksForEmployee`.
  Future<void> deleteEmployee(String employeeUid, String managerUid) async {
    final user = FirestoreService.getUser(employeeUid);
    if (user == null) return;
    final updated = user.copyWith(
      accountStatus: AccountStatus.deleted,
      approvedBy: managerUid,
      approvedAt: DateTime.now(),
    );
    await FirestoreService.saveUser(updated);
    notifyListeners();
  }

  /// Self-service password change for the CURRENTLY signed-in user (any
  /// role — manager or employee). Different from the manager-driven
  /// `adminResetPassword` Cloud Function (see manager_employees_tab.dart):
  /// here the user proves knowledge of their OWN current password via
  /// `reauthenticateWithCredential` before Firebase Auth allows
  /// `updatePassword`. No Firestore write is required — Firebase Auth owns
  /// credential storage entirely.
  ///
  /// Returns `null` on success. Returns an Arabic user-facing error
  /// message on failure (wrong current password, weak new password,
  /// requires-recent-login, etc. — all mapped via `_mapAuthError`).
  Future<String?> changeOwnPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _fbAuth.currentUser;
    if (user == null || user.email == null) {
      return 'جلسة الدخول منتهية، يرجى تسجيل الدخول مرة أخرى';
    }
    try {
      final cred = fb_auth.EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);
      await user.updatePassword(newPassword);
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      return _mapAuthError(e);
    }
  }

  /// Updates only the signed-in account's personal profile photo.
  Future<void> updateOwnProfilePhoto(String profilePhotoUrl) async {
    final user = _currentUser;
    if (user == null) return;
    final updated = user.copyWith(profilePhotoUrl: profilePhotoUrl);
    await FirestoreService.saveUser(updated);
    _currentUser = updated;
    notifyListeners();
  }

  /// Records that the manager acknowledged the current welcome experience.
  /// The versioned marker is account-scoped in Firestore, so it is not shown
  /// again when the same manager later signs in from another device.
  Future<void> completeManagerWelcome(int version) async {
    final user = _currentUser;
    if (user == null || user.role != UserRole.manager) return;
    await FirestoreService.updateManagerWelcomeVersion(user.uid, version);
    _currentUser = user.copyWith(managerWelcomeVersion: version);
    notifyListeners();
  }

  Future<void> _repairMissingManagerLock(AppUser user) async {
    if (user.role != UserRole.manager || FirestoreService.managerLockExists) {
      return;
    }
    try {
      await FirestoreService.ensureManagerLockForExistingManager(
        user.uid,
      ).timeout(const Duration(seconds: 5));
    } catch (error) {
      // A missing legacy sentinel must never invalidate a legitimate manager
      // session. The next authenticated launch retries the idempotent repair.
      if (kDebugMode) {
        debugPrint('Manager lock repair deferred: $error');
      }
    }
  }

  /// Manager-driven password change for ANOTHER user (see
  /// `manager_employees_tab.dart._startChangePasswordFlow`). A regular
  /// client cannot change another Firebase Auth user's password directly —
  /// this MUST go through a privileged server-side call. Invokes the
  /// `adminResetPassword` Cloud Function, which:
  ///   1. verifies the CALLER (via `context.auth`) is a manager
  ///      (custom claim or Firestore role lookup — enforced server-side,
  ///      never trust the client-side `isManager` check alone), THEN
  ///   2. calls `admin.auth().updateUser(targetUid, { password })`.
  ///
  /// NOTE: as of this writing the `adminResetPassword` function has been
  /// WRITTEN (see `functions/index.js`) but NOT YET DEPLOYED — deployment
  /// is blocked on the Firebase project being upgraded to the Blaze plan
  /// and the Cloud Build API being enabled by the project owner via the
  /// Firebase/GCP Console (the sandbox's service-account credentials lack
  /// permission to do either). Until deployment succeeds, calls to this
  /// method will fail with a `not-found` / `internal` FirebaseFunctions
  /// exception, surfaced below as an Arabic error message.
  ///
  /// Returns `null` on success. Returns an Arabic user-facing error message
  /// on failure (permission-denied, not-found/undeployed, invalid-argument,
  /// etc.).
  Future<String?> adminResetPassword({
    required String targetUid,
    required String newPassword,
  }) async {
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'adminResetPassword',
      );
      await callable.call<void>({
        'userId': targetUid,
        'newPassword': newPassword,
      });
      return null;
    } on FirebaseFunctionsException catch (e) {
      switch (e.code) {
        case 'permission-denied':
          return 'ليس لديك صلاحية تغيير كلمات مرور الموظفين';
        case 'not-found':
          return 'خدمة تغيير كلمة المرور غير متاحة حاليًا (لم يتم نشرها بعد)';
        case 'invalid-argument':
          return 'كلمة المرور الجديدة غير صالحة (6 أحرف على الأقل)';
        case 'unauthenticated':
          return 'جلسة الدخول منتهية، يرجى تسجيل الدخول مرة أخرى';
        default:
          return 'حدث خطأ غير متوقع: ${e.message ?? e.code}';
      }
    } catch (_) {
      return 'تعذّر الاتصال بخدمة تغيير كلمة المرور، حاول لاحقًا';
    }
  }

  Future<void> logout() async {
    _currentUser = null;
    await FirestoreService.resetAuthenticatedState();
    await _fbAuth.signOut();
    notifyListeners();
  }

  void refreshCurrentUser() {
    if (_currentUser != null) {
      final updated = FirestoreService.getUser(_currentUser!.uid);
      if (updated != null) {
        _currentUser = updated;
        notifyListeners();
      }
    }
  }

  /// Maps FirebaseAuthException error codes to Arabic user-facing messages.
  /// NOTE: every code here originally referred to a real email address;
  /// since the app never collects one, each message is rephrased in terms
  /// of "الرقم الوظيفي" (employee number) — the only identifier a user
  /// ever sees, even though Firebase Auth still internally uses a
  /// synthetic email derived from it (see [_syntheticEmail]).
  String _mapAuthError(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'الرقم الوظيفي غير صالح';
      case 'user-disabled':
        return 'هذا الحساب معطّل';
      case 'user-not-found':
        return 'الرقم الوظيفي غير مسجّل';
      case 'wrong-password':
      case 'invalid-credential':
        return 'الرقم السري غير صحيح';
      case 'email-already-in-use':
        return 'هذا الرقم الوظيفي مسجّل بالفعل';
      case 'weak-password':
        return 'الرقم السري ضعيف جدًا — يجب أن يكون 6 أحرف على الأقل';
      case 'too-many-requests':
        return 'محاولات كثيرة جدًا، يرجى الانتظار قليلًا ثم المحاولة مرة أخرى';
      case 'network-request-failed':
        return 'تعذّر الاتصال بالخادم، تحقّق من اتصال الإنترنت';
      default:
        return 'حدث خطأ غير متوقع (${e.code})';
    }
  }
}
