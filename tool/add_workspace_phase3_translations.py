from pathlib import Path

path = Path('lib/l10n/app_i18n.dart')
text = path.read_text(encoding='utf-8')

entries = {
    'سيظهر التقرير هنا بعد إغلاق التصويت وحساب النتيجة.':
        'The report will appear here after voting closes and the result is calculated.',
    'توزيع الأصوات ونسب كل اختيار': 'Vote distribution and percentage by option',
    'تعذّر حفظ القرار': 'Could not save the decision',
    'تعادل بين': 'Tie between',
    'الاختيار الفائز': 'Winning choice',
    'صوت': 'votes',
    'قائمة من صوّت': 'Voted',
    'قائمة من لم يصوّت': 'Not voted',
    'المتبقية': 'Remaining',
    'نسبة التقدم': 'Progress',
    'المعايير المرتبطة بالهدف وحالة تنفيذ كل منها':
        'Criteria linked to the goal and each item’s execution status',
    'بدون موظف': 'No employee assigned',
    'ملاحظات ومتابعات مرتبطة بالهدف': 'Notes and follow-ups linked to the goal',
    'مستخدم': 'User',
    'أدخل رقمًا صحيحًا': 'Enter a valid number',
    'استخدم صيغة YYYY-MM-DD': 'Use YYYY-MM-DD format',
    'ابدأ المحادثة بإرسال أول رسالة.': 'Start the conversation by sending the first message.',
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
    block = "    // Workspace refresh phase 3\n" + "\n".join(missing) + "\n\n"
    text = text.replace(marker, block + marker, 1)

path.write_text(text, encoding='utf-8')
print('Added NeoTask workspace phase 3 translations')
