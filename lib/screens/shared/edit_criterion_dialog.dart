import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:provider/provider.dart';
import '../../models/criterion_model.dart';
import '../../providers/criterion_provider.dart';

/// Manager-only dialog for editing an EXISTING Criterion's title/description
/// ONLY (per spec: assignees/status are edited elsewhere — this dialog is
/// scoped strictly to "نص/عنوان المعيار"). Calls
/// [CriterionProvider.updateCriterion] (a genuine Firestore write via
/// `saveCriterion`).
Future<void> showEditCriterionDialog(
  BuildContext context,
  Criterion criterion,
) async {
  final titleCtrl = TextEditingController(text: criterion.title);
  final descCtrl = TextEditingController(text: criterion.description);
  final formKey = GlobalKey<FormState>();
  bool saving = false;

  final saved = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: const Text('تعديل المعيار'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: context.tr('عنوان المعيار'),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? context.tr('أدخل عنوان المعيار')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: descCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: context.tr('وصف المعيار (اختياري)'),
                    ),
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
                        await context.read<CriterionProvider>().updateCriterion(
                          criterionId: criterion.criterionId,
                          title: titleCtrl.text.trim(),
                          description: descCtrl.text.trim(),
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
    ).showSnackBar(const SnackBar(content: Text('تم تعديل المعيار بنجاح')));
  }
}

/// Manager-only confirmation + delete for a single Criterion. Deletes ONLY
/// this criterion (via `FirestoreService.deleteCriterion`) — the parent
/// Goal and all its other criteria remain untouched.
Future<void> confirmAndDeleteCriterion(
  BuildContext context,
  Criterion criterion, {
  required VoidCallback onDeleted,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('حذف المعيار'),
      content: Text(
        'هل أنت متأكد من حذف هذا المعيار؟\n\n'
        '"${criterion.title}"\n\n'
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
    await context.read<CriterionProvider>().deleteCriterion(
      criterion.goalId,
      criterion.criterionId,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف المعيار بنجاح')));
      onDeleted();
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر حذف المعيار، حاول مجددًا')),
      );
    }
  }
}
