import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/poll_model.dart';
import '../models/poll_vote_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';

/// Manages the Poll ("تصويت") feature: creation, voting, live per-employee
/// status (manager view), and the auto-close + result-computation +
/// notification-dispatch pipeline.
///
/// AUTO-CLOSE ARCHITECTURE (documented explicitly — a genuinely new
/// problem for this codebase, see poll_model.dart doc comment): there is
/// no confirmed Cloud Functions / scheduled-backend infrastructure in this
/// project. The chosen mechanism is CLIENT-SIDE LAZY EVALUATION:
/// [_maybeAutoCloseOverduePolls] is called every time the live polls
/// stream emits a new snapshot (i.e. whenever ANY signed-in user's app has
/// the poll list loaded) and checks every still-`open` poll's `deadline`
/// against `DateTime.now()`. The FIRST client to observe an overdue poll
/// performs the close-and-notify write; the Firestore security rule (see
/// firestore.rules `polls/{pollId}` update rule) makes this transition
/// safe under a race between two clients (only the first `status ==
/// 'open'` write is accepted).
///
/// KNOWN LIMITATION (not silently glossed over): a poll only actually
/// closes once SOME signed-in user's client happens to load the poll list
/// after the deadline has passed — there is no guarantee this happens at
/// the exact deadline instant. If no one opens the app for hours after a
/// deadline, the poll remains (incorrectly) `open` in Firestore until
/// someone does. This is the same class of trade-off as every other
/// "date-derived" logic in this codebase (e.g. task overdue flags), which
/// are similarly evaluated on read, not via a background job.
class PollProvider extends ChangeNotifier {
  static const _uuid = Uuid();

  List<AppPoll> _allPolls = [];
  List<AppPoll> get allPolls {
    final sorted = List<AppPoll>.of(_allPolls)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(sorted);
  }

  List<AppPoll> get openPolls =>
      allPolls.where((p) => p.status == PollStatus.open).toList();

  List<AppPoll> get closedPolls =>
      allPolls.where((p) => p.status == PollStatus.closed).toList();

  PollProvider() {
    _listenAll();
  }

