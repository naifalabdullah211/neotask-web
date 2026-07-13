// `designer` — a read-only observer role added per explicit user request
// ("انا مصمم البرنامج... احتاج حساب اشوف فيه البرنامج من الداخل"). Answers
// locked in before implementation:
//   1-a: full read access to EVERY collection (tasks, goals, criteria,
//        messages/chat content included, users, history, documents,
//        meetings, contacts).
//   2-a: INVISIBLE — must never appear in the employee list, task/criterion
//        assignment dropdowns, or the reassignment-target picker. This is
//        achieved for free: every such list is built via
//        `FirestoreService.getAllEmployees()`, which filters strictly on
//        `role == UserRole.employee` — a `designer` account never matches.
//   3-no: ABSOLUTE zero write access — no create/update/delete of any
//        kind. Enforced at BOTH layers: (a) the UI never exposes a
//        designer to any action button (see DesignerHomeScreen and its
//        tabs, which are purpose-built read-only screens), and (b) the
//        Firestore security rules explicitly reject writes from this role
//        on every collection that was previously gated only by
//        `isSignedIn()` + self-ownership (calendar_imports/settings,
//        documents, meetings, contacts, favorites, messages, task_history,
//        criterion_history, invitations) — see `isDesigner()` in
//        firestore.rules. Collections already gated by isManager() or by
//        ownership fields a designer can never satisfy (tasks, criteria,
//        goals, users) required no additional rule change.
enum UserRole { manager, employee, designer }

enum AccountStatus { pendingApproval, active, rejected, deleted }

class AppUser {
  final String uid;
  final String name;
  final String email;
  final String employeeNumber;
  final UserRole role;
  final AccountStatus accountStatus;
  final String? approvedBy;
  final DateTime? approvedAt;
  final DateTime createdAt;

  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.employeeNumber,
    required this.role,
    required this.accountStatus,
    this.approvedBy,
    this.approvedAt,
    required this.createdAt,
  });

  AppUser copyWith({
    String? name,
    String? email,
    String? employeeNumber,
    UserRole? role,
    AccountStatus? accountStatus,
    String? approvedBy,
    DateTime? approvedAt,
  }) {
    return AppUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      employeeNumber: employeeNumber ?? this.employeeNumber,
      role: role ?? this.role,
      accountStatus: accountStatus ?? this.accountStatus,
      approvedBy: approvedBy ?? this.approvedBy,
      approvedAt: approvedAt ?? this.approvedAt,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'employeeNumber': employeeNumber,
      'role': role.name,
      'accountStatus': accountStatus.name,
      'approvedBy': approvedBy,
      'approvedAt': approvedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AppUser.fromMap(Map<dynamic, dynamic> map) {
    return AppUser(
      uid: map['uid'] as String,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      employeeNumber: map['employeeNumber'] as String? ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.name == map['role'],
        orElse: () => UserRole.employee,
      ),
      accountStatus: AccountStatus.values.firstWhere(
        (e) => e.name == map['accountStatus'],
        orElse: () => AccountStatus.pendingApproval,
      ),
      approvedBy: map['approvedBy'] as String?,
      approvedAt: map['approvedAt'] != null
          ? DateTime.parse(map['approvedAt'] as String)
          : null,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
