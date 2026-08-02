import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../models/poll_model.dart';
import '../theme/app_theme.dart';
import 'neo_selection_field.dart';
import 'neo_workspace_chrome.dart';

enum _PollFilter { all, active, draft, ended, cancelled }

class PollsMetricsBar extends StatelessWidget {
  const PollsMetricsBar({super.key, required this.polls});

  final List<AppPoll> polls;

  @override
  Widget build(BuildContext context) {
    int count(PollStatus status) =>
        polls.where((poll) => poll.status == status).length;
    final eligible = polls
        .where((poll) => poll.status == PollStatus.active)
        .fold<int>(0, (sum, poll) => sum + poll.participantUids.length);

    return NeoWorkspaceMetricsBar(
      items: [
        NeoWorkspaceMetric(
          label: 'إجمالي التصويتات',
          value: '${polls.length}',
          icon: Icons.how_to_vote_outlined,
          color: const Color(0xFF1F6FD2),
        ),
        NeoWorkspaceMetric(
          label: 'نشطة',
          value: '${count(PollStatus.active)}',
          icon: Icons.campaign_outlined,
          color: AppColors.mintAccent,
        ),
        NeoWorkspaceMetric(
          label: 'مسودات',
          value: '${count(PollStatus.draft)}',
          icon: Icons.edit_note_outlined,
          color: AppColors.gold,
        ),
        NeoWorkspaceMetric(
          label: 'منتهية',
          value: '${count(PollStatus.ended)}',
          icon: Icons.fact_check_outlined,
          color: const Color(0xFF7656C8),
        ),
        NeoWorkspaceMetric(
          label: 'مدعوون للتصويت',
          value: '$eligible',
          icon: Icons.groups_outlined,
          color: AppColors.deepBlue,
        ),
      ],
    );
  }
}

class PollsWorkspace extends StatefulWidget {
  const PollsWorkspace({
    super.key,
    required this.polls,
    required this.onOpenPoll,
  });

  final List<AppPoll> polls;
  final ValueChanged<AppPoll> onOpenPoll;

  @override
  State<PollsWorkspace> createState() => _PollsWorkspaceState();
}

class _PollsWorkspaceState extends State<PollsWorkspace> {
  String? _selectedPollId;
  _PollFilter _filter = _PollFilter.all;

  List<AppPoll> get _visiblePolls => switch (_filter) {
    _PollFilter.all => widget.polls,
    _PollFilter.active => widget.polls
        .where((poll) => poll.status == PollStatus.active)
        .toList(),
    _PollFilter.draft => widget.polls
        .where((poll) => poll.status == PollStatus.draft)
        .toList(),
    _PollFilter.ended => widget.polls
        .where((poll) => poll.status == PollStatus.ended)
        .toList(),
    _PollFilter.cancelled => widget.polls
        .where((poll) => poll.status == PollStatus.cancelled)
        .toList(),
  };

  AppPoll? get _selectedPoll {
    final polls = _visiblePolls;
    if (polls.isEmpty) return null;
    for (final poll in polls) {
      if (poll.pollId == _selectedPollId) return poll;
    }
    return polls.first;
  }

