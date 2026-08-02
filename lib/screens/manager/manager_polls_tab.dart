import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/poll_model.dart';
import '../../providers/poll_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_app_bar_tabs.dart';
import '../../widgets/poll_card.dart';
import '../shared/create_poll_screen.dart';
import 'manager_poll_detail_screen.dart';
import 'past_polls_screen.dart';

/// Manager-side "تصويت" list — UPGRADED (Phase E) to explicitly surface
/// all NON-ended statuses (نشط / مسودة / مُلغى) via a segmented tab bar,
/// instead of only the previous single "open polls" list — per the
/// requirement that all 4 statuses be visible in the manager's list
/// view. Ended polls remain in the permanent archive
/// ([PastPollsScreen]), reachable via the app-bar action. A FAB creates a
/// new poll.
class ManagerPollsTab extends StatefulWidget {
  const ManagerPollsTab({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  State<ManagerPollsTab> createState() => _ManagerPollsTabState();
}

class _ManagerPollsTabState extends State<ManagerPollsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 3,
    vsync: this,
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pollProvider = context.watch<PollProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('التصويتات'),
        actions: [
          IconButton(
            tooltip: 'التصويتات السابقة',
            icon: const Icon(Icons.archive_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PastPollsScreen(readOnly: widget.readOnly),
                ),
              );
            },
          ),
        ],
        bottom: NeoAppBarTabs(
          controller: _tabController,
          tabs: const [
            NeoAppBarTab(icon: Icons.campaign_outlined, label: 'نشط'),
            NeoAppBarTab(icon: Icons.edit_note_outlined, label: 'مسودة'),
            NeoAppBarTab(icon: Icons.cancel_outlined, label: 'مُلغى'),
          ],
        ),
      ),
      backgroundColor: AppColors.background,
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton(
              backgroundColor: AppColors.mintAccent,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CreatePollScreen()),
                );
              },
              child: const Icon(Icons.add),
            ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _PollList(
              polls: pollProvider.activePolls,
              readOnly: widget.readOnly,
              emptyMessage: widget.readOnly
                  ? 'لا توجد تصويتات نشطة حاليًا.'
                  : 'لا توجد تصويتات نشطة حاليًا. اضغط + لإنشاء تصويت جديد.',
            ),
            _PollList(
              polls: pollProvider.draftPolls,
              readOnly: widget.readOnly,
              emptyMessage: 'لا توجد مسودات محفوظة.',
            ),
            _PollList(
              polls: pollProvider.cancelledPolls,
              readOnly: widget.readOnly,
              emptyMessage: 'لا توجد تصويتات مُلغاة.',
            ),
          ],
        ),
      ),
    );
  }
}

class _PollList extends StatelessWidget {
  const _PollList({
    required this.polls,
    required this.emptyMessage,
    required this.readOnly,
  });

  final List<AppPoll> polls;
  final String emptyMessage;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    if (polls.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            emptyMessage,
            style: const TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: polls.length,
      itemBuilder: (context, index) {
        final AppPoll poll = polls[index];
        return PollCard(
          poll: poll,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ManagerPollDetailScreen(
                  pollId: poll.pollId,
                  readOnly: readOnly,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
