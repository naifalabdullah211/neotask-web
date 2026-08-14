import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import '../models/poll_model.dart';
import '../theme/app_theme.dart';
import 'status_chip.dart' show AppPill;

class PollCard extends StatefulWidget {
  const PollCard({super.key, required this.poll, required this.onTap});

  final AppPoll poll;
  final VoidCallback onTap;

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.poll.status == PollStatus.active) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accentColor(poll).withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.how_to_vote_outlined,
                  color: _accentColor(poll),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(poll.title, style: AppTextStyles.cardTitle),
                    if (poll.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        poll.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySecondary,
                      ),
                    ],
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _PollStatusBadge(poll: poll),
                        Text(
                          _secondaryLabel(context, poll),
                          style: AppTextStyles.bodySecondary.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentColor(AppPoll poll) {
    switch (poll.status) {
      case PollStatus.draft:
        return AppColors.textSecondary;
      case PollStatus.active:
        return AppColors.statusApproved;
      case PollStatus.cancelled:
        return AppColors.statusRejected;
      case PollStatus.ended:
        return (poll.isTie ?? false)
            ? AppColors.statusPending
            : AppColors.steel;
    }
  }

  String _secondaryLabel(BuildContext context, AppPoll poll) {
    switch (poll.status) {
      case PollStatus.draft:
        return '${context.tr('مسودة')} — ${context.tr('غير مرئي للموظفين')}';
      case PollStatus.active:
        return _countdownLabel(context, poll.deadline);
      case PollStatus.cancelled:
        return '${context.tr('أُلغي')}: ${_formatDateTime(poll.cancelledAt ?? poll.deadline)}';
      case PollStatus.ended:
        return '${context.tr('أُغلق')}: ${_formatDateTime(poll.endedAt ?? poll.deadline)}';
    }
  }

  String _countdownLabel(BuildContext context, DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) return context.tr('ينتهي الآن...');
    final d = remaining.inDays;
    final h = remaining.inHours % 24;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    if (d > 0) {
      return '${context.tr('يتبقى')}: $d ${context.tr('يوم')} $h ${context.tr('ساعة')}';
    }
    if (h > 0) {
      return '${context.tr('يتبقى')}: $h ${context.tr('ساعة')} $m ${context.tr('دقيقة')}';
    }
    if (m > 0) {
      return '${context.tr('يتبقى')}: $m ${context.tr('دقيقة')} $s ${context.tr('ثانية')}';
    }
    return '${context.tr('يتبقى')}: $s ${context.tr('ثانية')}';
  }

  String _formatDateTime(DateTime dt) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}

class _PollStatusBadge extends StatelessWidget {
  const _PollStatusBadge({required this.poll});

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
      case PollStatus.cancelled:
        color = AppColors.statusRejected;
        label = 'مُلغى';
        break;
      case PollStatus.ended:
        if (poll.isTie ?? false) {
          color = AppColors.statusPending;
          label = 'منتهي - تعادل';
        } else {
          color = AppColors.steel;
          label = 'منتهي';
        }
        break;
    }
    return AppPill(color: color, label: label);
  }
}
