/// "تصويت" (Poll) — a manager-created Yes/No vote addressed to a chosen
/// subset of ACTIVE employees, with a mandatory closing deadline.
///
/// SECRECY ARCHITECTURE (critical, do not "simplify" by inlining votes):
/// individual votes are NEVER stored as fields on this document. They live
/// in a separate `polls/{pollId}/votes/{employeeUid}` subcollection (see
/// poll_vote_model.dart) specifically because Firestore security rules are
/// document-level, not field-level — if votes were fields here, any rule
/// granting a participating employee read access to their own poll would
/// also expose every other employee's vote. This document only ever
/// carries the AGGREGATE outcome ([yesCount]/[noCount]/[result]), and
/// those aggregate fields stay null until the poll is actually closed — so
/// an employee reading this doc before closing time learns nothing about
/// the running tally either.
///
/// AUTO-CLOSE ARCHITECTURE (documented limitation, mirrors the
/// residual-limitation convention already used in firestore.rules): there
/// is no Cloud Functions scheduler confirmed in this project. Closing a
/// poll requires reading every participant's vote sub-document, which any
/// signed-in client can technically trigger (see firestore.rules — the
/// auto-close write is deliberately open to ANY signed-in user's client,
/// not manager-only, since the client that happens to load the poll list
/// past the deadline may be an employee's device, not the manager's).
/// Therefore the close+tally+notify step is executed CLIENT-SIDE,
/// opportunistically, by whichever client (manager OR employee) observes
/// `deadline.isBefore(now) && status == open` first (see
/// PollProvider._maybeAutoCloseOverduePolls). If no one opens the app
/// at/after the deadline, `status` remains `open` in Firestore until the
/// next one does — this is flagged, not silently hidden.
enum PollStatus { open, closed }

enum PollResult { yes, no, tiePendingManagerDecision }

class AppPoll {
  final String pollId;
  final String title;
  final String description;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentType; // 'image' | 'file'
  final List<String> participantUids; // active employees selected at creation
  final String createdBy; // manager uid
  final DateTime deadline;
  final DateTime createdAt;
  final PollStatus status;

  // Aggregate result — set ONLY once the poll is closed (see class doc).
  final PollResult? result;
  final int? yesCount;
  final int? noCount;
  final DateTime? closedAt;

  // Set ONLY when the manager manually resolves a tie (requirement #3's
  // tie-handling clause) — `status` remains `closed` throughout, only
  // `result` changes from `tiePendingManagerDecision` to yes/no.
  final String? managerDecisionBy;
  final DateTime? managerDecisionAt;

  AppPoll({
    required this.pollId,
    required this.title,
    required this.description,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentType,
    required this.participantUids,
    required this.createdBy,
    required this.deadline,
    required this.createdAt,
    required this.status,
    this.result,
    this.yesCount,
    this.noCount,
    this.closedAt,
    this.managerDecisionBy,
    this.managerDecisionAt,
  });

  /// Whether [deadline] has already passed — used by both the manager and
  /// employee auto-close/vote-blocking checks (see class doc comment on
  /// the auto-close architecture and its acknowledged limitation).
  bool get isPastDeadline => DateTime.now().isAfter(deadline);

  AppPoll copyWith({
    PollStatus? status,
    PollResult? result,
    int? yesCount,
    int? noCount,
    DateTime? closedAt,
    String? managerDecisionBy,
    DateTime? managerDecisionAt,
  }) {
    return AppPoll(
      pollId: pollId,
      title: title,
      description: description,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      attachmentType: attachmentType,
      participantUids: participantUids,
      createdBy: createdBy,
      deadline: deadline,
      createdAt: createdAt,
      status: status ?? this.status,
      result: result ?? this.result,
      yesCount: yesCount ?? this.yesCount,
      noCount: noCount ?? this.noCount,
      closedAt: closedAt ?? this.closedAt,
      managerDecisionBy: managerDecisionBy ?? this.managerDecisionBy,
      managerDecisionAt: managerDecisionAt ?? this.managerDecisionAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pollId': pollId,
      'title': title,
      'description': description,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'attachmentType': attachmentType,
      'participantUids': participantUids,
      'createdBy': createdBy,
      'deadline': deadline.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'result': result?.name,
      'yesCount': yesCount,
      'noCount': noCount,
      'closedAt': closedAt?.toIso8601String(),
      'managerDecisionBy': managerDecisionBy,
      'managerDecisionAt': managerDecisionAt?.toIso8601String(),
    };
  }

  factory AppPoll.fromMap(Map<dynamic, dynamic> map) {
    return AppPoll(
      pollId: map['pollId'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      attachmentUrl: map['attachmentUrl'] as String?,
      attachmentName: map['attachmentName'] as String?,
      attachmentType: map['attachmentType'] as String?,
      participantUids:
          (map['participantUids'] as List?)?.cast<String>() ?? const [],
      createdBy: map['createdBy'] as String? ?? '',
      deadline: map['deadline'] != null
          ? DateTime.parse(map['deadline'] as String)
          : DateTime.now(),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
      status: PollStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PollStatus.open,
      ),
      result: map['result'] != null
          ? PollResult.values.firstWhere(
              (e) => e.name == map['result'],
              orElse: () => PollResult.tiePendingManagerDecision,
            )
          : null,
      yesCount: map['yesCount'] as int?,
      noCount: map['noCount'] as int?,
      closedAt: map['closedAt'] != null
          ? DateTime.parse(map['closedAt'] as String)
          : null,
      managerDecisionBy: map['managerDecisionBy'] as String?,
      managerDecisionAt: map['managerDecisionAt'] != null
          ? DateTime.parse(map['managerDecisionAt'] as String)
          : null,
    );
  }
}
