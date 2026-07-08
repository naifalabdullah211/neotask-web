import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';
import 'task_review_detail_screen.dart';

/// Manager review queue — shows tasks submitted by employees needing a
/// live, real-time Approve / Reject / Request-Edit decision.
/// Backed by TaskProvider, which listens to Firestore's real-time
/// .snapshots() for near-instant updates the moment an employee submits,
/// synced live across devices.
class ManagerReviewTab extends StatelessWidget {
  const ManagerReviewTab({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final submitted = provider.submittedForReview;

    return SafeArea(
      child: submitted.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.inbox_outlined,
                        size: 56, color: AppColors.textSecondary),
                    SizedBox(height: 12),
                    Text('لا توجد مهام بانتظار المراجعة حاليًا',
                        style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: submitted.length,
              itemBuilder: (context, index) {
                final t = submitted[index];
                return Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    title: Text(t.title,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Text(
                          'أُرسلت: ${t.submittedAt != null ? intl.DateFormat('yyyy/MM/dd HH:mm').format(t.submittedAt!) : '-'}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        if (t.submissionNote != null &&
                            t.submissionNote!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('ملاحظة الموظف: ${t.submissionNote}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary)),
                          ),
                        if (t.revisionCount > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('عدد المراجعات: ${t.revisionCount}',
                                style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.statusPending)),
                          ),
                      ],
                    ),
                    trailing: const StatusChip(statusName: 'submitted'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => TaskReviewDetailScreen(task: t)),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
