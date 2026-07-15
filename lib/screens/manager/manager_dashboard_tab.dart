import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart' as intl;
import '../../models/task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/date_nav_arrow_button.dart';
import '../../widgets/dashboard_stat_widgets.dart';
import '../../widgets/task_list_tile.dart';
import '../../widgets/task_kanban_board.dart';
import 'quick_add_task_sheet.dart';
import 'task_review_detail_screen.dart';

// `_RangeMode` is now a thin local alias of the shared `TimeRangeMode`
// (dashboard_stat_widgets.dart) so this screen's existing internal API
// (day/week/month) is unchanged, while both the main dashboard AND the
// new employee stats detail page drive the SAME `TimeRangeSegmented`
// widget off one shared enum — no separate/duplicated mode type per
// screen.
typedef _RangeMode = TimeRangeMode;

/// "قائمة"/"لوحة" view-mode toggle for the manager's "الرئيسية" screen.
/// Persisted via shared_preferences (per explicit requirement: "العرض يُحفظ
/// كتفضيل حتى ما يرجع كل مرة للـ list الافتراضي") so the manager's last
/// choice survives app restarts. NOT a separate tab — lives inside this
/// same dashboard screen, per requirement #0.
enum _ViewMode { list, kanban }

const _kViewModePrefKey = 'manager_dashboard_view_mode';

/// Manager dashboard — daily / weekly / monthly tracking views as required.
class ManagerDashboardTab extends StatefulWidget {
  const ManagerDashboardTab({super.key});

  @override
  State<ManagerDashboardTab> createState() => _ManagerDashboardTabState();
}

class _ManagerDashboardTabState extends State<ManagerDashboardTab> {
  _RangeMode _mode = _RangeMode.day;
  DateTime _anchor = DateTime.now();
  _ViewMode _viewMode = _ViewMode.list;

  @override
  void initState() {
    super.initState();
    _loadViewModePreference();
  }

