import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/poll_model.dart';
import '../../providers/poll_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/polls_workspace.dart';
import '../shared/create_poll_screen.dart';
import 'manager_poll_detail_screen.dart';
import 'past_polls_screen.dart';

/// Manager decision centre for the complete poll lifecycle. Existing poll
/// creation, editing, reminders, cancellation, privacy and result routes are
/// preserved; only the top-level organisation is rebuilt as a responsive
/// workspace matching Work Plan and Automation.
class ManagerPollsTab extends StatelessWidget {
  const ManagerPollsTab({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final polls = context.watch<PollProvider>().allPolls;
    final compact = MediaQuery.sizeOf(context).width < 620;

    void openPoll(AppPoll poll) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ManagerPollDetailScreen(
            pollId: poll.pollId,
            readOnly: readOnly,
          ),
        ),
      );
    }

    void openArchive() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PastPollsScreen(readOnly: readOnly),
        ),
      );
    }

    void createPoll() {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreatePollScreen()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'التصويت',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (compact)
            IconButton(
              tooltip: 'التصويتات السابقة',
              onPressed: openArchive,
              icon: const Icon(Icons.archive_outlined),
            )
          else
            OutlinedButton.icon(
              onPressed: openArchive,
              icon: const Icon(Icons.archive_outlined, size: 18),
              label: const Text('الأرشيف'),
            ),
          if (!readOnly)
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 8, end: 12),
              child: compact
                  ? IconButton.filled(
                      tooltip: 'تصويت جديد',
                      onPressed: createPoll,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.mintAccent,
                        foregroundColor: AppColors.navy,
                      ),
                      icon: const Icon(Icons.add_rounded),
                    )
                  : FilledButton.icon(
                      onPressed: createPoll,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.mintAccent,
                        foregroundColor: AppColors.navy,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 20),
                      label: const Text(
                        'تصويت جديد',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
            )
          else
            const SizedBox(width: 12),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            PollsMetricsBar(polls: polls),
            Expanded(
              child: PollsWorkspace(polls: polls, onOpenPoll: openPoll),
            ),
          ],
        ),
      ),
    );
  }
}
