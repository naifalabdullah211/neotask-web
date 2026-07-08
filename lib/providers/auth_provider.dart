import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/invitation_model.dart';
import '../services/firestore_service.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;
  String? _authError;
  bool _isLoading = false;

  AppUser? get currentUser => _currentUser;
  String? get authError => _authError;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _currentUser != null;
  bool get isManager => _currentUser?.role == UserRole.manager;
  bool get isEmployee => _currentUser?.role == UserRole.employee;

  static const _uuid = Uuid();

  Future<void> restoreSession() async {
    final uid = FirestoreService.getCurrentUid();
    if (uid != null) {
      final user = FirestoreService.getUser(uid);
      // A previously-active session must not be honored if the manager has
      // since soft-deleted this account — force it back to the login screen.
      if (user != null && user.accountStatus == AccountStatus.deleted) {
        await FirestoreService.setCurrentUid(null);
        _currentUser = null;
      } else {
        _currentUser = user;
      }
      notifyListeners();
    }
  }

  /// Bootstraps the single manager account if none exists yet.
  Future<void> ensureManagerExists({
    required String name,
    required String email,
    required String employeeNumber,
    String password = '',
  }) async {
    final existingManager = FirestoreService.getManager();
    if (existingManager != null) return;

    final manager = AppUser(
      uid: _uuid.v4(),
      name: name,
      email: email,
      employeeNumber: employeeNumber,
      role: UserRole.manager,
      accountStatus: AccountStatus.active,
      createdAt: DateTime.now(),
      passwordPlaceholder: password,
    );
    await FirestoreService.saveUser(manager);
  }

  bool get managerExists => FirestoreService.getManager() != null;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    // NOTE: password verification is currently a plain-text comparison
    // against a value stored in Firestore (interim mechanism). This will be
    // replaced by real Firebase Authentication (email/password) next.
    await Future.delayed(const Duration(milliseconds: 400));

    final user = FirestoreService.getUserByEmail(email.trim());
    if (user == null) {
      _authError = 'البريد الإلكتروني غير مسجّل';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (user.passwordPlaceholder.isNotEmpty &&
        user.passwordPlaceholder != password) {
      _authError = 'كلمة المرور غير صحيحة';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (user.accountStatus == AccountStatus.pendingApproval) {
      _currentUser = user;
      await FirestoreService.setCurrentUid(user.uid);
      _isLoading = false;
      notifyListeners();
      return true; // login succeeds but UI will route to pending screen
    }

    if (user.accountStatus == AccountStatus.rejected) {
      _authError = 'تم رفض طلب انضمامك من قِبل المدير';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    if (user.accountStatus == AccountStatus.deleted) {
      _authError = 'هذا الحساب تم حذفه من قِبل المدير';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _currentUser = user;
    await FirestoreService.setCurrentUid(user.uid);
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
  /// Uses an atomic Firestore transaction (see
  /// FirestoreService.consumeInviteAndRegister) to guarantee the token
  /// cannot be consumed twice under concurrent registration attempts.
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

    final newUser = AppUser(
      uid: _uuid.v4(),
      name: name,
      email: email.trim(),
      employeeNumber: employeeNumber,
      role: UserRole.employee,
      accountStatus: AccountStatus.pendingApproval,
      createdAt: DateTime.now(),
      passwordPlaceholder: password,
    );

    final result = await FirestoreService.consumeInviteAndRegister(
      token: token,
      newUser: newUser,
    );

    if (result == null) {
      // Distinguish the two failure causes for a clearer user-facing message.
      final existing = FirestoreService.getUserByEmail(email.trim());
      _authError = existing != null
          ? 'هذا البريد الإلكتروني مسجّل بالفعل'
          : 'رابط الدعوة غير صالح أو مُستخدم مسبقًا';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    _currentUser = result;
    await FirestoreService.setCurrentUid(result.uid);
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

  Future<void> logout() async {
    _currentUser = null;
    await FirestoreService.setCurrentUid(null);
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
}
