import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/poll_model.dart';
import '../../models/poll_vote_model.dart';
import '../../providers/poll_provider.dart';
import '../../theme/app_theme.dart';

/// Employee's single-poll voting screen — requirement #2 in full:
///   - Yes/No single-tap voting, changeable any time before the deadline.
///   - Confirmation message "تم تسجيل صوتك" after every successful vote.
///   - The result/other-employees' votes are NEVER shown here while open
///     — this screen deliberately reads ONLY [watchMyVote] (never
///     [watchVotesForPoll], which is the manager-only full-detail stream),
///     so there is no code path by which this screen could leak another
///     employee's vote even by accident.
///   - Once closed, shows the FINAL RESULT ONLY (Yes/No/Tie) — still no
///     per-employee breakdown, per the explicit secrecy requirement.
///
/// CLIENT-SIDE DEADLINE GUARD (documented, see poll_model.dart /
/// poll_provider.dart doc comments on the auto-close architecture and its
/// acknowledged limitation): voting is blocked here the instant
/// `poll.isPastDeadline` is true, REGARDLESS of whether `status` has
/// already flipped to `closed` in Firestore yet — this closes the small
/// window where the persisted status might lag the real deadline because
/// no client has triggered the auto-close write yet.
class EmployeePollVoteScreen extends StatefulWidget {
  const EmployeePollVoteScreen({
    super.key,
    required this.pollId,
    required this.employeeUid,
  });

  final String pollId;
  final String employeeUid;

  @override
  State<EmployeePollVoteScreen> createState() => _EmployeePollVoteScreenState();
}

class _EmployeePollVoteScreenState extends State<EmployeePollVoteScreen> {
  bool _submitting = false;

  Future<void> _vote(VoteChoice choice) async {
    setState(() => _submitting = true);
    try {
      await context.read<PollProvider>().castVote(
        pollId: widget.pollId,
        employeeUid: widget.employeeUid,
        choice: choice,
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم تسجيل صوتك')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = context.watch<PollProvider>().getPoll(widget.pollId);

    if (poll == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('التصويت')),
        body: const Center(child: Text('التصويت غير متاح')),
      );
    }

    final votingBlocked = poll.status != PollStatus.open || poll.isPastDeadline;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(poll.title)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (poll.description.isNotEmpty) ...[
              Text(poll.description),
              const SizedBox(height: 12),
            ],
            if (poll.attachmentUrl != null)
              Card(
                child: ListTile(
                  leading: Icon(
                    poll.attachmentType == 'image'
                        ? Icons.image_outlined
                        : Icons.picture_as_pdf_outlined,
                    color: AppColors.deepBlue,
                  ),
                  title: Text(poll.attachmentName ?? 'مرفق'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () => launchUrl(Uri.parse(poll.attachmentUrl!)),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              'موعد الإغلاق: ${intl.DateFormat('yyyy/MM/dd — HH:mm').format(poll.deadline)}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),

            if (votingBlocked)
              _ResultOnlyView(poll: poll)
            else
              _VotingView(
                pollId: widget.pollId,
                employeeUid: widget.employeeUid,
                submitting: _submitting,
                onVote: _vote,
              ),
          ],
        ),
      ),
    );
  }
}

/// While the poll is open: shows Yes/No buttons + the employee's OWN
/// current vote (if any), via [watchMyVote] ONLY — never any aggregate or
/// other-employee data, per the secrecy requirement.
class _VotingView extends StatelessWidget {
  const _VotingView({
    required this.pollId,
    required this.employeeUid,
    required this.submitting,
    required this.onVote,
  });

  final String pollId;
  final String employeeUid;
  final bool submitting;
  final void Function(VoteChoice choice) onVote;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<PollVote?>(
      stream: context.read<PollProvider>().watchMyVote(pollId, employeeUid),
      builder: (context, snapshot) {
        final myVote = snapshot.data;
        return Column(
          children: [
            if (myVote != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  'صوتك الحالي: ${myVote.choice == VoteChoice.yes ? "نعم" : "لا"}'
                  ' — يمكنك تغييره حتى موعد الإغلاق',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: myVote?.choice == VoteChoice.yes
                          ? AppColors.statusApproved
                          : AppColors.statusApproved.withValues(alpha: 0.75),
                    ),
                    onPressed: submitting ? null : () => onVote(VoteChoice.yes),
                    icon: const Icon(Icons.thumb_up_outlined),
                    label: const Text('نعم'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: myVote?.choice == VoteChoice.no
                          ? AppColors.statusRejected
                          : AppColors.statusRejected.withValues(alpha: 0.75),
                    ),
                    onPressed: submitting ? null : () => onVote(VoteChoice.no),
                    icon: const Icon(Icons.thumb_down_outlined),
                    label: const Text('لا'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'نتيجة التصويت سرّية ولن تظهر إلا بعد إغلاق التصويت',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ],
        );
      },
    );
  }
}

/// Shown once the poll is closed (or past its deadline) — the FINAL
/// RESULT ONLY, per the explicit "result only, no per-vote detail for
/// employees" requirement. Deliberately never queries the votes
/// subcollection at all.
class _ResultOnlyView extends StatelessWidget {
  const _ResultOnlyView({required this.poll});

  final dynamic poll;

  @override
  Widget build(BuildContext context) {
    final AppPoll p = poll as AppPoll;
    if (p.status != PollStatus.closed) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'انتهى موعد التصويت — جارٍ إغلاق التصويت وحساب النتيجة...',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final String label;
    final Color color;
    switch (p.result) {
      case PollResult.yes:
        label = 'النتيجة النهائية: نعم';
        color = AppColors.statusApproved;
        break;
      case PollResult.no:
        label = 'النتيجة النهائية: لا';
        color = AppColors.statusRejected;
        break;
      case PollResult.tiePendingManagerDecision:
        label = 'تعادل - يتطلب قرار المدير';
        color = AppColors.statusPending;
        break;
      case null:
        label = 'النتيجة غير متاحة';
        color = AppColors.textSecondary;
        break;
    }

    return Card(
      color: color.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(Icons.how_to_vote_outlined, size: 40, color: color),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