  void _selectPoll(AppPoll poll, {required bool showSheet}) {
    setState(() => _selectedPollId = poll.pollId);
    if (!showSheet) return;
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: .82,
        child: _PollDetailsPanel(
          poll: poll,
          onOpen: () {
            Navigator.pop(sheetContext);
            widget.onOpenPoll(poll);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.polls.isEmpty) {
      return const NeoWorkspaceEmptyState(
        icon: Icons.how_to_vote_outlined,
        title: 'مركز القرار جاهز',
        message: 'أنشئ موضوع تصويت وحدد الخيارات والمشاركين ووقت الإغلاق.',
      );
    }

    final visible = _visiblePolls;
    final selected = _selectedPoll;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 760) {
          return _MobilePollsView(
            polls: visible,
            filter: _filter,
            onFilterChanged: (value) => setState(() => _filter = value),
            onSelect: (poll) => _selectPoll(poll, showSheet: true),
          );
        }

        final showDetails = constraints.maxWidth >= 1180;
        return Column(
          children: [
            _PollsToolbar(
              filter: _filter,
              visibleCount: visible.length,
              onFilterChanged: (value) => setState(() => _filter = value),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: visible.isEmpty || selected == null
                    ? const NeoWorkspaceEmptyState(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'لا توجد تصويتات ضمن هذا العرض',
                        message: 'غيّر عامل التصفية لعرض بقية التصويتات.',
                      )
                    : Row(
                        textDirection: TextDirection.rtl,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          NeoWorkspacePanel(
                            width: showDetails ? 400 : 360,
                            borderEnd: true,
                            child: _PollListPanel(
                              polls: visible,
                              selectedPollId: selected.pollId,
                              onSelect: (poll) => _selectPoll(
                                poll,
                                showSheet: !showDetails,
                              ),
                            ),
                          ),
                          Expanded(
                            child: _DecisionCanvas(
                              poll: selected,
                              onOpen: () => widget.onOpenPoll(selected),
                            ),
                          ),
                          if (showDetails)
                            NeoWorkspacePanel(
                              width: 320,
                              borderStart: true,
                              child: _PollDetailsPanel(
                                poll: selected,
                                onOpen: () => widget.onOpenPoll(selected),
                              ),
                            ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _PollsToolbar extends StatelessWidget {
  const _PollsToolbar({
    required this.filter,
    required this.visibleCount,
    required this.onFilterChanged,
  });

  final _PollFilter filter;
  final int visibleCount;
  final ValueChanged<_PollFilter> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          SizedBox(
            width: 230,
            child: NeoSelectionField<_PollFilter>(
              label: 'حالة التصويت',
              value: filter,
              options: const [
                NeoSelectionOption(
                  value: _PollFilter.all,
                  label: 'الكل',
                  icon: Icons.dashboard_outlined,
                ),
                NeoSelectionOption(
                  value: _PollFilter.active,
                  label: 'نشط',
                  icon: Icons.campaign_outlined,
                ),
                NeoSelectionOption(
                  value: _PollFilter.draft,
                  label: 'مسودة',
                  icon: Icons.edit_note_outlined,
                ),
                NeoSelectionOption(
                  value: _PollFilter.ended,
                  label: 'منتهي',
                  icon: Icons.fact_check_outlined,
                ),
                NeoSelectionOption(
                  value: _PollFilter.cancelled,
                  label: 'ملغى',
                  icon: Icons.cancel_outlined,
                ),
              ],
              onChanged: onFilterChanged,
            ),
          ),
          const Spacer(),
          Text(
            '$visibleCount تصويت في العرض',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _PollListPanel extends StatelessWidget {
  const _PollListPanel({
    required this.polls,
    required this.selectedPollId,
    required this.onSelect,
  });

  final List<AppPoll> polls;
  final String selectedPollId;
  final ValueChanged<AppPoll> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NeoWorkspaceSectionHeader(
          title: 'موضوعات التصويت',
          subtitle: 'اختر موضوعًا لعرض مسار القرار',
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: polls.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) => _PollListCard(
              poll: polls[index],
              selected: polls[index].pollId == selectedPollId,
              onTap: () => onSelect(polls[index]),
            ),
          ),
        ),
      ],
    );
  }
}

class _PollListCard extends StatelessWidget {
  const _PollListCard({
    required this.poll,
    required this.selected,
    required this.onTap,
  });

  final AppPoll poll;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = _pollStatusColor(poll.status);
    return Material(
      color: selected ? AppColors.deepBlue.withValues(alpha: .055) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: selected ? statusColor : AppColors.divider,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: Icon(
                      _pollStatusIcon(poll.status),
                      color: statusColor,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      poll.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  _StatusBadge(status: poll.status),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.groups_outlined,
                    color: AppColors.textSecondary,
                    size: 16,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${poll.participantUids.length} مشارك',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11.5,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.schedule_outlined,
                    color: AppColors.textSecondary,
                    size: 15,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    intl.DateFormat('yyyy/MM/dd').format(poll.deadline),
                    style: TextStyle(
                      color: poll.isPastDeadline && poll.status == PollStatus.active
                          ? AppColors.overdue
                          : AppColors.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DecisionCanvas extends StatelessWidget {
  const _DecisionCanvas({required this.poll, required this.onOpen});

  final AppPoll poll;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final statusColor = _pollStatusColor(poll.status);
    return ColoredBox(
      color: const Color(0xFFF8FAFD),
      child: ListView(
        padding: const EdgeInsets.all(26),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StatusBadge(status: poll.status),
                    const SizedBox(height: 10),
                    Text(
                      poll.title,
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (poll.description.isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        poll.description,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12.5,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: .12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.how_to_vote_rounded,
                  color: statusColor,
                  size: 34,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'خيارات القرار',
            style: TextStyle(
              color: AppColors.deepBlue,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 11),
          ...List.generate(
            poll.choices.length,
            (index) => Container(
              margin: const EdgeInsets.only(bottom: 9),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.divider),
              ),
              child: Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppColors.deepBlue.withValues(alpha: .07),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      poll.choices[index],
                      style: const TextStyle(
                        color: AppColors.deepBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  if (poll.status == PollStatus.ended &&
                      poll.choiceCounts != null &&
                      index < poll.choiceCounts!.length)
                    Text(
                      '${poll.choiceCounts![index]} صوت',
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: onOpen,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(
                poll.status == PollStatus.ended
                    ? 'فتح التقرير والنتيجة'
                    : 'فتح إدارة التصويت',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PollDetailsPanel extends StatelessWidget {
  const _PollDetailsPanel({required this.poll, required this.onOpen});

  final AppPoll poll;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final remaining = poll.deadline.difference(DateTime.now());
    final timeLabel = remaining.isNegative
        ? 'انتهى الموعد'
        : remaining.inDays > 0
        ? '${remaining.inDays} يوم متبقٍ'
        : '${remaining.inHours} ساعة متبقية';
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'تفاصيل التصويت',
          style: TextStyle(
            color: AppColors.deepBlue,
            fontSize: 17,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 18),
        _PollDetailLine(
          icon: Icons.play_arrow_rounded,
          label: 'بداية التصويت',
          value: intl.DateFormat('yyyy/MM/dd – HH:mm').format(poll.startDateTime),
        ),
        _PollDetailLine(
          icon: Icons.event_busy_outlined,
          label: 'موعد الإغلاق',
          value: intl.DateFormat('yyyy/MM/dd – HH:mm').format(poll.deadline),
        ),
        _PollDetailLine(
          icon: Icons.timelapse_rounded,
          label: 'الوقت',
          value: timeLabel,
          valueColor: remaining.isNegative ? AppColors.overdue : null,
        ),
        _PollDetailLine(
          icon: Icons.groups_outlined,
          label: 'المشاركون',
          value: '${poll.participantUids.length}',
        ),
        _PollDetailLine(
          icon: poll.privacyEnabled
              ? Icons.lock_outline_rounded
              : Icons.visibility_outlined,
          label: 'خصوصية النتائج',
          value: poll.privacyEnabled ? 'مفعّلة' : 'غير مفعّلة',
        ),
        _PollDetailLine(
          icon: Icons.format_list_numbered_rounded,
          label: 'عدد الخيارات',
          value: '${poll.choices.length}',
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: onOpen,
          icon: const Icon(Icons.open_in_new_rounded, size: 18),
          label: const Text('فتح التفاصيل'),
        ),
      ],
    );
  }
}

class _PollDetailLine extends StatelessWidget {
  const _PollDetailLine({
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.textSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: valueColor ?? AppColors.deepBlue,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final PollStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _pollStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        _pollStatusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MobilePollsView extends StatelessWidget {
  const _MobilePollsView({
    required this.polls,
    required this.filter,
    required this.onFilterChanged,
    required this.onSelect,
  });

  final List<AppPoll> polls;
  final _PollFilter filter;
  final ValueChanged<_PollFilter> onFilterChanged;
  final ValueChanged<AppPoll> onSelect;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PollsToolbar(
          filter: filter,
          visibleCount: polls.length,
          onFilterChanged: onFilterChanged,
        ),
        Expanded(
          child: polls.isEmpty
              ? const NeoWorkspaceEmptyState(
                  icon: Icons.filter_alt_off_outlined,
                  title: 'لا توجد تصويتات ضمن هذا العرض',
                  message: 'غيّر عامل التصفية لعرض بقية التصويتات.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
                  itemCount: polls.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 9),
                  itemBuilder: (context, index) => _PollListCard(
                    poll: polls[index],
                    selected: false,
                    onTap: () => onSelect(polls[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

Color _pollStatusColor(PollStatus status) => switch (status) {
  PollStatus.active => AppColors.mintAccent,
  PollStatus.draft => AppColors.gold,
  PollStatus.ended => const Color(0xFF7656C8),
  PollStatus.cancelled => AppColors.overdue,
};

IconData _pollStatusIcon(PollStatus status) => switch (status) {
  PollStatus.active => Icons.campaign_outlined,
  PollStatus.draft => Icons.edit_note_outlined,
  PollStatus.ended => Icons.fact_check_outlined,
  PollStatus.cancelled => Icons.cancel_outlined,
};

String _pollStatusLabel(PollStatus status) => switch (status) {
  PollStatus.active => 'نشط',
  PollStatus.draft => 'مسودة',
  PollStatus.ended => 'منتهي',
  PollStatus.cancelled => 'ملغى',
};
