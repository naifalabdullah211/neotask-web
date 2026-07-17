/// "تصويت" (Poll) — a manager-created multi-choice vote addressed to a
/// chosen subset of ACTIVE employees, with a mandatory start and end
/// date/time.
///
/// LIFECYCLE (4 statuses — upgraded from the original open/closed binary):
///   draft     -> not yet visible/votable by employees; manager-only, fully
///                editable, no participants notified yet.
///   active    -> published, votable by eligible employees until [deadline].
///   ended     -> voting window closed (naturally, at [deadline]) OR
///                already closed by legacy data; votes preserved, no new
///                votes accepted, a permanent [PollReport] exists (see
///                poll_report_model.dart) generated exactly once.
///   cancelled -> manager withdrew the topic before its natural end; votes
///                already cast are preserved (never deleted) but no report
///                is generated and no further votes are accepted.
///
/// BACKWARD COMPATIBILITY (explicit, not silent): the single legacy
/// document already in production used the old 2-state
/// `PollStatus{open,closed}` string values. [fromMap] maps
/// `'open' -> active` and `'closed' -> ended` on read, and a poll with no
/// `choices` field is treated as the original binary Yes/No poll (choices
/// defaulted to `['نعم', 'لا']`). No existing document is deleted or
/// mutated destructively by this change — see migrate_polls.py.
///
/// SECRECY ARCHITECTURE (critical, do not "simplify" by inlining votes):
/// individual votes are NEVER stored as fields on this document. They live
/// in a separate `polls/{pollId}/votes/{employeeUid}` subcollection (see
/// poll_vote_model.dart) specifically because Firestore security rules are
/// document-level, not field-level. This document only ever carries the
/// AGGREGATE outcome (choiceCounts/winningChoiceIndex/isTie), and those
/// aggregate fields stay null until the poll is actually ended.
///
/// PRIVACY TOGGLE ([privacyEnabled]): when true, the manager's live detail
/// view and the permanent report show ONLY voted/not-voted status per
/// employee — never which specific choice they picked. The underlying
/// vote documents are unaffected (tallying still needs the real choice);
/// this flag only gates what the UI/report layer is allowed to render.
///
/// SERVER-TIME ENFORCEMENT (upgraded from the original device-time-only
/// design): [deadline]/[startDateTime] are now written to Firestore as
/// genuine `Timestamp` values (not ISO-8601 strings), which lets
/// `firestore.rules` reject any vote write where `request.time > deadline`
/// directly at the database layer — enforcement no client's local clock
/// can bypass. [isPastDeadline] below still exists for UI-only concerns
/// (countdown display, disabling the vote buttons pre-emptively) — the
/// actual authoritative cutoff is the security rule, not this getter.
///
/// AUTO-CLOSE ARCHITECTURE (documented limitation — UPGRADED but not
/// eliminated): true Cloud Functions/Cloud Scheduler were confirmed
/// UNAVAILABLE in this project's environment (the service account has no
/// IAM permission to enable `cloudfunctions.googleapis.com` /
/// `cloudscheduler.googleapis.com` / `cloudbuild.googleapis.com`, and no
/// interactive `firebase login` is possible from this sandbox — verified
/// empirically, not assumed). The closing + report-generation + manager
/// notification sequence therefore still runs CLIENT-SIDE, opportunistically,
/// by whichever signed-in client's app observes `active && past deadline`
/// first — see PollProvider._maybeAutoEndOverduePolls. What IS genuinely
/// upgraded: (a) the actual vote cutoff is enforced by `request.time` in
/// firestore.rules regardless of which/whether a client is open, so no
/// vote can ever be cast after the deadline even during the window before
/// a client performs the ending write; (b) the ending + report write is
/// wrapped in a Firestore transaction gated by a one-way
/// `reportGenerated: false -> true` field flip enforced by the rules,
/// guaranteeing the report/notification are produced exactly once even if
/// several clients race to perform the transition simultaneously. The
/// residual, disclosed gap: if literally no client opens the app at/after
/// the deadline, `status` remains `active` in Firestore (though votes are
/// already rules-blocked) until the next one does.
library;

enum PollStatus { draft, active, ended, cancelled }

class AppPoll {
  final String pollId;
  final String title;
  final String description;

  /// The available choices employees can pick from. Legacy binary polls
  /// (no `choices` field in Firestore) are treated as `['نعم', 'لا']`.
  final List<String> choices;

  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentType; // 'image' | 'file'
  final List<String> participantUids; // active employees selected/eligible
  final String createdBy; // manager uid

  /// When voting opens. Defaults to [createdAt] for legacy documents that
  /// predate this field (they had no separate start concept — voting was
  /// open from creation).
  final DateTime startDateTime;

  /// When voting closes (was previously named "closing deadline" only).
  final DateTime deadline;
  final DateTime createdAt;
  final PollStatus status;

