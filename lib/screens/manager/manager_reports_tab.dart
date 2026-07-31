import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/pdf_report_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/date_nav_arrow_button.dart';

enum _ReportRange { day, week, month, employee }

/// Manager reports tab. PDF export is strictly ON-DEMAND (a button the
/// manager presses) — never generated automatically, per requirement.
class ManagerReportsTab extends StatefulWidget {
  const ManagerReportsTab({super.key});

  @override
  State<ManagerReportsTab> createState() => _ManagerReportsTabState();
}

class _ManagerReportsTabState extends State<ManagerReportsTab> {
  _ReportRange _range = _ReportRange.day;
  DateTime _anchor = DateTime.now();
  String? _selectedEmployeeUid;
  bool _exporting = false;

  // Manager personal tasks (المهام الشخصية للمدير) — NEW: the day/week/
  // month branches must exclude `isPersonal` tasks so a manager's own
  // reminder is never counted into a team performance report (see
  // TaskProvider.teamTasks doc comment). The `employee` branch is
  // deliberately left unfiltered: `tasksForEmployee` is keyed by
  // `_selectedEmployeeUid`, which is only ever populated from
  // FirestoreService.getAllEmployees() (see the dropdown below) — the
  // manager's own uid is never a selectable value there, so this branch
  // can never surface a personal task in the first place.
  List<AppTask> _filteredTasks(TaskProvider provider) {
    switch (_range) {
      case _ReportRange.day:
        return provider
            .tasksForDay(_anchor)
            .where((t) => !t.isPersonal)
            .toList();
      case _ReportRange.week:
        return provider
            .tasksForWeek(_anchor)
            .where((t) => !t.isPersonal)
            .toList();
      case _ReportRange.month:
        return provider
            .tasksForMonth(_anchor)
            .where((t) => !t.isPersonal)
            .toList();
      case _ReportRange.employee:
        if (_selectedEmployeeUid == null) return [];
        return provider.tasksForEmployee(_selectedEmployeeUid!);
    }
  }

  String get _rangeLabel {
    switch (_range) {
      case _ReportRange.day:
        return _fmt(_anchor);
      case _ReportRange.week:
        final weekday = _anchor.weekday;
        final start = _anchor.subtract(Duration(days: weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${_fmt(start)} - ${_fmt(end)}';
      case _ReportRange.month:
        return '${_anchor.year}/${_anchor.month.toString().padLeft(2, '0')}';
      case _ReportRange.employee:
        final emp = FirestoreService.getAllEmployees().where(
          (e) => e.uid == _selectedEmployeeUid,
        );
        return emp.isNotEmpty ? emp.first.name : 'اختر موظفًا';
    }
  }

  String _fmt(DateTime d) =>
      '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';

  Future<void> _export(TaskProvider provider) async {
    final tasks = _filteredTasks(provider);
    if (tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مهام لتصديرها في هذا النطاق')),
      );
      return;
    }
    setState(() => _exporting = true);
    try {
      final stats = provider.statsForRange(tasks);
      final employees = FirestoreService.getAllEmployees();
      final employeesById = {for (final e in employees) e.uid: e};
      final bytes = await PdfReportService.buildReport(
        title: _rangeTitleAr,
        rangeLabel: _rangeLabel,
        tasks: tasks,
        stats: stats,
        employeesById: employeesById,
      );
      await PdfReportService.shareOrPrint(
        bytes,
        'neotask_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  String get _rangeTitleAr {
    switch (_range) {
      case _ReportRange.day:
        return 'تقرير يومي';
      case _ReportRange.week:
        return 'تقرير أسبوعي';
      case _ReportRange.month:
        return 'تقرير شهري';
      case _ReportRange.employee:
        return 'تقرير موظف';
    }
  }

  /// Arabic period noun used to build tooltip labels ('اليوم التالي',
  /// 'الأسبوع السابق', ...). The chevron row is only rendered for
  /// day/week/month ranges (see the `else` branch below), so `employee`
  /// never actually reaches this getter, but the switch is kept
  /// exhaustive for safety.
  String get _periodLabel {
    switch (_range) {
      case _ReportRange.day:
        return 'اليوم';
      case _ReportRange.week:
        return 'الأسبوع';
      case _ReportRange.month:
        return 'الشهر';
      case _ReportRange.employee:
        return 'النطاق';
    }
  }

  void _shift(int direction) {
    setState(() {
      switch (_range) {
        case _ReportRange.day:
          _anchor = _anchor.add(Duration(days: direction));
          break;
        case _ReportRange.week:
          _anchor = _anchor.add(Duration(days: 7 * direction));
          break;
        case _ReportRange.month:
          _anchor = DateTime(_anchor.year, _anchor.month + direction, 1);
          break;
        case _ReportRange.employee:
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TaskProvider>();
    final tasks = _filteredTasks(provider);
    final employees = FirestoreService.getAllEmployees()
        .where((u) => u.accountStatus == AccountStatus.active)
        .toList();

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('يومي'),
                selected: _range == _ReportRange.day,
                onSelected: (_) => setState(() => _range = _ReportRange.day),
              ),
              ChoiceChip(
                label: const Text('أسبوعي'),
                selected: _range == _ReportRange.week,
                onSelected: (_) => setState(() => _range = _ReportRange.week),
              ),
              ChoiceChip(
                label: const Text('شهري'),
                selected: _range == _ReportRange.month,
                onSelected: (_) => setState(() => _range = _ReportRange.month),
              ),
              ChoiceChip(
                label: const Text('موظف محدد'),
                selected: _range == _ReportRange.employee,
                onSelected: (_) =>
                    setState(() => _range = _ReportRange.employee),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_range == _ReportRange.employee)
            DropdownButtonFormField<String>(
              initialValue: _selectedEmployeeUid,
              decoration: const InputDecoration(labelText: 'اختر الموظف'),
              items: employees
                  .map(
                    (e) => DropdownMenuItem(value: e.uid, child: Text(e.name)),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selectedEmployeeUid = v),
            )
          else
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
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    'عدد المهام في هذا النطاق: ${tasks.length}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _exporting ? null : () => _export(provider),
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      label: Text(
                        _exporting ? 'جارٍ التصدير...' : 'تصدير كملف PDF',
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'التصدير يتم فقط عند الضغط على هذا الزر (غير تلقائي).',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
