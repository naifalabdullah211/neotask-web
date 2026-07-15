import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/criterion_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/criterion_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';
import 'criterion_chat_body.dart';
import 'edit_criterion_dialog.dart';

/// The core Criterion UI: a Criterion's details on the LEFT and its own
/// dedicated live chat thread on the RIGHT, Smartsheet-row-comment style.
///
/// CRITICAL IMPLEMENTATION NOTE — RTL override: `main.dart` wraps the
/// whole app in `Directionality(textDirection: TextDirection.rtl, ...)`.
/// Under RTL, a plain `Row(children: [A, B])` renders A on the PHYSICAL
/// RIGHT and B on the PHYSICAL LEFT. To guarantee criterion-physically-
/// left / chat-physically-right regardless of the app-wide RTL wrapper,
/// the split-panel `Row` below explicitly sets
/// `textDirection: TextDirection.ltr`.
///
/// On wide viewports (>= 700 logical px — tablet/landscape) this renders
/// the literal left/right split; on narrow phones it degrades to two
/// tabs ("المعيار" then "المحادثة"), preserving the same reading-order
/// intent without an unusable cramped split.
///
/// REBUILD NOTE: per the simplified spec, a Criterion has NO manager
/// approve/reject review gate anymore — any assigned employee or the
/// manager may freely set the 3-state status (لم يبدأ/قيد التنفيذ/
/// مكتمل). There is also NO history log (the model/collection backing
/// it were removed entirely). The chat panel is now backed by
/// [CriterionChatBody] — a fully separate chat system from the Task
/// chat, reading/writing the Firestore subcollection
/// `goals/{goalId}/criteria/{criteriaId}/chat/{messageId}`.
class CriterionDetailScreen extends StatelessWidget {
  const CriterionDetailScreen({
    super.key,
    required this.goalId,
    required this.criterionId,
  });

  final String goalId;
  final String criterionId;

  @override
  Widget build(BuildContext context) {
    final criterionProvider = context.watch<CriterionProvider>();
    final criterion = criterionProvider.getCriterion(criterionId);
    final currentUser = context.watch<AuthProvider>().currentUser!;
    final isManager = context.watch<AuthProvider>().isManager;
    // Read-only designer/observer role: the chat panel needs an explicit
    // readOnly flag so it does not expose a message-input bar.
    final isDesigner = context.watch<AuthProvider>().isDesigner;

    if (criterion == null) {
      return const Scaffold(body: Center(child: Text('المعيار غير موجود')));
    }

    final goal = FirestoreService.getGoal(criterion.goalId);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(criterion.title),
        actions: isManager
            ? [
                IconButton(
                  tooltip: 'تعديل المعيار',
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      showEditCriterionDialog(context, criterion),
                ),
                IconButton(
                  tooltip: 'حذف المعيار',
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => confirmAndDeleteCriterion(
                    context,
                    criterion,
                    onDeleted: () => Navigator.of(context).pop(),
                  ),
                ),
              ]
            : null,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              goal != null ? 'ضمن الهدف: ${goal.title}' : '',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            final criterionPanel = _CriterionPanel(
              criterion: criterion,
              currentUserUid: currentUser.uid,
              isManager: isManager,
            );
            final chatPanel = CriterionChatBody(
              goalId: goalId,
              criterionId: criterionId,
              currentUserUid: currentUser.uid,
              readOnly: isDesigner,
            );

            if (isWide) {
              // Forced LTR order: criterion physically LEFT, chat
              // physically RIGHT, independent of the app-wide RTL wrap.
              return Row(
                textDirection: TextDirection.ltr,
                children: [
                  Expanded(flex: 5, child: criterionPanel),
                  const VerticalDivider(width: 1),
                  Expanded(flex: 6, child: chatPanel),
                ],
              );
            }

            return DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'المعيار'),
                      Tab(text: 'المحادثة'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(children: [criterionPanel, chatPanel]),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// LEFT panel — criterion info and a simple 3-state status selector. Any
/// assigned employee OR the manager may change the status freely (no
/// approval gate).
class _CriterionPanel extends StatefulWidget {
  const _CriterionPanel({
    required this.criterion,
    required this.currentUserUid,
    required this.isManager,
  });

  final Criterion criterion;
  final String currentUserUid;
  final bool isManager;

  @override
  State<_CriterionPanel> createState() => _CriterionPanelState();
}

class _CriterionPanelState extends State<_CriterionPanel> {
  bool _busy = false;

  Future<void> _setStatus(CriterionStatus status) async {
    setState(() => _busy = true);
    await context.read<CriterionProvider>().updateStatus(
      widget.criterion.criterionId,
      status,
      widget.currentUserUid,
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final criterion = widget.criterion;
    final assigneeNames = criterion.assignees
        .map((uid) => FirestoreService.getUser(uid)?.name ?? 'موظف')
        .join('، ');
    final isAssignedToMe = criterion.assignees.contains(
      widget.currentUserUid,
    );
    final canEditStatus = widget.isManager || isAssignedToMe;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          criterion.title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        StatusChip(statusName: criterion.status.name),
        if (criterion.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            criterion.description,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
        const SizedBox(height: 12),
        _InfoRow(
          icon: Icons.people_outline,
          label: 'الموظفون المشاركون',
          value: assigneeNames.isEmpty ? 'بدون موظف' : assigneeNames,
        ),
        const SizedBox(height: 20),
        if (canEditStatus) ...[
          const Text(
            'الحالة',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          SegmentedButton<CriterionStatus>(
            segments: const [
              ButtonSegment(
                value: CriterionStatus.notStarted,
                label: Text('لم يبدأ'),
                icon: Icon(Icons.circle_outlined),
              ),
              ButtonSegment(
                value: CriterionStatus.inProgress,
                label: Text('قيد التنفيذ'),
                icon: Icon(Icons.autorenew),
              ),
              ButtonSegment(
                value: CriterionStatus.completed,
                label: Text('مكتمل'),
                icon: Icon(Icons.check_circle_outline),
              ),
            ],
            selected: {criterion.status},
            onSelectionChanged: _busy
                ? null
                : (s) => _setStatus(s.first),
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
