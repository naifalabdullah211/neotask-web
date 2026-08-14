import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:provider/provider.dart';
import '../../models/poll_model.dart';
import '../../providers/poll_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_workspace_chrome.dart';
import '../../widgets/poll_card.dart';
import 'manager_poll_detail_screen.dart';

class PastPollsScreen extends StatelessWidget {
  const PastPollsScreen({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final polls = context.watch<PollProvider>().endedPolls;
    final ties = polls.where((poll) => poll.isTie == true).length;
    final decided = polls
        .where(
          (poll) =>
              poll.winningChoiceIndex != null || poll.managerDecisionBy != null,
        )
        .length;
    final eligible = polls.fold<int>(
      0,
      (sum, poll) => sum + poll.participantUids.length,
    );

    void openPoll(AppPoll poll) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ManagerPollDetailScreen(pollId: poll.pollId, readOnly: readOnly),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'التصويتات السابقة',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            NeoWorkspaceMetricsBar(
              items: [
                NeoWorkspaceMetric(
                  label: 'إجمالي التصويتات',
                  value: '${polls.length}',
                  icon: Icons.archive_outlined,
                  color: const Color(0xFF1F6FD2),
                ),
                NeoWorkspaceMetric(
                  label: 'نتيجة محسومة',
                  value: '$decided',
                  icon: Icons.verified_outlined,
                  color: AppColors.mintAccent,
                ),
                NeoWorkspaceMetric(
                  label: 'تعادل',
                  value: '$ties',
                  icon: Icons.balance_outlined,
                  color: AppColors.statusPending,
                ),
                NeoWorkspaceMetric(
                  label: 'إجمالي المستحقّين',
                  value: '$eligible',
                  icon: Icons.groups_outlined,
                  color: AppColors.deepBlue,
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
                        icon: Icons.inventory_2_outlined,
                        title: 'لا توجد تصويتات سابقة بعد',
                        message:
                            'عند إغلاق أي تصويت سيبقى سجله ونتيجته هنا للرجوع إليه.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const NeoWorkspaceSectionHeader(
                            title: 'أرشيف القرارات',
                            subtitle:
                                'السجل الدائم للتصويتات المنتهية ونتائجها',
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
      ),
    );
  }
}
