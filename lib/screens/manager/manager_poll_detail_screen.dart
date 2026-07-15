import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/poll_model.dart';
import '../../models/poll_vote_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/poll_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

/// Manager's poll detail view — requirement #4 in full: available at ANY
/// time (open OR closed, see [PollProvider.watchVotesForPoll] which is a
/// LIVE stream, not a one-time snapshot), listing every selected employee
/// with their current status (voted "نعم" / voted "لا" / لم يصوّت بعد),
/// shown with the employee's explicit name and the EXACT time they voted.
///
/// Also implements requirement #3's tie-handling clause: when
/// [poll.result] is [PollResult.tiePendingManagerDecision], shows a
/// dedicated "قرار المدير" action to manually resolve Yes/No, which
/// triggers the same "result only" notification to every participant
/// (see PollProvider.applyManagerTieDecision).
///
/// This SAME screen also serves as the permanent archive-detail view
/// (requirement #5) — a closed poll opened from the past-polls archive
/// renders identically, with the tie-decision action hidden once already
/// resolved (poll.result no longer tiePendingManagerDecision).
class ManagerPollDetailScreen extends StatelessWidget {
  const ManagerPollDetailScreen({super.key, required this.pollId});

  final String pollId;

  Future<void> _decideTie(BuildContext context, AppPoll poll) async {
    final decision = await showDialog<VoteChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قرار المدير — تعادل في التصويت'),
        content: const Text('انتهى التصويت بتعادل تام. اختر القرار النهائي:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, VoteChoice.no),
            child: const Text('لا'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, VoteChoice.yes),
            child: const Text('نعم'),
          ),
        ],
      ),
    );
    if (decision == null || !context.mounted) return;

    final managerUid = context.read<AuthProvider>().currentUser!.uid;
    try {
      await context.read<PollProvider>().applyManagerTieDecision(
        pollId: poll.pollId,
        decision: decision,
        managerUid: managerUid,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل قرارك وإشعار الموظفين')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذّر حفظ القرار: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = context.watch<PollProvider>().getPoll(pollId);

    if (poll == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل التصويت')),
        body: const Center(child: Text('التصويت غير متاح')),
      );
    }

    final needsTieDecision =
        poll.status == PollStatus.closed &&
        poll.result == PollResult.tiePendingManagerDecision;

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
            const SizedBox(height: 8),
            Text(
              'موعد الإغلاق: '
              '${intl.DateFormat('yyyy/MM/dd — HH:mm').format(poll.deadline)}',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            if (poll.status == PollStatus.closed) ...[
              const SizedBox(height: 16),
              _ResultSummaryCard(poll: poll),
            ],
            if (needsTieDecision) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.statusPending,
                ),
                onPressed: () => _decideTie(context, poll),
                icon: const Icon(Icons.gavel_outlined),
                label: const Text('اتخاذ القرار النهائي'),
              ),
            ],
            const SizedBox(height: 20),
            const Text(
              'حالة تصويت كل موظف',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<PollVote>>(
              stream: context.read<PollProvider>().watchVotesForPoll(
                poll.pollId,
              ),
              builder: (context, snapshot) {
                final votes = snapshot.data ?? const <PollVote>[];
                final voteByUid = {for (final v in votes) v.employeeUid: v};
                return Column(
                  children: poll.participantUids.map((uid) {
                    final employee = FirestoreService.getUser(uid);
                    final vote = voteByUid[uid];
                    return _EmployeeVoteStatusTile(
                      employeeName: employee?.name ?? uid,
                      vote: vote,
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultSummaryCard extends StatelessWidget {
  const _ResultSummaryCard({required this.poll});

  final AppPoll poll;

  @override
  Widget build(BuildContext context) {
    final String label;
    final Color color;
    switch (poll.result) {
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
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.bar_chart, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$label\nنعم: ${poll.yesCount ?? 0}  ·  لا: ${poll.noCount ?? 0}',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeVoteStatusTile extends StatelessWidget {
  const _EmployeeVoteStatusTile({required this.employeeName, this.vote});

  final String employeeName;
  final PollVote? vote;

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;
    final String statusLabel;

    if (vote == null) {
      icon = Icons.hourglass_empty;
      color = AppColors.textSecondary;
      statusLabel = 'لم يصوّت بعد';
    } else if (vote!.choice == VoteChoice.yes) {
      icon = Icons.thumb_up;
      color = AppColors.statusApproved;
      statusLabel = 'صوّت: نعم';
    } else {
      icon = Icons.thumb_down;
      color = AppColors.statusRejected;
      statusLabel = 'صوّت: لا';
    }

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(
          employeeName,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(statusLabel, style: TextStyle(color: color)),
        trailing: vote != null
            ? Text(
                intl.DateFormat('MM/dd HH:mm').format(vote!.votedAt),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              )
            : null,
      ),
    );
  }
}
