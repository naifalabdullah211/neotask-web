import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/goal_provider.dart';
import '../../theme/goal_style_options.dart';
import 'goal_style_picker.dart';

/// Small manager-only dialog for creating a new Goal ("هدف"). Per the
/// rebuilt spec, a Goal carries ONLY title, description, startDate,
/// endDate — plus (per the Goals-tab comprehensive-improvements
/// requirement) a fixed-palette [colorName] and a fixed-icon-set
/// [iconName] — no assignee/chat of its own (those live on its Criteria).
Future<void> showCreateGoalDialog(BuildContext context) async {
  final titleCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final formKey = GlobalKey<FormState>();
  DateTime startDate = DateTime.now();
  DateTime endDate = DateTime.now().add(const Duration(days: 7));
  String colorName = goalColorNames.first; // default: navy
  String iconName = goalIconNames.first; // default: flag

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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  const SizedBox(height: 12),
                  const Text(
                    'لون الهدف',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  GoalColorPicker(
                    selected: colorName,
                    onChanged: (name) => setState(() => colorName = name),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'أيقونة الهدف',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  GoalIconPicker(
                    selected: iconName,
                    accentColor: goalColorSwatches[colorName]!,
                    onChanged: (name) => setState(() => iconName = name),
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
    colorName: colorName,
    iconName: iconName,
  );

  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('تم إنشاء الهدف بنجاح')));
  }
}