  /// When true, per-employee CHOICE is never surfaced in the manager
  /// detail view or the final report — only voted/not-voted status is
  /// shown. Defaults to false (matches the pre-existing behaviour, where
  /// the manager's detail screen already showed each employee's exact
  /// Yes/No vote).
  final bool privacyEnabled;

  /// Free-text notes a manager may still add after the poll has ended —
  /// the ONLY field editable post-ending (per explicit requirement: "no
  /// editing after Ended except non-result-affecting admin notes").
  final String adminNotes;

  /// Cooldown guard for "حث الموظفين على التصويت" — the reminder action is
  /// blocked while this is within the cooldown window (see
  /// PollProvider.remindNotYetVoted).
  final DateTime? lastReminderSentAt;

  /// One-way idempotency flag: flips false -> true exactly once, inside
  /// the SAME transaction that writes [status]=ended, computes the
  /// aggregate result fields below, and creates the permanent
  /// `poll_reports/{pollId}` document + the manager's "انتهى التصويت"
  /// notification. firestore.rules rejects any write that would set this
  /// back to false or set it to true a second time, which is what makes
  /// the whole ending sequence exactly-once even under a race between
  /// multiple clients (see class doc's AUTO-CLOSE ARCHITECTURE note).
  final bool reportGenerated;

  final String? cancelledBy;
  final DateTime? cancelledAt;

  // ---- Aggregate result — set ONLY once the poll is ended (see class
  // doc). Index-aligned with [choices]. ----
  final List<int>? choiceCounts;
  final int? winningChoiceIndex; // null if tie or zero votes cast
  final bool? isTie;
  final List<int>? tiedChoiceIndexes; // populated only when isTie == true
  final DateTime? endedAt;

  // Manual tie-break — manager picks the final winning choice by index.
  // `status` remains `ended` throughout (permanent-archive requirement).
  final String? managerDecisionBy;
  final DateTime? managerDecisionAt;

  AppPoll({
    required this.pollId,
    required this.title,
    required this.description,
    List<String>? choices,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentType,
    required this.participantUids,
    required this.createdBy,
    DateTime? startDateTime,
    required this.deadline,
    required this.createdAt,
    required this.status,
    this.privacyEnabled = false,
    this.adminNotes = '',
    this.lastReminderSentAt,
    this.reportGenerated = false,
    this.cancelledBy,
    this.cancelledAt,
    this.choiceCounts,
    this.winningChoiceIndex,
    this.isTie,
    this.tiedChoiceIndexes,
    this.endedAt,
    this.managerDecisionBy,
    this.managerDecisionAt,
  }) : choices = (choices == null || choices.isEmpty)
           ? const ['نعم', 'لا']
           : choices,
       startDateTime = startDateTime ?? createdAt;

  /// UI-ONLY convenience getter (see class doc — the authoritative cutoff
  /// is the `request.time` check in firestore.rules, not this).
  bool get isPastDeadline => DateTime.now().isAfter(deadline);

  bool get isActive => status == PollStatus.active;
  bool get isEnded => status == PollStatus.ended;
  bool get isDraft => status == PollStatus.draft;
  bool get isCancelled => status == PollStatus.cancelled;

  /// Whether this poll may still be voted on right now — active status
  /// AND not yet past its deadline (defense-in-depth alongside the rule).
  bool get votingOpen => status == PollStatus.active && !isPastDeadline;

