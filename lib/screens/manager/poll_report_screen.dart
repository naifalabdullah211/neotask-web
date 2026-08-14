import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/poll_report_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/poll_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart' show AppPill;
import '../../widgets/neo_workspace_chrome.dart';

/// The PERMANENT final voting report screen — per the explicit
/// requirement §6: title, description, start/end date-time, creating
/// manager, total eligible, total voted, total not-voted, participation
/// %, per-choice count+percentage, winning choice, tie detection, list of
/// voters, list of non-voters, generation timestamp. If the poll's
/// privacy toggle was enabled, this screen NEVER reveals which choice an
/// employee picked — only voted/not-voted status (this is additionally a
/// STRUCTURAL guarantee: [PollReport] has no field anywhere that stores
/// an individual's specific choice, see poll_report_model.dart).
///
/// Reached either directly from the manager's "انتهى التصويت"
/// notification tap, or from [ManagerPollDetailScreen]'s report button —
/// this is the SAME screen either way, live via
/// [PollProvider.watchPollReport] so a manual tie-decision update
/// reflects immediately without a manual refresh.
class PollReportScreen extends StatelessWidget {
  const PollReportScreen({super.key, required this.pollId});

  final String pollId;

  Future<void> _decideTie(BuildContext context, PollReport report) async {
    final decision = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('قرار المدير — تعادل في التصويت'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('انتهى التصويت بتعادل. اختر القرار النهائي:'),
              const SizedBox(height: 12),
              ...report.tiedChoiceIndexes.map(
                (idx) => ListTile(
                  title: Text(report.choices[idx]),
                  onTap: () => Navigator.pop(context, idx),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
    if (decision == null || !context.mounted) return;

    final managerUid = context.read<AuthProvider>().currentUser!.uid;
    try {
      await context.read<PollProvider>().applyManagerTieDecision(
        pollId: report.pollId,
        decisionChoiceIndex: decision,
        managerUid: managerUid,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تسجيل القرار النهائي')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${context.tr('تعذّر حفظ القرار')}: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'التقرير النهائي للتصويت',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<PollReport?>(
          stream: context.read<PollProvider>().watchPollReport(pollId),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final report = snapshot.data;
            if (report == null) {
              return const NeoWorkspaceEmptyState(
                icon: Icons.poll_outlined,
                title: 'لا يوجد تقرير نهائي لهذا التصويت',
                message: 'سيظهر التقرير هنا بعد إغلاق التصويت وحساب النتيجة.',
              );
            }
            final manager = FirestoreService.getUser(
              report.createdByManagerUid,
            );

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.deepBlue.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(
                              Icons.how_to_vote_outlined,
                              color: AppColors.deepBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (report.description.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    report.description,
                                    style: AppTextStyles.bodySecondary.copyWith(
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (report.privacyWasEnabled) ...[
                        const SizedBox(height: 14),
                        AppPill(
                          color: AppColors.deepBlue,
                          label: 'الخصوصية كانت مفعّلة عند إجراء التصويت',
                          icon: Icons.privacy_tip_outlined,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ---- summary metrics ----
                NeoWorkspaceMetricsBar(
                  items: [
                    NeoWorkspaceMetric(
                      label: 'إجمالي المستحقّين',
                      value: '${report.totalEligible}',
                      icon: Icons.groups_outlined,
                      color: AppColors.deepBlue,
                    ),
                    NeoWorkspaceMetric(
                      label: 'صوّتوا',
                      value: '${report.totalVoted}',
                      icon: Icons.check_circle_outline,
                      color: AppColors.statusApproved,
                    ),
                    NeoWorkspaceMetric(
                      label: 'لم يصوّتوا',
                      value: '${report.totalNotVoted}',
                      icon: Icons.remove_circle_outline,
                      color: AppColors.statusRejected,
                    ),
                    NeoWorkspaceMetric(
                      label: 'نسبة المشاركة',
                      value:
                          '${report.participationPercent.toStringAsFixed(1)}%',
                      icon: Icons.pie_chart_outline,
                      color: AppColors.statusPending,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: (report.participationPercent / 100).clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: AppColors.divider,
                    color: AppColors.statusApproved,
                  ),
                ),
                const SizedBox(height: 20),

                // ---- winner / tie ----
                _WinnerCard(report: report),
                if (report.isTie)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.statusPending,
                      ),
                      onPressed: () => _decideTie(context, report),
                      icon: const Icon(Icons.gavel_outlined),
                      label: const Text('اتخاذ القرار النهائي للتعادل'),
                    ),
                  ),
                const SizedBox(height: 20),

                // ---- per-choice bars ----
                const NeoWorkspaceSectionHeader(
                  title: 'نتائج كل اختيار',
                  subtitle: 'توزيع الأصوات ونسب كل اختيار',
                ),
                ...List.generate(report.choices.length, (i) {
                  return _ChoiceResultBar(
                    label: report.choices[i],
                    count: report.choiceCounts[i],
                    percent: report.choicePercentages[i],
                    isWinner: report.winningChoiceIndex == i,
                  );
                }),
                const SizedBox(height: 20),

                // ---- dates / manager / generation timestamp ----
                _InfoRow(
                  icon: Icons.play_circle_outline,
                  label: 'موعد البدء',
                  value: intl.DateFormat(
                    'yyyy/MM/dd — HH:mm',
                  ).format(report.startDateTime),
                ),
                _InfoRow(
                  icon: Icons.event_busy_outlined,
                  label: 'موعد الانتهاء',
                  value: intl.DateFormat(
                    'yyyy/MM/dd — HH:mm',
                  ).format(report.endDateTime),
                ),
                _InfoRow(
                  icon: Icons.person_outline,
                  label: 'المدير المُنشئ',
                  value: manager?.name ?? report.createdByManagerUid,
                ),
                _InfoRow(
                  icon: Icons.schedule,
                  label: 'وقت إنشاء التقرير',
                  value: intl.DateFormat(
                    'yyyy/MM/dd — HH:mm',
                  ).format(report.generatedAt),
                ),
                const SizedBox(height: 20),

                // ---- voters / non-voters lists ----
                _EmployeeListSection(
                  title:
                      '${context.tr('قائمة من صوّت')} (${report.voterUids.length})',
                  uids: report.voterUids,
                  color: AppColors.statusApproved,
                  icon: Icons.check_circle_outline,
                ),
                const SizedBox(height: 12),
                _EmployeeListSection(
                  title:
                      '${context.tr('قائمة من لم يصوّت')} (${report.nonVoterUids.length})',
                  uids: report.nonVoterUids,
                  color: AppColors.statusRejected,
                  icon: Icons.remove_circle_outline,
                ),
                const SizedBox(height: 40),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        color: color.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _WinnerCard extends StatelessWidget {
  const _WinnerCard({required this.report});

  final PollReport report;

  @override
  Widget build(BuildContext context) {
    if (report.totalVoted == 0) {
      return Card(
        color: AppColors.textSecondary.withValues(alpha: 0.08),
        child: const Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: AppColors.textSecondary),
              SizedBox(width: 10),
              Expanded(child: Text('لا توجد أصوات — لا يمكن تحديد نتيجة')),
            ],
          ),
        ),
      );
    }
    if (report.isTie) {
      return Card(
        color: AppColors.statusPending.withValues(alpha: 0.1),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const Icon(Icons.balance, color: AppColors.statusPending),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${context.tr('تعادل بين')}: '
                  '${report.tiedChoiceIndexes.map((i) => report.choices[i]).join(Localizations.localeOf(context).languageCode == 'en' ? ', ' : ' و ')}',
                  style: const TextStyle(
                    color: AppColors.statusPending,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
    final winnerLabel = report.winningChoiceIndex != null
        ? report.choices[report.winningChoiceIndex!]
        : context.tr('غير محدد');
    return Card(
      color: AppColors.statusApproved.withValues(alpha: 0.1),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(
              Icons.emoji_events_outlined,
              color: AppColors.statusApproved,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${context.tr('الاختيار الفائز')}: $winnerLabel',
                style: const TextStyle(
                  color: AppColors.statusApproved,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceResultBar extends StatelessWidget {
  const _ChoiceResultBar({
    required this.label,
    required this.count,
    required this.percent,
    required this.isWinner,
  });

  final String label;
  final int count;
  final double percent;
  final bool isWinner;

  @override
  Widget build(BuildContext context) {
    final color = isWinner ? AppColors.statusApproved : AppColors.deepBlue;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: isWinner ? color : AppColors.textPrimary,
                  ),
                ),
              ),
              if (isWinner)
                const Padding(
                  padding: EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.emoji_events_outlined,
                    size: 16,
                    color: AppColors.statusApproved,
                  ),
                ),
              Text(
                '$count ${context.tr('صوت')} (${percent.toStringAsFixed(1)}%)',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: (percent / 100).clamp(0, 1),
              minHeight: 14,
              backgroundColor: AppColors.divider,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '${context.tr(label)}: ',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmployeeListSection extends StatelessWidget {
  const _EmployeeListSection({
    required this.title,
    required this.uids,
    required this.color,
    required this.icon,
  });

  final String title;
  final List<String> uids;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        if (uids.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'لا يوجد',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          Card(
            child: Column(
              children: uids.map((uid) {
                final employee = FirestoreService.getUser(uid);
                return ListTile(
                  dense: true,
                  leading: Icon(icon, color: color, size: 20),
                  title: Text(employee?.name ?? uid),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
