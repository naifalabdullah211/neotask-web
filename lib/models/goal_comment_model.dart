/// A single comment on a [Goal] ("تعليق على الهدف") — architecturally
/// SEPARATE from the Criterion chat system (see criterion_chat_model.dart)
/// and from Task's `ActivityLogEntry` (see task_model.dart), but
/// deliberately mirrors the EXACT SAME UX mechanism already built for
/// tasks ("التعليقات السريعة"): a text box + إرسال button, each comment
/// displaying author name + timestamp + text — per the explicit
/// requirement to reuse that mechanism rather than invent a new one.
///
/// JUDGMENT CALL (flagged per this codebase's established convention of
/// documenting non-obvious design decisions inline): unlike [AppTask]
/// (which already had `activityLog` before Quick Comments was built on
/// top of it), [Goal] has NO history/event-log mechanism of any kind
/// prior to this feature — the REBUILD NOTE on goal_model.dart confirms
/// goal-level completion tracking was explicitly removed, and no other
/// goal-level "event" type exists in the rebuilt architecture (no
/// approve/reject, no status change). Since a comment is the ONLY event
/// type a Goal can currently have, this `comments` array on [Goal] IS the
/// goal's history/event log — there is no separate `goal_history`
/// collection, because no other event exists that would need one. If a
/// future requirement introduces a distinct goal-level event (e.g. a
/// manual completion action), a genuine dedicated history collection
/// should be introduced at that point instead of overloading this list
/// further.
class GoalComment {
  final String authorUid;
  final String text;
  final DateTime createdAt;

  GoalComment({
    required this.authorUid,
    required this.text,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'authorUid': authorUid,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory GoalComment.fromMap(Map<dynamic, dynamic> map) {
    return GoalComment(
      authorUid: map['authorUid'] as String? ?? '',
      text: map['text'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
