import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/goal_model.dart';
import '../../providers/goal_provider.dart';
import '../../theme/goal_style_options.dart';
import 'goal_style_picker.dart';

/// Manager-only dialog for editing an EXISTING Goal's title, description,
/// startDate, endDate, and (per the Goals-tab comprehensive-improvements
/// requirement) fixed-palette color + fixed-icon-set icon. Mirrors
/// [showCreateGoalDialog] but pre-fills all fields from [goal] and calls
/// [GoalProvider.updateGoal] (a genuine Firestore write via `saveGoal`)
/// instead of `createGoal`.
Future<void> showEditGoalDialog(BuildContext context, Goal goal) async {
  final titleCtrl = TextEditingController(text: goal.title);
  final descCtrl = TextEditingController(text: goal.description);
  final formKey = GlobalKey<FormState>();
  DateTime startDate = goal.startDate;
  DateTime endDate = goal.endDate;
  String colorName = goal.colorName ?? goalColorNames.first;
  String iconName = goal.iconName ?? goalIconNames.first;
  bool saving = false;

  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
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
          title: const Text('تعديل الهدف'),
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
                    onTap: saving ? null : () => pickDate(isStart: true),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available_outlined),
                    title: const Text('تاريخ النهاية'),
                    subtitle: Text(DateFormat('yyyy/MM/dd').format(endDate)),
                    onTap: saving ? null : () => pickDate(isStart: false),
                  ),
                  const SizedBox(height: 12),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'لون الهدف',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GoalColorPicker(
                    selected: colorName,
                    onChanged: saving
                        ? (_) {}
                        : (name) => setState(() => colorName = name),
                  ),
                  const SizedBox(height: 16),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'أيقونة الهدف',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GoalIconPicker(
                    selected: iconName,
                    accentColor: goalColorSwatches[colorName]!,
                    onChanged: saving
                        ? (_) {}
                        : (name) => setState(() => iconName = name),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setState(() => saving = true);
                      try {
                        await context.read<GoalProvider>().updateGoal(
                          goalId: goal.goalId,
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim(),
                          startDate: startDate,
                          endDate: endDate,
                          colorName: colorName,
                          iconName: iconName,
                        );
                        if (context.mounted) Navigator.of(context).pop(true);
                      } catch (e) {
                        setState(() => saving = false);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('تعذر حفظ التعديلات، حاول مجددًا'),
                            ),
                          );
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('حفظ'),
            ),
          ],
        );
      },
    ),
  );

  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم تعديل الهدف بنجاح')));
  }
}

/// Manager-only confirmation + cascade-delete for a Goal. Shows an explicit
/// warning that ALL its criteria are deleted together (matches the real
/// cascade behavior in `FirestoreService.deleteGoal`), then performs the
/// Firestore write and pops the caller back (typically to the Goals list).
Future<void> confirmAndDeleteGoal(
  BuildContext context,
  Goal goal, {
  required VoidCallback onDeleted,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('حذف الهدف'),
      content: Text(
        'هل أنت متأكد من حذف هذا الهدف وكل معاييره المرتبطة به؟\n\n'
        '"${goal.title}"\n\n'
        'لا يمكن التراجع عن هذا الإجراء.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('حذف'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  try {
    await context.read<GoalProvider>().deleteGoal(goal.goalId);
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف الهدف بنجاح')));
      onDeleted();
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف الهدف، حاول مجددًا')),
      );
    }
  }
}
