import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';

/// Small manager-only dialog for creating a new Goal ("هدف"). Per the
/// rebuilt spec, a Goal carries ONLY title, description, startDate and
/// endDate — no assignee/chat of its own (those live on its Criteria).
Future<void> showCreateGoalDialog(BuildContext context) async {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 7));

  final created = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        Future<void> pickDate({required bool isStart}) async {
          final picked = await showDatePicker(
            context: context,
            initialDate: isStart ? startDate : endDate,
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
          );
          if (picked != null) {
            setState(() {
              if (isStart) {
                startDate = picked;
                if (endDate.isBefore(startDate)) {
                  endDate = startDate.add(const Duration(days: 1));
                }
              } else {
                endDate = picked;
              }
            });
          }
        }

        return AlertDialog(
          title: const Text('هدف جديد'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    autofocus: true,
                    decoration: const InputDecoration(labelText: 'عنوان الهدف'),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'أدخل عنوان الهدف'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'الوصف (اختياري)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_outlined),
                    title: const Text('تاريخ البداية'),
                    subtitle: Text(DateFormat('yyyy/MM/dd').format(startDate)),
                    onTap: () => pickDate(isStart: true),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available_outlined),
                    title: const Text('تاريخ النهاية'),
                    subtitle: Text(DateFormat('yyyy/MM/dd').format(endDate)),
                    onTap: () => pickDate(isStart: false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.of(context).pop(true);
                }
              },
              child: const Text('إنشاء'),
            ),
          ],
        );
      },
    ),
  );

  if (created != true || !context.mounted) return;

  final managerUid = context.read<AuthProvider>().currentUser!.uid;
  await context.read<GoalProvider>().createGoal(
    title: titleCtrl.text.trim(),
    description: descCtrl.text.trim(),
    createdBy: managerUid,
    startDate: startDate,
    endDate: endDate,
  );

  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم إنشاء الهدف بنجاح')));
  }
}
