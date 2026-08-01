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
  final String? profilePhotoUrl;

  // ---- Per-user preferences (الإعدادات الشخصية) — NEW, added for the
  // Settings screen (الإشعارات الصوتية + التذكيرات sections). All default
  // to `true` (opt-out model) so existing accounts created before these
  // fields existed behave exactly as before once `fromMap` back-fills the
  // default — no migration/backfill script is required.
  //
  // `soundMessagesEnabled` / `soundTasksEnabled` gate audible notification
  // playback for new chat messages and task events respectively.
  // `remindersEnabled` gates whether THIS user receives the existing
  // automatic due-soon/overdue task reminders (see
  // TaskProvider._maybeDispatchReminders, which now checks this flag on
  // the recipient before dispatching).
  final bool soundMessagesEnabled;
  final bool soundTasksEnabled;
  final bool remindersEnabled;

  /// Weekly work capacity used by the project workload planner. Managers
  /// can tailor it to part-time and shift-based employees; older accounts
  /// safely default to a standard 40-hour week.
  final double weeklyCapacityHours;

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
    this.profilePhotoUrl,
    this.soundMessagesEnabled = true,
    this.soundTasksEnabled = true,
    this.remindersEnabled = true,
    this.weeklyCapacityHours = 40,
  });

  AppUser copyWith({
    String? name,
    String? email,
    String? employeeNumber,
    UserRole? role,
    AccountStatus? accountStatus,
    String? approvedBy,
    DateTime? approvedAt,
    String? profilePhotoUrl,
    bool? soundMessagesEnabled,
    bool? soundTasksEnabled,
    bool? remindersEnabled,
    double? weeklyCapacityHours,
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
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      soundMessagesEnabled: soundMessagesEnabled ?? this.soundMessagesEnabled,
      soundTasksEnabled: soundTasksEnabled ?? this.soundTasksEnabled,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      weeklyCapacityHours: weeklyCapacityHours ?? this.weeklyCapacityHours,
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
      if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
      'soundMessagesEnabled': soundMessagesEnabled,
      'soundTasksEnabled': soundTasksEnabled,
      'remindersEnabled': remindersEnabled,
      'weeklyCapacityHours': weeklyCapacityHours,
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
      profilePhotoUrl: map['profilePhotoUrl'] as String?,
      // Safe casting + explicit default (NOT null-assertion) per this
      // project's Firebase data-consistency guideline — accounts created
      // before these fields existed simply back-fill to `true` here,
      // requiring no Firestore migration script.
      soundMessagesEnabled: map['soundMessagesEnabled'] as bool? ?? true,
      soundTasksEnabled: map['soundTasksEnabled'] as bool? ?? true,
      remindersEnabled: map['remindersEnabled'] as bool? ?? true,
      weeklyCapacityHours:
          (map['weeklyCapacityHours'] as num?)?.toDouble() ?? 40,
    );
  }
}
