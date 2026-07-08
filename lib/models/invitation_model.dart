enum InvitationStatus { pending, used }

class Invitation {
  final String inviteId;
  final String token;
  final String createdBy; // manager uid
  final DateTime createdAt;
  final InvitationStatus status;
  final String? expectedEmployeeName;
  final DateTime? usedAt;
  final String? usedByUid;

  Invitation({
    required this.inviteId,
    required this.token,
    required this.createdBy,
    required this.createdAt,
    required this.status,
    this.expectedEmployeeName,
    this.usedAt,
    this.usedByUid,
  });

  Invitation copyWith({
    InvitationStatus? status,
    DateTime? usedAt,
    String? usedByUid,
  }) {
    return Invitation(
      inviteId: inviteId,
      token: token,
      createdBy: createdBy,
      createdAt: createdAt,
      status: status ?? this.status,
      expectedEmployeeName: expectedEmployeeName,
      usedAt: usedAt ?? this.usedAt,
      usedByUid: usedByUid ?? this.usedByUid,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'inviteId': inviteId,
      'token': token,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'expectedEmployeeName': expectedEmployeeName,
      'usedAt': usedAt?.toIso8601String(),
      'usedByUid': usedByUid,
    };
  }

  factory Invitation.fromMap(Map<dynamic, dynamic> map) {
    return Invitation(
      inviteId: map['inviteId'] as String,
      token: map['token'] as String,
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      status: InvitationStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => InvitationStatus.pending,
      ),
      expectedEmployeeName: map['expectedEmployeeName'] as String?,
      usedAt: map['usedAt'] != null
          ? DateTime.parse(map['usedAt'] as String)
          : null,
      usedByUid: map['usedByUid'] as String?,
    );
  }
}
