import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/task_urgency_indicator.dart';
import '../../widgets/date_nav_arrow_button.dart';
import '../../widgets/favorite_star_button.dart';
import 'task_review_detail_screen.dart';

enum _RangeMode { day, week, month }

/// Manager dashboard — daily / weekly / monthly tracking views as required.
class ManagerDashboardTab extends StatefulWidget {
  const ManagerDashboardTab({super.key});

  @override
  State<ManagerDashboardTab> createState() => _ManagerDashboardTabState();
}

class _ManagerDashboardTabState extends State<ManagerDashboardTab> {
  _RangeMode _mode = _RangeMode.day;
  DateTime _anchor = DateTime.now();

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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final rangeTasks = _tasksForRange(provider);
    final stats = provider.statsForRange(rangeTasks);
    final managerUid = context.read<AuthProvider>().currentUser!.uid;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<_RangeMode>(
            segments: const [
              ButtonSegment(value: _RangeMode.day, label: Text('يومي')),
              ButtonSegment(value: _RangeMode.week, label: Text('أسبوعي')),
              ButtonSegment(value: _RangeMode.month, label: Text('شهري')),
            ],
            selected: {_mode},
            onSelectionChanged: (s) => setState(() => _mode = s.first),
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
          const SizedBox(height: 8),
          // Fixed-size boxes via Wrap (not GridView.count — see the
          // designer dashboard's identical fix for why GridView.count
          // stretches cells on wide viewports).
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatCard(
                metric: DashboardMetric.total,
                value: stats.total,
                icon: Icons.assignment_outlined,
              ),
              _StatCard(
                metric: DashboardMetric.completed,
                value: stats.completed,
                icon: Icons.check_circle_outline,
              ),
              _StatCard(
                metric: DashboardMetric.pending,
                value: stats.pendingDisplay,
                icon: Icons.hourglass_empty,
              ),
              _StatCard(
                metric: DashboardMetric.review,
                value: stats.submitted,
                icon: Icons.rate_review_outlined,
              ),
              _StatCard(
                metric: DashboardMetric.rejected,
                value: stats.rejected,
                icon: Icons.cancel_outlined,
              ),
              _StatCard(
                metric: DashboardMetric.overdue,
                value: stats.overdue,
                icon: Icons.warning_amber_outlined,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ManagerCompletionChartCard(
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
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'لا توجد مهام في هذه الفترة',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
            )
          else
            ...rangeTasks.map(
              (t) => Card(
                child: ListTile(
                  // Clickable for EVERY status (assigned/inProgress/
                  // submitted/approved/rejected/editRequested) — previously
                  // gated to `status == submitted` only, which made every
                  // other-status card silently non-interactive. Matches the
                  // pattern already used by manager_calendar_screen.dart and
                  // designer_dashboard_tab.dart.
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => TaskReviewDetailScreen(task: t),
                      ),
                    );
                  },
                  leading: TaskUrgencyDot(task: t),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          t.title,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      FavoriteStarButton(
                        userUid: managerUid,
                        taskId: t.taskId,
                        size: 20,
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          StatusChip(statusName: t.status.name),
                          PriorityBadge(
                            priorityName: t.priority.name,
                            compact: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${t.category} · ${intl.DateFormat('yyyy/MM/dd').format(t.dueDate)}',
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final DashboardMetric metric;
  final int value;
  final IconData icon;

  const _StatCard({
    required this.metric,
    required this.value,
    required this.icon,
  });

  static const double _boxWidth = 104;

  @override
  Widget build(BuildContext context) {
    // Color/label read from the shared dashboardMetricColors/
    // dashboardMetricLabelsAr maps (app_theme.dart) — single source of
    // truth shared with _ManagerCompletionChartCard below.
    final color = dashboardMetricColors[metric]!;
    final label = dashboardMetricLabelsAr[metric]!;
    return Container(
      width: _boxWidth,
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7E9EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 15, color: Colors.white),
          ),
          const SizedBox(height: 10),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              height: 1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Same completed/overdue/pending bar chart used on the designer
/// dashboard — kept as a separate class here (rather than importing the
/// private widget from the other file) since both `_CompletionChartCard`
/// classes are file-private by convention in this codebase.
class _ManagerCompletionChartCard extends StatelessWidget {
  const _ManagerCompletionChartCard({
    required this.completed,
    required this.overdue,
    required this.pending,
  });

  final int completed;
  final int overdue;
  final int pending;

  @override
  Widget build(BuildContext context) {
    final maxVal = [
      completed,
      overdue,
      pending,
    ].fold<int>(1, (m, v) => v > m ? v : m);
    final maxY = (maxVal * 1.35).ceilToDouble();

    // Same DashboardMetric enum + shared color/label maps used by the
    // stat cards above — guarantees identical colors between the cards
    // and this chart.
    final bars = <_ManagerBarSpec>[
      _ManagerBarSpec(DashboardMetric.completed, completed),
      _ManagerBarSpec(DashboardMetric.overdue, overdue),
      _ManagerBarSpec(DashboardMetric.pending, pending),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE7E9EE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 18,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'المنجز مقابل المتأخر',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 190,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                minY: 0,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY / 4).clamp(1, double.infinity),
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: const Color(0xFFEEF0F4), strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final i = value.toInt();
                        if (i < 0 || i >= bars.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            bars[i].label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  for (var i = 0; i < bars.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: bars[i].value.toDouble(),
                          color: bars[i].color,
                          width: 34,
                          borderRadius: BorderRadius.circular(6),
                          // Deliberately NOT using backDrawRodData/
                          // BackgroundBarChartRodData — a full-height
                          // pale-gray "ghost" bar behind every real bar
                          // reads as an unfinished loading skeleton, not
                          // a chart. Gridlines above give scale instead.
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // COLOR-MISMATCH FIX: the chart's X-axis labels above (drawn by
          // fl_chart's BarChart) are laid out strictly in `bars` list
          // order (completed, overdue, pending — left to right),
          // completely ignoring the app's ambient RTL Directionality.
          // This legend row, however, is a plain Flutter `Row`, which
          // DOES auto-mirror its children under RTL — so without forcing
          // `textDirection: ltr` here, the legend silently renders in
          // REVERSED order relative to the axis labels/bars above it
          // (e.g. the leftmost legend chip showed "قيد الانتظار"'s
          // value+color while the leftmost bar/label above was "مكتملة").
          // Forcing ltr here keeps this row's visual order identical to
          // the `bars` list order used by the chart, so each value+color
          // chip lines up under its correct bar.
          Directionality(
            textDirection: TextDirection.ltr,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final b in bars)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: b.color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${b.value}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: b.color,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

class _ManagerBarSpec {
  _ManagerBarSpec(this.metric, this.value)
    : label = dashboardMetricLabelsAr[metric]!,
      color = dashboardMetricColors[metric]!;
  final DashboardMetric metric;
  final int value;
  final String label;
  final Color color;
}
