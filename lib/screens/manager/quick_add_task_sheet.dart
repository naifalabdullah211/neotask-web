import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

/// Quick "add task" bottom sheet opened from the circular FAB on the
/// manager home screen. Deliberately a REDUCED field set compared to
/// [ManagerCreateTaskScreen] (title/assignee/category/priority/date only —
/// no description, no recurrence) per the explicit request: this is meant
/// as a fast quick-add path, not a replacement for the full creation
/// screen (which remains reachable from the review tab's FAB).
///
/// Wired to the SAME [TaskProvider.createTask] used by the full screen, so
/// tasks created here are fully consistent with the existing data model —
/// no parallel/duplicate task-creation logic was introduced.
class QuickAddTaskSheet extends StatefulWidget {
  const QuickAddTaskSheet({super.key});

  /// Opens the sheet as a modal bottom sheet. Returns true if a task was
  /// created, false/null otherwise (dismissed or cancelled).
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const QuickAddTaskSheet(),
    );
  }

  @override
  State<QuickAddTaskSheet> createState() => _QuickAddTaskSheetState();
}

class _QuickAddTaskSheetState extends State<QuickAddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController(text: 'عام');

  AppUser? _selectedEmployee;
  // Manager personal tasks (المهام الشخصية للمدير) — NEW. See the same
  // toggle in ManagerCreateTaskScreen for the full rationale.
  bool _isPersonal = false;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  TaskPriority _priority = TaskPriority.medium;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
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
        description: '',
        assignedTo: _isPersonal ? managerUid : _selectedEmployee!.uid,
        assignedBy: managerUid,
        dueDate: _dueDate,
        priority: _priority,
        category: _categoryCtrl.text.trim().isEmpty
            ? 'عام'
            : _categoryCtrl.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 150),
      padding: EdgeInsets.only(bottom: bottomInset),
      child: DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              // Matches the app-wide bottomSheetTheme radius (AppRadius.xl
              // = 20) now applied to every OTHER showModalBottomSheet call
              // site — this sheet previously used a slightly different
              // radius (24) since it wraps its own Container instead of
              // relying on the theme's shape.
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Form(
                key: _formKey,
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppColors.textSecondary.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const Text('مهمة جديدة', style: AppTextStyles.screenTitle),
                    const SizedBox(height: AppSpacing.lg + 2),
                    TextFormField(
                      controller: _titleCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'عنوان المهمة',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'أدخل عنوان المهمة'
                          : null,
                    ),
                    const SizedBox(height: 14),
                    // Manager personal tasks (المهام الشخصية للمدير) — NEW.
                    const Text(
                      'نوع المهمة',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, label: Text('لفريق')),
                        ButtonSegment(value: true, label: Text('شخصية')),
                      ],
                      selected: {_isPersonal},
                      onSelectionChanged: (s) =>
                          setState(() => _isPersonal = s.first),
                    ),
                    const SizedBox(height: 14),
                    if (!_isPersonal)
                      if (employees.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'لا يوجد موظفون نشطون بعد. أضف موظفين أولًا من '
                            'تبويب "الموظفون".',
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
                                  child: Text(
                                    '${u.name} (${u.employeeNumber})',
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _selectedEmployee = v),
                        ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _categoryCtrl,
                      decoration: const InputDecoration(labelText: 'التصنيف'),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'الأولوية',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<TaskPriority>(
                      segments: const [
                        ButtonSegment(
                          value: TaskPriority.low,
                          label: Text('منخفضة'),
                        ),
                        ButtonSegment(
                          value: TaskPriority.medium,
                          label: Text('متوسطة'),
                        ),
                        ButtonSegment(
                          value: TaskPriority.high,
                          label: Text('عالية'),
                        ),
                      ],
                      selected: {_priority},
                      onSelectionChanged: (s) =>
                          setState(() => _priority = s.first),
                    ),
                    const SizedBox(height: 14),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('تاريخ الاستحقاق'),
                      subtitle: Text(
                        intl.DateFormat('yyyy/MM/dd').format(_dueDate),
                      ),
                      trailing: const Icon(Icons.calendar_today_outlined),
                      onTap: _pickDueDate,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.mintAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
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
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
