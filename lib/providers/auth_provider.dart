import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/invitation_model.dart';
import '../services/firestore_service.dart';

/// AuthProvider — backed by real Firebase Authentication (email/password).
///
/// SECURITY NOTE (replaces the previous interim mechanism): passwords are no
/// longer stored or compared in Firestore. `FirebaseAuth.instance` now owns
/// credential storage/verification entirely; the Firestore `users` document
/// (`AppUser`) holds ONLY the non-secret profile fields (name, email,
/// employeeNumber, role, accountStatus, ...) and is keyed by the Firebase
/// Auth `uid` for every account.
///
/// The public method signatures below are UNCHANGED from the previous
/// implementation on purpose — every screen that calls into this provider
/// (14 files) continues to work without modification.
class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;
  String? _authError;
  bool _isLoading = false;

  final fb_auth.FirebaseAuth _fbAuth = fb_auth.FirebaseAuth.instance;

  AppUser? get currentUser => _currentUser;
  String? get authError => _authError;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  bool get isManager => _currentUser?.role == UserRole.manager;
  bool get isEmployee => _currentUser?.role == UserRole.employee;
  // Read-only observer role — see UserRole.designer doc comment
  // (user_model.dart) for the full 1-a/2-a/3-no design rationale.
  bool get isDesigner => _currentUser?.role == UserRole.designer;

  static const _uuid = Uuid();

  /// Restores the session from Firebase Auth's own persisted state (it keeps
  /// the user signed in across reloads on Web/Android by itself — no manual
  /// SharedPreferences caching is needed anymore).
  Future<void> restoreSession() async {
    final fbUser = _fbAuth.currentUser;
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
    }
    notifyListeners();
  }

  /// Bootstraps the single manager account if none exists yet.
  ///
  /// Creates the Firebase Auth account first (credential storage), then the
  /// Firestore profile document keyed by the resulting Auth uid. If the
  /// Firestore write fails after the Auth account was created, the Auth
  /// account is rolled back to avoid an orphaned credential with no profile.
  Future<void> ensureManagerExists({
    required String name,
    required String email,
    required String employeeNumber,
    String password = '',
  }) async {
    if (FirestoreService.managerLockExists) return;

    fb_auth.UserCredential cred;
    try {
      cred = await _fbAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on fb_auth.FirebaseAuthException catch (e) {
      _authError = _mapAuthError(e);
      notifyListeners();
      return;
    }

    final fbUid = cred.user!.uid;
    final manager = AppUser(
      uid: fbUid,
      name: name,
      email: email.trim(),
      employeeNumber: employeeNumber,
      role: UserRole.manager,
      accountStatus: AccountStatus.active,
      createdAt: DateTime.now(),
    );

    // The `system/manager_lock` sentinel + `users/{uid}` doc are created in
    // one atomic transaction (see createManagerProfile) which requires the
    // caller to already be signed in as `manager.uid` — start the
    // authenticated listeners now so subsequent `getManager()`/cache reads
    // (e.g. from the immediately-following `login()` call) work correctly.
    await FirestoreService.initAuthenticated();

    bool created;
    try {
      created = await FirestoreService.createManagerProfile(manager);
    } catch (_) {
      await FirestoreService.resetAuthenticatedState();
      await cred.user!.delete();
      rethrow;
    }

    if (!created) {
      // Another manager-bootstrap request won the race (or the security
      // rules already reject this write) — roll back the orphaned Auth
      // account so the email address is not left stuck on an unusable
      // credential.
      await FirestoreService.resetAuthenticatedState();
      await cred.user!.delete();
    }
  }

  /// Whether a manager account exists yet — readable BEFORE sign-in via the
  /// public `system/manager_lock` sentinel (see
  /// `FirestoreService.managerLockExists`), since the `users` collection
  /// itself requires authentication to read under the security rules.
  bool get managerExists => FirestoreService.managerLockExists;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    fb_auth.UserCredential cred;
    try {
      cred = await _fbAuth.signInWithEmailAndPassword(
        email: email.trim(),
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
    _isLoading = false;
    notifyListeners();
    return true;
  }

  /// Generates a single-use invite link token (manager action).
  Future<Invitation> generateInvitation({
    required String managerUid,
    String? expectedName,
  }) async {
    final invite = Invitation(
      inviteId: _uuid.v4(),
      token: _uuid.v4(),
      createdBy: managerUid,
      createdAt: DateTime.now(),
      status: InvitationStatus.pending,
      expectedEmployeeName: expectedName,
    );
    await FirestoreService.saveInvitation(invite);
    return invite;
  }

  Invitation? validateInviteToken(String token) {
    final invite = FirestoreService.getInvitationByToken(token);
    if (invite == null) return null;
    if (invite.status == InvitationStatus.used) return null;
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
    required String email,
    required String employeeNumber,
    String password = '',
  }) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    fb_auth.UserCredential cred;
    try {
      cred = await _fbAuth.createUserWithEmailAndPassword(
        email: email.trim(),
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
      email: email.trim(),
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
      String? existingEmail;
      try {
        await FirestoreService.initAuthenticated();
        existingEmail = FirestoreService.getUserByEmail(email.trim())?.email;
      } catch (_) {
        // ignore — fall back to generic message below
      }
      await FirestoreService.resetAuthenticatedState();
      await cred.user!.delete();
      _authError = existingEmail != null
          ? 'هذا البريد الإلكتروني مسجّل بالفعل'
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
  String _mapAuthError(fb_auth.FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'صيغة البريد الإلكتروني غير صحيحة';
      case 'user-disabled':
        return 'هذا الحساب معطّل';
      case 'user-not-found':
        return 'البريد الإلكتروني غير مسجّل';
      case 'wrong-password':
      case 'invalid-credential':
        return 'كلمة المرور غير صحيحة';
      case 'email-already-in-use':
        return 'هذا البريد الإلكتروني مسجّل بالفعل';
      case 'weak-password':
        return 'كلمة المرور ضعيفة جدًا — يجب أن تكون 6 أحرف على الأقل';
      case 'too-many-requests':
        return 'محاولات كثيرة جدًا، يرجى الانتظار قليلًا ثم المحاولة مرة أخرى';
      case 'network-request-failed':
        return 'تعذّر الاتصال بالخادم، تحقّق من اتصال الإنترنت';
      default:
        return 'حدث خطأ غير متوقع (${e.code})';
    }
  }
}
