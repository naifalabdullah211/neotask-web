import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/poll_model.dart';
import '../../models/poll_vote_model.dart';
import '../../providers/poll_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart' show AppPill;
import 'edit_poll_screen.dart';
import 'poll_report_screen.dart';

/// Manager's poll detail view — UPGRADED (Phase E) for the full 4-status /
/// multi-choice lifecycle. Displays every required data point per the
/// explicit specification:
///   عنوان، وصف، الاختيارات المتاحة، تاريخ/وقت البدء، تاريخ/وقت الانتهاء،
///   الحالة الحالية، عدد الموظفين المستحقين، عدد من صوّت، عدد من لم يصوّت،
///   نسبة المشاركة، الوقت المتبقي (أثناء النشاط)
/// and offers the manager actions appropriate to the poll's current
/// status: edit (draft/active), "حث الموظفين على التصويت" (active only),
/// cancel (draft/active), and — once ended — a direct route into the
/// PERMANENT [PollReportScreen] rather than duplicating the report UI
/// here. Available for BOTH active and ended polls, opened from either
/// the manager's live list or the past-polls archive.
class ManagerPollDetailScreen extends StatefulWidget {
  const ManagerPollDetailScreen({super.key, required this.pollId});

  final String pollId;

  @override
  State<ManagerPollDetailScreen> createState() =>
      _ManagerPollDetailScreenState();
}

class _ManagerPollDetailScreenState extends State<ManagerPollDetailScreen> {
  Timer? _ticker;
  bool _reminding = false;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    // Drives the "الوقت المتبقي" live countdown while the poll is active.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _remindNotVoted(AppPoll poll) async {
    setState(() => _reminding = true);
    try {
      final count = await context.read<PollProvider>().remindNotYetVoted(
        poll.pollId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'جميع الموظفين المستحقين قد صوّتوا بالفعل'
                : 'تم إرسال تذكير إلى $count موظف لم يصوّت بعد',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذّر إرسال التذكير: $e')));
      }
    } finally {
      if (mounted) setState(() => _reminding = false);
    }
  }

  Future<void> _cancelPoll(AppPoll poll) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد إلغاء التصويت'),
        content: const Text(
          'سيتم إلغاء هذا التصويت نهائيًا. الأصوات الحالية (إن وُجدت) '
          'ستبقى محفوظة، ولكن لن يتم إنشاء تقرير نهائي له ولن يُقبل أي '
          'تصويت جديد. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('تراجع'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusRejected,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تأكيد الإلغاء'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _cancelling = true);
    try {
      final managerUid = context
          .read<PollProvider>()
          .getPoll(poll.pollId)!
          .createdBy;
      await context.read<PollProvider>().cancelPoll(poll.pollId, managerUid);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إلغاء التصويت')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذّر إلغاء التصويت: $e')));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final poll = context.watch<PollProvider>().getPoll(widget.pollId);

    if (poll == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('تفاصيل التصويت')),
        body: const Center(child: Text('التصويت غير متاح')),
      );
    }

    final canEditOrCancel =
        poll.status == PollStatus.draft || poll.status == PollStatus.active;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(poll.title),
        actions: [
          if (canEditOrCancel)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'تعديل التصويت',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EditPollScreen(pollId: poll.pollId),
                ),
              ),
            ),
          if (poll.status == PollStatus.ended)
            IconButton(
              icon: const Icon(Icons.assessment_outlined),
              tooltip: 'عرض التقرير النهائي',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PollReportScreen(pollId: poll.pollId),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _StatusRow(poll: poll),
            const SizedBox(height: 12),
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

            // ---- اختيارات التصويت ----
            const Text(
              'اختيارات التصويت',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: poll.choices
                  .map((c) => AppPill(color: AppColors.deepBlue, label: c))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // ---- تواريخ البدء/الانتهاء ----
            _InfoTile(
              icon: Icons.play_circle_outline,
              label: 'موعد البدء',
              value: intl.DateFormat(
                'yyyy/MM/dd — HH:mm',
              ).format(poll.startDateTime),
            ),
            _InfoTile(
              icon: Icons.event_busy_outlined,
              label: 'موعد الانتهاء',
              value: intl.DateFormat(
                'yyyy/MM/dd — HH:mm',
              ).format(poll.deadline),
            ),
            if (poll.status == PollStatus.active)
              _InfoTile(
                icon: Icons.timer_outlined,
                label: 'الوقت المتبقي',
                value: _remainingLabel(poll.deadline),
                valueColor: AppColors.statusPending,
              ),
            if (poll.privacyEnabled)
              const _InfoTile(
                icon: Icons.privacy_tip_outlined,
                label: 'الخصوصية',
                value: 'مفعّلة — لا يتم إظهار اختيار أي موظف بعينه',
              ),
            const SizedBox(height: 16),

            // ---- إحصاءات المشاركة ----
            StreamBuilder<List<PollVote>>(
              stream: context.read<PollProvider>().watchVotesForPoll(
                poll.pollId,
              ),
              builder: (context, snapshot) {
                final votes = snapshot.data ?? const <PollVote>[];
                final totalEligible = poll.participantUids.length;
                final totalVoted = votes.length;
                final totalNotVoted = totalEligible - totalVoted;
                final participation = totalEligible == 0
                    ? 0.0
                    : (totalVoted / totalEligible) * 100;
                return _ParticipationSummaryCard(
                  totalEligible: totalEligible,
                  totalVoted: totalVoted,
                  totalNotVoted: totalNotVoted,
                  participationPercent: participation,
                );
              },
            ),
            const SizedBox(height: 16),

            // ---- actions ----
            if (poll.status == PollStatus.active) ...[
              FilledButton.icon(
                onPressed: _reminding ? null : () => _remindNotVoted(poll),
                icon: _reminding
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.campaign_outlined),
                label: const Text('حث الموظفين على التصويت'),
              ),
              const SizedBox(height: 10),
            ],
            if (canEditOrCancel) ...[
              OutlinedButton.icon(
                onPressed: _cancelling ? null : () => _cancelPoll(poll),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.statusRejected,
                  side: const BorderSide(color: AppColors.statusRejected),
                ),
                icon: _cancelling
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.cancel_outlined),
                label: const Text('إلغاء التصويت'),
              ),
              const SizedBox(height: 10),
            ],
            if (poll.status == PollStatus.ended)
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PollReportScreen(pollId: poll.pollId),
                  ),
                ),
                icon: const Icon(Icons.assessment_outlined),
                label: const Text('عرض التقرير النهائي الكامل'),
              ),

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
                      choices: poll.choices,
                      privacyEnabled: poll.privacyEnabled,
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

  String _remainingLabel(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) return 'ينتهي الآن...';
    final d = remaining.inDays;
    final h = remaining.inHours % 24;
    final m = remaining.inMinutes % 60;
    if (d > 0) return '$d يوم و $h ساعة';
    if (h > 0) return '$h ساعة و $m دقيقة';
    return '$m دقيقة';
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.poll});

  final AppPoll poll;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    switch (poll.status) {
      case PollStatus.draft:
        color = AppColors.textSecondary;
        label = 'مسودة';
        break;
      case PollStatus.active:
        color = AppColors.statusApproved;
        label = 'نشط';
        break;
      case PollStatus.ended:
        color = (poll.isTie ?? false)
            ? AppColors.statusPending
            : AppColors.textSecondary;
        label = (poll.isTie ?? false) ? 'منتهي - تعادل' : 'منتهي';
        break;
      case PollStatus.cancelled:
        color = AppColors.statusRejected;
        label = 'مُلغى';
        break;
    }
    return AppPill(color: color, label: label);
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.w600, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}

