import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_selection_field.dart';

/// Task creation screen for the manager — exposes ALL recurrence options
/// per explicit requirement: none / daily / weekly / monthly-fixed-date
/// (e.g. "15th of every month") / monthly-weekday-pattern
/// (e.g. "last Thursday of every month").
class ManagerCreateTaskScreen extends StatefulWidget {
  const ManagerCreateTaskScreen({
    super.key,
    this.initialDueDate,
    this.initialIsPersonal = false,
    this.initialTitle,
    this.initialDescription,
    this.initialCategory,
  });

  /// Optional pre-filled due date — passed in when this screen is opened
  /// from ManagerCalendarScreen (tapping a specific day), so the manager
  /// doesn't have to re-pick the date they already selected on the calendar.
  final DateTime? initialDueDate;

  /// Manager personal tasks (المهام الشخصية للمدير) — NEW.
  /// Set to true when this screen is opened from the manager's own
  /// "مهامي الشخصية" FAB (ManagerMyTasksScreen), so the type toggle below
  /// starts pre-selected on "شخصية" instead of the default "لفريق".
  final bool initialIsPersonal;
  final String? initialTitle;
  final String? initialDescription;
  final String? initialCategory;

  @override
  State<ManagerCreateTaskScreen> createState() =>
      _ManagerCreateTaskScreenState();
}

