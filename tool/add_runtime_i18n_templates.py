from pathlib import Path

path = Path('lib/l10n/app_i18n.dart')
text = path.read_text(encoding='utf-8')

marker = "    return null;\n  }\n\n  static const Map<String, String> _en = {"
if marker not in text:
    raise SystemExit('AppI18n template marker not found')

sentinel = "    // Runtime product-copy templates — keep user-authored values verbatim.\n"
if sentinel not in text:
    block = r'''    // Runtime product-copy templates — keep user-authored values verbatim.
    match = RegExp(r'^(\d+) قاعدة$').firstMatch(source);
    if (match != null) return '${match.group(1)} rules';
    match = RegExp(r'^(\d+) هدف في العرض$').firstMatch(source);
    if (match != null) return '${match.group(1)} goals in view';
    match = RegExp(r'^(\d+) تصويت في العرض$').firstMatch(source);
    if (match != null) return '${match.group(1)} polls in view';
    match = RegExp(r'^(\d+) مهمة في العرض$').firstMatch(source);
    if (match != null) return '${match.group(1)} tasks in view';
    match = RegExp(r'^(\d+)/(\d+) معايير$').firstMatch(source);
    if (match != null) return '${match.group(1)}/${match.group(2)} criteria';
    match = RegExp(r'^قبل الموعد بـ ([\d.]+) ساعة$').firstMatch(source);
    if (match != null) return '${match.group(1)} hours before due time';
    match = RegExp(r'^أحداث الشهر الحالي \((\d+)\)$').firstMatch(source);
    if (match != null) return 'Current month events (${match.group(1)})';
    match = RegExp(r'^المهام \((\d+)\)$').firstMatch(source);
    if (match != null) return 'Tasks (${match.group(1)})';
    match = RegExp(r'^عدد المهام في هذا النطاق: (\d+)$').firstMatch(source);
    if (match != null) return 'Tasks in this range: ${match.group(1)}';
    match = RegExp(r'^ملاحظة الموظف: (.+)$').firstMatch(source);
    if (match != null) return 'Employee note: ${match.group(1)}';
    match = RegExp(r'^ملاحظة المدير: (.+)$').firstMatch(source);
    if (match != null) return 'Manager note: ${match.group(1)}';
    match = RegExp(r'^سبب الرفض: (.+)$').firstMatch(source);
    if (match != null) return 'Rejection reason: ${match.group(1)}';
    match = RegExp(r'^ضمن الهدف: (.+)$').firstMatch(source);
    if (match != null) return 'Goal: ${match.group(1)}';
    match = RegExp(r'^الملف: (.+)$').firstMatch(source);
    if (match != null) return 'File: ${match.group(1)}';
    match = RegExp(r'^(.+) - نسخة$').firstMatch(source);
    if (match != null) return '${match.group(1)} - Copy';
    match = RegExp(r'^تعديل الإصدار (\d+)$').firstMatch(source);
    if (match != null) return 'Edit version ${match.group(1)}';
    match = RegExp(r'^(.+) · الإصدار (\d+)$').firstMatch(source);
    if (match != null) {
      final value = match.group(1)!;
      return '${_en[value] ?? value} · Version ${match.group(2)}';
    }
    match = RegExp(r'^(\d+) من (\d+) مهمة مكتملة في الوقت(?: المحدد)?$').firstMatch(source);
    if (match != null) {
      return '${match.group(1)} of ${match.group(2)} tasks completed on time';
    }
    match = RegExp(r'^تم تحديث الحالة إلى (.+)$').firstMatch(source);
    if (match != null) {
      final value = match.group(1)!;
      return 'Status updated to ${_en[value] ?? value}';
    }
    match = RegExp(r'^تعذّر بدء التسجيل: (.+)$').firstMatch(source);
    if (match != null) return 'Could not start recording: ${match.group(1)}';
    match = RegExp(r'^تعذّر إيقاف التسجيل: (.+)$').firstMatch(source);
    if (match != null) return 'Could not stop recording: ${match.group(1)}';
    match = RegExp(r'^تعذّر إنشاء الصفحة: (.+)$').firstMatch(source);
    if (match != null) return 'Could not create the page: ${match.group(1)}';
    match = RegExp(r'^سيتم حذف «(.+)» نهائيًا\.$').firstMatch(source);
    if (match != null) return '“${match.group(1)}” will be permanently deleted.';
    match = RegExp(r'^سيُحذف نموذج «(.+)» وجميع الردود المرتبطة به نهائيًا\.$').firstMatch(source);
    if (match != null) {
      return 'Form “${match.group(1)}” and all related responses will be permanently deleted.';
    }
    match = RegExp(r'^تم تغيير كلمة مرور "?(.+?)"? بنجاح$').firstMatch(source);
    if (match != null) return 'Password changed successfully for ${match.group(1)}';

'''
    text = text.replace(marker, block + marker, 1)

path.write_text(text, encoding='utf-8')
print('Added NeoTask runtime translation templates')