class _ParticipationSummaryCard extends StatelessWidget {
  const _ParticipationSummaryCard({
    required this.totalEligible,
    required this.totalVoted,
    required this.totalNotVoted,
    required this.participationPercent,
  });

  final int totalEligible;
  final int totalVoted;
  final int totalNotVoted;
  final double participationPercent;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'إحصاءات المشاركة',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _statChip('مستحقّون', '$totalEligible', AppColors.deepBlue),
                const SizedBox(width: 8),
                _statChip('صوّتوا', '$totalVoted', AppColors.statusApproved),
                const SizedBox(width: 8),
                _statChip(
                  'لم يصوّتوا',
                  '$totalNotVoted',
                  AppColors.statusRejected,
                ),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (participationPercent / 100).clamp(0, 1),
                minHeight: 10,
                backgroundColor: AppColors.divider,
                color: AppColors.statusApproved,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'نسبة المشاركة: ${participationPercent.toStringAsFixed(1)}%',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statChip(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, color: color),
            ),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmployeeVoteStatusTile extends StatelessWidget {
  const _EmployeeVoteStatusTile({
    required this.employeeName,
    required this.choices,
    required this.privacyEnabled,
    this.vote,
  });

  final String employeeName;
  final List<String> choices;
  final bool privacyEnabled;
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
    } else if (privacyEnabled) {
      // Privacy toggle: never reveal WHICH choice, only the fact of voting.
      icon = Icons.check_circle_outline;
      color = AppColors.statusApproved;
      statusLabel = 'صوّت';
    } else {
      icon = Icons.check_circle_outline;
      color = AppColors.statusApproved;
      final idx = vote!.choiceIndex;
      final choiceLabel = (idx >= 0 && idx < choices.length)
          ? choices[idx]
          : 'اختيار غير معروف';
      statusLabel = 'صوّت: $choiceLabel';
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
