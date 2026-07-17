/// The PERMANENT final report for a poll, generated exactly once when the
/// poll transitions to [PollStatus.ended] (see poll_model.dart's
/// AUTO-CLOSE ARCHITECTURE note and PollProvider._endAndGenerateReport).
///
/// Lives at `poll_reports/{pollId}` — deliberately a SEPARATE top-level
/// collection (not a subcollection of `polls/{pollId}`) so that
/// firestore.rules can grant it a simple, permanent, read-only-after-
/// creation rule independent of the poll document's own (mutable, while
/// active) update rules. Document ID equals the poll's own `pollId`,
/// which is what makes report generation idempotent — creating this
/// document is only ever attempted from inside the SAME transaction that
/// flips `polls/{pollId}.reportGenerated` false -> true, and Firestore
/// transactions guarantee that concurrent attempts to create the same
/// document ID resolve to exactly one winner.
///
/// PRIVACY (mirrors [AppPoll.privacyEnabled]): when the poll had privacy
/// enabled, [voterUids] still lists WHO voted (this is never secret — the
/// manager already sees per-employee voted/not-voted status live), but
/// [choiceCounts] alone (no per-employee choice breakdown field exists
/// anywhere on this model) is what the report screen renders — there is
/// no field on this document that could leak an individual employee's
/// specific choice even if privacy were disabled at the UI layer by
/// mistake, because it was never captured here in the first place. This
/// is a structural guarantee, not just a UI-layer toggle.
class PollReport {
  final String pollId;
  final String title;
  final String description;
  final List<String> choices;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String createdByManagerUid;
  final int totalEligible;
  final int totalVoted;
  final int totalNotVoted;
  final double participationPercent; // 0-100
  final List<int> choiceCounts; // index-aligned with [choices]
  final List<double> choicePercentages; // index-aligned with [choices]
  final int? winningChoiceIndex; // null if tie
  final bool isTie;
  final List<int> tiedChoiceIndexes;
  final List<String> voterUids;
  final List<String> nonVoterUids;
  final DateTime generatedAt;
  final bool privacyWasEnabled;

  PollReport({
    required this.pollId,
    required this.title,
    required this.description,
    required this.choices,
    required this.startDateTime,
    required this.endDateTime,
    required this.createdByManagerUid,
    required this.totalEligible,
    required this.totalVoted,
    required this.totalNotVoted,
    required this.participationPercent,
    required this.choiceCounts,
    required this.choicePercentages,
    this.winningChoiceIndex,
    required this.isTie,
    required this.tiedChoiceIndexes,
    required this.voterUids,
    required this.nonVoterUids,
    required this.generatedAt,
    required this.privacyWasEnabled,
  });

  Map<String, dynamic> toMap() {
    return {
      'pollId': pollId,
      'title': title,
      'description': description,
      'choices': choices,
      'startDateTime': startDateTime.toIso8601String(),
      'endDateTime': endDateTime.toIso8601String(),
      'createdByManagerUid': createdByManagerUid,
      'totalEligible': totalEligible,
      'totalVoted': totalVoted,
      'totalNotVoted': totalNotVoted,
      'participationPercent': participationPercent,
      'choiceCounts': choiceCounts,
      'choicePercentages': choicePercentages,
      'winningChoiceIndex': winningChoiceIndex,
      'isTie': isTie,
      'tiedChoiceIndexes': tiedChoiceIndexes,
      'voterUids': voterUids,
      'nonVoterUids': nonVoterUids,
      'generatedAt': generatedAt.toIso8601String(),
      'privacyWasEnabled': privacyWasEnabled,
    };
  }

  factory PollReport.fromMap(Map<dynamic, dynamic> map) {
    return PollReport(
      pollId: map['pollId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      choices: (map['choices'] as List?)?.cast<String>() ?? const [],
      startDateTime: map['startDateTime'] != null
          ? DateTime.parse(map['startDateTime'] as String)
          : DateTime.now(),
      endDateTime: map['endDateTime'] != null
          ? DateTime.parse(map['endDateTime'] as String)
          : DateTime.now(),
      createdByManagerUid: map['createdByManagerUid'] as String? ?? '',
      totalEligible: map['totalEligible'] as int? ?? 0,
      totalVoted: map['totalVoted'] as int? ?? 0,
      totalNotVoted: map['totalNotVoted'] as int? ?? 0,
      participationPercent:
          (map['participationPercent'] as num?)?.toDouble() ?? 0,
      choiceCounts: (map['choiceCounts'] as List?)?.cast<int>() ?? const [],
      choicePercentages:
          (map['choicePercentages'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      winningChoiceIndex: map['winningChoiceIndex'] as int?,
      isTie: map['isTie'] as bool? ?? false,
      tiedChoiceIndexes:
          (map['tiedChoiceIndexes'] as List?)?.cast<int>() ?? const [],
      voterUids: (map['voterUids'] as List?)?.cast<String>() ?? const [],
      nonVoterUids: (map['nonVoterUids'] as List?)?.cast<String>() ?? const [],
      generatedAt: map['generatedAt'] != null
          ? DateTime.parse(map['generatedAt'] as String)
          : DateTime.now(),
      privacyWasEnabled: map['privacyWasEnabled'] as bool? ?? false,
    );
  }
}