class _ManagerCreateTaskScreenState extends State<ManagerCreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController(text: 'عام');
  final _plannedHoursCtrl = TextEditingController(text: '8');

  AppUser? _selectedEmployee;
  // Manager personal tasks (المهام الشخصية للمدير) — NEW.
  // When true, the employee dropdown/validation is skipped entirely and
  // `assignedTo` is forced to the manager's own uid on save (see _save()).
  late bool _isPersonal;
  late DateTime _dueDate;
  late DateTime _startDate;
  String? _parentTaskId;
  final Set<String> _predecessorTaskIds = {};
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
    _titleCtrl.text = widget.initialTitle ?? '';
    _descCtrl.text = widget.initialDescription ?? '';
    _categoryCtrl.text = widget.initialCategory ?? 'عام';
    _isPersonal = widget.initialIsPersonal;
    _dueDate =
        widget.initialDueDate ?? DateTime.now().add(const Duration(days: 1));
    final today = DateTime.now();
    _startDate = DateTime(today.year, today.month, today.day);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    _plannedHoursCtrl.dispose();
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

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 3650)),
      lastDate: DateTime.now().add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        if (_dueDate.isBefore(_startDate)) _dueDate = _startDate;
      });
    }
  }

  Future<void> _selectPredecessors(List<AppTask> tasks) async {
    final draft = <String>{..._predecessorTaskIds};
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('المهام السابقة المطلوبة'),
          content: SizedBox(
            width: 520,
            child: tasks.isEmpty
                ? const Text('لا توجد مهام سابقة يمكن ربطها')
                : ListView(
                    shrinkWrap: true,
                    children: tasks
                        .map(
                          (task) => CheckboxListTile(
                            value: draft.contains(task.taskId),
                            title: Text(task.title),
                            subtitle: Text(
                              intl.DateFormat(
                                'yyyy/MM/dd',
                              ).format(task.dueDate),
                            ),
                            onChanged: (selected) => setDialogState(() {
                              if (selected ?? false) {
                                draft.add(task.taskId);
                              } else {
                                draft.remove(task.taskId);
                              }
                            }),
                          ),
                        )
                        .toList(),
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                setState(() {
                  _predecessorTaskIds
                    ..clear()
                    ..addAll(draft);
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('اعتماد'),
            ),
          ],
        ),
      ),
    );
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
    final managerUid = context.read<AuthProvider>().currentUser!.uid;
    if (!_isPersonal && _selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الموظف المسؤول عن المهمة')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await context.read<TaskProvider>().createTask(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        assignedTo: _isPersonal ? managerUid : _selectedEmployee!.uid,
        assignedBy: managerUid,
        dueDate: _dueDate,
        startDate: _startDate,
        plannedHours: double.parse(_plannedHoursCtrl.text.trim()),
        parentTaskId: _parentTaskId,
        predecessorTaskIds: _predecessorTaskIds.toList(),
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
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error.toString().replaceFirst('Invalid argument(s): ', ''),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final employees = FirestoreService.getAllEmployees()
        .where((u) => u.accountStatus == AccountStatus.active)
        .toList();
    final planningTasks =
        context
            .watch<TaskProvider>()
            .teamTasks
            .where((task) => task.status != TaskStatus.approved)
            .toList()
          ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

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
                decoration: InputDecoration(labelText: context.tr('عنوان المهمة')),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.tr('أدخل عنوان المهمة')
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: InputDecoration(labelText: context.tr('وصف المهمة')),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _categoryCtrl,
                decoration: InputDecoration(labelText: context.tr('التصنيف')),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الخطة الزمنية',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'تحدد مدة المهمة وترابطها وعبء العمل على الموظف',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('تاريخ البداية'),
                            subtitle: Text(
                              intl.DateFormat('yyyy/MM/dd').format(_startDate),
                            ),
                            trailing: const Icon(Icons.play_circle_outline),
                            onTap: _pickStartDate,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('تاريخ الاستحقاق'),
                            subtitle: Text(
                              intl.DateFormat('yyyy/MM/dd').format(_dueDate),
                            ),
                            trailing: const Icon(Icons.flag_outlined),
                            onTap: _pickDueDate,
                          ),
                        ),
                      ],
                    ),
                    TextFormField(
                      controller: _plannedHoursCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: context.tr('الساعات المخططة'),
                        suffixText: 'ساعة',
                      ),
                      validator: (value) {
                        final hours = double.tryParse(value ?? '');
                        return hours == null || hours <= 0
                            ? context.tr('أدخل عدد ساعات صحيحًا')
                            : null;
                      },
                    ),
                    const SizedBox(height: 12),
                    NeoSelectionField<String?>(
                      label: 'المهمة الرئيسية (اختياري)',
                      value: _parentTaskId,
                      searchable: planningTasks.length > 7,
                      options: [
                        const NeoSelectionOption<String?>(
                          value: null,
                          label: 'بدون مهمة رئيسية',
                          icon: Icons.remove_circle_outline_rounded,
                        ),
                        ...planningTasks.map(
                          (task) => NeoSelectionOption<String?>(
                            value: task.taskId,
                            label: task.title,
                            subtitle: intl.DateFormat(
                              'yyyy/MM/dd',
                            ).format(task.dueDate),
                            icon: Icons.account_tree_outlined,
                          ),
                        ),
                      ],
                      onChanged: (value) =>
                          setState(() => _parentTaskId = value),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _selectPredecessors(planningTasks),
                      icon: const Icon(Icons.account_tree_outlined),
                      label: Text(
                        _predecessorTaskIds.isEmpty
                            ? 'ربط بمهام سابقة'
                            : 'المهام السابقة: ${_predecessorTaskIds.length}',
                      ),
                    ),
                    if (_predecessorTaskIds.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      const Text(
                        'لن يستطيع الموظف بدء هذه المهمة قبل اعتماد جميع المهام السابقة',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // ---------------------------------------------------------
              // Manager personal tasks (المهام الشخصية للمدير) — NEW.
              // "لفريق" keeps the existing employee-assignment behavior
              // unchanged; "شخصية" hides the employee dropdown below and
              // forces assignedTo = the manager's own uid on save.
              NeoSelectionField<bool>(
                label: 'نوع المهمة',
                value: _isPersonal,
                options: const [
                  NeoSelectionOption(
                    value: false,
                    label: 'لفريق',
                    subtitle: 'إسناد المهمة إلى أحد الموظفين',
                    icon: Icons.groups_2_outlined,
                  ),
                  NeoSelectionOption(
                    value: true,
                    label: 'شخصية',
                    subtitle: 'مهمة خاصة بالمدير',
                    icon: Icons.person_outline_rounded,
                  ),
                ],
                onChanged: (value) => setState(() {
                  _isPersonal = value;
                  if (value) _selectedEmployee = null;
                }),
              ),
              const SizedBox(height: 14),
              if (!_isPersonal)
                if (employees.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'لا يوجد موظفون نشطون بعد. أضف موظفين أولًا من تبويب "الموظفون".',
                      style: TextStyle(color: AppColors.statusRejected),
                    ),
                  )
                else
                  NeoSelectionField<AppUser>(
                    label: 'إسناد إلى موظف',
                    value: _selectedEmployee,
                    searchable: true,
                    requiredSelection: true,
                    options: employees
                        .map(
                          (user) => NeoSelectionOption(
                            value: user,
                            label: user.name,
                            subtitle: 'الرقم الوظيفي ${user.employeeNumber}',
                            icon: Icons.badge_outlined,
                            searchTerms: [user.employeeNumber],
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => _selectedEmployee = value),
                  ),
              const SizedBox(height: 14),
              NeoSelectionField<TaskPriority>(
                label: 'الأولوية',
                value: _priority,
                options: const [
                  NeoSelectionOption(
                    value: TaskPriority.low,
                    label: 'منخفضة',
                    color: AppColors.statusApproved,
                  ),
                  NeoSelectionOption(
                    value: TaskPriority.medium,
                    label: 'متوسطة',
                    color: AppColors.gold,
                  ),
                  NeoSelectionOption(
                    value: TaskPriority.high,
                    label: 'عالية',
                    color: AppColors.statusRejected,
                  ),
                ],
                onChanged: (value) => setState(() => _priority = value),
              ),
              const SizedBox(height: 20),
              NeoSelectionField<RecurrenceType>(
                label: 'التكرار',
                value: _recurrenceType,
                options: const [
                  NeoSelectionOption(
                    value: RecurrenceType.none,
                    label: 'بدون تكرار',
                    icon: Icons.event_busy_outlined,
                  ),
                  NeoSelectionOption(
                    value: RecurrenceType.daily,
                    label: 'يوميًا',
                    icon: Icons.today_outlined,
                  ),
                  NeoSelectionOption(
                    value: RecurrenceType.weekly,
                    label: 'أسبوعيًا',
                    icon: Icons.view_week_outlined,
                  ),
                  NeoSelectionOption(
                    value: RecurrenceType.monthlyFixedDate,
                    label: 'شهريًا - يوم ثابت من الشهر',
                    icon: Icons.calendar_month_outlined,
                  ),
                  NeoSelectionOption(
                    value: RecurrenceType.monthlyWeekdayPattern,
                    label: 'شهريًا - نمط يوم أسبوعي',
                    subtitle: 'مثال: آخر خميس من كل شهر',
                    icon: Icons.date_range_outlined,
                  ),
                ],
                onChanged: (value) => setState(() => _recurrenceType = value),
              ),
              if (_recurrenceType == RecurrenceType.monthlyFixedDate) ...[
                const SizedBox(height: 14),
                NeoSelectionField<int>(
                  label: 'يوم الشهر (1-31)',
                  value: _dayOfMonth,
                  searchable: true,
                  options: List.generate(
                    31,
                    (index) => NeoSelectionOption(
                      value: index + 1,
                      label: 'يوم ${index + 1}',
                    ),
                  ),
                  onChanged: (value) => setState(() => _dayOfMonth = value),
                ),
              ],
              if (_recurrenceType == RecurrenceType.monthlyWeekdayPattern) ...[
                const SizedBox(height: 14),
                NeoSelectionField<WeekOrdinal>(
                  label: 'الأسبوع',
                  value: _weekOrdinal,
                  options: const [
                    NeoSelectionOption(
                      value: WeekOrdinal.first,
                      label: 'الأول',
                    ),
                    NeoSelectionOption(
                      value: WeekOrdinal.second,
                      label: 'الثاني',
                    ),
                    NeoSelectionOption(
                      value: WeekOrdinal.third,
                      label: 'الثالث',
                    ),
                    NeoSelectionOption(
                      value: WeekOrdinal.fourth,
                      label: 'الرابع',
                    ),
                    NeoSelectionOption(
                      value: WeekOrdinal.last,
                      label: 'الأخير',
                    ),
                  ],
                  onChanged: (value) => setState(() => _weekOrdinal = value),
                ),
                const SizedBox(height: 14),
                NeoSelectionField<Weekday>(
                  label: 'اليوم',
                  value: _weekday,
                  options: const [
                    NeoSelectionOption(value: Weekday.monday, label: 'الاثنين'),
                    NeoSelectionOption(
                      value: Weekday.tuesday,
                      label: 'الثلاثاء',
                    ),
                    NeoSelectionOption(
                      value: Weekday.wednesday,
                      label: 'الأربعاء',
                    ),
                    NeoSelectionOption(
                      value: Weekday.thursday,
                      label: 'الخميس',
                    ),
                    NeoSelectionOption(value: Weekday.friday, label: 'الجمعة'),
                    NeoSelectionOption(value: Weekday.saturday, label: 'السبت'),
                    NeoSelectionOption(value: Weekday.sunday, label: 'الأحد'),
                  ],
                  onChanged: (value) => setState(() => _weekday = value),
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
