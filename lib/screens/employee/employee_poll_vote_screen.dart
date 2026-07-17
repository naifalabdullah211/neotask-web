import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/poll_model.dart';
import '../../models/poll_vote_model.dart';
import '../../providers/poll_provider.dart';
import '../../theme/app_theme.dart';

/// Employee's single-poll voting screen — UPGRADED (Phase E) from the
/// original binary Yes/No form into a DYNAMIC multi-choice voting UI
/// built from [AppPoll.choices]:
///   - single-tap voting on any of the poll's choices, changeable any
///     time before the deadline (identical UX principle as before, now
///     generalized to N choices instead of exactly 2).
///   - confirmation message "تم تسجيل صوتك" after every successful vote.
///   - the result/other-employees' votes are NEVER shown here while
///     active — this screen deliberately reads ONLY [watchMyVote] (never
///     [watchVotesForPoll], which is the manager-only full-detail
///     stream), so there is no code path by which this screen could leak
///     another employee's vote even by accident.
///   - once the poll is [PollStatus.ended], shows the FINAL RESULT ONLY
///     (winning choice / tie) — still no per-employee breakdown, per the
///     explicit secrecy requirement.
///
/// CLIENT-SIDE DEADLINE GUARD (documented, see poll_model.dart /
/// poll_provider.dart doc comments on the auto-close architecture and its
/// acknowledged limitation): voting is blocked here via
/// `!poll.votingOpen` (active AND not past deadline), REGARDLESS of
/// whether `status` has already flipped to `ended` in Firestore yet —
/// the AUTHORITATIVE cutoff remains the server-time `request.time` check
/// in firestore.rules, this is only a fast client-side pre-check.
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

  Future<void> _vote(int choiceIndex) async {
    setState(() => _submitting = true);
    try {
      await context.read<PollProvider>().castVote(
        pollId: widget.pollId,
        employeeUid: widget.employeeUid,
        choiceIndex: choiceIndex,
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

    final votingBlocked = !poll.votingOpen;

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
            if (poll.status == PollStatus.active)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _remainingLabel(poll.deadline),
                  style: const TextStyle(
                    color: AppColors.statusPending,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 24),

            if (votingBlocked)
              _ResultOnlyView(poll: poll)
            else
              _VotingView(
                pollId: widget.pollId,
                employeeUid: widget.employeeUid,
                choices: poll.choices,
                submitting: _submitting,
                onVote: _vote,
              ),
          ],
        ),
      ),
    );
  }

  String _remainingLabel(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) return 'ينتهي الآن...';
    final d = remaining.inDays;
    final h = remaining.inHours % 24;
    final m = remaining.inMinutes % 60;
    if (d > 0) return 'يتبقى: $d يوم و $h ساعة';
    if (h > 0) return 'يتبقى: $h ساعة و $m دقيقة';
    return 'يتبقى: $m دقيقة';
  }
}

/// While the poll is active: shows one button per choice + the
/// employee's OWN current vote (if any), via [watchMyVote] ONLY — never
/// any aggregate or other-employee data, per the secrecy requirement.
class _VotingView extends StatelessWidget {
  const _VotingView({
    required this.pollId,
    required this.employeeUid,
    required this.choices,
    required this.submitting,
    required this.onVote,
  });

  final String pollId;
  final String employeeUid;
  final List<String> choices;
  final bool submitting;
  final void Function(int choiceIndex) onVote;

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
                  'صوتك الحالي: '
                  '${myVote.choiceIndex >= 0 && myVote.choiceIndex < choices.length ? choices[myVote.choiceIndex] : "-"}'
                  ' — يمكنك تغييره حتى موعد الإغلاق',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ...List.generate(choices.length, (index) {
              final selected = myVote?.choiceIndex == index;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selected
                          ? AppColors.statusApproved
                          : AppColors.deepBlue.withValues(alpha: 0.85),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: submitting ? null : () => onVote(index),
                    icon: Icon(
                      selected
                          ? Icons.check_circle_outline
                          : Icons.radio_button_unchecked,
                    ),
                    label: Text(choices[index]),
                  ),
                ),
              );
            }),
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

/// Shown once the poll is ended (or past its deadline while status has
/// not yet flipped) — the FINAL RESULT ONLY, per the explicit
/// "result only, no per-vote detail for employees" requirement.
/// Deliberately never queries the votes subcollection at all — reads
/// only the poll's own persisted aggregate fields
/// (winningChoiceIndex/isTie/tiedChoiceIndexes/choiceCounts).
class _ResultOnlyView extends StatelessWidget {
  const _ResultOnlyView({required this.poll});

  final AppPoll poll;

  @override
  Widget build(BuildContext context) {
    if (poll.status == PollStatus.cancelled) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'تم إلغاء هذا التصويت من قِبل المدير',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (poll.status != PollStatus.ended) {
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
    if ((poll.isTie ?? false)) {
      label = 'تعادل - يتطلب قرار المدير';
      color = AppColors.statusPending;
    } else if (poll.winningChoiceIndex != null) {
      final idx = poll.winningChoiceIndex!;
      final winnerLabel = (idx >= 0 && idx < poll.choices.length)
          ? poll.choices[idx]
          : 'غير معروف';
      label = 'النتيجة النهائية: $winnerLabel';
      color = AppColors.statusApproved;
    } else {
      label = 'النتيجة غير متاحة';
      color = AppColors.textSecondary;
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
