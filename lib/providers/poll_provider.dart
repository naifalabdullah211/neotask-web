import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/poll_model.dart';
import '../models/poll_vote_model.dart';
import '../models/poll_report_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

/// Manages the full "تصويت" (Poll) lifecycle: draft/active/ended/cancelled
/// status, multi-choice creation and editing, voting, live per-employee
/// status (manager view), reminder dispatch, and the auto-end +
/// report-generation + notification pipeline.
///
/// AUTO-END ARCHITECTURE (documented explicitly, UPGRADED from the
/// original binary-poll design but NOT fully eliminated — see
/// poll_model.dart's class doc for the full rationale): genuine Cloud
/// Functions / Cloud Scheduler were EMPIRICALLY CONFIRMED unavailable in
/// this project (the service account has no IAM permission to enable the
/// required Google Cloud APIs, and no interactive `firebase login` is
/// possible from this sandbox — verified via direct API probes, not
/// assumed). The chosen mechanism remains CLIENT-SIDE LAZY EVALUATION:
/// [_maybeAutoEndOverduePolls] runs on every live polls-stream emission
/// and, for every still-`active` poll past its `deadline`, attempts
/// [_endAndGenerateReport]. What IS genuinely upgraded over the previous
/// design:
///   1. VOTE CUTOFF is enforced by `request.time` in firestore.rules
///      (a real Firestore server clock comparison against a genuine
///      Timestamp field) — no vote can succeed after the deadline
///      regardless of whether any client has yet performed the ending
///      transition below.
///   2. The ending + report-generation write is a single Firestore
///      TRANSACTION (`FirestoreService.endPollAndGenerateReport`) gated by
///      a one-way `reportGenerated` flag enforced by the security rule —
///      this guarantees the permanent report and the manager's "انتهى
///      التصويت" notification are produced EXACTLY ONCE even if several
///      clients race to observe the same overdue poll simultaneously
///      (the loser's transaction sees `reportGenerated == true` already
///      and returns `false`, so it sends no notification).
/// RESIDUAL, DISCLOSED LIMITATION: if literally no client opens the app
/// at/after the deadline, `status` remains `active` in Firestore (though
/// votes are already rules-blocked from that instant on) until the next
/// one does — this is the same class of trade-off as every other
/// "date-derived" logic in this codebase (e.g. task overdue flags).
class PollProvider extends ChangeNotifier {
  static const _uuid = Uuid();

  /// Cooldown for "حث الموظفين على التصويت" — prevents spamming the same
  /// not-yet-voted employees repeatedly. Chosen value: 4 hours (not
  /// specified numerically by the user; a conservative, clearly-stated
  /// default so the anti-spam intent is honoured without inventing an
  /// arbitrarily short window).
  static const Duration reminderCooldown = Duration(hours: 4);

  List<AppPoll> _allPolls = [];
  List<AppPoll> get allPolls {
    final sorted = List<AppPoll>.of(_allPolls)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(sorted);
  }

  List<AppPoll> get draftPolls =>
      allPolls.where((p) => p.status == PollStatus.draft).toList();

  List<AppPoll> get activePolls =>
      allPolls.where((p) => p.status == PollStatus.active).toList();

  List<AppPoll> get endedPolls =>
      allPolls.where((p) => p.status == PollStatus.ended).toList();

  List<AppPoll> get cancelledPolls =>
      allPolls.where((p) => p.status == PollStatus.cancelled).toList();

  // Legacy-name aliases kept ONLY so any not-yet-migrated call site does
  // not crash outright (all in-repo call sites are updated as part of
  // this same change; kept briefly for defensive safety, not intended as
  // a long-lived API).
  List<AppPoll> get openPolls => activePolls;
  List<AppPoll> get closedPolls => endedPolls;

  PollProvider() {
    _listenAll();
  }

  void _listenAll() {
    FirestoreService.watchAllPolls().listen((polls) {
      _allPolls = polls;
      notifyListeners();
      // Fire-and-forget: check for overdue active polls on every update.
      // Errors are caught internally (see method doc) so a transient
      // Firestore failure here never crashes the listener subscription.
      _maybeAutoEndOverduePolls(polls);
    });
  }

