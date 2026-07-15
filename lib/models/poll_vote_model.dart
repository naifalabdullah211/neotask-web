/// A single employee's vote on a Poll — lives at
/// `polls/{pollId}/votes/{employeeUid}` (document ID IS the employee uid,
/// deterministic — see poll_model.dart doc comment for why votes are a
/// separate subcollection rather than an embedded map, and why this
/// deterministic ID scheme is what makes "change my vote" a plain
/// idempotent `.set()` upsert instead of a query-then-update).
///
/// [votedAt] mirrors [ChatMessage.readAt]'s nullable-timestamp pattern —
/// null only in the theoretical construction-before-first-write moment;
/// in practice a PollVote document is never created without one.
enum VoteChoice { yes, no }

class PollVote {
  final String pollId;
  final String employeeUid;
  final VoteChoice choice;
  final DateTime votedAt;

  PollVote({
    required this.pollId,
    required this.employeeUid,
    required this.choice,
    required this.votedAt,
  });

  PollVote copyWith({VoteChoice? choice, DateTime? votedAt}) {
    return PollVote(
      pollId: pollId,
      employeeUid: employeeUid,
      choice: choice ?? this.choice,
      votedAt: votedAt ?? this.votedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pollId': pollId,
      'employeeUid': employeeUid,
      'choice': choice.name,
      'votedAt': votedAt.toIso8601String(),
    };
  }

  factory PollVote.fromMap(Map<dynamic, dynamic> map) {
    return PollVote(
      pollId: map['pollId'] as String? ?? '',
      employeeUid: map['employeeUid'] as String? ?? '',
      choice: VoteChoice.values.firstWhere(
        (e) => e.name == map['choice'],
        orElse: () => VoteChoice.no,
      ),
      votedAt: map['votedAt'] != null
          ? DateTime.parse(map['votedAt'] as String)
          : DateTime.now(),
    );
  }
}
