import 'dart:async';

import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/poll_model.dart';
import '../../models/poll_vote_model.dart';
import '../../providers/locale_provider.dart';
import '../../providers/poll_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart' show AppPill;

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
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _vote(int choiceIndex) async {
    setState(() => _submitting = true);
    try {
      await context.read<PollProvider>().castVote(
        pollId: widget.pollId,
        employeeUid: widget.employeeUid,
        choiceIndex: choiceIndex,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل صوتك')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
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
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('التصويت')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('التصويت غير متاح'),
          ),
        ),
      );
    }

    final votingBlocked = !poll.votingOpen;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: Text(
          poll.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            _PollOverviewCard(poll: poll),
            const SizedBox(height: AppSpacing.lg),
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
}

class _PollOverviewCard extends StatelessWidget {
  const _PollOverviewCard({required this.poll});

  final AppPoll poll;

  @override
  Widget build(BuildContext context) {
    final english = context.watch<LocaleProvider>().languageCode == 'en';
    final statusColor = switch (poll.status) {
      PollStatus.active => AppColors.statusApproved,
      PollStatus.ended => AppColors.steel,
      PollStatus.cancelled => AppColors.statusRejected,
      PollStatus.draft => AppColors.textSecondary,
    };
    final statusLabel = switch (poll.status) {
      PollStatus.active => context.tr('نشط'),
      PollStatus.ended => context.tr('منتهي'),
      PollStatus.cancelled => context.tr('ملغى'),
      PollStatus.draft => context.tr('مسودة'),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(
                    Icons.how_to_vote_outlined,
                    color: statusColor,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poll.title,
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (poll.description.trim().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          poll.description,
                          style: AppTextStyles.bodySecondary.copyWith(
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      AppPill(color: statusColor, label: statusLabel),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _InfoPill(
                  icon: Icons.event_busy_outlined,
                  label: '${context.tr('موعد الإغلاق')}: '
                      '${intl.DateFormat('yyyy/MM/dd — HH:mm').format(poll.deadline)}',
                ),
                if (poll.status == PollStatus.active)
                  _InfoPill(
                    icon: Icons.schedule_outlined,
                    label: _remainingLabel(context, poll.deadline),
                    color: AppColors.statusPending,
                  ),
                if (poll.privacyEnabled)
                  _InfoPill(
                    icon: Icons.privacy_tip_outlined,
                    label: english ? 'Private voting' : 'تصويت خاص',
                    color: AppColors.deepBlue,
                  ),
              ],
            ),
          ),
          if (poll.attachmentUrl != null) ...[
            const Divider(height: 1),
            InkWell(
              onTap: () => launchUrl(Uri.parse(poll.attachmentUrl!)),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Icon(
                      poll.attachmentType == 'image'
                          ? Icons.image_outlined
                          : Icons.attach_file_rounded,
                      color: AppColors.deepBlue,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        poll.attachmentName ?? (english ? 'Attachment' : 'مرفق'),
                        style: AppTextStyles.cardTitle,
                      ),
                    ),
                    const Icon(
                      Icons.open_in_new_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _remainingLabel(BuildContext context, DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) return context.tr('ينتهي الآن...');
    final d = remaining.inDays;
    final h = remaining.inHours % 24;
    final m = remaining.inMinutes % 60;
    if (d > 0) {
      return '${context.tr('يتبقى')}: $d ${context.tr('يوم')} · '
          '$h ${context.tr('ساعة')}';
    }
    if (h > 0) {
      return '${context.tr('يتبقى')}: $h ${context.tr('ساعة')} · '
          '$m ${context.tr('دقيقة')}';
    }
    return '${context.tr('يتبقى')}: $m ${context.tr('دقيقة')}';
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    this.color = AppColors.deepBlue,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: color.withValues(alpha: .14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

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
    final english = context.watch<LocaleProvider>().languageCode == 'en';
    return StreamBuilder<PollVote?>(
      stream: context.read<PollProvider>().watchMyVote(pollId, employeeUid),
      builder: (context, snapshot) {
        final myVote = snapshot.data;
        final currentChoice = myVote != null &&
                myVote.choiceIndex >= 0 &&
                myVote.choiceIndex < choices.length
            ? choices[myVote.choiceIndex]
            : '-';

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.tr('اختيارات التصويت'),
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      english
                          ? 'Choose one option. You can change your vote until the poll closes.'
                          : 'اختر خيارًا واحدًا، ويمكنك تغيير صوتك حتى موعد الإغلاق',
                      style: AppTextStyles.bodySecondary,
                    ),
                  ],
                ),
              ),
              if (myVote != null) ...[
                const Divider(height: 1),
                Container(
                  margin: const EdgeInsets.all(AppSpacing.lg),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.mintAccent.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_outline_rounded,
                        color: AppColors.statusApproved,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          english
                              ? 'Your current vote: $currentChoice'
                              : 'صوتك الحالي: $currentChoice',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    ...List.generate(choices.length, (index) {
                      final selected = myVote?.choiceIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Material(
                          color: selected
                              ? AppColors.mintAccent.withValues(alpha: .12)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: InkWell(
                            onTap: submitting ? null : () => onVote(index),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 15,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.mintAccent
                                      : AppColors.divider,
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    selected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: selected
                                        ? AppColors.statusApproved
                                        : AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      choices[index],
                                      style: TextStyle(
                                        color: AppColors.textPrimary,
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  if (submitting && selected)
                                    const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            context.tr(
                              'نتيجة التصويت سرّية ولن تظهر إلا بعد إغلاق التصويت',
                            ),
                            textAlign: TextAlign.center,
                            style: AppTextStyles.bodySecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ResultOnlyView extends StatelessWidget {
  const _ResultOnlyView({required this.poll});

  final AppPoll poll;

  @override
  Widget build(BuildContext context) {
    final english = context.watch<LocaleProvider>().languageCode == 'en';

    if (poll.status == PollStatus.cancelled) {
      return _ResultCard(
        icon: Icons.cancel_outlined,
        color: AppColors.statusRejected,
        title: context.tr('تم إلغاء هذا التصويت من قِبل المدير'),
        subtitle: english
            ? 'No further voting is available.'
            : 'لم يعد التصويت متاحًا على هذا الموضوع',
      );
    }

    if (poll.status != PollStatus.ended) {
      return _ResultCard(
        icon: Icons.hourglass_top_rounded,
        color: AppColors.statusPending,
        title: context.tr(
          'انتهى موعد التصويت — جارٍ إغلاق التصويت وحساب النتيجة...',
        ),
        subtitle: english
            ? 'The final result will appear here once closing completes.'
            : 'ستظهر النتيجة النهائية هنا بعد اكتمال الإغلاق',
      );
    }

    if (poll.isTie ?? false) {
      return _ResultCard(
        icon: Icons.balance_rounded,
        color: AppColors.statusPending,
        title: english ? 'Final result: Tie' : 'النتيجة النهائية: تعادل',
        subtitle: english
            ? 'The final tie-break decision is with the manager.'
            : 'القرار النهائي للتعادل لدى المدير',
      );
    }

    if (poll.winningChoiceIndex != null) {
      final idx = poll.winningChoiceIndex!;
      final winnerLabel = idx >= 0 && idx < poll.choices.length
          ? poll.choices[idx]
          : (english ? 'Unknown' : 'غير معروف');
      return _ResultCard(
        icon: Icons.emoji_events_outlined,
        color: AppColors.statusApproved,
        title: english
            ? 'Final result: $winnerLabel'
            : 'النتيجة النهائية: $winnerLabel',
        subtitle: english
            ? 'Only the final result is shown here; individual votes remain hidden.'
            : 'تظهر النتيجة النهائية فقط، وتبقى أصوات الأفراد غير معروضة',
      );
    }

    return _ResultCard(
      icon: Icons.info_outline_rounded,
      color: AppColors.textSecondary,
      title: english ? 'Result unavailable' : 'النتيجة غير متاحة',
      subtitle: english
          ? 'There is no final result to display.'
          : 'لا توجد نتيجة نهائية متاحة للعرض',
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: .28)),
      ),
      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(icon, color: color, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySecondary.copyWith(fontSize: 13),
          ),
        ],
      ),
    );
  }
}
