/// A single employee's vote on a Poll — lives at
/// `polls/{pollId}/votes/{employeeUid}` (document ID IS the employee uid,
/// deterministic — see poll_model.dart doc comment for why votes are a
/// separate subcollection rather than an embedded map, and why this
/// deterministic ID scheme is what makes "change my vote" a plain
/// idempotent `.set()` upsert instead of a query-then-update).
///
/// MULTI-CHOICE UPGRADE (from the original binary `VoteChoice{yes,no}`):
/// [choiceIndex] is now a 0-based index into the parent [AppPoll.choices]
/// list, supporting an arbitrary number of options instead of exactly two.
///
/// BACKWARD COMPATIBILITY (explicit): any legacy vote document written
/// under the old schema carries a `choice` field with string value
/// `'yes'`/`'no'` and NO `choiceIndex` field. [fromMap] maps
/// `'yes' -> 0` and `'no' -> 1`, which is consistent with
/// [AppPoll]'s own legacy-choices default of `['نعم' (index 0), 'لا' (index 1)]`
/// — so an old vote continues to tally against the correct choice text
/// after migration, with no data loss or reinterpretation.
///
/// [votedAt] mirrors [ChatMessage.readAt]'s nullable-timestamp pattern —
/// null only in the theoretical construction-before-first-write moment;
/// in practice a PollVote document is never created without one.
class PollVote {
  final String pollId;
  final String employeeUid;
  final int choiceIndex;
  final DateTime votedAt;

  PollVote({
    required this.pollId,
    required this.employeeUid,
    required this.choiceIndex,
    required this.votedAt,
  });

  PollVote copyWith({int? choiceIndex, DateTime? votedAt}) {
    return PollVote(
      pollId: pollId,
      employeeUid: employeeUid,
      choiceIndex: choiceIndex ?? this.choiceIndex,
      votedAt: votedAt ?? this.votedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pollId': pollId,
      'employeeUid': employeeUid,
      'choiceIndex': choiceIndex,
      'votedAt': votedAt.toIso8601String(),
    };
  }

  factory PollVote.fromMap(Map<dynamic, dynamic> map) {
    return PollVote(
      pollId: map['pollId'] as String? ?? '',
      employeeUid: map['employeeUid'] as String? ?? '',
      choiceIndex: _parseChoiceIndex(map),
      votedAt: map['votedAt'] != null
          ? DateTime.parse(map['votedAt'] as String)
          : DateTime.now(),
    );
  }

  static int _parseChoiceIndex(Map<dynamic, dynamic> map) {
    if (map['choiceIndex'] != null) {
      return map['choiceIndex'] as int;
    }
    // Legacy binary vote document — see class doc's BACKWARD COMPATIBILITY
    // note. Explicit mapping, not a silent guess.
    final legacyChoice = map['choice'] as String?;
    if (legacyChoice == 'yes') return 0;
    if (legacyChoice == 'no') return 1;
    return 0;
  }
}
