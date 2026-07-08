enum UserRole { manager, employee }

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

  /// NOTE: plain-text password stored in Firestore, ONLY acceptable as an
  /// interim mechanism before real Firebase Authentication is connected.
  /// This field will be removed entirely once Firebase Auth
  /// (email/password) replaces this placeholder mechanism.
  final String passwordPlaceholder;

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
    this.passwordPlaceholder = '',
  });

  AppUser copyWith({
    String? name,
    String? email,
    String? employeeNumber,
    UserRole? role,
    AccountStatus? accountStatus,
    String? approvedBy,
    DateTime? approvedAt,
    String? passwordPlaceholder,
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
      passwordPlaceholder: passwordPlaceholder ?? this.passwordPlaceholder,
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
      'passwordPlaceholder': passwordPlaceholder,
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
      passwordPlaceholder: map['passwordPlaceholder'] as String? ?? '',
    );
  }
}
