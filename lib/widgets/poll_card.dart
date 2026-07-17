import 'dart:async';
import 'package:flutter/material.dart';
import '../models/poll_model.dart';
import '../theme/app_theme.dart';
import 'status_chip.dart' show AppPill;

/// Poll list-row card — deliberately mirrors [TaskListTile]'s exact
/// `Card` + rounded-corner styling per explicit requirement #6 ("نفس
/// أسلوب بطاقة المهمة الحالي (نفس الألوان، الحواف المدورة)"), with two
/// additions on top: a 3-state status badge and a live countdown for open
/// polls.
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
    // Only ticks while the poll is open — a closed poll's remaining-time
    // display is irrelevant, so no timer is started at all in that case
    // (avoids an unnecessary periodic rebuild for archived polls).
    if (widget.poll.status == PollStatus.open) {
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
            if (poll.status == PollStatus.open)
              Text(_countdownLabel(poll.deadline))
            else
              Text('أُغلق: ${_formatDateTime(poll.closedAt ?? poll.deadline)}'),
          ],
        ),
      ),
    );
  }

  Color _accentColor(AppPoll poll) {
    if (poll.status == PollStatus.open) return AppColors.statusApproved;
    if (poll.result == PollResult.tiePendingManagerDecision) {
      return AppColors.statusPending;
    }
    return AppColors.textSecondary;
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

/// The 3-state status badge — مفتوح (green) / مغلق (gray) / تعادل - بانتظار
/// قرار المدير (orange), per explicit requirement #6. Deliberately a
/// separate small widget (rather than reusing [StatusChip], which is
/// keyed to [TaskStatus]'s name strings) since Poll status/result values
/// have no equivalent in that enum — but now built on the SAME shared
/// [AppPill] base as [StatusChip]/[PriorityBadge], so the pill visual
/// (padding/radius/border) stays identical across all three instead of
/// being a third independent copy of the pattern.
class _PollStatusBadge extends StatelessWidget {
  const _PollStatusBadge({required this.poll});

  final AppPoll poll;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    if (poll.status == PollStatus.open) {
      color = AppColors.statusApproved;
      label = 'مفتوح';
    } else if (poll.result == PollResult.tiePendingManagerDecision) {
      color = AppColors.statusPending;
      label = 'تعادل - بانتظار قرار المدير';
    } else {
      color = AppColors.textSecondary;
      label = 'مغلق';
    }
    return AppPill(color: color, label: label);
  }
}
