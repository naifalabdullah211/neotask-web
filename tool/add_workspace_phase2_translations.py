from pathlib import Path

path = Path('lib/l10n/app_i18n.dart')
text = path.read_text(encoding='utf-8')

entries = {
    'إجمالي الإشعارات': 'Total notifications',
    'غير مقروءة': 'Unread',
    'مرتبطة بمهام': 'Task-related',
    'مرتبطة بتصويت': 'Poll-related',
    'معرفة ووثائق': 'Knowledge & documents',
    'ستظهر هنا التنبيهات والتحديثات المرتبطة بمهامك وتصويتاتك ووثائقك.':
        'Alerts and updates related to your tasks, polls, and documents will appear here.',
    'مركز الإشعارات': 'Notification center',
    'جميع الإشعارات مقروءة': 'All notifications are read',
    'إجمالي النماذج': 'Total forms',
    'نماذج نشطة': 'Active forms',
    'نماذج متوقفة': 'Paused forms',
    'إجمالي الحقول': 'Total fields',
    'مساحة النماذج جاهزة': 'Forms workspace is ready',
    'أنشئ نموذجًا وحدد حقوله ثم شارك رابطه وتابع الردود من نفس المكان.':
        'Create a form, define its fields, share its link, and track responses in one place.',
    'مكتبة النماذج': 'Forms library',
    'النماذج وروابطها وحالة استقبال الردود في مساحة واحدة':
        'Forms, share links, and response status in one workspace',
    'إيقاف استقبال الردود': 'Stop accepting responses',
    'تفعيل النموذج': 'Activate form',
}

missing = []
for key, value in entries.items():
    needle = f"    {key!r}:"
    if needle not in text:
        missing.append(f"    {key!r}: {value!r},")

if missing:
    marker = "    // Extended screen copy\n"
    if marker not in text:
        raise SystemExit('translation insertion marker not found')
    block = "    // Workspace refresh phase 2\n" + "\n".join(missing) + "\n\n"
    text = text.replace(marker, block + marker, 1)

# Dynamic notification subtitle used by the workspace header.
template = """    match = RegExp(r'^(\\d+) غير مقروءة وتحتاج انتباهك$').firstMatch(source);
    if (match != null) return '${match.group(1)} unread notifications need your attention';
"""
if "غير مقروءة وتحتاج انتباهك" not in text:
    marker = "    return null;\n  }\n\n  static const Map<String, String> _en = {"
    if marker not in text:
        raise SystemExit('template insertion marker not found')
    text = text.replace(
        marker,
        template + "\n" + marker,
        1,
    )

path.write_text(text, encoding='utf-8')
print('Added NeoTask workspace phase 2 translations')
