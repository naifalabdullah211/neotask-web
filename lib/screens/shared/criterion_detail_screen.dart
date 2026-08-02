import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:provider/provider.dart';
import '../../models/criterion_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/criterion_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_selection_field.dart';
import '../../widgets/status_chip.dart';
import 'criterion_chat_body.dart';
import 'edit_criterion_dialog.dart';

/// The core Criterion UI: a Criterion's details on the LEFT and its own
/// dedicated live chat thread on the RIGHT, Smartsheet-row-comment style.
///
/// CRITICAL IMPLEMENTATION NOTE — RTL override: `main.dart` wraps the
/// whole app in `Directionality(textDirection: Directionality.of(context), ...)`.
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
/// approve/reject review gate anymore. There is also NO history log (the
/// model/collection backing it were removed entirely). The chat panel is
/// now backed by [CriterionChatBody] — a fully separate chat system from
/// the Task chat, reading/writing the Firestore subcollection
/// `goals/{goalId}/criteria/{criteriaId}/chat/{messageId}`.
///
/// EXTENDED (multi-employee individual status — additive): the previous
/// single shared 3-state [SegmentedButton] is REPLACED by
/// [_EmployeeStatusRows] — one row per assignee, each with their OWN
/// [DropdownButton], editable ONLY by that specific employee (or the
/// manager, who may override any employee's status — see
/// [_EmployeeStatusRow] doc comment for that judgment call) — plus a
/// separate [_AggregateStatusBanner] showing the derived overall status
/// and completion ratio.
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
                  tooltip: context.tr('تعديل المعيار'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => showEditCriterionDialog(context, criterion),
                ),
                IconButton(
                  tooltip: context.tr('حذف المعيار'),
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
              // Goal title shown noticeably larger/Bold elsewhere (the
              // goal detail header); here it is only a small breadcrumb,
              // so no font-size change is needed on this specific line —
              // the typography-hierarchy requirement is about the goal
              // TITLE vs criterion TITLE when BOTH are shown as primary
              // headings together (see _CriterionPanel below), not this
              // secondary breadcrumb caption.
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
                  TabBar(
                    tabs: [
                      Tab(text: context.tr('المعيار')),
                      Tab(text: context.tr('المحادثة')),
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

/// LEFT panel — criterion info + per-employee individual status rows +
/// the derived aggregate/overall status banner.
class _CriterionPanel extends StatelessWidget {
  const _CriterionPanel({
    required this.criterion,
    required this.currentUserUid,
    required this.isManager,
  });

  final Criterion criterion;
  final String currentUserUid;
  final bool isManager;

  @override
  Widget build(BuildContext context) {
    final assigneeNames = criterion.assignees
        .map((uid) => FirestoreService.getUser(uid)?.name ?? 'موظف')
        .join('، ');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          criterion.title,
          // Deliberately smaller (16-18px) + a lighter weight than the
          // goal title (24-28px Bold, see goal_detail_screen.dart's
          // header) — the typography-hierarchy requirement, applied here
          // since this screen shows "ضمن الهدف: {goal.title}" directly
          // above (in the AppBar) alongside this criterion title.
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 10),
        _AggregateStatusBanner(criterion: criterion),
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
        const Text(
          'حالة كل موظف',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        if (criterion.assignees.isEmpty)
          const Text(
            'لا يوجد موظفون مُسندون لهذا المعيار بعد',
            style: TextStyle(color: AppColors.textSecondary),
          )
        else
          ...criterion.assignees.map(
            (uid) => _EmployeeStatusRow(
              criterion: criterion,
              employeeUid: uid,
              currentUserUid: currentUserUid,
              isManager: isManager,
            ),
          ),
        if (isManager) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () =>
                showEditCriterionAssigneesDialog(context, criterion),
            icon: const Icon(Icons.group_add_outlined, size: 18),
            label: const Text('إضافة/إزالة موظفين'),
          ),
        ],
        const SizedBox(height: 40),
      ],
    );
  }
}

/// Derived overall/aggregate status — computed client-side from
/// [Criterion.aggregateStatus] (see criterion_model.dart doc comment),
/// NEVER persisted. Shows both the status label AND the "X من Y مكتمل"
/// ratio explicitly offered as an alternative display in the spec.
class _AggregateStatusBanner extends StatelessWidget {
  const _AggregateStatusBanner({required this.criterion});

  final Criterion criterion;

