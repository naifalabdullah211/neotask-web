import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/poll_model.dart';
import '../../providers/poll_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/poll_card.dart';
import '../shared/create_poll_screen.dart';
import 'manager_poll_detail_screen.dart';
import 'past_polls_screen.dart';

/// Manager-side "تصويت" list — shows currently OPEN polls (the manager's
/// day-to-day working view); closed polls move to the permanent archive
/// (requirement #5), reachable via the app-bar action into
/// [PastPollsScreen]. A FAB creates a new poll (requirement #1).
class ManagerPollsTab extends StatelessWidget {
  const ManagerPollsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final pollProvider = context.watch<PollProvider>();
    final openPolls = pollProvider.openPolls;

    return Scaffold(
      appBar: AppBar(
        title: const Text('التصويتات'),
        actions: [
          IconButton(
            tooltip: 'التصويتات السابقة',
            icon: const Icon(Icons.archive_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PastPollsScreen()),
              );
            },
          ),
        ],
      ),
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.mintAccent,
        onPressed: () {
          Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const CreatePollScreen()));
        },
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: openPolls.isEmpty
            ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'لا توجد تصويتات مفتوحة حاليًا. اضغط + لإنشاء تصويت جديد.',
                    style: TextStyle(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: openPolls.length,
                itemBuilder: (context, index) {
                  final AppPoll poll = openPolls[index];
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
