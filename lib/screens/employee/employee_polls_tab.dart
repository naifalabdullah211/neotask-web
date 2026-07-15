import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/poll_model.dart';
import '../../providers/poll_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/poll_card.dart';
import 'employee_poll_vote_screen.dart';

/// Employee-side "تصويت" tab (requirement #0/#2) — lists every poll where
/// the signed-in employee is a selected participant, newest first. Tapping
/// a poll opens [EmployeePollVoteScreen] (open polls: vote/change vote;
/// closed polls: see the final result only — never other employees'
/// votes, per the explicit secrecy requirement).
class EmployeePollsTab extends StatelessWidget {
  const EmployeePollsTab({super.key, required this.employeeUid});

  final String employeeUid;

  @override
  Widget build(BuildContext context) {
    final pollProvider = context.watch<PollProvider>();
    final polls = pollProvider.pollsForEmployee(employeeUid);

    if (polls.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد تصويتات موجّهة إليك حاليًا',
            style: TextStyle(color: AppColors.textSecondary),
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
                builder: (_) => EmployeePollVoteScreen(
                  pollId: poll.pollId,
                  employeeUid: employeeUid,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
