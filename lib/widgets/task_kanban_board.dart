import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:intl/intl.dart' as intl;
import '../models/task_model.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';
import 'status_chip.dart';

/// Reusable Kanban board for tasks, grouped by [PrimaryTaskStatus] — the
/// SAME 5-bucket single-source-of-truth classification already used by
/// every dashboard stat card/chart (see task_model.dart's
/// `AppTaskStatusX.primaryStatus` doc comment). "متأخرة" (overdue) is
/// deliberately NOT a 6th column — per the explicit design requirement it
/// stays a badge on the card itself, matching how [AppTask.isOverdue] is
/// treated everywhere else in this codebase (independent of status,
/// coexists with any non-completed column).
///
/// Used by BOTH:
/// - the manager dashboard (drag & drop ENABLED — dragging a card to a
///   different column calls [onStatusChanged], which the caller wires to
///   `TaskProvider.updateStatus` so the write goes to Firestore AND is
///   logged to the task's history exactly like the existing manual
///   status-editor dialog in task_review_detail_screen.dart).
/// - the employee tasks tab (VIEW-ONLY — [canDrag]=false; tapping a card
///   only calls [onTapTask], no drag handles are attached at all).
class TaskKanbanBoard extends StatelessWidget {
  const TaskKanbanBoard({
    super.key,
    required this.tasks,
    required this.onTapTask,
    this.onStatusChanged,
    this.canDrag = false,
  });

  final List<AppTask> tasks;
  final void Function(AppTask task) onTapTask;

  /// Called when a card is dropped onto a column whose bucket differs
  /// from the task's current [AppTask.primaryStatus]. Null (or
  /// [canDrag]=false) disables dragging entirely — used for the
  /// read-only employee view.
  final void Function(AppTask task, TaskStatus newStatus)? onStatusChanged;
  final bool canDrag;

  static const List<_KanbanColumnSpec> _columns = [
    _KanbanColumnSpec(
      PrimaryTaskStatus.pending,
      'قيد الانتظار',
      TaskStatus.assigned,
    ),
    _KanbanColumnSpec(
      PrimaryTaskStatus.inProgress,
      'قيد التنفيذ',
      TaskStatus.inProgress,
    ),
    _KanbanColumnSpec(
      PrimaryTaskStatus.submitted,
      'بانتظار المراجعة',
      TaskStatus.submitted,
    ),
    _KanbanColumnSpec(
      PrimaryTaskStatus.completed,
      'مكتملة',
      TaskStatus.approved,
    ),
    _KanbanColumnSpec(
      PrimaryTaskStatus.rejected,
      'مرفوضة',
      TaskStatus.rejected,
    ),
  ];

  /// Desktop/wide-viewport breakpoint — above this width, columns are
  /// laid out as an equal-width grid (Row + Expanded); below it, columns
  /// are fixed-width and horizontally scrollable (mobile).
  static const double _wideBreakpoint = 900;

  @override
  Widget build(BuildContext context) {
    final byColumn = <PrimaryTaskStatus, List<AppTask>>{
      for (final c in _columns) c.bucket: <AppTask>[],
    };
    for (final t in tasks) {
      byColumn[t.primaryStatus]!.add(t);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;
        // Caller MUST give this widget a bounded height (wrap in
        // `Expanded` inside a `Column`) — each column needs a definite
        // height for its own internal scroll region.
        final columnHeight = constraints.maxHeight.isFinite
            ? constraints.maxHeight
            : 520.0;

        final columnWidgets = [
          for (final c in _columns)
            _KanbanColumn(
              key: ValueKey(c.bucket),
              spec: c,
              tasks: byColumn[c.bucket]!,
              onTapTask: onTapTask,
              onStatusChanged: canDrag ? onStatusChanged : null,
              width: isWide ? null : 270,
              height: columnHeight,
            ),
        ];

        if (isWide) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [for (final w in columnWidgets) Expanded(child: w)],
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: columnWidgets,
          ),
        );
      },
    );
  }
}

class _KanbanColumnSpec {
  const _KanbanColumnSpec(this.bucket, this.label, this.targetStatus);
  final PrimaryTaskStatus bucket;
  final String label;
  final TaskStatus targetStatus;
}