  AppPoll copyWith({
    String? title,
    String? description,
    List<String>? choices,
    List<String>? participantUids,
    DateTime? startDateTime,
    DateTime? deadline,
    PollStatus? status,
    bool? privacyEnabled,
    String? adminNotes,
    DateTime? lastReminderSentAt,
    bool? reportGenerated,
    String? cancelledBy,
    DateTime? cancelledAt,
    List<int>? choiceCounts,
    int? winningChoiceIndex,
    bool? isTie,
    List<int>? tiedChoiceIndexes,
    DateTime? endedAt,
    String? managerDecisionBy,
    DateTime? managerDecisionAt,
  }) {
    return AppPoll(
      pollId: pollId,
      title: title ?? this.title,
      description: description ?? this.description,
      choices: choices ?? this.choices,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      attachmentType: attachmentType,
      participantUids: participantUids ?? this.participantUids,
      createdBy: createdBy,
      startDateTime: startDateTime ?? this.startDateTime,
      deadline: deadline ?? this.deadline,
      createdAt: createdAt,
      status: status ?? this.status,
      privacyEnabled: privacyEnabled ?? this.privacyEnabled,
      adminNotes: adminNotes ?? this.adminNotes,
      lastReminderSentAt: lastReminderSentAt ?? this.lastReminderSentAt,
      reportGenerated: reportGenerated ?? this.reportGenerated,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      choiceCounts: choiceCounts ?? this.choiceCounts,
      winningChoiceIndex: winningChoiceIndex ?? this.winningChoiceIndex,
      isTie: isTie ?? this.isTie,
      tiedChoiceIndexes: tiedChoiceIndexes ?? this.tiedChoiceIndexes,
      endedAt: endedAt ?? this.endedAt,
      managerDecisionBy: managerDecisionBy ?? this.managerDecisionBy,
      managerDecisionAt: managerDecisionAt ?? this.managerDecisionAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pollId': pollId,
      'title': title,
      'description': description,
      'choices': choices,
      'attachmentUrl': attachmentUrl,
      'attachmentName': attachmentName,
      'attachmentType': attachmentType,
      'participantUids': participantUids,
      'createdBy': createdBy,
      // NOTE: deliberately NOT .toIso8601String() — passing a raw DateTime
      // here lets the cloud_firestore Flutter plugin auto-serialize it as
      // a genuine Firestore `Timestamp` on write (documented SDK
      // behaviour), which is REQUIRED for firestore.rules to enforce
      // `request.time > resource.data.deadline` as true server-time
      // comparison (see class doc's SERVER-TIME ENFORCEMENT note). Kept
      // out of an explicit `Timestamp.fromDate()` call so this model file
      // stays free of a `cloud_firestore` import, matching every other
      // model in this codebase.
      'startDateTime': startDateTime,
      'deadline': deadline,
      'createdAt': createdAt.toIso8601String(),
      'status': status.name,
      'privacyEnabled': privacyEnabled,
      'adminNotes': adminNotes,
      'lastReminderSentAt': lastReminderSentAt?.toIso8601String(),
      'reportGenerated': reportGenerated,
      'cancelledBy': cancelledBy,
      'cancelledAt': cancelledAt?.toIso8601String(),
      'choiceCounts': choiceCounts,
      'winningChoiceIndex': winningChoiceIndex,
      'isTie': isTie,
      'tiedChoiceIndexes': tiedChoiceIndexes,
      'endedAt': endedAt?.toIso8601String(),
      'managerDecisionBy': managerDecisionBy,
      'managerDecisionAt': managerDecisionAt?.toIso8601String(),
    };
  }

  static PollStatus _parseStatus(dynamic raw) {
    final s = raw as String?;
    // Legacy mapping — explicit, not silent (see class doc's BACKWARD
    // COMPATIBILITY note).
    if (s == 'open') return PollStatus.active;
    if (s == 'closed') return PollStatus.ended;
    return PollStatus.values.firstWhere(
      (e) => e.name == s,
      orElse: () => PollStatus.active,
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is String) return DateTime.parse(raw);
    // Firestore Timestamp objects expose toDate(); avoid a hard dependency
    // on cloud_firestore in this model file (kept plain-Dart, matching
    // every other model in this codebase) by duck-typing the call.
    try {
      // ignore: avoid_dynamic_calls
      return (raw as dynamic).toDate() as DateTime;
    } catch (_) {
      return null;
    }
  }

  factory AppPoll.fromMap(Map<dynamic, dynamic> map) {
    final createdAt = _parseDate(map['createdAt']) ?? DateTime.now();
    return AppPoll(
      pollId: map['pollId'] as String,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      choices: (map['choices'] as List?)?.cast<String>(),
      attachmentUrl: map['attachmentUrl'] as String?,
      attachmentName: map['attachmentName'] as String?,
      attachmentType: map['attachmentType'] as String?,
      participantUids:
          (map['participantUids'] as List?)?.cast<String>() ?? const [],
      createdBy: map['createdBy'] as String? ?? '',
      startDateTime: _parseDate(map['startDateTime']) ?? createdAt,
      deadline: _parseDate(map['deadline']) ?? DateTime.now(),
      createdAt: createdAt,
      status: _parseStatus(map['status']),
      privacyEnabled: map['privacyEnabled'] as bool? ?? false,
      adminNotes: map['adminNotes'] as String? ?? '',
      lastReminderSentAt: _parseDate(map['lastReminderSentAt']),
      reportGenerated: map['reportGenerated'] as bool? ?? false,
      cancelledBy: map['cancelledBy'] as String?,
      cancelledAt: _parseDate(map['cancelledAt']),
      choiceCounts: (map['choiceCounts'] as List?)?.cast<int>(),
      winningChoiceIndex: map['winningChoiceIndex'] as int?,
      isTie: map['isTie'] as bool?,
      tiedChoiceIndexes: (map['tiedChoiceIndexes'] as List?)?.cast<int>(),
      endedAt: _parseDate(map['endedAt']),
      managerDecisionBy: map['managerDecisionBy'] as String?,
      managerDecisionAt: _parseDate(map['managerDecisionAt']),
    );
  }
}