  Future<void> _loadViewModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kViewModePrefKey);
    if (saved == _ViewMode.kanban.name && mounted) {
      setState(() => _viewMode = _ViewMode.kanban);
    }
  }

  Future<void> _setViewMode(_ViewMode mode) async {
    setState(() => _viewMode = mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kViewModePrefKey, mode.name);
  }

  List<AppTask> _tasksForRange(TaskProvider provider) {
    switch (_mode) {
      case _RangeMode.day:
        return provider.tasksForDay(_anchor);
      case _RangeMode.week:
        return provider.tasksForWeek(_anchor);
      case _RangeMode.month:
        return provider.tasksForMonth(_anchor);
    }
  }

  void _shift(int direction) {
    setState(() {
      switch (_mode) {
        case _RangeMode.day:
          _anchor = _anchor.add(Duration(days: direction));
          break;
        case _RangeMode.week:
          _anchor = _anchor.add(Duration(days: 7 * direction));
          break;
        case _RangeMode.month:
          _anchor = DateTime(_anchor.year, _anchor.month + direction, 1);
          break;
      }
    });
  }

  String get _rangeLabel {
    final df = intl.DateFormat('yyyy/MM/dd');
    switch (_mode) {
      case _RangeMode.day:
        return df.format(_anchor);
      case _RangeMode.week:
        final weekday = _anchor.weekday;
        final start = _anchor.subtract(Duration(days: weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${df.format(start)} - ${df.format(end)}';
      case _RangeMode.month:
        return '${_arabicMonths[_anchor.month - 1]} ${_anchor.year}';
    }
  }

  /// Arabic period noun used to build tooltip labels ('اليوم التالي',
  /// 'الأسبوع السابق', ...) matching the currently-selected range mode.
  String get _periodLabel {
    switch (_mode) {
      case _RangeMode.day:
        return 'اليوم';
      case _RangeMode.week:
        return 'الأسبوع';
      case _RangeMode.month:
        return 'الشهر';
    }
  }

  /// Period-aware empty-state title for the "لا توجد مهام..." case (item
  /// #4 of the redesign request). For day mode this literally matches the
  /// requested exact wording "لا توجد مهام مجدولة اليوم".
  String get _emptyStateTitle {
    switch (_mode) {
      case _RangeMode.day:
        return 'لا توجد مهام مجدولة اليوم';
      case _RangeMode.week:
        return 'لا توجد مهام مجدولة هذا الأسبوع';
      case _RangeMode.month:
        return 'لا توجد مهام مجدولة هذا الشهر';
    }
  }

  static const _arabicMonths = [
    'يناير',
    'فبراير',
    'مارس',
    'أبريل',
    'مايو',
    'يونيو',
    'يوليو',
    'أغسطس',
    'سبتمبر',
    'أكتوبر',
    'نوفمبر',
    'ديسمبر',
  ];

  Widget _viewToggleButton(_ViewMode mode, IconData icon, String label) {
    final selected = _viewMode == mode;
    return Expanded(
      child: InkWell(
        onTap: selected ? null : () => _setViewMode(mode),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.navy : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final managerUid = context.read<AuthProvider>().currentUser!.uid;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Column(
          children: [
            // View toggle ("قائمة" / "لوحة") — lives beside the time
            // filter, inside this SAME "الرئيسية" screen (no separate
            // tab). Persisted to shared_preferences on every change.
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFEDEFF3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _viewToggleButton(
                    _ViewMode.list,
                    Icons.view_list_outlined,
                    'قائمة',
                  ),
                  _viewToggleButton(
                    _ViewMode.kanban,
                    Icons.view_kanban_outlined,
                    'لوحة',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // Time filter (يومي/أسبوعي/شهري) — shown ONLY in "قائمة" mode.
            // Kanban always shows every current non-archived task
            // regardless of date, so the date range control is meaningless
            // there and is hidden entirely (per explicit requirement).
            if (_viewMode == _ViewMode.list) ...[
              // Unified pill-shaped navy segmented control (replaces the
              // default `SegmentedButton`, which rendered as three
              // separate bordered boxes) — per explicit redesign request
              // #1: "شريط واحد بخلفية داكنة... والقسم المُفعّل يظهر بخلفية
              // بيضاء بارزة داخل الشريط".
              TimeRangeSegmented(
                mode: _mode,
                onChanged: (m) => setState(() => _mode = m),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // RTL: right arrow = next period, left arrow = previous.
                  DateNavArrowButton.next(
                    onTap: () => _shift(1),
                    periodLabel: _periodLabel,
                  ),
                  Text(
                    _rangeLabel,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  DateNavArrowButton.previous(
                    onTap: () => _shift(-1),
                    periodLabel: _periodLabel,
                  ),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Expanded(
              child: _viewMode == _ViewMode.list
                  ? _ListView(
                      provider: provider,
                      rangeTasks: _tasksForRange(provider),
                      managerUid: managerUid,
                      emptyStateTitle: _emptyStateTitle,
                    )
                  : TaskKanbanBoard(
                      // Kanban ignores the day/week/month filter entirely —
                      // it always shows EVERY current task (all statuses),
                      // grouped by status only (per explicit requirement).
                      tasks: provider.allTasks,
                      canDrag: true,
                      onTapTask: (t) => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => TaskReviewDetailScreen(task: t),
                        ),
                      ),
                      onStatusChanged: (task, newStatus) {
                        context.read<TaskProvider>().updateStatus(
                          task.taskId,
                          newStatus,
                          managerUid,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The original "قائمة" (list) dashboard content — stat cards + completion
/// chart + date-filtered task list — extracted unchanged into its own
/// widget so it can be swapped for [TaskKanbanBoard] by the view toggle
/// above without duplicating the stat/chart logic inline.
class _ListView extends StatelessWidget {
  const _ListView({
    required this.provider,
    required this.rangeTasks,
    required this.managerUid,
    required this.emptyStateTitle,
  });

  final TaskProvider provider;
  final List<AppTask> rangeTasks;
  final String managerUid;
  final String emptyStateTitle;

  @override
  Widget build(BuildContext context) {
    final stats = provider.statsForRange(rangeTasks);
    return ListView(
      children: [
        // Fixed-size boxes via Wrap (not GridView.count — see the
        // designer dashboard's identical fix for why GridView.count
        // stretches cells on wide viewports).
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            StatCard(metric: DashboardMetric.total, value: stats.total),
            StatCard(metric: DashboardMetric.completed, value: stats.completed),
            StatCard(
              metric: DashboardMetric.pending,
              value: stats.pendingDisplay,
            ),
            StatCard(metric: DashboardMetric.review, value: stats.submitted),
            StatCard(metric: DashboardMetric.rejected, value: stats.rejected),
            StatCard(metric: DashboardMetric.overdue, value: stats.overdue),
          ],
        ),
        const SizedBox(height: 20),
        CompletionChartCard(
          completed: stats.completed,
          overdue: stats.overdue,
          // Same `pendingDisplay` value shown on the قيد الانتظار stat
          // card above (pending + inProgress) — MUST match the card
          // exactly (previously added `submitted` on top of `pending`
          // here, which is what caused the reported card/chart
          // mismatch).
          pending: stats.pendingDisplay,
        ),
        const SizedBox(height: 20),
        Text(
          'المهام (${rangeTasks.length})',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (rangeTasks.isEmpty)
          NoTasksEmptyState(
            title: emptyStateTitle,
            onAddTask: () => QuickAddTaskSheet.show(context),
          )
        else
          ...rangeTasks.map(
            (t) => TaskListTile(task: t, managerUid: managerUid),
          ),
      ],
    );
  }
}
