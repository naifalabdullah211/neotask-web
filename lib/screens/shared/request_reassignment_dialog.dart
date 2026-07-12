import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

/// Employee-facing dialog: propose handing [task] over to another active
/// employee, subject to the manager's approval (per the manager's design
/// answer "٧- مراجعة المدير الحالي": the request itself is created here,
/// but decided inside the existing ManagerReviewTab).
///
/// Per answer "٥- أي موظف": any ACTIVE employee other than the current
/// assignee may be selected — no further restriction is enforced here.
Future<void> showRequestReassignmentDialog(
  BuildContext context, {
  required AppTask task,
  required String currentEmployeeUid,
}) async {
  final candidates = FirestoreService.getAllEmployees()
      .where(
        (u) =>
            u.accountStatus == AccountStatus.active &&
            u.uid != currentEmployeeUid,
      )
      .toList();

  if (candidates.isEmpty) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('لا يوجد موظفون نشطون آخرون لإسناد المهمة إليهم')),
    );
    return;
  }

  AppUser? selected = candidates.first;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('طلب إسناد المهمة لموظف آخر'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'سيُرسل هذا الطلب إلى المدير للموافقة. ستستمر في العمل على المهمة كالمعتاد لحين رده.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            const Text('إسناد المهمة إلى:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            DropdownButtonFormField<AppUser>(
              initialValue: selected,
              decoration: const InputDecoration(isDense: true),
              items: candidates
                  .map((u) => DropdownMenuItem(value: u, child: Text(u.name)))
                  .toList(),
              onChanged: (v) => setState(() => selected = v),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('إرسال الطلب'),
          ),
        ],
      ),
    ),
  );

  if (confirmed != true || selected == null || !context.mounted) return;

  try {
    await context.read<TaskProvider>().requestReassignment(
      taskId: task.taskId,
      requestedBy: currentEmployeeUid,
      requestedTo: selected!.uid,
    );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم إرسال طلب الإسناد إلى المدير')),
    );
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
  }
}