  AppPoll? getPoll(String pollId) {
    for (final p in _allPolls) {
      if (p.pollId == pollId) return p;
    }
    return null;
  }

  List<AppPoll> pollsForEmployee(String employeeUid) {
    return allPolls
        .where(
          (p) =>
              p.participantUids.contains(employeeUid) &&
              p.status != PollStatus.draft,
        )
        .toList();
  }

  // ---------------- CREATE / PUBLISH / EDIT / CANCEL ----------------

  /// Creates a new poll. [deadline] is REQUIRED (non-nullable) at the type
  /// level — this is what makes "a poll must not be creatable without a
  /// deadline" impossible to violate from this provider's API surface, on
  /// top of the UI-level validation in the creation screen. [asDraft]
  /// controls whether the poll is immediately votable ([PollStatus.active])
  /// or created as [PollStatus.draft] (manager-only, invisible to
  /// employees, per requirement #1's status list).
  Future<AppPoll> createPoll({
    required String title,
    required String description,
    required List<String> participantUids,
    required List<String> choices,
    DateTime? startDateTime,
    required DateTime deadline,
    required String createdBy,
    bool privacyEnabled = false,
    bool asDraft = false,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
  }) async {
    final now = DateTime.now();
    final poll = AppPoll(
      pollId: _uuid.v4(),
      title: title,
      description: description,
      choices: choices,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      attachmentType: attachmentType,
      participantUids: participantUids,
      startDateTime: startDateTime ?? now,
      deadline: deadline,
      status: asDraft ? PollStatus.draft : PollStatus.active,
      privacyEnabled: privacyEnabled,
      createdBy: createdBy,
      createdAt: now,
    );
    await FirestoreService.savePoll(poll);
    return poll;
  }

  /// Publishes a draft poll (draft -> active), making it visible/votable
  /// by its selected employees.
  Future<void> publishDraft(String pollId) async {
    final poll = getPoll(pollId);
    if (poll == null) throw Exception('التصويت غير موجود');
    if (poll.status != PollStatus.draft) {
      throw Exception('لا يمكن نشر تصويت ليس في وضع المسودة');
    }
    await FirestoreService.updatePoll(pollId, {
      'status': PollStatus.active.name,
    });
  }

  /// Edits a draft-or-active poll's title/description/choices/eligible
  /// employees/end date-time — per the explicit editing requirement.
  /// [resetVotesIfChoicesChanged]: when the manager has confirmed (via a
  /// UI dialog — see ManagerPollDetailScreen) that changing the available
  /// choices while votes already exist should wipe those votes, this
  /// flag triggers the deletion; the CALLER is responsible for having
  /// obtained that confirmation, this method does not itself re-confirm.
  Future<void> updateActivePoll({
    required String pollId,
    String? title,
    String? description,
    List<String>? choices,
    List<String>? participantUids,
    DateTime? startDateTime,
    DateTime? deadline,
    bool? privacyEnabled,
    bool resetVotesIfChoicesChanged = false,
  }) async {
    final poll = getPoll(pollId);
    if (poll == null) throw Exception('التصويت غير موجود');
    if (poll.status != PollStatus.draft && poll.status != PollStatus.active) {
      throw Exception('لا يمكن تعديل تصويت منتهٍ أو مُلغى');
    }

    final fields = <String, dynamic>{};
    if (title != null) fields['title'] = title;
    if (description != null) fields['description'] = description;
    if (choices != null) fields['choices'] = choices;
    if (participantUids != null) fields['participantUids'] = participantUids;
    if (startDateTime != null) fields['startDateTime'] = startDateTime;
    if (deadline != null) fields['deadline'] = deadline;
    if (privacyEnabled != null) fields['privacyEnabled'] = privacyEnabled;

    if (fields.isEmpty) return;

    final choicesChanged =
        choices != null && !_listEquals(choices, poll.choices);

    await FirestoreService.updatePoll(
      pollId,
      fields,
      resetVotes: choicesChanged && resetVotesIfChoicesChanged,
    );
  }

