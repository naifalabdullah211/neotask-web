import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import '../models/poll_model.dart';
import '../theme/app_theme.dart';
import 'status_chip.dart' show AppPill;

/// Poll list-row card — deliberately mirrors [TaskListTile]'s exact
/// `Card` + rounded-corner styling, upgraded (Phase E) to reflect the full
/// 4-status lifecycle (draft/active/ended/cancelled) instead of the
/// original open/closed binary, and to show the tie indicator via
/// [AppPoll.isTie] (the [PollResult] enum this used to read from no
/// longer exists — see poll_model.dart).
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
    // Only ticks while the poll is active — an ended/draft/cancelled
    // poll's remaining-time display is irrelevant, so no timer is started
    // at all in that case (avoids an unnecessary periodic rebuild).
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
      child: ListTile(
        onTap: widget.onTap,
        leading: Icon(Icons.how_to_vote_outlined, color: _accentColor(poll)),
        title: Text(poll.title, style: AppTextStyles.cardTitle),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 6),
            _PollStatusBadge(poll: poll),
            const SizedBox(height: 6),
            Text(_secondaryLabel(poll)),
          ],
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
            : AppColors.textSecondary;
    }
  }

  String _secondaryLabel(AppPoll poll) {
    switch (poll.status) {
      case PollStatus.draft:
        return 'مسودة — غير مرئي للموظفين';
      case PollStatus.active:
        return _countdownLabel(poll.deadline);
      case PollStatus.cancelled:
        return 'أُلغي: ${_formatDateTime(poll.cancelledAt ?? poll.deadline)}';
      case PollStatus.ended:
        return 'أُغلق: ${_formatDateTime(poll.endedAt ?? poll.deadline)}';
    }
  }

  String _countdownLabel(DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) return 'ينتهي الآن...';
    final d = remaining.inDays;
    final h = remaining.inHours % 24;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    if (d > 0) return 'يتبقى: $d يوم $h ساعة';
    if (h > 0) return 'يتبقى: $h ساعة $m د';
    if (m > 0) return 'يتبقى: $m دقيقة $s ث';
    return 'يتبقى: $s ثانية';
  }

  String _formatDateTime(DateTime dt) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}

/// The 4-state status badge — مسودة (gray) / نشط (green) / منتهي (gray, or
/// amber when tied) / مُلغى (red) — per the explicit requirement, built on
/// the shared [AppPill] base so the pill visual (padding/radius/border)
/// stays identical across all badge usages in the app.
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
          color = AppColors.textSecondary;
          label = 'منتهي';
        }
        break;
    }
    return AppPill(color: color, label: label);
  }
}
