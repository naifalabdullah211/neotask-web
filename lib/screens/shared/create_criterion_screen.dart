import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:provider/provider.dart';

import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/criterion_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_workspace_chrome.dart';

class CreateCriterionScreen extends StatefulWidget {
  const CreateCriterionScreen({super.key, required this.goalId});

  final String goalId;

  @override
  State<CreateCriterionScreen> createState() => _CreateCriterionScreenState();
}

class _CreateCriterionScreenState extends State<CreateCriterionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final Set<String> _selectedEmployeeUids = {};
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeUids.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('يرجى اختيار موظف واحد على الأقل للمعيار')),
        ),
      );
      return;
    }

    setState(() => _saving = true);
    final managerUid = context.read<AuthProvider>().currentUser!.uid;
    try {
      await context.read<CriterionProvider>().createCriterion(
        goalId: widget.goalId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        assignees: _selectedEmployeeUids.toList(),
        assignedBy: managerUid,
      );
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('تم إنشاء المعيار بنجاح'))),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.tr('تعذر حفظ المعيار، حاول مجددًا')),
            backgroundColor: AppColors.statusRejected,
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
        .where((user) => user.accountStatus == AccountStatus.active)
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'معيار جديد',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              return SingleChildScrollView(
                padding: EdgeInsets.all(compact ? AppSpacing.lg : AppSpacing.xxl),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 900),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _CriterionFormCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const NeoWorkspaceSectionHeader(
                                title: 'بيانات المعيار',
                                subtitle: 'عرّف المعيار بوضوح قبل توزيعه على فريق التنفيذ',
                              ),
                              const Divider(height: 1),
                              Padding(
                                padding: const EdgeInsets.all(AppSpacing.xl),
                                child: Column(
                                  children: [
                                    TextFormField(
                                      controller: _titleCtrl,
                                      decoration: InputDecoration(
                                        labelText: context.tr('عنوان المعيار'),
                                        prefixIcon: const Icon(
                                          Icons.fact_check_outlined,
                                        ),
                                      ),
                                      validator: (value) =>
                                          value == null || value.trim().isEmpty
                                          ? context.tr('أدخل عنوان المعيار')
                                          : null,
                                    ),
                                    const SizedBox(height: AppSpacing.lg),
                                    TextFormField(
                                      controller: _descCtrl,
                                      minLines: 3,
                                      maxLines: 5,
                                      decoration: InputDecoration(
                                        labelText: context.tr('وصف المعيار'),
                                        prefixIcon: const Padding(
                                          padding: EdgeInsets.only(bottom: 54),
                                          child: Icon(Icons.notes_outlined),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        _CriterionFormCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              NeoWorkspaceSectionHeader(
                                title: 'فريق التنفيذ',
                                subtitle: 'يمكن اختيار أكثر من موظف واحد',
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.deepBlue.withValues(alpha: .08),
                                    borderRadius: BorderRadius.circular(AppRadius.pill),
                                  ),
                                  child: Text(
                                    '${_selectedEmployeeUids.length} ${context.tr('موظفون')}',
                                    style: const TextStyle(
                                      color: AppColors.deepBlue,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const Divider(height: 1),
                              if (employees.isEmpty)
                                const NeoWorkspaceEmptyState(
                                  icon: Icons.group_off_outlined,
                                  title: 'لا يوجد موظفون نشطون بعد',
                                  message: 'أضف موظفين من تبويب الموظفين ثم عُد لإسناد المعيار.',
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  child: Column(
                                    children: [
                                      for (final employee in employees)
                                        _EmployeeSelectionTile(
                                          employee: employee,
                                          selected: _selectedEmployeeUids.contains(
                                            employee.uid,
                                          ),
                                          onChanged: (checked) {
                                            setState(() {
                                              if (checked) {
                                                _selectedEmployeeUids.add(employee.uid);
                                              } else {
                                                _selectedEmployeeUids.remove(employee.uid);
                                              }
                                            });
                                          },
                                        ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Container(
                          padding: const EdgeInsets.all(AppSpacing.lg),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(color: AppColors.divider),
                          ),
                          child: Row(
                            children: [
                              if (!compact) ...[
                                const Icon(
                                  Icons.info_outline_rounded,
                                  color: AppColors.textSecondary,
                                  size: 19,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    context.tr(
                                      'حدد بيانات المعيار وفريق التنفيذ ثم احفظه لبدء المتابعة.',
                                    ),
                                    style: AppTextStyles.bodySecondary,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.lg),
                              ] else
                                const Spacer(),
                              FilledButton.icon(
                                onPressed: _saving ? null : _save,
                                icon: _saving
                                    ? const SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.save_outlined),
                                label: const Text('حفظ المعيار'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CriterionFormCard extends StatelessWidget {
  const _CriterionFormCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: child,
    );
  }
}

class _EmployeeSelectionTile extends StatelessWidget {
  const _EmployeeSelectionTile({
    required this.employee,
    required this.selected,
    required this.onChanged,
  });

  final AppUser employee;
  final bool selected;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: selected
            ? AppColors.deepBlue.withValues(alpha: .055)
            : const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: InkWell(
          onTap: () => onChanged(!selected),
          borderRadius: BorderRadius.circular(AppRadius.md),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: selected ? AppColors.deepBlue : AppColors.divider,
                width: selected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.deepBlue.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Text(
                    employee.name.isNotEmpty ? employee.name[0] : '?',
                    style: const TextStyle(
                      color: AppColors.deepBlue,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(employee.name, style: AppTextStyles.cardTitle),
                      const SizedBox(height: 2),
                      Text(
                        employee.employeeNumber,
                        style: AppTextStyles.bodySecondary,
                      ),
                    ],
                  ),
                ),
                Checkbox(
                  value: selected,
                  onChanged: (value) => onChanged(value ?? false),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