  void _listenAll() {
    FirestoreService.watchAllPolls().listen((polls) {
      _allPolls = polls;
      notifyListeners();
      // Fire-and-forget: check for overdue open polls on every update.
      // Errors are caught internally (see method doc) so a transient
      // Firestore failure here never crashes the listener subscription.
      _maybeAutoCloseOverduePolls(polls);
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
        .where((p) => p.participantUids.contains(employeeUid))
        .toList();
  }

  /// Creates a new poll. [deadline] is REQUIRED (non-nullable) at the type
  /// level — this is what makes "a poll must not be creatable without a
  /// deadline" (explicit hard requirement) impossible to violate from
  /// this provider's API surface, on top of the UI-level validation in the
  /// creation screen.
  Future<AppPoll> createPoll({
    required String title,
    required String description,
    required List<String> participantUids,
    required DateTime deadline,
    required String createdBy,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
  }) async {
    final now = DateTime.now();
    final poll = AppPoll(
      pollId: _uuid.v4(),
      title: title,
      description: description,
      attachmentUrl: attachmentUrl,
      attachmentName: attachmentName,
      attachmentType: attachmentType,
      participantUids: participantUids,
      deadline: deadline,
      status: PollStatus.open,
      createdBy: createdBy,
      createdAt: now,
    );
    await FirestoreService.savePoll(poll);
    return poll;
  }

  /// Casts or changes [employeeUid]'s vote on [pollId]. Enforces the
  /// "only before deadline" rule at the provider layer (the Firestore
  /// security rule is the authoritative enforcement — see firestore.rules
  /// — this is a fast client-side pre-check to give immediate UI feedback
  /// without a round trip).
  Future<void> castVote({
    required String pollId,
    required String employeeUid,
    required VoteChoice choice,
  }) async {
    final poll = getPoll(pollId);
    if (poll == null) {
      throw Exception('التصويت غير موجود');
    }
    if (poll.status != PollStatus.open || poll.isPastDeadline) {
      throw Exception('انتهى وقت التصويت، لا يمكن التصويت أو تغيير صوتك الآن');
    }
    final vote = PollVote(
      pollId: pollId,
      employeeUid: employeeUid,
      choice: choice,
      votedAt: DateTime.now(),
    );
    await FirestoreService.castOrChangeVote(pollId, vote);
  }

  Stream<PollVote?> watchMyVote(String pollId, String employeeUid) =>
      FirestoreService.watchMyVote(pollId, employeeUid);

  /// Manager-only live vote list — used by the manager's poll detail
  /// screen (requirement #4: works both while open AND after closing).
  Stream<List<PollVote>> watchVotesForPoll(String pollId) =>
      FirestoreService.watchVotesForPoll(pollId);

  /// Applies the manager's manual decision on a tied poll (requirement
  /// #3's tie-handling clause) and notifies every participant of the
  /// final decision (same "result only, no per-vote detail" rule as the
  /// automatic-close notification below).
  Future<void> applyManagerTieDecision({
    required String pollId,
    required VoteChoice decision,
    required String managerUid,
  }) async {
    final result = decision == VoteChoice.yes ? PollResult.yes : PollResult.no;
    await FirestoreService.applyManagerTieDecision(
      pollId: pollId,
      decision: result,
      managerUid: managerUid,
    );
    final poll = getPoll(pollId);
    if (poll == null) return;
    await _notifyParticipantsOfResult(poll, result);
  }

  /// Scans every currently-`open` poll and closes any whose [deadline] has
  /// passed — see class-level doc comment for the full auto-close
  /// architecture rationale/limitation. Safe to call redundantly from
  /// multiple clients (the security rule guarantees at most one write
  /// succeeds per poll).
  Future<void> _maybeAutoCloseOverduePolls(List<AppPoll> polls) async {
    final overdue = polls.where(
      (p) => p.status == PollStatus.open && p.isPastDeadline,
    );
    for (final poll in overdue) {
      try {
        await _closeAndNotify(poll);
      } catch (e) {
        // Expected/benign in the common case where another client's
        // request already closed this poll first (the security rule
        // rejects the second write with a permission error) — logged only
        // in debug builds, never surfaced to the user, since this is a
        // background reconciliation pass, not a user-initiated action.
        if (kDebugMode) {
          debugPrint('PollProvider: auto-close skipped for ${poll.pollId}: $e');
        }
      }
    }
  }

  /// Computes the result (majority wins; exact 50/50 => tie), persists the
  /// closure fields, then dispatches the two DIFFERENT notification
  /// payloads (manager: full by-name detail; employees: result only) —
  /// per explicit requirement #3.
  Future<void> _closeAndNotify(AppPoll poll) async {
    final votes = await FirestoreService.getVotesForPoll(poll.pollId);
    final yesCount = votes.where((v) => v.choice == VoteChoice.yes).length;
    final noCount = votes.where((v) => v.choice == VoteChoice.no).length;

    final PollResult result;
    if (yesCount == noCount) {
      result = PollResult.tiePendingManagerDecision;
    } else if (yesCount > noCount) {
      result = PollResult.yes;
    } else {
      result = PollResult.no;
    }

    await FirestoreService.closePoll(
      pollId: poll.pollId,
      result: result,
      yesCount: yesCount,
      noCount: noCount,
    );

    final closedPoll = poll.copyWith(
      status: PollStatus.closed,
      result: result,
      yesCount: yesCount,
      noCount: noCount,
      closedAt: DateTime.now(),
    );

    await _notifyManagerOfClosure(closedPoll, votes);
    await _notifyParticipantsOfResult(closedPoll, result);
  }

  /// Manager notification: FULL detail, by employee name, per requirement
  /// #3 ("المدير: بالنتيجة النهائية والتفصيل الكامل لكل صوت بالاسم"). The
  /// tie case additionally uses [NotificationType.pollTieNeedsDecision] so
  /// the manager's notification can be visually distinguished as requiring
  /// action, per requirement #3's "إشعار خاص للمدير لاتخاذ القرار يدويًا".
  Future<void> _notifyManagerOfClosure(
    AppPoll poll,
    List<PollVote> votes,
  ) async {
    final voteByUid = {for (final v in votes) v.employeeUid: v};
    final breakdown = <Map<String, dynamic>>[];
    for (final uid in poll.participantUids) {
      final user = FirestoreService.getUser(uid);
      final vote = voteByUid[uid];
      breakdown.add({
        'uid': uid,
        'name': user?.name ?? uid,
        'choice': vote?.choice.name,
        'votedAt': vote?.votedAt.toIso8601String(),
      });
    }

    final isTie = poll.result == PollResult.tiePendingManagerDecision;
    final resultLabel = _resultLabelAr(poll.result);

    await FirestoreService.saveNotification(
      AppNotification(
        notificationId: _uuid.v4(),
        recipientUid: poll.createdBy,
        type: isTie
            ? NotificationType.pollTieNeedsDecision
            : NotificationType.pollClosed,
        title: isTie
            ? 'تعادل في التصويت: ${poll.title}'
            : 'أُغلق التصويت: ${poll.title}',
        body: isTie
            ? 'التصويت انتهى بتعادل (${poll.yesCount}/${poll.noCount}) — '
                  'يتطلب قرارك.'
            : 'النتيجة النهائية: $resultLabel '
                  '(نعم: ${poll.yesCount} / لا: ${poll.noCount})',
        relatedPollId: poll.pollId,
        payload: {
          'result': poll.result?.name,
          'yesCount': poll.yesCount,
          'noCount': poll.noCount,
          'voteBreakdown': breakdown,
        },
        createdAt: DateTime.now(),
      ),
    );
  }

  /// Employee notification: result ONLY (Yes/No/Tie) — explicitly WITHOUT
  /// any per-vote detail, per requirement #3
  /// ("كل الموظفين المشاركين: بالنتيجة النهائية فقط ... بدون تفاصيل من
  /// صوّت بماذا"). Sent to every participant, called both from the
  /// automatic close path AND from [applyManagerTieDecision] (so
  /// participants are also informed once the manager breaks a tie).
  Future<void> _notifyParticipantsOfResult(
    AppPoll poll,
    PollResult result,
  ) async {
    final resultLabel = _resultLabelAr(result);
    for (final uid in poll.participantUids) {
      await FirestoreService.saveNotification(
        AppNotification(
          notificationId: _uuid.v4(),
          recipientUid: uid,
          type: NotificationType.pollClosed,
          title: 'نتيجة التصويت: ${poll.title}',
          body: 'النتيجة النهائية: $resultLabel',
          relatedPollId: poll.pollId,
          payload: {'result': result.name},
          createdAt: DateTime.now(),
        ),
      );
    }
  }

  String _resultLabelAr(PollResult? result) {
    switch (result) {
      case PollResult.yes:
        return 'نعم';
      case PollResult.no:
        return 'لا';
      case PollResult.tiePendingManagerDecision:
        return 'تعادل - يتطلب قرار المدير';
      case null:
        return '—';
    }
  }

  /// Active employees only — direct pass-through used by the poll
  /// creation screen's multi-select picker (mirrors
  /// CreateCriterionScreen's identical filter).
  List<AppUser> getActiveEmployees() {
    return FirestoreService.getAllEmployees()
        .where((u) => u.accountStatus == AccountStatus.active)
        .toList();
  }
}
