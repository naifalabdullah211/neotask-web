import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

/// Task creation screen for the manager — exposes ALL recurrence options
/// per explicit requirement: none / daily / weekly / monthly-fixed-date
/// (e.g. "15th of every month") / monthly-weekday-pattern
/// (e.g. "last Thursday of every month").
class ManagerCreateTaskScreen extends StatefulWidget {
  const ManagerCreateTaskScreen({super.key, this.initialDueDate});

  /// Optional pre-filled due date — passed in when this screen is opened
  /// from ManagerCalendarScreen (tapping a specific day), so the manager
  /// doesn't have to re-pick the date they already selected on the calendar.
  final DateTime? initialDueDate;

  @override
  State<ManagerCreateTaskScreen> createState() =>
      _ManagerCreateTaskScreenState();
}

class _ManagerCreateTaskScreenState extends State<ManagerCreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController(text: 'عام');

  AppUser? _selectedEmployee;
  late DateTime _dueDate;
  TaskPriority _priority = TaskPriority.medium;
  RecurrenceType _recurrenceType = RecurrenceType.none;
  int _dayOfMonth = 1;
  WeekOrdinal _weekOrdinal = WeekOrdinal.first;
  Weekday _weekday = Weekday.monday;
  DateTime? _recurrenceEndDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dueDate =
        widget.initialDueDate ?? DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _pickRecurrenceEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurrenceEndDate ?? _dueDate.add(const Duration(days: 90)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) setState(() => _recurrenceEndDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الموظف المسؤول عن المهمة')),
      );
      return;
    }

    setState(() => _saving = true);
    final managerUid = context.read<AuthProvider>().currentUser!.uid;
    try {
      await context.read<TaskProvider>().createTask(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        assignedTo: _selectedEmployee!.uid,
        assignedBy: managerUid,
        dueDate: _dueDate,
        priority: _priority,
        category: _categoryCtrl.text.trim().isEmpty
            ? 'عام'
            : _categoryCtrl.text.trim(),
        recurrenceType: _recurrenceType,
        recurrenceDayOfMonth: _recurrenceType == RecurrenceType.monthlyFixedDate
            ? _dayOfMonth
            : null,
        recurrenceWeekOrdinal:
            _recurrenceType == RecurrenceType.monthlyWeekdayPattern
            ? _weekOrdinal
            : null,
        recurrenceWeekday:
            _recurrenceType == RecurrenceType.monthlyWeekdayPattern
            ? _weekday
            : null,
        recurrenceEndDate: _recurrenceType != RecurrenceType.none
            ? _recurrenceEndDate
            : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إنشاء المهمة بنجاح')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employees = FirestoreService.getAllEmployees()
        .where((u) => u.accountStatus == AccountStatus.active)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('إنشاء مهمة جديدة')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'عنوان المهمة'),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'أدخل عنوان المهمة'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'وصف المهمة'),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _categoryCtrl,
                decoration: const InputDecoration(labelText: 'التصنيف'),
              ),
              const SizedBox(height: 14),
              if (employees.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'لا يوجد موظفون نشطون بعد. أضف موظفين أولًا من تبويب "الموظفون".',
                    style: TextStyle(color: AppColors.statusRejected),
                  ),
                )
              else
                DropdownButtonFormField<AppUser>(
                  initialValue: _selectedEmployee,
                  decoration: const InputDecoration(
                    labelText: 'إسناد إلى موظف',
                  ),
                  items: employees
                      .map(
                        (u) => DropdownMenuItem(
                          value: u,
                          child: Text('${u.name} (${u.employeeNumber})'),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _selectedEmployee = v),
                ),
              const SizedBox(height: 14),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('تاريخ الاستحقاق'),
                subtitle: Text(intl.DateFormat('yyyy/MM/dd').format(_dueDate)),
                trailing: const Icon(Icons.calendar_today_outlined),
                onTap: _pickDueDate,
              ),
              const Divider(),
              const SizedBox(height: 6),
              const Text(
                'الأولوية',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              SegmentedButton<TaskPriority>(
                segments: const [
                  ButtonSegment(value: TaskPriority.low, label: Text('منخفضة')),
                  ButtonSegment(
                    value: TaskPriority.medium,
                    label: Text('متوسطة'),
                  ),
                  ButtonSegment(value: TaskPriority.high, label: Text('عالية')),
                ],
                selected: {_priority},
                onSelectionChanged: (s) => setState(() => _priority = s.first),
              ),
              const SizedBox(height: 20),
              const Text(
                'التكرار',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<RecurrenceType>(
                initialValue: _recurrenceType,
                decoration: const InputDecoration(labelText: 'نوع التكرار'),
                items: const [
                  DropdownMenuItem(
                    value: RecurrenceType.none,
                    child: Text('بدون تكرار'),
                  ),
                  DropdownMenuItem(
                    value: RecurrenceType.daily,
                    child: Text('يوميًا'),
                  ),
                  DropdownMenuItem(
                    value: RecurrenceType.weekly,
                    child: Text('أسبوعيًا'),
                  ),
                  DropdownMenuItem(
                    value: RecurrenceType.monthlyFixedDate,
                    child: Text('شهريًا - يوم ثابت من الشهر'),
                  ),
                  DropdownMenuItem(
                    value: RecurrenceType.monthlyWeekdayPattern,
                    child: Text('شهريًا - نمط يوم أسبوعي (مثال: آخر خميس)'),
                  ),
                ],
                onChanged: (v) =>
                    setState(() => _recurrenceType = v ?? RecurrenceType.none),
              ),
              if (_recurrenceType == RecurrenceType.monthlyFixedDate) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: _dayOfMonth,
                  decoration: const InputDecoration(
                    labelText: 'يوم الشهر (1-31)',
                  ),
                  items: List.generate(31, (i) => i + 1)
                      .map(
                        (d) =>
                            DropdownMenuItem(value: d, child: Text('يوم $d')),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _dayOfMonth = v ?? 1),
                ),
              ],
              if (_recurrenceType == RecurrenceType.monthlyWeekdayPattern) ...[
                const SizedBox(height: 14),
                DropdownButtonFormField<WeekOrdinal>(
                  initialValue: _weekOrdinal,
                  decoration: const InputDecoration(labelText: 'الأسبوع'),
                  items: const [
                    DropdownMenuItem(
                      value: WeekOrdinal.first,
                      child: Text('الأول'),
                    ),
                    DropdownMenuItem(
                      value: WeekOrdinal.second,
                      child: Text('الثاني'),
                    ),
                    DropdownMenuItem(
                      value: WeekOrdinal.third,
                      child: Text('الثالث'),
                    ),
                    DropdownMenuItem(
                      value: WeekOrdinal.fourth,
                      child: Text('الرابع'),
                    ),
                    DropdownMenuItem(
                      value: WeekOrdinal.last,
                      child: Text('الأخير'),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _weekOrdinal = v ?? WeekOrdinal.first),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<Weekday>(
                  initialValue: _weekday,
                  decoration: const InputDecoration(labelText: 'اليوم'),
                  items: const [
                    DropdownMenuItem(
                      value: Weekday.monday,
                      child: Text('الاثنين'),
                    ),
                    DropdownMenuItem(
                      value: Weekday.tuesday,
                      child: Text('الثلاثاء'),
                    ),
                    DropdownMenuItem(
                      value: Weekday.wednesday,
                      child: Text('الأربعاء'),
                    ),
                    DropdownMenuItem(
                      value: Weekday.thursday,
                      child: Text('الخميس'),
                    ),
                    DropdownMenuItem(
                      value: Weekday.friday,
                      child: Text('الجمعة'),
                    ),
                    DropdownMenuItem(
                      value: Weekday.saturday,
                      child: Text('السبت'),
                    ),
                    DropdownMenuItem(
                      value: Weekday.sunday,
                      child: Text('الأحد'),
                    ),
                  ],
                  onChanged: (v) =>
                      setState(() => _weekday = v ?? Weekday.monday),
                ),
              ],
              if (_recurrenceType != RecurrenceType.none) ...[
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تاريخ انتهاء التكرار (اختياري)'),
                  subtitle: Text(
                    _recurrenceEndDate != null
                        ? intl.DateFormat(
                            'yyyy/MM/dd',
                          ).format(_recurrenceEndDate!)
                        : 'بدون تاريخ انتهاء',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_recurrenceEndDate != null)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () =>
                              setState(() => _recurrenceEndDate = null),
                        ),
                      const Icon(Icons.calendar_today_outlined),
                    ],
                  ),
                  onTap: _pickRecurrenceEndDate,
                ),
              ],
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('حفظ المهمة'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