  @override
  Widget build(BuildContext context) {
    final aggregate = criterion.aggregateStatus;
    final ratio = criterion.completionRatio;

    return Row(
      children: [
        const Text(
          'الحالة العامة: ',
          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        StatusChip(statusName: aggregate.name),
        if (ratio.total > 0) ...[
          const SizedBox(width: 8),
          Text(
            '(${ratio.completed} من ${ratio.total} مكتمل)',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// One employee's OWN status row. Only that employee (or the manager) may
/// change it via the [DropdownButton] — for anyone else it renders
/// disabled/read-only.
///
/// JUDGMENT CALL (flagged per this codebase's established convention):
/// the spec explicitly says "كل موظف يحدّث حالته هو فقط، ولا يقدر يعدّل
/// حالة زميله" (each employee updates ONLY their own status, cannot edit
/// a colleague's) — this literally restricts EMPLOYEE-to-EMPLOYEE edits,
/// but does not explicitly forbid the MANAGER from overriding an
/// individual employee's status. Per this codebase's existing precedent
/// (criteria have NO manager-approval gate; the manager already has
/// unrestricted Firestore update rights on every criterion field), the
/// manager is ALSO allowed to edit any employee's row here — consistent
/// with "the manager can do anything an employee can, plus more" being
/// the norm elsewhere in this file (e.g. delete/edit criterion). If this
/// reading is wrong, restricting manager edits here is a one-line change
/// (drop the `isManager` term from `canEdit` below).
class _EmployeeStatusRow extends StatefulWidget {
  const _EmployeeStatusRow({
    required this.criterion,
    required this.employeeUid,
    required this.currentUserUid,
    required this.isManager,
  });

  final Criterion criterion;
  final String employeeUid;
  final String currentUserUid;
  final bool isManager;

  @override
  State<_EmployeeStatusRow> createState() => _EmployeeStatusRowState();
}

class _EmployeeStatusRowState extends State<_EmployeeStatusRow> {
  bool _busy = false;

  Future<void> _setStatus(CriterionStatus status) async {
    setState(() => _busy = true);
    await context.read<CriterionProvider>().setEmployeeStatus(
      criterionId: widget.criterion.criterionId,
      employeeUid: widget.employeeUid,
      status: status,
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final name = FirestoreService.getUser(widget.employeeUid)?.name ?? 'موظف';
    final status = widget.criterion.statusFor(widget.employeeUid);
    final canEdit =
        !_busy &&
        (widget.isManager || widget.employeeUid == widget.currentUserUid);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            width: 170,
            child: NeoSelectionField<CriterionStatus>(
              label: 'الحالة',
              value: status,
              enabled: canEdit,
              options: CriterionStatus.values
                  .map(
                    (item) => NeoSelectionOption(
                      value: item,
                      label: criterionStatusLabelAr(item),
                      color: statusColor(item.name),
                    ),
                  )
                  .toList(),
              onChanged: canEdit ? _setStatus : null,
            ),
          ),
        ],
      ),
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

/// Manager-only dialog to add/remove employees from a criterion's
/// responsible list AT ANY TIME. Per the explicit requirement, this must
/// NOT affect the already-recorded statuses of employees who remain
/// assigned — [CriterionProvider.setAssignees] already guarantees this
/// (seeds new employees fresh, drops removed employees' entries, leaves
/// every remaining employee's own entry untouched).
Future<void> showEditCriterionAssigneesDialog(
  BuildContext context,
  Criterion criterion,
) async {
  final employees = FirestoreService.getAllEmployees()
      .where((u) => u.accountStatus == AccountStatus.active)
      .toList();
  final Set<String> selected = {...criterion.assignees};
  bool saving = false;

  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('إضافة/إزالة موظفين'),
          content: SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'إزالة موظف لا تؤثر على حالة باقي الموظفين المُسندين مسبقًا.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (employees.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'لا يوجد موظفون نشطون بعد.',
                        style: TextStyle(color: AppColors.statusRejected),
                      ),
                    )
                  else
                    ...employees.map((AppUser u) {
                      final isSelected = selected.contains(u.uid);
                      return CheckboxListTile(
                        value: isSelected,
                        title: Text(u.name),
                        subtitle: Text(u.employeeNumber),
                        onChanged: saving
                            ? null
                            : (checked) {
                                setState(() {
                                  if (checked == true) {
                                    selected.add(u.uid);
                                  } else {
                                    selected.remove(u.uid);
                                  }
                                });
                              },
                      );
                    }),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      setState(() => saving = true);
                      try {
                        await context.read<CriterionProvider>().setAssignees(
                          criterionId: criterion.criterionId,
                          assignees: selected.toList(),
                        );
                        if (context.mounted) Navigator.of(context).pop(true);
                      } catch (e) {
                        setState(() => saving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تعذر حفظ التعديلات، حاول مجددًا'),
                            ),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('حفظ'),
            ),
          ],
        );
      },
    ),
  );

  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم تحديث قائمة الموظفين')));
  }
}