class _KanbanColumn extends StatefulWidget {
  const _KanbanColumn({
    super.key,
    required this.spec,
    required this.tasks,
    required this.onTapTask,
    required this.onStatusChanged,
    required this.width,
    required this.height,
  });

  final _KanbanColumnSpec spec;
  final List<AppTask> tasks;
  final void Function(AppTask task) onTapTask;
  final void Function(AppTask task, TaskStatus newStatus)? onStatusChanged;
  final double? width; // null => Expanded fills available width (wide layout)
  final double height;

  @override
  State<_KanbanColumn> createState() => _KanbanColumnState();
}

class _KanbanColumnState extends State<_KanbanColumn> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    // Reuse the app-wide per-status color function (app_theme.dart) —
    // the SAME color every StatusChip already uses for this status —
    // rather than inventing a parallel color mapping for column headers.
    final color = statusColor(widget.spec.targetStatus.name);

    final content = Container(
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: _hovering
            ? color.withValues(alpha: 0.08)
            : const Color(0xFFF1F3F7),
        borderRadius: BorderRadius.circular(AppRadius.lg - 2),
        border: Border.all(
          color: _hovering ? color : AppColors.divider,
          width: _hovering ? 1.6 : 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${widget.spec.label} (${widget.tasks.length})',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: widget.tasks.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Text(
                        'لا توجد مهام',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    itemCount: widget.tasks.length,
                    itemBuilder: (context, i) => _KanbanCard(
                      task: widget.tasks[i],
                      onTap: () => widget.onTapTask(widget.tasks[i]),
                      draggable: widget.onStatusChanged != null,
                    ),
                  ),
          ),
        ],
      ),
    );

    final sized = SizedBox(
      width: widget.width,
      height: widget.height,
      child: content,
    );

    final onChanged = widget.onStatusChanged;
    if (onChanged == null) return sized;

    return DragTarget<AppTask>(
      // Any column accepts any dragged task — drops are allowed between
      // any two columns directly, with no forced sequence (per explicit
      // requirement: "السحب مسموح بين أي عمودين مباشرة، بدون فرض تسلسل
      // إلزامي").
      onWillAcceptWithDetails: (details) {
        if (!_hovering) setState(() => _hovering = true);
        return true;
      },
      onLeave: (_) {
        if (_hovering) setState(() => _hovering = false);
      },
      onAcceptWithDetails: (details) {
        setState(() => _hovering = false);
        final dropped = details.data;
        if (dropped.primaryStatus != widget.spec.bucket) {
          onChanged(dropped, widget.spec.targetStatus);
        }
      },
      builder: (context, candidateData, rejectedData) => sized,
    );
  }
}

class _KanbanCard extends StatelessWidget {
  const _KanbanCard({
    required this.task,
    required this.onTap,
    required this.draggable,
  });

  final AppTask task;
  final VoidCallback onTap;
  final bool draggable;

  @override
  Widget build(BuildContext context) {
    final card = _CardBody(task: task);
    final tappable = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: card,
    );

    if (!draggable) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: tappable,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Draggable<AppTask>(
        data: task,
        feedback: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 240,
            child: Opacity(opacity: 0.92, child: card),
          ),
        ),
        childWhenDragging: Opacity(opacity: 0.35, child: card),
        child: tappable,
      ),
    );
  }
}

/// Card body — per requirement #3: title, assigned employee, priority,
/// due date, and an overdue ("متأخرة") badge/flag when applicable. Same
/// visual language (colors, PriorityBadge) as the existing list-view task
/// cards, just recomposed for the narrower Kanban column width.
class _CardBody extends StatelessWidget {
  const _CardBody({required this.task});
  final AppTask task;

  @override
  Widget build(BuildContext context) {
    final assignee = FirestoreService.getUser(task.assignedTo);
    final overdue = task.isOverdue;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.divider),
        boxShadow: AppElevation.lowShadow,
      ),
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            task.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 13,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  assignee?.name ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              PriorityBadge(priorityName: task.priority.name, compact: true),
              const Spacer(),
              Text(
                intl.DateFormat('MM/dd').format(task.dueDate),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (overdue) ...[
            const SizedBox(height: 6),
            AppPill(
              color: AppColors.overdue,
              icon: Icons.warning_amber_rounded,
              label: 'متأخرة',
              compact: true,
            ),
          ],
        ],
      ),
    );
  }
}
