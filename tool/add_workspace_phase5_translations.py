from pathlib import Path

path = Path('lib/l10n/app_i18n.dart')
text = path.read_text(encoding='utf-8')

entries = {
    # Meetings workspace
    'إجمالي الاجتماعات': 'Total meetings',
    'اجتماعات قادمة': 'Upcoming meetings',
    'محاضر سابقة': 'Past minutes',
    'إجمالي القرارات': 'Total decisions',
    'لا توجد محاضر سابقة': 'No past meeting minutes',
    'ستظهر هنا الاجتماعات المكتملة ومحاضرها للرجوع إليها.':
        'Completed meetings and their minutes will appear here for reference.',
    'أنشئ اجتماعًا جديدًا وحدد المشاركين والموعد لبدء المتابعة.':
        'Create a new meeting and set the participants and time to begin tracking.',
    'أرشيف الاجتماعات': 'Meeting archive',
    'مساحة الاجتماعات': 'Meetings workspace',
    'المحاضر والقرارات السابقة في مكان واحد':
        'Past minutes and decisions in one place',
    'اختر اجتماعًا لفتح المحضر والقرارات والإجراءات':
        'Select a meeting to open its minutes, decisions, and actions',
    'المكان غير محدد': 'Location not specified',
    'قرارات': 'decisions',
    'مشاركون': 'participants',
    'قادم': 'Upcoming',
    # Bulk import workspace
    'إجمالي الصفوف': 'Total rows',
    'صفوف صالحة': 'Valid rows',
    'صفوف بها أخطاء': 'Rows with errors',
    'إعداد الاستيراد': 'Import setup',
    'اختر نوع البيانات وارفع الملف ثم راجع النتيجة قبل الحفظ':
        'Choose the data type, upload the file, then review the result before saving',
    'لم يتم اختيار ملف بعد': 'No file selected yet',
    'ملف جاهز للمراجعة': 'File ready for review',
    'اختر ملف CSV أو XLSX لبدء المعاينة والتحقق قبل الحفظ.':
        'Choose a CSV or XLSX file to start preview and validation before saving.',
    'مراجعة البيانات': 'Data review',
    'راجع الصفوف الصالحة والأخطاء قبل تنفيذ الاستيراد':
        'Review valid rows and errors before running the import',
    'اختيار ملف CSV أو XLSX': 'Choose CSV or XLSX file',
    'الملف': 'File',
    'الاسم | الرقم الوظيفي | كلمة المرور':
        'Name | Employee ID | Password',
    'عنوان المهمة | الرقم الوظيفي | تاريخ الاستحقاق | الوصف | تاريخ البداية | الساعات | الأولوية | التصنيف':
        'Task title | Employee ID | Due date | Description | Start date | Hours | Priority | Category',
    'صف بلا عنوان': 'Untitled row',
    'صالح للاستيراد': 'Ready to import',
    'تعذّر قراءة الملف': 'Could not read the file',
    'صيغة الملف غير صالحة أو الملف تالف': 'The file format is invalid or the file is corrupted',
    'الأعمدة المطلوبة: الاسم، الرقم الوظيفي، كلمة المرور':
        'Required columns: Name, Employee ID, Password',
    'الأعمدة المطلوبة: عنوان المهمة، الرقم الوظيفي، تاريخ الاستحقاق':
        'Required columns: Task title, Employee ID, Due date',
    'الاسم مفقود': 'Name is missing',
    'الرقم الوظيفي مفقود': 'Employee ID is missing',
    'كلمة المرور أقل من 6 أحرف': 'Password is shorter than 6 characters',
    'الرقم الوظيفي موجود مسبقًا': 'Employee ID already exists',
    'الرقم الوظيفي مكرر داخل الملف': 'Employee ID is duplicated in the file',
    'عنوان المهمة مفقود': 'Task title is missing',
    'الموظف غير موجود أو غير نشط': 'Employee does not exist or is inactive',
    'تاريخ الاستحقاق غير صالح': 'Due date is invalid',
    'تاريخ البداية غير صالح': 'Start date is invalid',
    'الاستحقاق يسبق البداية': 'Due date is before the start date',
    'الساعات غير صالحة': 'Hours are invalid',
    'الأولوية غير صالحة': 'Priority is invalid',
    'المهمة موجودة مسبقًا': 'Task already exists',
    'المهمة مكررة داخل الملف': 'Task is duplicated in the file',
}

marker = "    // Extended screen copy\n"
missing = []
for key, value in entries.items():
    if f"    {key!r}:" not in text:
        missing.append(f"    {key!r}: {value!r},")
if missing:
    if marker not in text:
        raise SystemExit('AppI18n phase5 insertion marker not found')
    block = "    // Meetings + import workspace refresh\n" + "\n".join(missing) + "\n\n"
    text = text.replace(marker, block + marker, 1)

# Dynamic import feedback.
template_marker = "    // Runtime product-copy templates — keep user-authored values verbatim.\n"
if template_marker not in text:
    raise SystemExit('runtime template section not found')
if "r'^تم إنشاء (\\d+) حساب موظف$'" not in text:
    insertion = r'''    match = RegExp(r'^تم إنشاء (\d+) حساب موظف$').firstMatch(source);
    if (match != null) return '${match.group(1)} employee accounts created';
    match = RegExp(r'^تم إنشاء (\d+) حساب موظف، وتعذر (\d+)$').firstMatch(source);
    if (match != null) {
      return '${match.group(1)} employee accounts created; ${match.group(2)} failed';
    }
    match = RegExp(r'^تم إنشاء (\d+) مهمة بنجاح$').firstMatch(source);
    if (match != null) return '${match.group(1)} tasks created successfully';
    match = RegExp(r'^تعذر الاستيراد: (.+)$').firstMatch(source);
    if (match != null) return 'Import failed: ${match.group(1)}';
    match = RegExp(r'^(\d+) قرار · (\d+) مشارك$').firstMatch(source);
    if (match != null) {
      return '${match.group(1)} decisions · ${match.group(2)} participants';
    }

'''
    text = text.replace(template_marker, template_marker + insertion, 1)

path.write_text(text, encoding='utf-8')
print('Added NeoTask phase 5 translations')
