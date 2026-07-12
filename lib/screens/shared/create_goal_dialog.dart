import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';

/// Small manager-only dialog for creating a new Goal ("هدف"). Goals carry
/// no due date/assignee of their own (see goal_model.dart) — those live on
/// their Criteria — so this form is deliberately minimal (title +
/// description only).
Future<void> showCreateGoalDialog(BuildContext context) async {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final created = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('هدف جديد'),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: titleCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'عنوان الهدف'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'أدخل عنوان الهدف' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'الوصف (اختياري)'),
            ),
          ],
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
    ),
  );

  if (created != true || !context.mounted) return;

  final managerUid = context.read<AuthProvider>().currentUser!.uid;
  await context.read<GoalProvider>().createGoal(
    title: titleCtrl.text.trim(),
    description: descCtrl.text.trim(),
    createdBy: managerUid,
  );

  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم إنشاء الهدف بنجاح')));
  }
}
