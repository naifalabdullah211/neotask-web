import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/poll_model.dart';
import '../../providers/poll_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/poll_card.dart';
import 'manager_poll_detail_screen.dart';

/// "التصويتات السابقة" — permanent archive of every closed poll, per
/// requirement #5: the manager can return to any archived poll at any
/// time and see the full permanent record (who voted what + the final
/// result) via [ManagerPollDetailScreen], which renders identically for
/// open and closed polls.
class PastPollsScreen extends StatelessWidget {
  const PastPollsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final closedPolls = context.watch<PollProvider>().closedPolls;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('التصويتات السابقة')),
      body: SafeArea(
        child: closedPolls.isEmpty
            ? const Center(
                child: Text(
                  'لا توجد تصويتات سابقة بعد',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: closedPolls.length,
                itemBuilder: (context, index) {
                  final AppPoll poll = closedPolls[index];
                  return PollCard(
                    poll: poll,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ManagerPollDetailScreen(pollId: poll.pollId),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
