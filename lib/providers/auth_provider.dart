import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/invitation_model.dart';
import '../services/local_db_service.dart';

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
    final uid = LocalDbService.getCurrentUid();
    if (uid != null) {
      _currentUser = LocalDbService.getUser(uid);
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
    final existingManager = LocalDbService.getManager();
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
    await LocalDbService.saveUser(manager);
  }

  bool get managerExists => LocalDbService.getManager() != null;

  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _authError = null;
    notifyListeners();

    // NOTE: password verification is a placeholder in the local (Hive) mode.
    // Once Firestore + Firebase Auth are connected, this will use real
    // Firebase Authentication (email/password) instead.
    await Future.delayed(const Duration(milliseconds: 400));

    final user = LocalDbService.getUserByEmail(email.trim());
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
      await LocalDbService.setCurrentUid(user.uid);
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

    _currentUser = user;
    await LocalDbService.setCurrentUid(user.uid);
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
    await LocalDbService.saveInvitation(invite);
    return invite;
  }

  Invitation? validateInviteToken(String token) {
    final invite = LocalDbService.getInvitationByToken(token);
    if (invite == null) return null;
    if (invite.status == InvitationStatus.used) return null;
    return invite;
  }

  /// Employee self-registration via a valid single-use invite token.
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

    final invite = validateInviteToken(token);
    if (invite == null) {
      _authError = 'رابط الدعوة غير صالح أو مُستخدم مسبقًا';
      _isLoading = false;
      notifyListeners();
      return false;
    }

    final existing = LocalDbService.getUserByEmail(email.trim());
    if (existing != null) {
      _authError = 'هذا البريد الإلكتروني مسجّل بالفعل';
      _isLoading = false;
      notifyListeners();
      return false;
    }

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
    await LocalDbService.saveUser(newUser);

    // Burn the invite token — single use enforced.
    final updatedInvite = invite.copyWith(
      status: InvitationStatus.used,
      usedAt: DateTime.now(),
      usedByUid: newUser.uid,
    );
    await LocalDbService.saveInvitation(updatedInvite);

    _currentUser = newUser;
    await LocalDbService.setCurrentUid(newUser.uid);
    _isLoading = false;
    notifyListeners();
    return true;
  }

  Future<void> approveEmployee(String employeeUid, String managerUid) async {
    final user = LocalDbService.getUser(employeeUid);
    if (user == null) return;
    final updated = user.copyWith(
      accountStatus: AccountStatus.active,
      approvedBy: managerUid,
      approvedAt: DateTime.now(),
    );
    await LocalDbService.saveUser(updated);
    if (_currentUser?.uid == employeeUid) {
      _currentUser = updated;
    }
    notifyListeners();
  }

  Future<void> rejectEmployee(String employeeUid, String managerUid) async {
    final user = LocalDbService.getUser(employeeUid);
    if (user == null) return;
    final updated = user.copyWith(
      accountStatus: AccountStatus.rejected,
      approvedBy: managerUid,
      approvedAt: DateTime.now(),
    );
    await LocalDbService.saveUser(updated);
    notifyListeners();
  }

  Future<void> logout() async {
    _currentUser = null;
    await LocalDbService.setCurrentUid(null);
    notifyListeners();
  }

  void refreshCurrentUser() {
    if (_currentUser != null) {
      final updated = LocalDbService.getUser(_currentUser!.uid);
      if (updated != null) {
        _currentUser = updated;
        notifyListeners();
      }
    }
  }
}