  bool _listEquals(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Whether [pollId] currently has at least one cast vote — used by the
  /// edit screen to decide whether to show the "تغيير الاختيارات سيؤدي
  /// إلى حذف الأصوات الحالية، هل تريد المتابعة؟" confirmation before
  /// calling [updateActivePoll] with `resetVotesIfChoicesChanged: true`.
  Future<bool> hasAnyVotes(String pollId) async {
    final votes = await FirestoreService.getVotesForPoll(pollId);
    return votes.isNotEmpty;
  }

  /// Withdraws a draft-or-active poll before its natural end. Existing
  /// votes are preserved (never deleted) — no report is generated for a
  /// cancelled poll, per the requirement that reports exist "for every
  /// ended topic" (cancelled is a distinct, non-ended terminal state).
  Future<void> cancelPoll(String pollId, String managerUid) async {
    final poll = getPoll(pollId);
    if (poll == null) throw Exception('التصويت غير موجود');
    if (poll.status != PollStatus.draft && poll.status != PollStatus.active) {
      throw Exception('لا يمكن إلغاء تصويت منتهٍ بالفعل');
    }
    await FirestoreService.cancelPoll(pollId, managerUid);
  }

  Future<void> saveAdminNotes(String pollId, String notes) async {
    final poll = getPoll(pollId);
    if (poll == null) throw Exception('التصويت غير موجود');
    if (poll.status != PollStatus.ended) {
      throw Exception('ملاحظات الإدارة تُضاف فقط بعد انتهاء التصويت');
    }
    await FirestoreService.updatePollAdminNotes(pollId, notes);
  }

  // ---------------- VOTING ----------------

  /// Casts or changes [employeeUid]'s vote (by [choiceIndex] into the
  /// poll's [AppPoll.choices]) on [pollId]. Enforces the "only while
  /// active and before deadline" rule at the provider layer as a fast
  /// client-side pre-check for immediate UI feedback — the Firestore
  /// security rule (request.time-based, see firestore.rules) is the
  /// AUTHORITATIVE, server-time enforcement that cannot be bypassed by a
  /// stale/incorrect client clock.
  Future<void> castVote({
    required String pollId,
    required String employeeUid,
    required int choiceIndex,
  }) async {
    final poll = getPoll(pollId);
    if (poll == null) {
      throw Exception('التصويت غير موجود');
    }
    if (!poll.votingOpen) {
      throw Exception('انتهى وقت التصويت، لا يمكن التصويت أو تغيير صوتك الآن');
    }
    if (choiceIndex < 0 || choiceIndex >= poll.choices.length) {
      throw Exception('اختيار غير صالح');
    }
    final vote = PollVote(
      pollId: pollId,
      employeeUid: employeeUid,
      choiceIndex: choiceIndex,
      votedAt: DateTime.now(),
    );
    await FirestoreService.castOrChangeVote(pollId, vote);
  }

  Stream<PollVote?> watchMyVote(String pollId, String employeeUid) =>
      FirestoreService.watchMyVote(pollId, employeeUid);

  /// Manager-only live vote list — used by the manager's poll detail
  /// screen (works both while active AND after ending).
  Stream<List<PollVote>> watchVotesForPoll(String pollId) =>
      FirestoreService.watchVotesForPoll(pollId);

  Stream<PollReport?> watchPollReport(String pollId) =>
      FirestoreService.watchPollReport(pollId);

  Future<PollReport?> getPollReport(String pollId) =>
      FirestoreService.getPollReport(pollId);

  // ---------------- REMINDERS ("حث الموظفين على التصويت") ----------------

  /// Notifies every ELIGIBLE employee who has NOT yet voted on [pollId],
  /// each with the poll's title + remaining time + an implicit direct
  /// link (via [AppNotification.relatedPollId], resolved by the
  /// notification center to the vote screen). Blocked while within
  /// [reminderCooldown] of the last reminder to prevent spam, per the
  /// explicit requirement. Returns the number of employees actually
  /// reminded (0 if none were eligible/not-yet-voted, which is not an
  /// error — the caller can show "الجميع صوّت بالفعل" in that case).
  Future<int> remindNotYetVoted(String pollId) async {
    final poll = getPoll(pollId);
    if (poll == null) throw Exception('التصويت غير موجود');
    if (poll.status != PollStatus.active) {
      throw Exception('لا يمكن إرسال تذكير لتصويت غير نشط');
    }

    final last = poll.lastReminderSentAt;
    if (last != null) {
      final elapsed = DateTime.now().difference(last);
      if (elapsed < reminderCooldown) {
        final remaining = reminderCooldown - elapsed;
        throw Exception(
          'يجب الانتظار ${_formatDuration(remaining)} قبل إرسال تذكير جديد',
        );
      }
    }

    final votes = await FirestoreService.getVotesForPoll(pollId);
    final votedUids = votes.map((v) => v.employeeUid).toSet();
    final notYetVoted = poll.participantUids
        .where((uid) => !votedUids.contains(uid))
        .toList();

    if (notYetVoted.isEmpty) return 0;

    final remaining = poll.deadline.difference(DateTime.now());
    final remainingLabel = remaining.isNegative
        ? 'ينتهي الآن'
        : _formatDuration(remaining);

    for (final uid in notYetVoted) {
      await FirestoreService.saveNotification(
        AppNotification(
          notificationId: _uuid.v4(),
          recipientUid: uid,
          type: NotificationType.voteReminder,
          title: 'تذكير بالتصويت: ${poll.title}',
          body:
              'يتبقى $remainingLabel على انتهاء التصويت. صوّتك مهم — اضغط للتصويت الآن.',
          relatedPollId: poll.pollId,
          createdAt: DateTime.now(),
        ),
      );
    }

    await FirestoreService.recordReminderSent(pollId);
    return notYetVoted.length;
  }

  String _formatDuration(Duration d) {
    if (d.inDays > 0) return '${d.inDays} يوم';
    if (d.inHours > 0) return '${d.inHours} ساعة';
    if (d.inMinutes > 0) return '${d.inMinutes} دقيقة';
    return 'أقل من دقيقة';
  }

  // ---------------- TIE DECISION (post-ended) ----------------

  /// Applies the manager's manual decision on a tied, ALREADY-ended poll
  /// and notifies every participant of the final decision.
  Future<void> applyManagerTieDecision({
    required String pollId,
    required int decisionChoiceIndex,
    required String managerUid,
  }) async {
    await FirestoreService.applyManagerTieDecision(
      pollId: pollId,
      decisionChoiceIndex: decisionChoiceIndex,
      managerUid: managerUid,
    );
  }

  // ---------------- AUTO-END + REPORT GENERATION ----------------

  /// Scans every currently-`active` poll and ends any whose [deadline] has
  /// passed — see class-level doc comment for the full architecture
  /// rationale/limitation. Safe to call redundantly from multiple clients
  /// (the Firestore transaction inside [_endAndGenerateReport] guarantees
  /// at most one client's attempt actually produces the report/notification).
  Future<void> _maybeAutoEndOverduePolls(List<AppPoll> polls) async {
    final overdue = polls.where(
      (p) => p.status == PollStatus.active && p.isPastDeadline,
    );
    for (final poll in overdue) {
      try {
        await _endAndGenerateReport(poll);
      } catch (e) {
        // Expected/benign in the common case where another client already
        // won the race (the transaction's own reportGenerated guard, or
        // the security rule, rejects a duplicate attempt) — logged only
        // in debug builds, never surfaced to the user, since this is a
        // background reconciliation pass, not a user-initiated action.
        if (kDebugMode) {
          debugPrint('PollProvider: auto-end skipped for ${poll.pollId}: $e');
        }
      }
    }
  }

  /// Computes the full tally + winner/tie, persists the ending fields and
  /// the PERMANENT [PollReport] in one atomic Firestore transaction (see
  /// FirestoreService.endPollAndGenerateReport), then — ONLY if this
  /// client's transaction attempt was the one that actually won the race
  /// (returns `true`) — dispatches the manager's "انتهى التصويت"
  /// notification exactly once.
  Future<void> _endAndGenerateReport(AppPoll poll) async {
    final votes = await FirestoreService.getVotesForPoll(poll.pollId);
    final voteByUid = {for (final v in votes) v.employeeUid: v};

    final choiceCounts = List<int>.filled(poll.choices.length, 0);
    for (final v in votes) {
      if (v.choiceIndex >= 0 && v.choiceIndex < choiceCounts.length) {
        choiceCounts[v.choiceIndex]++;
      }
    }

    final totalVoted = votes.length;
    final totalEligible = poll.participantUids.length;
    final totalNotVoted = totalEligible - totalVoted;
    final participationPercent = totalEligible == 0
        ? 0.0
        : (totalVoted / totalEligible) * 100;

    final choicePercentages = choiceCounts
        .map((c) => totalVoted == 0 ? 0.0 : (c / totalVoted) * 100)
        .toList();

    int? winningIndex;
    bool isTie = false;
    final tiedIndexes = <int>[];
    if (totalVoted > 0) {
      final maxCount = choiceCounts.reduce((a, b) => a > b ? a : b);
      final leaders = <int>[
        for (var i = 0; i < choiceCounts.length; i++)
          if (choiceCounts[i] == maxCount) i,
      ];
      if (leaders.length == 1) {
        winningIndex = leaders.first;
      } else {
        isTie = true;
        tiedIndexes.addAll(leaders);
      }
    }

    final voterUids = poll.participantUids
        .where((uid) => voteByUid.containsKey(uid))
        .toList();
    final nonVoterUids = poll.participantUids
        .where((uid) => !voteByUid.containsKey(uid))
        .toList();

    final report = PollReport(
      pollId: poll.pollId,
      title: poll.title,
      description: poll.description,
      choices: poll.choices,
      startDateTime: poll.startDateTime,
      endDateTime: poll.deadline,
      createdByManagerUid: poll.createdBy,
      totalEligible: totalEligible,
      totalVoted: totalVoted,
      totalNotVoted: totalNotVoted,
      participationPercent: participationPercent,
      choiceCounts: choiceCounts,
      choicePercentages: choicePercentages,
      winningChoiceIndex: winningIndex,
      isTie: isTie,
      tiedChoiceIndexes: tiedIndexes,
      voterUids: voterUids,
      nonVoterUids: nonVoterUids,
      generatedAt: DateTime.now(),
      privacyWasEnabled: poll.privacyEnabled,
    );

    final wonTheRace = await FirestoreService.endPollAndGenerateReport(
      poll: poll,
      report: report,
    );

    if (!wonTheRace) return; // another client already generated the report

    await _notifyManagerOfEnding(poll);
  }

  /// The manager notification on voting end — EXACT required strings per
  /// the explicit requirement: title "انتهى التصويت", body "انتهى
  /// التصويت على: {title}. اضغط لعرض النتيجة." [relatedPollId] routes the
  /// notification tap directly to PollReportScreen (see
  /// notification_center_screen.dart), not the old ManagerPollDetailScreen.
  Future<void> _notifyManagerOfEnding(AppPoll poll) async {
    await FirestoreService.saveNotification(
      AppNotification(
        notificationId: _uuid.v4(),
        recipientUid: poll.createdBy,
        type: NotificationType.pollEnded,
        title: 'انتهى التصويت',
        body: 'انتهى التصويت على: ${poll.title}. اضغط لعرض النتيجة.',
        relatedPollId: poll.pollId,
        createdAt: DateTime.now(),
      ),
    );
  }

  // ---------------- HELPERS ----------------

  /// Active employees only — direct pass-through used by the poll
  /// creation/edit screen's multi-select picker (mirrors
  /// CreateCriterionScreen's identical filter).
  List<AppUser> getActiveEmployees() {
    return FirestoreService.getAllEmployees()
        .where((u) => u.accountStatus == AccountStatus.active)
        .toList();
  }
}
