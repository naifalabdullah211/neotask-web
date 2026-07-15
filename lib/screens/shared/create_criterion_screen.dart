import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/criterion_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

/// Manager-only screen for creating a new Criterion ("معيار") under a
/// specific Goal. Unlike ManagerCreateTaskScreen (single `assignedTo`
/// employee), this form uses MULTI-select — a criterion may be shared by
/// several employees at once.
///
/// REBUILD NOTE: per the simplified spec, a Criterion has NO due date and
/// NO priority — only title, description, status and assignees.
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
        const SnackBar(
          content: Text('يرجى اختيار موظف واحد على الأقل للمعيار'),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم إنشاء المعيار بنجاح')));
    } catch (e) {
      // CRITICAL FIX: previously there was no `catch` at all here — any
      // failure (Firestore permission error, network error, etc.) was
      // silently swallowed by the bare `finally`, leaving the user with no
      // indication the save had failed and the typed criterion simply
      // vanishing from the screen. Now shown explicitly per requirement.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر حفظ المعيار، حاول مجددًا')),
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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('معيار جديد')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _titleCtrl,
                decoration: const InputDecoration(labelText: 'عنوان المعيار'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty)
                    ? 'أدخل عنوان المعيار'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: const InputDecoration(labelText: 'وصف المعيار'),
              ),
              const SizedBox(height: 20),
              const Text(
                'الموظفون المشاركون في هذا المعيار',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              const Text(
                'يمكن اختيار أكثر من موظف واحد',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 8),
              if (employees.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'لا يوجد موظفون نشطون بعد. أضف موظفين أولًا من تبويب "الموظفون".',
                    style: TextStyle(color: AppColors.statusRejected),
                  ),
                )
              else
                Card(
                  child: Column(
                    children: employees.map((AppUser u) {
                      final selected = _selectedEmployeeUids.contains(u.uid);
                      return CheckboxListTile(
                        value: selected,
                        title: Text(u.name),
                        subtitle: Text(u.employeeNumber),
                        onChanged: (checked) {
                          setState(() {
                            if (checked == true) {
                              _selectedEmployeeUids.add(u.uid);
                            } else {
                              _selectedEmployeeUids.remove(u.uid);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
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
                    : const Text('حفظ المعيار'),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
