import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:provider/provider.dart';
import '../../models/poll_model.dart';
import '../../providers/poll_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_workspace_chrome.dart';
import '../../widgets/poll_card.dart';
import 'employee_poll_vote_screen.dart';

class EmployeePollsTab extends StatelessWidget {
  const EmployeePollsTab({super.key, required this.employeeUid});

  final String employeeUid;

  @override
  Widget build(BuildContext context) {
    final polls = context.watch<PollProvider>().pollsForEmployee(employeeUid);
    final now = DateTime.now();
    final active = polls
        .where((poll) => poll.status == PollStatus.active)
        .length;
    final ended = polls.where((poll) => poll.status == PollStatus.ended).length;
    final closingSoon = polls.where((poll) {
      if (poll.status != PollStatus.active) return false;
      final remaining = poll.deadline.difference(now);
      return !remaining.isNegative && remaining <= const Duration(hours: 24);
    }).length;

    void openPoll(AppPoll poll) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmployeePollVoteScreen(
            pollId: poll.pollId,
            employeeUid: employeeUid,
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          NeoWorkspaceMetricsBar(
            items: [
              NeoWorkspaceMetric(
                label: 'إجمالي التصويتات',
                value: '${polls.length}',
                icon: Icons.how_to_vote_outlined,
                color: const Color(0xFF1F6FD2),
              ),
              NeoWorkspaceMetric(
                label: 'نشطة',
                value: '$active',
                icon: Icons.campaign_outlined,
                color: AppColors.mintAccent,
              ),
              NeoWorkspaceMetric(
                label: 'تغلق خلال 24 ساعة',
                value: '$closingSoon',
                icon: Icons.timer_outlined,
                color: AppColors.statusPending,
              ),
              NeoWorkspaceMetric(
                label: 'منتهية',
                value: '$ended',
                icon: Icons.fact_check_outlined,
                color: AppColors.steel,
              ),
            ],
          ),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: polls.isEmpty
                  ? const NeoWorkspaceEmptyState(
                      icon: Icons.how_to_vote_outlined,
                      title: 'لا توجد تصويتات موجّهة إليك حاليًا',
                      message:
                          'ستظهر هنا موضوعات التصويت التي تحتاج مشاركتك أو نتائجها بعد الإغلاق.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const NeoWorkspaceSectionHeader(
                          title: 'تصويتاتي',
                          subtitle: 'الموضوعات النشطة والسابقة في مكان واحد',
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            itemCount: polls.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.md),
                            itemBuilder: (context, index) => PollCard(
                              poll: polls[index],
                              onTap: () => openPoll(polls[index]),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
