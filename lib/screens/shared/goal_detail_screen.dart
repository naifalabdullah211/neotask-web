import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/criterion_model.dart';
import '../../models/goal_comment_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/criterion_provider.dart';
import '../../providers/goal_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/goal_style_options.dart';
import '../../widgets/status_chip.dart';
import 'create_criterion_screen.dart';
import 'criterion_detail_screen.dart';
import 'edit_goal_dialog.dart';

/// Detail screen for a single Goal — shows the Goal's info (title,
/// description, start/end dates, fixed-palette color, fixed-icon-set
/// icon), a thicker progress bar with a numeric percentage, a "تعليقات"
/// section (goal-level comments, separate from the Criterion chat
/// system), and the list of its Criteria, plus a manager-only "معيار
/// جديد" FAB.
///
/// REBUILD NOTE: per the simplified spec, a Goal has NO manual
/// close/reopen action anymore — `isClosed`/`closedAt` were removed
/// entirely from the Goal model.
class GoalDetailScreen extends StatelessWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context) {
    final isManager = context.watch<AuthProvider>().isManager;
    final goalProvider = context.watch<GoalProvider>();
    final criterionProvider = context.watch<CriterionProvider>();
    final goal = goalProvider.getGoal(goalId);

    if (goal == null) {
      return const Scaffold(body: Center(child: Text('الهدف غير موجود')));
    }

    final criteria = criterionProvider.criteriaForGoal(goalId);
    final progress = goalProvider.progressForGoal(goalId);
    final goalColor = goalColorFromName(goal.colorName);
    final goalIcon = goalIconFromName(goal.iconName);
    final percent = progress.total == 0
        ? 0
        : ((progress.completed / progress.total) * 100).round();
    final currentUserUid = context.watch<AuthProvider>().currentUser!.uid;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(goal.title),
        actions: isManager
            ? [
                IconButton(
                  tooltip: context.tr('تعديل الهدف'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showEditGoalDialog(context, goal),
                ),
                IconButton(
                  tooltip: context.tr('حذف الهدف'),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => confirmAndDeleteGoal(
                    context,
                    goal,
                    onDeleted: () => Navigator.of(context).pop(),
                  ),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ---- Goal header card: colored border + icon avatar + large
            // Bold title (24-28px per the typography-hierarchy
            // requirement) + thicker progress bar w/ numeric %. ----
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: goalColor, width: 2),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 26,
                            backgroundColor: goalColor.withValues(alpha: 0.15),
                            child: Icon(goalIcon, color: goalColor, size: 26),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              goal.title,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (goal.description.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Text(
                          goal.description,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(
                            Icons.event_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${intl.DateFormat('yyyy/MM/dd').format(goal.startDate)}'
                            ' - ${intl.DateFormat('yyyy/MM/dd').format(goal.endDate)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress.total == 0
                                    ? 0
                                    : progress.completed / progress.total,
                                minHeight: 14,
                                backgroundColor: AppColors.background,
                                color: goalColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '$percent%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: goalColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${progress.completed}/${progress.total} معايير مكتملة',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'المعايير',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            if (criteria.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'لا توجد معايير بعد لهذا الهدف',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              )
            else
              ...criteria.map((c) => _CriterionTile(criterion: c)),
            const SizedBox(height: 24),
            _GoalCommentsSection(
              goalId: goalId,
              comments: goal.comments,
              currentUserUid: currentUserUid,
            ),
            const SizedBox(height: 90),
          ],
        ),
      ),
      floatingActionButton: isManager
          ? FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateCriterionScreen(goalId: goalId),
                ),
              ),
              icon: const Icon(Icons.add),
              label: const Text('معيار جديد'),
            )
          : null,
    );
  }
}

class _CriterionTile extends StatelessWidget {
  const _CriterionTile({required this.criterion});

  final Criterion criterion;

  @override
  Widget build(BuildContext context) {
    final assigneeNames = criterion.assignees
        .map((uid) => FirestoreService.getUser(uid)?.name ?? 'موظف')
        .join('، ');
    final ratio = criterion.completionRatio;
    final aggregate = criterion.aggregateStatus;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Card(
        margin: EdgeInsets.zero,
        // Criteria remain neutral gray/white — never colored with the
        // parent goal's color — per the explicit requirement to keep a
        // clear visual distinction between goal-level and criterion-level
        // UI.
        color: AppColors.surface,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 12,
          ),
          title: Text(
            criterion.title,
            // Smaller + lighter than the goal title (24-28px Bold) above,
            // per the typography-hierarchy requirement.
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.textPrimary,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(
                assigneeNames.isEmpty ? 'بدون موظف' : assigneeNames,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  StatusChip(statusName: aggregate.name, fontSize: 11),
                  if (ratio.total > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '${ratio.completed} من ${ratio.total} مكتمل',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => CriterionDetailScreen(
                goalId: criterion.goalId,
                criterionId: criterion.criterionId,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Goal-level "تعليقات" section — architecturally SEPARATE from the
/// Criterion chat system (CriterionChatBody), reusing the exact Quick-
/// Comments UX mechanism already built for tasks: an inline text box +
/// إرسال button, each comment showing author name + timestamp + text.
class _GoalCommentsSection extends StatelessWidget {
  const _GoalCommentsSection({
    required this.goalId,
    required this.comments,
    required this.currentUserUid,
  });

  final String goalId;
  final List<GoalComment> comments;
  final String currentUserUid;

  Future<void> _addComment(BuildContext context, String text) async {
    await context.read<GoalProvider>().addComment(
      goalId: goalId,
      authorUid: currentUserUid,
      text: text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = List<GoalComment>.of(comments)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تعليقات',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        if (sorted.isEmpty)
          const Text(
            'لا توجد تعليقات بعد',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          ...sorted.map((c) => _GoalCommentTile(comment: c)),
        const SizedBox(height: 8),
        _CommentInputBox(onSubmit: (text) => _addComment(context, text)),
      ],
    );
  }
}

class _GoalCommentTile extends StatelessWidget {
  const _GoalCommentTile({required this.comment});

  final GoalComment comment;

  @override
  Widget build(BuildContext context) {
    final authorName =
        FirestoreService.getUser(comment.authorUid)?.name ?? 'مستخدم';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: AppColors.statusPending.withValues(alpha: 0.05),
      child: ListTile(
        dense: true,
        leading: const Icon(Icons.comment_outlined),
        title: Text(comment.text, style: const TextStyle(fontSize: 13)),
        subtitle: Text(
          '$authorName • '
          '${intl.DateFormat('yyyy/MM/dd HH:mm').format(comment.createdAt)}',
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

/// Inline "تعليقات" input box: a plain multi-line [TextField] plus an
/// "إرسال" (Send) [FilledButton] — deliberately NOT a modal dialog,
/// duplicated verbatim (same convention as the Task Quick-Comments
/// feature's `_CommentInputBox`) from
/// task_detail_screen.dart/task_review_detail_screen.dart, matching this
/// codebase's existing convention of per-screen private widgets.
class _CommentInputBox extends StatefulWidget {
  const _CommentInputBox({required this.onSubmit});

  final Future<void> Function(String text) onSubmit;

  @override
  State<_CommentInputBox> createState() => _CommentInputBoxState();
}

class _CommentInputBoxState extends State<_CommentInputBox> {
  final _controller = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    await widget.onSubmit(text);
    if (!mounted) return;
    _controller.clear();
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _controller,
          enabled: !_sending,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: context.tr('اكتب تعليقًا...'),
            isDense: true,
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: _sending ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, size: 18),
            label: const Text('إرسال'),
          ),
        ),
      ],
    );
  }
}
