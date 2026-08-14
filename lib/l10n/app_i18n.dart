import 'package:flutter/widgets.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';

import '../providers/locale_provider.dart';

extension AppI18nContext on BuildContext {
  String tr(String source) {
    final inBuildPhase =
        SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks;
    Locale locale;
    try {
      locale = Provider.of<LocaleProvider>(this, listen: inBuildPhase).locale;
    } on ProviderNotFoundException {
      locale = const Locale('ar');
    }
    return AppI18n.translate(source, locale);
  }

  String trRead(String source) {
    Locale locale;
    try {
      locale = read<LocaleProvider>().locale;
    } on ProviderNotFoundException {
      locale = const Locale('ar');
    }
    return AppI18n.translate(source, locale);
  }
}

/// Central Arabic → English UI catalogue.
///
/// Only known product copy and anchored system-message templates are
/// translated. User-authored task titles, comments and names therefore stay
/// exactly as entered.
class AppI18n {
  const AppI18n._();

  static bool isEnglish(Locale locale) => locale.languageCode == 'en';

  static String translate(String source, Locale locale) {
    if (!isEnglish(locale) || source.trim().isEmpty) return source;
    final exact = _en[source];
    if (exact != null) return exact;
    for (final prefix in const [
      'Exception: ',
      'Bad state: ',
      'Invalid argument(s): ',
    ]) {
      if (source.startsWith(prefix)) {
        final detail = source.substring(prefix.length);
        final translated = translate(detail, locale);
        if (translated != detail) return translated;
      }
    }
    return _translateTemplate(source) ?? source;
  }

  static String? _translateTemplate(String source) {
    Match? match;

    match = RegExp(r'^رقم وظيفي: (.+)$').firstMatch(source);
    if (match != null) return 'Employee ID: ${match.group(1)}';
    match = RegExp(r'^الرقم الوظيفي (.+)$').firstMatch(source);
    if (match != null) return 'Employee ID ${match.group(1)}';
    match = RegExp(r'^الرقم الوظيفي: (.+)$').firstMatch(source);
    if (match != null) return 'Employee ID: ${match.group(1)}';
    match = RegExp(r'^تغيير كلمة المرور — (.+)$').firstMatch(source);
    if (match != null) return 'Change password — ${match.group(1)}';
    match = RegExp(r'^السعة الأسبوعية — (.+)$').firstMatch(source);
    if (match != null) return 'Weekly capacity — ${match.group(1)}';
    match = RegExp(r'^تم تحويل المهمة إلى (.+)$').firstMatch(source);
    if (match != null) return 'Task reassigned to ${match.group(1)}';
    match = RegExp(r'^تم حذف نموذج «(.+)»$').firstMatch(source);
    if (match != null) return 'Form “${match.group(1)}” was deleted';
    match = RegExp(r'^رد رقم (\d+)$').firstMatch(source);
    if (match != null) return 'Response ${match.group(1)}';
    match = RegExp(r'^ردود: (.+)$').firstMatch(source);
    if (match != null) return 'Responses: ${match.group(1)}';
    match = RegExp(r'^استيراد (\d+) صف صالح$').firstMatch(source);
    if (match != null) return 'Import ${match.group(1)} valid rows';
    match = RegExp(r'^(\d+) خطأ$').firstMatch(source);
    if (match != null) return '${match.group(1)} errors';
    match = RegExp(r'^(\d+) صالح$').firstMatch(source);
    if (match != null) return '${match.group(1)} valid';
    match = RegExp(r'^(\d+) يوم متبقٍ$').firstMatch(source);
    if (match != null) return '${match.group(1)} days remaining';
    match = RegExp(r'^(\d+) ساعة متبقية$').firstMatch(source);
    if (match != null) return '${match.group(1)} hours remaining';
    match = RegExp(r'^(\d+) يوم$').firstMatch(source);
    if (match != null) return '${match.group(1)} days';
    match = RegExp(r'^(\d+) ساعة$').firstMatch(source);
    if (match != null) return '${match.group(1)} hours';
    match = RegExp(r'^(\d+) دقيقة$').firstMatch(source);
    if (match != null) return '${match.group(1)} minutes';
    match = RegExp(r'^(\d+) صوت$').firstMatch(source);
    if (match != null) return '${match.group(1)} votes';
    match = RegExp(r'^(\d+) مشارك$').firstMatch(source);
    if (match != null) return '${match.group(1)} participants';
    match = RegExp(r'^(\d+) وثيقة$').firstMatch(source);
    if (match != null) return '${match.group(1)} documents';
    match = RegExp(r'^(\d+) مكتملة هذا الأسبوع$').firstMatch(source);
    if (match != null) return '${match.group(1)} completed this week';
    match = RegExp(r'^(\d+) مهام$').firstMatch(source);
    if (match != null) return '${match.group(1)} tasks';
    match = RegExp(r'^(\d+) مهمة$').firstMatch(source);
    if (match != null) return '${match.group(1)} tasks';
    match = RegExp(r'^(\d+) من (\d+) مكتمل$').firstMatch(source);
    if (match != null) return '${match.group(1)} of ${match.group(2)} complete';
    match = RegExp(r'^(\d+)/(\d+) معايير مكتملة$').firstMatch(source);
    if (match != null)
      return '${match.group(1)}/${match.group(2)} criteria complete';
    match = RegExp(r'^اختيار (\d+)$').firstMatch(source);
    if (match != null) return 'Option ${match.group(1)}';
    match = RegExp(r'^يوم (\d+)$').firstMatch(source);
    if (match != null) return 'Day ${match.group(1)}';
    match = RegExp(r'^آخر تحديث (.+)$').firstMatch(source);
    if (match != null) return 'Last updated ${match.group(1)}';
    match = RegExp(r'^الإصدار (.+)$').firstMatch(source);
    if (match != null) return 'Version ${match.group(1)}';
    match = RegExp(r'^موعد الإغلاق: (.+)$').firstMatch(source);
    if (match != null) return 'Closes: ${match.group(1)}';
    match = RegExp(r'^تاريخ الطلب: (.+)$').firstMatch(source);
    if (match != null) return 'Request date: ${match.group(1)}';
    match = RegExp(r'^أُرسلت: (.+)$').firstMatch(source);
    if (match != null) return 'Submitted: ${match.group(1)}';
    match = RegExp(r'^الموعد: (.+)$').firstMatch(source);
    if (match != null) return 'Due: ${match.group(1)}';
    match = RegExp(r'^الاستحقاق: (.+)$').firstMatch(source);
    if (match != null) return 'Due: ${match.group(1)}';
    match = RegExp(r'^البداية (.+)$').firstMatch(source);
    if (match != null) return 'Start ${match.group(1)}';
    match = RegExp(r'^النهاية (.+)$').firstMatch(source);
    if (match != null) return 'End ${match.group(1)}';
    match = RegExp(r'^محادثة المهمة مع (.+)$').firstMatch(source);
    if (match != null) return 'Task chat with ${match.group(1)}';
    match = RegExp(r'^تذكير: مهمة "(.+)" تستحق غدًا$').firstMatch(source);
    if (match != null) return 'Reminder: “${match.group(1)}” is due tomorrow';
    match = RegExp(r'^مهمتك الشخصية "(.+)" أصبحت متأخرة$').firstMatch(source);
    if (match != null)
      return 'Your personal task “${match.group(1)}” is overdue';
    match = RegExp(
      r'^مهمة "(.+)" المسندة لـ(.+) أصبحت متأخرة$',
    ).firstMatch(source);
    if (match != null) {
      return 'Task “${match.group(1)}” assigned to ${match.group(2)} is overdue';
    }
    match = RegExp(r'^تعليق جديد على مهمة: (.+)$').firstMatch(source);
    if (match != null) return 'New comment on task: ${match.group(1)}';
    match = RegExp(r'^تذكير بالتصويت: (.+)$').firstMatch(source);
    if (match != null) return 'Poll reminder: ${match.group(1)}';
    match = RegExp(
      r'^انتهى التصويت على: (.+)\. اضغط لعرض النتيجة\.$',
    ).firstMatch(source);
    if (match != null)
      return 'Voting ended for: ${match.group(1)}. Tap to view the result.';
    match = RegExp(r'^شهريًا \(يوم (\d+)\)$').firstMatch(source);
    if (match != null) return 'Monthly (day ${match.group(1)})';
    match = RegExp(r'^أولوية (.+)$').firstMatch(source);
    if (match != null) {
      final value = match.group(1)!;
      return '${_en[value] ?? value} priority';
    }
    match = RegExp(r'^هل تريد حذف «(.+)» نهائيًا؟$').firstMatch(source);
    if (match != null) return 'Permanently delete “${match.group(1)}”?';
    match = RegExp(r'^هل تريد حذف «(.+)» ومحضره؟$').firstMatch(source);
    if (match != null) return 'Delete “${match.group(1)}” and its minutes?';
    match = RegExp(r'^هل تريد حذف "(.+)"؟$').firstMatch(source);
    if (match != null) return 'Delete “${match.group(1)}”?';
    match = RegExp(r'^تم تغيير كلمة مرور "?(.+?)"?$').firstMatch(source);
    if (match != null) return 'Password changed for ${match.group(1)}';
    match = RegExp(r'^تم حذف حساب "?(.+?)"?$').firstMatch(source);
    if (match != null) return 'Account deleted for ${match.group(1)}';
    match = RegExp(r'^تعذّر رفع الصورة: (.+)$').firstMatch(source);
    if (match != null) return 'Could not upload the image: ${match.group(1)}';
    match = RegExp(r'^تعذّر رفع المرفق: (.+)$').firstMatch(source);
    if (match != null)
      return 'Could not upload the attachment: ${match.group(1)}';
    match = RegExp(r'^تعذّر رفع الملف: (.+)$').firstMatch(source);
    if (match != null) return 'Could not upload the file: ${match.group(1)}';
    match = RegExp(r'^تعذّر إرسال الرسالة: (.+)$').firstMatch(source);
    if (match != null) return 'Could not send the message: ${match.group(1)}';
    match = RegExp(r'^حدث خطأ غير متوقع[ :]*(.*)$').firstMatch(source);
    if (match != null) {
      final detail = match.group(1)!.trim();
      return detail.isEmpty
          ? 'An unexpected error occurred'
          : 'Unexpected error: $detail';
    }
    match = RegExp(r'^الصورة الشخصية لـ (.+)$').firstMatch(source);
    if (match != null) return '${match.group(1)} profile photo';
    match = RegExp(r'^(.+) التالي$').firstMatch(source);
    if (match != null) {
      final value = match.group(1)!;
      return 'Next ${_en[value] ?? value}';
    }
    match = RegExp(r'^(.+) السابق$').firstMatch(source);
    if (match != null) {
      final value = match.group(1)!;
      return 'Previous ${_en[value] ?? value}';
    }
    match = RegExp(r'^يرجى اختيار (.+)$').firstMatch(source);
    if (match != null) {
      final value = match.group(1)!;
      return 'Please select ${_en[value] ?? value}';
    }

    match = RegExp(r'^(\d+) غير مقروءة وتحتاج انتباهك$').firstMatch(source);
    if (match != null)
      return '${match.group(1)} unread notifications need your attention';

    // Runtime product-copy templates — keep user-authored values verbatim.
    match = RegExp(r'^تم إنشاء (\d+) حساب موظف$').firstMatch(source);
    if (match != null) return '${match.group(1)} employee accounts created';
    match = RegExp(
      r'^تم إنشاء (\d+) حساب موظف، وتعذر (\d+)$',
    ).firstMatch(source);
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
    match = RegExp(
      r'^(\d+) من (\d+) مهمة مكتملة في الوقت(?: المحدد)?$',
    ).firstMatch(source);
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
    if (match != null)
      return '“${match.group(1)}” will be permanently deleted.';
    match = RegExp(
      r'^سيُحذف نموذج «(.+)» وجميع الردود المرتبطة به نهائيًا\.$',
    ).firstMatch(source);
    if (match != null) {
      return 'Form “${match.group(1)}” and all related responses will be permanently deleted.';
    }
    match = RegExp(r'^تم تغيير كلمة مرور "?(.+?)"? بنجاح$').firstMatch(source);
    if (match != null)
      return 'Password changed successfully for ${match.group(1)}';

    return null;
  }

  static const Map<String, String> _en = {
    // Global navigation and account
    'العربية': 'Arabic',
    'English': 'English',
    'الرئيسية': 'Home',
    'المراجعة': 'Review',
    'الموظفون': 'Employees',
    'التقارير': 'Reports',
    'المحادثات': 'Chats',
    'المحادثة': 'Chat',
    'الإعدادات': 'Settings',
    'الإشعارات': 'Notifications',
    'المفضلة': 'Favorites',
    'تسجيل الخروج': 'Sign out',
    'إغلاق القائمة': 'Close menu',
    'مدير النظام': 'System manager',
    'مصمم · عرض فقط': 'Designer · View only',
    'موظف': 'Employee',
    'قراءة فقط': 'View only',
    'عرض فقط': 'View only',
    'التخطيط والتنفيذ': 'Planning & execution',
    'الإدارة والتواصل': 'Management & communication',
    'المعرفة والموارد': 'Knowledge & resources',
    'التبويبات الرئيسية': 'Main tabs',
    'الأيقونات والإجراءات': 'Icons & actions',
    'الحساب والنظام': 'Account & system',
    'خطة العمل': 'Work plan',
    'الأتمتة الشرطية': 'Conditional automation',
    'الأتمتة': 'Automation',
    'التقويم': 'Calendar',
    'الأهداف': 'Goals',
    'مهامي الشخصية': 'My personal tasks',
    'التصويت': 'Voting',
    'أفكار المدير': 'Manager ideas',
    'النماذج المخصصة': 'Custom forms',
    'استيراد Excel / CSV': 'Import Excel / CSV',
    'مركز المعرفة': 'Knowledge center',
    'الاجتماعات': 'Meetings',
    'جهات الاتصال': 'Contacts',
    'مساعد NeoTask': 'NeoTask Assistant',
    'المساعدة': 'Help',
    'ملخص المدير': 'Manager summary',
    'تحديث مباشر لحالة العمل': 'Live work status',
    'ملخص اليوم': 'Today’s summary',
    'ملخص الأسبوع': 'Weekly summary',
    'تصفح الملخصات السابقة': 'Browse previous summaries',
    'اختر ما تريد شرحه': 'Choose what you want explained',
    'الموضوعات الظاهرة مطابقة لصلاحية حسابك الحالية.':
        'The topics shown match your current account permissions.',
    'شرح مساعد NeoTask': 'NeoTask Assistant explanation',
    'وظيفتها': 'What it does',
    'طريقة الاستخدام': 'How to use it',
    'الصلاحية': 'Permission',
    'النتيجة': 'Result',
    'أحتاج تحديد الأيقونة أو التبويب': 'Please identify the icon or tab',
    'هل تقصد:': 'Did you mean:',
    'مثال: اشرح لي أيقونة المراجعة': 'Example: Explain the Review icon',
    'عرض الشرح': 'Show explanation',
    'اسأل مساعد NeoTask عن تبويب أو أيقونة':
        'Ask the NeoTask Assistant about a tab or icon',

    // Authentication
    'مساحة عمل واحدة لإنجاز أوضح': 'One workspace. Clearer execution.',
    'نظم مهامك وتابع فريقك وأنجز أعمالك اليومية بسهولة من أي جهاز':
        'Organize tasks, follow your team, and complete daily work from any device.',
    'مرحبًا بعودتك': 'Welcome back',
    'سجّل الدخول للوصول إلى مساحة عملك': 'Sign in to access your workspace',
    'الرقم الوظيفي': 'Employee ID',
    'الرقم السري': 'Password',
    'تسجيل الدخول': 'Sign in',
    'أدخل الرقم الوظيفي': 'Enter your employee ID',
    'أدخل الرقم السري': 'Enter your password',
    'بياناتك آمنة ومشفرة بالكامل': 'Your data is secure and fully encrypted',
    'الموظفون الجدد يسجّلون عبر رابط الدعوة المُرسل من المدير':
        'New employees register using the invitation link sent by the manager',
    'العودة لتسجيل الدخول': 'Back to sign in',
    'إنشاء حساب المدير': 'Create manager account',
    'إنشاء الحساب': 'Create account',
    'إنشاء حساب موظف': 'Create employee account',
    'مفتاح التأسيس': 'Setup key',
    'أدخل مفتاح التأسيس': 'Enter the setup key',
    'الاسم الكامل': 'Full name',
    'تأكيد الرقم السري': 'Confirm password',
    'إرسال طلب الانضمام': 'Submit join request',
    'طلبك قيد المراجعة': 'Your request is under review',
    'دعوة صالحة — أكمل بياناتك للانضمام':
        'Valid invitation — complete your details to join',
    'بعد الإرسال سيصبح حسابك بانتظار موافقة المدير.':
        'After submission, your account will await manager approval.',
    'رابط الدعوة غير صالح': 'Invalid invitation link',
    'ابدأ الآن على بركة الله': 'Start now',
    'مرحبًا بكم في تجربة عمل أكثر وضوحًا':
        'Welcome to a clearer way of working',
    'تظهر هذه الصفحة مرة واحدة عند أول تسجيل دخول':
        'This page appears once on the first sign-in',
    'صُمّم المشروع ليكون عونًا لكم': 'Designed to support your work',
    'جميع الحقوق محفوظة · NAY211@2026': 'All rights reserved · NAY211@2026',

    // Common actions
    'إضافة': 'Add',
    'إضافة مهمة': 'Add task',
    'إضافة مهمة جديدة': 'Add new task',
    'مهمة جديدة': 'New task',
    'إنشاء مهمة جديدة': 'Create new task',
    'إنشاء مهمة مرتبطة': 'Create linked task',
    'إضافة تعليق': 'Add comment',
    'إضافة قرار': 'Add decision',
    'إضافة اختيار': 'Add option',
    'إضافة حقل': 'Add field',
    'إضافة معرفة': 'Add knowledge',
    'إضافة/إزالة موظفين': 'Add/remove employees',
    'تعديل': 'Edit',
    'حفظ': 'Save',
    'حفظ التعديلات': 'Save changes',
    'حفظ المهمة': 'Save task',
    'حفظ التقدم': 'Save progress',
    'حفظ القرار': 'Save decision',
    'حفظ المعيار': 'Save criterion',
    'حفظ النموذج': 'Save form',
    'حفظ وتشغيل': 'Save and activate',
    'حفظ وإغلاق الاجتماع': 'Save and close meeting',
    'حفظ إصدار جديد': 'Save new version',
    'إرسال': 'Send',
    'إرسال الرد': 'Submit response',
    'إرسال الطلب': 'Send request',
    'إرسال للمراجعة': 'Submit for review',
    'إرسال المهمة للمراجعة': 'Submit task for review',
    'إغلاق': 'Close',
    'إلغاء': 'Cancel',
    'تأكيد': 'Confirm',
    'اعتماد': 'Approve',
    'موافقة': 'Approve',
    'رفض': 'Reject',
    'تراجع': 'Undo',
    'استعادة': 'Restore',
    'أرشفة': 'Archive',
    'الأرشيف': 'Archive',
    'نشر': 'Publish',
    'نسخ الرابط': 'Copy link',
    'نسخ الرابط الفعّال وإرساله': 'Copy and send active link',
    'رفع ملف': 'Upload file',
    'ملف': 'File',
    'ملف PDF': 'PDF file',
    'صورة': 'Image',
    'فتح التفاصيل': 'Open details',
    'فتح التفاصيل والتعديل': 'Open details and edit',
    'عرض الطلب': 'View request',
    'عرض التقرير النهائي الكامل': 'View full final report',
    'متابعة': 'Follow up',
    'رد': 'Reply',
    'تحويل': 'Reassign',
    'تحويل لمهمة': 'Convert to task',
    'تحويل الرد إلى مهمة': 'Convert response to task',
    'تحويل لموظف / فريق': 'Reassign to employee / team',
    'تحويل المهمة لموظف / فريق': 'Reassign task to employee / team',
    'طلب تعديل': 'Request changes',
    'إعادة للتعديل': 'Return for changes',
    'تحديث الحالة': 'Update status',
    'تحديث نسبة الإنجاز': 'Update completion',
    'تغيير': 'Change',
    'تغيير كلمة المرور': 'Change password',
    'بحث': 'Search',
    'بحث شامل': 'Global search',
    'صورة الحساب والقائمة': 'Profile photo & menu',
    'المرفقات': 'Attachments',

    // Task language and statuses
    'المهام': 'Tasks',
    'مهامي': 'My tasks',
    'المهمة': 'Task',
    'اسم المهمة': 'Task name',
    'تفاصيل المهمة': 'Task details',
    'سجل المهمة الكامل': 'Full task history',
    'محادثة المهمة': 'Task chat',
    'محادثات المهام': 'Task chats',
    'الأولوية': 'Priority',
    'الحالة': 'Status',
    'التقدم': 'Progress',
    'التصنيف': 'Category',
    'المسؤول': 'Owner',
    'الموظف المكلَّف': 'Assigned employee',
    'تاريخ الاستحقاق': 'Due date',
    'الموعد النهائي': 'Deadline',
    'تاريخ البداية': 'Start date',
    'تاريخ النهاية': 'End date',
    'البداية': 'Start',
    'النهاية': 'End',
    'تكرار': 'Recurrence',
    'بدون تكرار': 'No recurrence',
    'قيد الانتظار': 'Pending',
    'قيد التنفيذ': 'In progress',
    'بانتظار المراجعة': 'Awaiting review',
    'مكتملة': 'Completed',
    'مرفوضة': 'Rejected',
    'مطلوب تعديلها': 'Changes requested',
    'متأخرة': 'Overdue',
    'متأخر': 'Overdue',
    'متوقفة بتبعية': 'Blocked by dependency',
    'كل الحالات': 'All statuses',
    'لفريق': 'Team task',
    'شخصية': 'Personal',
    'إسناد إلى موظف': 'Assign to employee',
    'طلب إسناد المهمة لموظف آخر': 'Request reassignment',
    'رفض طلب الإسناد': 'Reject reassignment request',
    'تأكيد استلام المهمة': 'Confirm task receipt',
    'استئناف العمل على المهمة': 'Resume work on task',
    'فتح المهمة كاملة': 'Open full task',
    'المهام السابقة': 'Predecessor tasks',
    'المهام السابقة المطلوبة': 'Required predecessor tasks',
    'المهمة الرئيسية': 'Parent task',
    'بدون مهمة رئيسية': 'No parent task',
    'الساعات المخططة': 'Planned hours',
    'الخطة الزمنية': 'Schedule',
    'المنجز مقابل المتأخر': 'Completed vs overdue',
    'مسار التنفيذ': 'Execution flow',
    'نبض الفريق': 'Team pulse',
    'توزيع عبء العمل': 'Workload distribution',
    'القادم': 'Upcoming',
    'نسبة إنجاز الفترة': 'Period completion rate',
    'وضع المتابعة · عرض فقط': 'Monitoring mode · View only',

    // Time and filters
    'اليوم': 'Today',
    'الأسبوع': 'Week',
    'الشهر': 'Month',
    'يومي': 'Daily',
    'أسبوعي': 'Weekly',
    'شهري': 'Monthly',
    'يوميًا': 'Daily',
    'أسبوعيًا': 'Weekly',
    'الفترة': 'Period',
    'الفترة الزمنية': 'Time range',
    'نوع التقرير': 'Report type',
    'تقرير يومي': 'Daily report',
    'تقرير أسبوعي': 'Weekly report',
    'تقرير شهري': 'Monthly report',
    'موظف محدد': 'Specific employee',
    'اختر الموظف': 'Select employee',
    'السابق': 'Previous',
    'التالي': 'Next',
    'الوقت المتبقي': 'Time remaining',
    'هذا الأسبوع': 'This week',
    'هذا الشهر': 'This month',
    'مستحقة اليوم': 'Due today',
    'القادمة': 'Upcoming',
    'الاثنين': 'Monday',
    'الثلاثاء': 'Tuesday',
    'الأربعاء': 'Wednesday',
    'الخميس': 'Thursday',
    'الجمعة': 'Friday',
    'السبت': 'Saturday',
    'الأحد': 'Sunday',
    'الأول': 'First',
    'الثاني': 'Second',
    'الثالث': 'Third',
    'الرابع': 'Fourth',
    'الأخير': 'Last',

    // Goals, criteria and planning
    'هدف': 'Goal',
    'هدف جديد': 'New goal',
    'تفاصيل الهدف': 'Goal details',
    'فتح الهدف وإدارة المعايير': 'Open goal and manage criteria',
    'المعايير': 'Criteria',
    'معايير': 'Criteria',
    'معيار': 'Criterion',
    'معيار جديد': 'New criterion',
    'المعيار': 'Criterion',
    'تفاصيل المعيار': 'Criterion details',
    'عنوان المعيار': 'Criterion title',
    'وصف المعيار': 'Criterion description',
    'حالة كل موظف': 'Status by employee',
    'الحالة العامة: ': 'Overall status: ',
    'تعليق على الهدف': 'Goal comment',
    'تعليقات': 'Comments',
    'التعليقات': 'Comments',
    'التعليقات السريعة': 'Quick comments',
    'لا توجد تعليقات بعد': 'No comments yet',
    'لا توجد معايير بعد': 'No criteria yet',
    'الخطة والتنفيذ': 'Plan and execution',
    'الخط الزمني': 'Timeline',
    'الجدول الزمني': 'Timeline',
    'عبء العمل': 'Workload',
    'المسار الحرج': 'Critical path',
    'ضمن المسار الحرج': 'On the critical path',
    'أسبوع العمل': 'Work week',

    // Polls
    'تصويت': 'Polls',
    'تصويت جديد': 'New poll',
    'تفاصيل التصويت': 'Poll details',
    'التصويتات السابقة': 'Past polls',
    'إلغاء التصويت': 'Cancel poll',
    'التصويت غير متاح': 'Voting unavailable',
    'اختيارات التصويت': 'Poll options',
    'الموظفون المشاركون': 'Participating employees',
    'الموظفون المشاركون في التصويت': 'Employees invited to vote',
    'إحصاءات المشاركة': 'Participation statistics',
    'حالة تصويت كل موظف': 'Voting status by employee',
    'التقرير النهائي للتصويت': 'Final poll report',
    'تفعيل خصوصية التصويت': 'Enable private voting',
    'تم تسجيل صوتك': 'Your vote was recorded',
    'انتهى التصويت': 'Poll closed',
    'حث الموظفين على التصويت': 'Remind employees to vote',
    'قرار المدير — تعادل في التصويت': 'Manager decision — tied poll',
    'اتخاذ القرار النهائي للتعادل': 'Set final tie-break decision',
    'لا توجد أصوات — لا يمكن تحديد نتيجة':
        'No votes — a result cannot be determined',
    'لا يوجد تقرير نهائي لهذا التصويت':
        'No final report is available for this poll',

    // Knowledge, forms, meetings and contacts
    'تفاصيل المعرفة': 'Knowledge details',
    'بيانات المعرفة': 'Knowledge information',
    'إنشاء صفحة معرفة': 'Create knowledge page',
    'إضافة إلى مركز المعرفة': 'Add to knowledge center',
    'سياسة أو إجراء أو دليل مكتوب داخل NeoTask':
        'A policy, procedure, or guide written in NeoTask',
    'المعرفة المرتبطة بالمهمة': 'Knowledge linked to this task',
    'مهمة مرتبطة بالوثيقة': 'Task linked to document',
    'النماذج والحقول المخصصة': 'Custom forms and fields',
    'نموذج جديد': 'New form',
    'تعديل النموذج': 'Edit form',
    'عنوان النموذج': 'Form title',
    'وصف وتعليمات النموذج': 'Form description and instructions',
    'بيانات النموذج الأساسية': 'Basic form information',
    'الحقول': 'Fields',
    'اسم الحقل': 'Field name',
    'نوع الحقل': 'Field type',
    'الردود': 'Responses',
    'لا توجد نماذج بعد': 'No forms yet',
    'هذا النموذج غير متاح أو تم إيقافه': 'This form is unavailable or inactive',
    'تم استلام ردك بنجاح': 'Your response was received successfully',
    'اجتماع جديد': 'New meeting',
    'محاضر الاجتماعات': 'Meeting minutes',
    'محضر الاجتماع': 'Meeting minutes',
    'المشاركون': 'Participants',
    'قرار جديد': 'New decision',
    'حذف الاجتماع': 'Delete meeting',
    'جهة اتصال جديدة': 'New contact',
    'الاسم': 'Name',
    'الهاتف': 'Phone',
    'البريد الإلكتروني': 'Email',
    'المسمى الوظيفي': 'Job title',
    'ملاحظات': 'Notes',

    // Automation and imports
    'قاعدة جديدة': 'New rule',
    'قواعد الأتمتة': 'Automation rules',
    'مساحة القواعد': 'Rules workspace',
    'سجل التنفيذ': 'Execution log',
    'مسار الأتمتة': 'Automation flow',
    'مسار القاعدة': 'Rule flow',
    'تفاصيل القاعدة': 'Rule details',
    'اسم القاعدة': 'Rule name',
    'عند حدوث': 'When this happens',
    'الشرط': 'Condition',
    'الإجراء': 'Action',
    'الحدث': 'Trigger',
    'المعامل': 'Operator',
    'كل العمليات': 'All runs',
    'ناجحة': 'Successful',
    'متعثرة': 'Failed',
    'نشطة': 'Active',
    'متوقفة': 'Paused',
    'آخر تنفيذ': 'Last run',
    'معدل النجاح': 'Success rate',
    'نوع البيانات': 'Data type',
    'معاينة الصفوف': 'Preview rows',
    'عناوين الصف الأول': 'First-row headers',
    'استيراد حقيقي مع فحص قبل الحفظ': 'Validated import before saving',
    'لن يُحفظ أي صف خاطئ أو مكرر، وسترى نتيجة كل صف أولًا':
        'Invalid or duplicate rows will not be saved, and every row is reviewed first',
    'تُقبل العناوين العربية أو الإنجليزية، والتاريخ بصيغة YYYY-MM-DD':
        'Arabic or English headers are accepted; dates must use YYYY-MM-DD',

    // Empty states and validation
    'لا توجد مهام': 'No tasks',
    'لا توجد مهام في هذه الفترة': 'No tasks in this period',
    'لا توجد مهام في هذا اليوم': 'No tasks on this day',
    'لا توجد مهام مجدولة اليوم': 'No tasks scheduled today',
    'لا توجد مهام ضمن هذا العرض': 'No tasks in this view',
    'لا توجد مهام بانتظار المراجعة حاليًا':
        'No tasks currently awaiting review',
    'لا توجد اجتماعات قادمة': 'No upcoming meetings',
    'لا توجد إشعارات': 'No notifications',
    'لا توجد نتائج مطابقة': 'No matching results',
    'لا توجد نتائج في مركز المعرفة': 'No results in the knowledge center',
    'لا توجد محادثات حتى الآن': 'No chats yet',
    'لا توجد رسائل بعد — ابدأ المحادثة':
        'No messages yet — start the conversation',
    'لا يوجد سجل بعد': 'No history yet',
    'لا يوجد موظفون نشطون': 'No active employees',
    'لا يوجد موظفون نشطون بعد': 'No active employees yet',
    'لا يوجد موظفون نشطون حاليًا': 'There are currently no active employees',
    'لا يوجد مدير مسجّل حاليًا': 'No manager is currently registered',
    'لا توجد تبعيات': 'No dependencies',
    'لا توجد مهام سابقة يمكن ربطها': 'No predecessor tasks are available',
    'لا توجد مهام لتصديرها في هذا النطاق': 'No tasks to export in this range',
    'لم يصل أي رد حتى الآن': 'No responses have been received yet',
    'المعيار غير موجود': 'Criterion not found',
    'الهدف غير موجود': 'Goal not found',
    'حقل مطلوب': 'Required field',
    'أدخل ساعات مخططة صحيحة': 'Enter valid planned hours',
    'أضف حقلًا واحدًا على الأقل': 'Add at least one field',
    'يجب إدخال اختيارين على الأقل': 'Enter at least two options',
    'يجب اختيار موظف واحد على الأقل': 'Select at least one employee',
    'موعد الإغلاق يجب أن يكون في المستقبل':
        'The closing time must be in the future',
    'موعد البدء يجب أن يكون قبل موعد الإغلاق':
        'The start time must be before the closing time',
    'تعذّرت قراءة الملف المحدَّد': 'The selected file could not be read',
    'حجم الصورة يجب ألا يتجاوز 5 ميجابايت': 'Image size must not exceed 5 MB',

    // Success and failure feedback
    'تم حفظ التعديلات بنجاح': 'Changes saved successfully',
    'تم حفظ الفكرة': 'Idea saved',
    'تم حفظ قاعدة الأتمتة': 'Automation rule saved',
    'تم إنشاء المهمة بنجاح': 'Task created successfully',
    'تم تعديل المهمة بنجاح': 'Task updated successfully',
    'تم حذف المهمة': 'Task deleted',
    'تم إرسال المهمة للمراجعة بنجاح': 'Task submitted for review',
    'تم إنشاء الهدف بنجاح': 'Goal created successfully',
    'تم تعديل الهدف بنجاح': 'Goal updated successfully',
    'تم حذف الهدف بنجاح': 'Goal deleted successfully',
    'تم إنشاء المعيار بنجاح': 'Criterion created successfully',
    'تم تعديل المعيار بنجاح': 'Criterion updated successfully',
    'تم حذف المعيار بنجاح': 'Criterion deleted successfully',
    'تم تغيير كلمة المرور بنجاح': 'Password changed successfully',
    'تم تحديث الصورة الشخصية': 'Profile photo updated',
    'تم تحديث قائمة الموظفين': 'Employee list updated',
    'تم تحديث السعة الأسبوعية': 'Weekly capacity updated',
    'تم تسجيل القرار النهائي': 'Final decision recorded',
    'تم إلغاء التصويت': 'Poll cancelled',
    'تم نسخ رابط الدعوة الفعّال': 'Active invitation link copied',
    'تم نسخ رابط النموذج': 'Form link copied',
    'تم إرسال طلب الإسناد إلى المدير':
        'Reassignment request sent to the manager',
    'تم تأكيد استلام المهمة، وهي الآن مهمتك':
        'Task receipt confirmed; it is now assigned to you',
    'تعذر حفظ التعديلات، حاول مجددًا': 'Could not save changes. Try again.',
    'تعذّر حفظ المتابعة، حاول مرة أخرى':
        'Could not save the follow-up. Try again.',
    'تعذّر إرسال الرد. حاول مرة أخرى': 'Could not send the reply. Try again.',
    'تعذر تحديث السعة الأسبوعية': 'Could not update weekly capacity',
    'تعذر حذف المعيار، حاول مجددًا':
        'Could not delete the criterion. Try again.',
    'تعذر حذف الهدف، حاول مجددًا': 'Could not delete the goal. Try again.',
    'تعذر حذف النموذج. حاول مرة أخرى.': 'Could not delete the form. Try again.',

    // Destructive confirmations
    'حذف': 'Delete',
    'حذف نهائي': 'Delete permanently',
    'حذف المهمة': 'Delete task',
    'حذف الهدف': 'Delete goal',
    'حذف المعيار': 'Delete criterion',
    'حذف النموذج': 'Delete form',
    'حذف النموذج بالكامل': 'Delete form permanently',
    'حذف النموذج بالكامل؟': 'Delete this form permanently?',
    'حذف قاعدة الأتمتة': 'Delete automation rule',
    'حذف القاعدة': 'Delete rule',
    'حذف الحساب': 'Delete account',
    'حذف حساب الموظف': 'Delete employee account',
    'حذف جهة الاتصال': 'Delete contact',
    'حذف الفكرة؟': 'Delete this idea?',
    'حذف كل المهام': 'Delete all tasks',
    'نعم، احذف النموذج': 'Yes, delete form',
    'إلغاء الحذف بالكامل': 'Cancel permanent deletion',
    'تأكيد الإلغاء': 'Confirm cancellation',
    'تأكيد الرفض': 'Confirm rejection',
    'تأكيد إزالة موظفين': 'Confirm employee removal',
    'تأكيد إلغاء التصويت': 'Confirm poll cancellation',

    // Miscellaneous
    'الكل': 'All',
    'الجميع': 'Everyone',
    'عضو': 'Member',
    'إجمالي': 'Total',
    'الإجمالي': 'Total',
    'نشط': 'Active',
    'مسودة': 'Draft',
    'منتهي': 'Closed',
    'ملغى': 'Cancelled',
    'خصوصية النتائج': 'Results privacy',
    'عدد الخيارات': 'Number of options',
    'إشعار أشخاص محددين': 'Notify selected people',
    'مكالمة صوتية واردة': 'Incoming voice call',
    'تشغيل الميكروفون': 'Unmute microphone',
    'كتم الصوت': 'Mute',
    'إنهاء المكالمة': 'End call',
    'PDF أو Word أو Excel أو صورة': 'PDF, Word, Excel, or image',
    'قريبًا': 'Coming soon',
    'حياك الله في ': 'Welcome to ',
    'الملف الشخصي': 'Profile',
    'لغة الواجهة': 'Interface language',
    'واجهة عربية واتجاه من اليمين إلى اليسار':
        'Arabic interface with right-to-left layout',
    'الإشعارات الصوتية': 'Sound notifications',
    'صوت الرسائل': 'Message sound',
    'تشغيل صوت عند استلام رسالة جديدة':
        'Play a sound when a new message arrives',
    'صوت المهام': 'Task sound',
    'تشغيل صوت عند إسناد أو تحديث مهمة':
        'Play a sound when a task is assigned or updated',
    'التذكيرات': 'Reminders',
    'تذكيرات المهام': 'Task reminders',
    'تلقّي تذكير عند اقتراب الاستحقاق أو تأخر المهمة':
        'Receive a reminder when a task is due soon or becomes overdue',
    'الحساب': 'Account',
    'جارٍ رفع الصورة...': 'Uploading photo…',
    'إضافة صورة شخصية': 'Add profile photo',
    'تغيير الصورة الشخصية': 'Change profile photo',
    'أدخل كلمة المرور الحالية': 'Enter your current password',
    'أدخل كلمة المرور الجديدة': 'Enter a new password',
    'يجب أن تكون 6 أحرف على الأقل': 'Use at least 6 characters',
    'أعد كتابة كلمة المرور الجديدة': 'Re-enter the new password',
    'كلمتا المرور غير متطابقتين': 'Passwords do not match',
    'مفتاح التأسيس غير صحيح': 'Incorrect setup key',
    'أدخل الاسم': 'Enter the name',
    'الرقم السري 6 أحرف على الأقل':
        'Password must contain at least 6 characters',
    'الرقمان السريان لا يتطابقان': 'Passwords do not match',
    'هذا الحقل مطلوب': 'This field is required',
    'يجب تأكيد هذا الحقل': 'This field must be confirmed',
    'أدخل عنوان المهمة': 'Enter the task title',
    'عنوان المهمة مطلوب': 'Task title is required',
    'أدخل عدد ساعات صحيحًا': 'Enter a valid number of hours',
    'اكتب اسم الحقل': 'Enter the field name',
    'أدخل خيارين على الأقل': 'Enter at least two options',
    'أدخل العنوان': 'Enter the title',
    'أدخل عنوان التصويت': 'Enter the poll title',
    'أدخل عنوان الهدف': 'Enter the goal title',
    'أدخل عنوان المعيار': 'Enter the criterion title',
    'يرجى إدخال كلمة المرور الجديدة': 'Enter the new password',
    'يجب أن تتكون كلمة المرور من 6 أحرف على الأقل':
        'Password must contain at least 6 characters',
    'يرجى تأكيد كلمة المرور': 'Confirm the password',
    'اختر الحالة': 'Select a status',
    'اختر الأولوية': 'Select a priority',
    'عالية': 'High',
    'متوسطة': 'Medium',
    'منخفضة': 'Low',
    'مُسندة': 'Assigned',
    'لم يبدأ': 'Not started',
    'مكتمل': 'Complete',
    'مطلوب تعديل': 'Changes requested',
    'قيد المراجعة': 'In review',
    'تعديل مطلوب': 'Changes requested',
    'تحت المراجعة': 'In review',
    'معتمد': 'Approved',
    'مؤرشف': 'Archived',
    'صفحة معرفة': 'Knowledge page',
    'سياسة': 'Policy',
    'إجراء تشغيلي': 'Operating procedure',
    'دليل': 'Guide',
    'عام': 'General',
    'نعم': 'Yes',
    'لا': 'No',
    'أول': 'First',
    'ثاني': 'Second',
    'ثالث': 'Third',
    'رابع': 'Fourth',
    'آخر': 'Last',
    'اثنين': 'Monday',
    'ثلاثاء': 'Tuesday',
    'أربعاء': 'Wednesday',
    'خميس': 'Thursday',
    'جمعة': 'Friday',
    'سبت': 'Saturday',
    'أحد': 'Sunday',
    'كحلي': 'Navy',
    'نعناعي': 'Mint',
    'ذهبي': 'Gold',
    'بنفسجي': 'Purple',
    'تركواز': 'Teal',
    'علم': 'Flag',
    'نجمة': 'Star',
    'كأس': 'Trophy',
    'صاروخ': 'Rocket',
    'فكرة': 'Idea',
    'تم إنشاء حساب المدير بالفعل من جهاز آخر':
        'A manager account has already been created from another device',
    'تعذّر إنشاء الحساب، حاول مرة أخرى':
        'Could not create the account. Try again.',
    'الحساب غير مكتمل، يرجى التواصل مع المدير':
        'The account setup is incomplete. Contact the manager.',
    'تم رفض طلب انضمامك من قِبل المدير':
        'Your join request was rejected by the manager',
    'هذا الحساب تم حذفه من قِبل المدير':
        'This account was deleted by the manager',
    'جلسة الدخول منتهية، يرجى تسجيل الدخول مرة أخرى':
        'Your session has expired. Sign in again.',
    'ليس لديك صلاحية تغيير كلمات مرور الموظفين':
        'You do not have permission to change employee passwords',
    'خدمة تغيير كلمة المرور غير متاحة حاليًا (لم يتم نشرها بعد)':
        'The password-change service is currently unavailable',
    'كلمة المرور الجديدة غير صالحة (6 أحرف على الأقل)':
        'The new password is invalid (minimum 6 characters)',
    'تعذّر الاتصال بخدمة تغيير كلمة المرور، حاول لاحقًا':
        'Could not reach the password-change service. Try again later.',
    'الرقم الوظيفي غير صالح': 'Invalid employee ID',
    'هذا الحساب معطّل': 'This account is disabled',
    'الرقم الوظيفي غير مسجّل': 'Employee ID is not registered',
    'الرقم السري غير صحيح': 'Incorrect password',
    'هذا الرقم الوظيفي مسجّل بالفعل': 'This employee ID is already registered',
    'الرقم السري ضعيف جدًا — يجب أن يكون 6 أحرف على الأقل':
        'Password is too weak — use at least 6 characters',
    'محاولات كثيرة جدًا، يرجى الانتظار قليلًا ثم المحاولة مرة أخرى':
        'Too many attempts. Wait briefly, then try again.',
    'تعذّر الاتصال بالخادم، تحقّق من اتصال الإنترنت':
        'Could not connect to the server. Check your internet connection.',

    // Workspace refresh + Manager AI
    'مساعد المدير الذكي': 'Manager AI Assistant',
    'يحلل الطلب ويعرض الإجراء قبل التنفيذ':
        'Analyzes requests and previews actions before execution',
    'جارٍ الفحص': 'Checking',
    'جاهز': 'Ready',
    'غير متصل': 'Offline',
    'بانتظار اعتماد المدير': 'Awaiting manager approval',
    'موظف غير محدد': 'Employee not specified',
    'أولوية مرتفعة': 'High priority',
    'أولوية متوسطة': 'Medium priority',
    'أولوية منخفضة': 'Low priority',
    'جارٍ الاعتماد': 'Approving…',
    'سجل عمليات المساعد': 'Assistant activity log',
    'دليل لما حفظه أو أنشأه الوكيل فعليًا':
        'Evidence of what the agent actually saved or created',
    'تعذر تحميل سجل عمليات المساعد':
        'Could not load the assistant activity log',
    'لا توجد إجراءات محفوظة': 'No saved actions',
    'لا توجد عمليات في هذا التصنيف': 'No actions in this category',
    'قواعد المدير': 'Manager rules',
    'المبادرات': 'Initiatives',
    'التحليلات': 'Analyses',
    'مبادرة منشأة': 'Created initiative',
    'مهمة منشأة': 'Created task',
    'قاعدة مدير': 'Manager rule',
    'تحليل محفوظ': 'Saved analysis',
    'سجل عام': 'General record',
    'خيارات حذف القاعدة والسجل': 'Rule and record deletion options',
    'حذف سجل العملية': 'Delete activity record',
    'جارٍ التحقق': 'Verifying',
    'المهمة محذوفة': 'Task deleted',
    'غير محدد': 'Not specified',
    'فتح المهمة': 'Open task',
    'فتح المهمة وتعديلها': 'Open and edit task',
    'جارٍ التحقق من المهمة': 'Verifying task',
    'المهمة غير موجودة': 'Task not found',
    'جارٍ التحقق من القاعدة': 'Verifying rule',
    'قاعدة فعّالة': 'Active rule',
    'القاعدة غير فعّالة': 'Rule inactive',
    'سجل قديم غير مرتبط': 'Unlinked legacy record',
    'هذه القاعدة تؤثر على طلبات الوكيل القادمة.':
        'This rule affects future agent requests.',
    'حذف هذا السجل القديم لا يضمن إيقاف القاعدة.':
        'Deleting this legacy record does not guarantee the rule is disabled.',
    'اكتب طلبك لمساعد المدير...': 'Ask the Manager AI Assistant…',
    'وضع العرض فقط': 'View-only mode',
    'إضافة للمفضلة': 'Add to favorites',
    'إزالة من المفضلة': 'Remove from favorites',
    'إجمالي المفضلة': 'Total favorites',
    'استخدم النجمة في أي مهمة لتضيفها إلى مساحة التركيز السريع.':
        'Use the star on any task to add it to your quick-focus workspace.',
    'المهام التي اخترت الرجوع إليها بسرعة': 'Tasks you chose for quick access',
    'إجمالي جهات الاتصال': 'Total contacts',
    'لديهم رقم هاتف': 'With phone number',
    'لديهم بريد إلكتروني': 'With email',
    'دليل جهات الاتصال': 'Contact directory',
    'ابحث واتصل بالجهات الداخلية والخارجية من مكان واحد':
        'Search and call internal and external contacts from one place',
    'ابحث بالاسم أو المسمى أو رقم الهاتف':
        'Search by name, job title, or phone number',
    'مسح البحث': 'Clear search',
    'أضف جهات الاتصال المهمة لفريقك لتكون متاحة من مكان واحد.':
        'Add important team contacts so they are available in one place.',
    'جرّب اسمًا أو رقمًا مختلفًا.': 'Try a different name or number.',
    'اتصال': 'Call',
    'تغلق خلال 24 ساعة': 'Closing within 24 hours',
    'تصويتاتي': 'My polls',
    'الموضوعات النشطة والسابقة في مكان واحد':
        'Active and past poll topics in one place',
    'ستظهر هنا موضوعات التصويت التي تحتاج مشاركتك أو نتائجها بعد الإغلاق.':
        'Polls that need your participation, or their results after closing, will appear here.',
    'نتيجة محسومة': 'Resolved result',
    'تعادل': 'Tie',
    'أرشيف القرارات': 'Decision archive',
    'السجل الدائم للتصويتات المنتهية ونتائجها':
        'Permanent archive of closed polls and their results',
    'عند إغلاق أي تصويت سيبقى سجله ونتيجته هنا للرجوع إليه.':
        'When a poll closes, its record and result remain here for reference.',
    'غير مرئي للموظفين': 'Hidden from employees',
    'أُلغي': 'Cancelled',
    'أُغلق': 'Closed',
    'ينتهي الآن...': 'Closing now…',
    'يتبقى': 'Remaining',
    'يوم': 'day',
    'ساعة': 'hour',
    'دقيقة': 'minute',
    'ثانية': 'second',
    'منتهي - تعادل': 'Closed — tie',
    'ابحث في NeoTask': 'Search NeoTask',
    'اكتب اسم موظف أو رقمًا وظيفيًا أو عنوان هدف أو معيار أو مهمة.':
        'Enter an employee name or ID, or a goal, criterion, or task title.',
    'جرّب كلمة أقصر أو اسمًا أو رقمًا مختلفًا.':
        'Try a shorter keyword, name, or number.',
    'رقم وظيفي': 'Employee ID',
    // Workspace refresh phase 2
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

    // Workspace refresh phase 3
    'سيظهر التقرير هنا بعد إغلاق التصويت وحساب النتيجة.':
        'The report will appear here after voting closes and the result is calculated.',
    'توزيع الأصوات ونسب كل اختيار':
        'Vote distribution and percentage by option',
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
    'ابدأ المحادثة بإرسال أول رسالة.':
        'Start the conversation by sending the first message.',
    'مدير القسم': 'Department manager',
    'متابعة · عرض فقط': 'Monitoring · View only',

    // Criterion workspace refresh
    'بيانات المعيار': 'Criterion information',
    'عرّف المعيار بوضوح قبل توزيعه على فريق التنفيذ':
        'Define the criterion clearly before assigning it to the delivery team',
    'فريق التنفيذ': 'Delivery team',
    'أضف موظفين من تبويب الموظفين ثم عُد لإسناد المعيار.':
        'Add employees from the Employees tab, then return to assign the criterion.',
    'حدد بيانات المعيار وفريق التنفيذ ثم احفظه لبدء المتابعة.':
        'Complete the criterion information and delivery team, then save to begin tracking.',
    'تعذر حفظ المعيار، حاول مجددًا': 'Could not save the criterion. Try again.',

    // Meetings + import workspace refresh
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
    'الاسم | الرقم الوظيفي | كلمة المرور': 'Name | Employee ID | Password',
    'عنوان المهمة | الرقم الوظيفي | تاريخ الاستحقاق | الوصف | تاريخ البداية | الساعات | الأولوية | التصنيف':
        'Task title | Employee ID | Due date | Description | Start date | Hours | Priority | Category',
    'صف بلا عنوان': 'Untitled row',
    'صالح للاستيراد': 'Ready to import',
    'تعذّر قراءة الملف': 'Could not read the file',
    'صيغة الملف غير صالحة أو الملف تالف':
        'The file format is invalid or the file is corrupted',
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

    // Meetings + import workspace refresh
    'الملف': 'File',

    // Extended screen copy
    'إنشاء': 'Create',
    'أيقونة الهدف': 'Goal icon',
    'لون الهدف': 'Goal color',
    'إجراءات المدير': 'Manager actions',
    'إسناد المهمة إلى:': 'Assign task to:',
    'ابحث عن معيار، هدف، موظف، أو أعمال موظف':
        'Search for a criterion, goal, employee, or employee work',
    'اجمع الطلبات والبيانات برابط مباشر':
        'Collect requests and data through a direct link',
    'أنشئ حقولك، فعّل النموذج، ثم تابع الردود من نفس المكان':
        'Create fields, activate the form, and manage responses in one place',
    'أنشئ سياسة أو إجراء أو ارفع ملفًا':
        'Create a policy or procedure, or upload a file',
    'أضف مهمة وحدد البداية والنهاية لتظهر هنا تلقائيًا.':
        'Add a task and set its start and end dates to place it here automatically.',
    'اختر الحالة الجديدة للمهمة:': 'Select the task’s new status:',
    'اختر موظفًا مسؤولًا أو أسند المهمة لكل أعضاء الفريق النشطين. تبقى التفاصيل والتعليقات محفوظة.':
        'Select an owner or assign the task to all active team members. Details and comments remain saved.',
    'اكتب فكرتك': 'Write your idea',
    'الأفكار المسجلة': 'Saved ideas',
    'بانتظار التنفيذ': 'Awaiting implementation',
    'مساحة أفكار المدير': 'Manager ideas workspace',
    'سجّل أي تطوير أو ملاحظة لتبقى محفوظة للمراجعة والتنفيذ':
        'Record any improvement or note so it remains available for review and implementation',
    'الخطة جاهزة لاستقبال أول مهمة': 'The plan is ready for its first task',
    'الموظفون المشاركون في هذا المعيار':
        'Employees participating in this criterion',
    'انتهى التصويت بتعادل. اختر القرار النهائي:':
        'The poll ended in a tie. Select the final decision:',
    'انتهى موعد التصويت — جارٍ إغلاق التصويت وحساب النتيجة...':
        'Voting has ended — closing the poll and calculating the result…',
    'تأكيد تغيير الاختيارات': 'Confirm option changes',
    'تحدد مدة المهمة وترابطها وعبء العمل على الموظف':
        'Defines task duration, dependencies, and employee workload',
    'تعادل بين: ': 'Tie between: ',
    'تعليق جديد': 'New comment',
    'تغيير كلمة مرور حسابك الحالي': 'Change your current account password',
    'تم إرسال المهمة وهي الآن بانتظار مراجعة المدير.':
        'The task was submitted and is now awaiting manager review.',
    'تم إرسال طلب إسناد هذه المهمة لموظف آخر، وهو بانتظار موافقة المدير. يمكنك الاستمرار بالعمل عليها حتى الرد.':
        'A reassignment request was sent and is awaiting manager approval. You can continue working until a decision is made.',
    'تم إلغاء هذا التصويت من قِبل المدير':
        'This poll was cancelled by the manager',
    'تم إنشاء نسخة متوقفة من القاعدة': 'A paused copy of the rule was created',
    'تم إنشاء هذا التقرير بواسطة المدير عبر منصة':
        'This report was generated by the manager through',
    'تم تحويل القرار إلى مهمة وإسنادها':
        'The decision was converted into a task and assigned',
    'تم حذف قاعدة الأتمتة': 'Automation rule deleted',
    'تمت الموافقة على هذه المهمة من قِبل المدير. أحسنت!':
        'The manager approved this task. Well done!',
    'توليد رابط دعوة موظف جديد': 'Generate a new employee invitation link',
    'جارٍ حذف النموذج وردوده…': 'Deleting the form and its responses…',
    'خيارات القرار': 'Decision options',
    'رابط استخدام واحد فقط: يصبح غير صالح تلقائيًا بمجرد تسجيل أول موظف من خلاله. لا ينتهي بمرور الوقت.':
        'Single-use link: it becomes invalid as soon as one employee registers. It does not expire over time.',
    'سجّل القرارات وحوّلها إلى مهام قابلة للمتابعة':
        'Record decisions and convert them into trackable tasks',
    'سيتم حذفها نهائيًا من قائمة أفكار المدير':
        'It will be permanently removed from the manager ideas list',
    'سيتم رفض الطلب وتبقى المهمة كاملة عند الموظف الحالي. هل تريد الاستمرار؟':
        'The request will be rejected and the task will remain with the current employee. Continue?',
    'سيُرسل هذا الطلب إلى المدير للموافقة. ستستمر في العمل على المهمة كالمعتاد لحين رده.':
        'This request will be sent to the manager for approval. Continue working normally until a decision is made.',
    'صوتك الحالي: ': 'Your current vote: ',
    'طلبات إسناد المهام': 'Task reassignment requests',
    'عرض التقرير فقط': 'View report only',
    'عرض فقط: المدير ينشئ الرابط من هنا ثم يرسله للموظف، وبعد التسجيل يوافق على طلب الانضمام.':
        'View only: the manager creates the link here, sends it to the employee, then approves the join request after registration.',
    'لا توجد أحداث مستوردة بعد': 'No imported events yet',
    'لا توجد تصويتات سابقة بعد': 'No past polls yet',
    'لا توجد تصويتات موجّهة إليك حاليًا':
        'There are currently no polls assigned to you',
    'لا توجد جهات اتصال': 'No contacts',
    'لا توجد معايير بعد لهذا الهدف': 'No criteria have been added to this goal',
    'لا توجد مهام مرتبطة': 'No linked tasks',
    'لا توجد مهام مفضّلة حتى الآن': 'No favorite tasks yet',
    'لا يمكن إنشاء التصويت بدون تحديد موعد إغلاق':
        'A poll cannot be created without a closing time',
    'لا يمكن اختيارها: ستنشئ مسارًا دائريًا':
        'Cannot select this item because it would create a circular dependency',
    'لا يمكن تكرار نفس الاختيار مرتين': 'The same option cannot be repeated',
    'لا يوجد': 'None',
    'لا يوجد موظف مطابق لعملية البحث.': 'No employee matches the search.',
    'لا يوجد موظفون مُسندون لهذا المعيار بعد':
        'No employees have been assigned to this criterion yet',
    'لا يوجد موظفون نشطون آخرون لإسناد المهمة إليهم':
        'There are no other active employees available for assignment',
    'لا يوجد موظفون نشطون آخرون لتحويل المهمة إليهم':
        'There are no other active employees available for reassignment',
    'لا يوجد موظفون نشطون آخرون لنقل المهام إليهم، لذا الخيار المتاح هو الحذف فقط.':
        'There are no other active employees to receive these tasks, so deletion is the only available option.',
    'لا يوجد موظفون نشطون بعد.': 'No active employees yet.',
    'لم تُسجل قرارات بعد': 'No decisions have been recorded yet',
    'لم يُضف جدول أعمال': 'No agenda has been added',
    'لن يستطيع الموظف بدء هذه المهمة قبل اعتماد جميع المهام السابقة':
        'The employee cannot start this task until all predecessor tasks are approved',
    'مسار المعايير': 'Criteria flow',
    'مصير مهام الموظف': 'Employee task disposition',
    'ملخص هذا الأسبوع': 'This week’s summary',
    'من الاجتماع إلى التنفيذ': 'From meeting to execution',
    'منشئ القاعدة': 'Rule creator',
    'مهام بانتظار المراجعة': 'Tasks awaiting review',
    'مهام بانتظار تأكيد استلامك': 'Tasks awaiting your receipt confirmation',
    'مهمة شخصية جديدة': 'New personal task',
    'موعد البدء': 'Start time',
    'نتائج كل اختيار': 'Results by option',
    'نتيجة التصويت سرّية ولن تظهر إلا بعد إغلاق التصويت':
        'Poll results are private and will appear only after the poll closes',
    'نسبة الإنجاز في الوقت المحدد': 'On-time completion rate',
    'نعم، حذف الأصوات والمتابعة': 'Yes, delete votes and follow-up data',
    'نقل المهام': 'Transfer tasks',
    'نقل جميع المهام إلى:': 'Transfer all tasks to:',
    'هل أنت متأكد من حذف هذه المهمة؟ هذا الإجراء لا يمكن التراجع عنه':
        'Delete this task? This action cannot be undone.',
    'وافق المدير على إسناد هذه المهمة لموظف آخر، وهي الآن بانتظار تأكيده. المهمة لا تزال معك حتى يتم التأكيد.':
        'The manager approved reassignment to another employee. The task remains with you until the new assignee confirms receipt.',
    'يجب إدخال اختيارين على الأقل بنص غير فارغ':
        'Enter at least two non-empty options',
    'يجب إدخال سبب أو ملاحظة عند الرفض أو طلب التعديل':
        'Enter a reason or note when rejecting or requesting changes',
    'يجب تحديد موعد إغلاق التصويت': 'Set the poll closing time',
    'يجب تحديد موعد إغلاق التصويت — لا يمكن الحفظ بدونه':
        'Set the poll closing time — the poll cannot be saved without it',
    'يجب توفر اختيارين على الأقل': 'At least two options are required',
    'يرجى اختيار الموظف المسؤول عن المهمة':
        'Select the employee responsible for the task',
    'يرجى اختيار موظف واحد على الأقل للمشاركة بالتصويت':
        'Select at least one employee to participate in the poll',
    'يرجى اختيار موظف واحد على الأقل للمعيار':
        'Select at least one employee for the criterion',
    'يمكن اختيار أكثر من موظف واحد': 'You may select more than one employee',
    'يمكنك تعديل عنوان النموذج ووصفه، ثم إدارة الحقول أدناه.':
        'You can edit the form title and description, then manage its fields below.',
    'أضف أي تفاصيل تريد إطلاع المدير عليها...':
        'Add any details you want the manager to review…',
    'ابحث عن معيار، هدف، موظف، أو أعمال موظف...':
        'Search for a criterion, goal, employee, or employee work…',
    'ابحث في العنوان والمحتوى والوسوم': 'Search title, content, and tags',
    'اتصال صوتي': 'Voice call',
    'اسم الموظف المتوقع (اختياري)': 'Expected employee name (optional)',
    'اكتب السبب أو الملاحظة هنا...': 'Enter the reason or note here…',
    'اكتب النقاشات والنتائج الأساسية':
        'Record the main discussion and outcomes',
    'اكتب تعليقًا سريعًا...': 'Write a quick comment…',
    'اكتب تعليقًا...': 'Write a comment…',
    'اكتب رسالة...': 'Write a message…',
    'التعليق *': 'Comment *',
    'الخيارات — خيار في كل سطر': 'Options — one per line',
    'العنوان': 'Title',
    'العنوان *': 'Title *',
    'الغرض من الاجتماع': 'Meeting purpose',
    'الفترة التالية': 'Next period',
    'الفترة السابقة': 'Previous period',
    'الفقرة أو النص المقصود (اختياري)':
        'Referenced paragraph or text (optional)',
    'القسم': 'Department',
    'المحتوى': 'Content',
    'المكان أو رابط الاتصال': 'Location or meeting link',
    'الملاحظة المطلوبة *': 'Required note *',
    'الملخص': 'Summary',
    'الوسوم مفصولة بفاصلة': 'Comma-separated tags',
    'الوصف': 'Description',
    'الوصف (اختياري)': 'Description (optional)',
    'بحث عن موظف بالاسم أو الرقم الوظيفي...': 'Search by employee name or ID…',
    'بحث عن موظف...': 'Search for an employee…',
    'تأكيح الرقم السري': 'Confirm password',
    'تأكيد كلمة المرور': 'Confirm password',
    'تأكيد كلمة المرور الجديدة': 'Confirm new password',
    'تعديل الخطة': 'Edit plan',
    'تعديل السعة الأسبوعية': 'Edit weekly capacity',
    'تعديل القاعدة': 'Edit rule',
    'تعديل وإصدار جديد': 'Edit and create new version',
    'تعليم الكل كمقروء': 'Mark all as read',
    'جدول الأعمال — بند في كل سطر': 'Agenda — one item per line',
    'جودة، JCI، صيدلية': 'Quality, JCI, Pharmacy',
    'حذف الفكرة': 'Delete idea',
    'رابط ICS / Webcal': 'ICS / Webcal link',
    'ساعات العمل المتاحة أسبوعيًا': 'Available work hours per week',
    'شعار NeoTask': 'NeoTask logo',
    'عرض التقرير النهائي': 'View final report',
    'عرض محادثة المهمة': 'Open task chat',
    'عنوان / الفكرة المطروحة للتصويت': 'Poll title / proposal',
    'عنوان الاجتماع *': 'Meeting title *',
    'عنوان المهمة': 'Task title',
    'عنوان الهدف': 'Goal title',
    'كلمة المرور الجديدة': 'New password',
    'كلمة المرور الحالية': 'Current password',
    'مثال: 20 للدوام الجزئي، 40 للدوام الكامل':
        'Example: 20 for part-time, 40 for full-time',
    'مثال: إضافة تقرير مختصر للمهام المتأخرة...':
        'Example: Add a brief overdue-task report…',
    'ملاحظة (اختياري)': 'Note (optional)',
    'ملخص التغيير': 'Change summary',
    'ملخص قصير': 'Short summary',
    'نص التنبيه': 'Alert text',
    'نص القرار *': 'Decision text *',
    'وصف المعيار (اختياري)': 'Criterion description (optional)',
    'وصف المهمة': 'Task description',
    'وصف تفصيلي (اختياري)': 'Detailed description (optional)',
    'الموظف': 'Employee',
    'الاستحقاق': 'Due date',
    'بتاريخ': 'on',
    'اختر موظفًا': 'Select an employee',
    'تعديل التصويت': 'Edit poll',
    'تعديل المعيار': 'Edit criterion',
    'تعديل المهمة': 'Edit task',
    'تعديل الهدف': 'Edit goal',
    'ألصق رابط الاشتراك (.ics) من تطبيق تقويم الآيفون. تتم المزامنة تلقائيًا عند فتح الصفحة، بالإضافة لإمكانية المزامنة اليدوية. الاتجاه: من تقويم الآيفون إلى هذا التطبيق فقط.':
        'Paste the subscription (.ics) link from the iPhone Calendar app. It syncs automatically when this page opens, and you can also sync manually. Sync direction is from iPhone Calendar to NeoTask only.',
    'أدخل كلمة مرور جديدة لهذا الموظف. لن تُعرض كلمة المرور أو تُخزَّن في أي مكان بعد إنشائها.':
        'Enter a new password for this employee. The password will not be displayed or stored after it is created.',
    'إزالة موظف لا تؤثر على حالة باقي الموظفين المُسندين مسبقًا.':
        'Removing an employee does not change the status of other previously assigned employees.',
    'إمّا أن هذا الرابط قد استُخدم مسبقًا من قِبل موظف آخر، أو أنه غير صحيح.\nيرجى التواصل مع المدير للحصول على رابط دعوة جديد.':
        'This link has already been used by another employee or is invalid.\nContact the manager for a new invitation link.',
    'عند التفعيل: لا يمكن معرفة اختيار موظف معيّن — فقط حالة التصويت/عدم التصويت':
        'When enabled, individual choices are hidden; only whether each employee voted is shown.',
    'لا يوجد حساب مدير مُفعّل بعد. بصفتك أول مستخدم، أدخل بياناتك لإنشاء حساب المدير.':
        'No active manager account exists. As the first user, enter your details to create the manager account.',
    'لا يوجد موظفون نشطون بعد. أضف موظفين أولًا من تبويب "الموظفون".':
        'There are no active employees yet. Add employees from the Employees tab first.',
    'يوجد أصوات مسجّلة حاليًا على هذا التصويت. تغيير الاختيارات سيؤدي إلى حذف جميع الأصوات الحالية بشكل نهائي. هل تريد المتابعة؟':
        'This poll already has recorded votes. Changing the options will permanently delete all current votes. Continue?',
    'آخر تحديث': 'Last updated',
    'أجندة الأيام': 'Daily agenda',
    'أعيدت الوثيقة للتعديل': 'Document returned for changes',
    'أهداف': 'Goals',
    'إجراء': 'Action',
    'إجمالي الأهداف': 'Total goals',
    'إجمالي التصويتات': 'Total polls',
    'إجمالي القواعد': 'Total rules',
    'إجمالي المستحقّين': 'Total eligible voters',
    'إجمالي المعايير': 'Total criteria',
    'إسناد المهمة إلى أحد الموظفين': 'Assign the task to an employee',
    'إعادة الإسناد إلى': 'Reassign to',
    'اختر موضوعًا لعرض مسار القرار': 'Select a topic to view its decision flow',
    'اختر هدفًا لاستعراض تقدمه ومعاييره':
        'Select a goal to review its progress and criteria',
    'اختر يومًا لعرض مهامه': 'Select a day to view its tasks',
    'اعتمد بواسطة': 'Approved by',
    'الأولوية الجديدة': 'New priority',
    'البحث': 'Search',
    'التحديثات': 'Updates',
    'التعليقات والمنشن': 'Comments & mentions',
    'التقدم الموزون': 'Weighted progress',
    'التكرار': 'Recurrence',
    'الحالة الجديدة': 'New status',
    'الخصوصية': 'Privacy',
    'الخصوصية كانت مفعّلة عند إجراء التصويت':
        'Privacy was enabled while voting',
    'السابقة والمحاضر': 'History & minutes',
    'العرض': 'View',
    'الفريق كاملًا': 'Entire team',
    'القرارات والإجراءات': 'Decisions & actions',
    'المالك': 'Owner',
    'المتوقفة': 'Paused',
    'المحضر': 'Minutes',
    'المدة': 'Duration',
    'المدير المُنشئ': 'Created by manager',
    'المراجعة القادمة': 'Next review',
    'المقياس': 'Scale',
    'المكتملة': 'Completed',
    'الملف المرفق': 'Attached file',
    'المهام المرتبطة': 'Linked tasks',
    'المهمة الرئيسية (اختياري)': 'Parent task (optional)',
    'الموظف البديل': 'Replacement employee',
    'الموظف الجديد': 'New employee',
    'الموظف المسؤول': 'Responsible employee',
    'النشطة': 'Active',
    'النوع': 'Type',
    'الوقت': 'Time',
    'اليوم متاح': 'The day is available',
    'بداية التصويت': 'Poll start',
    'بيانات الوثيقة': 'Document information',
    'تاريخ الإرسال': 'Submission date',
    'تاريخ الانتهاء': 'End date',
    'تاريخ البدء': 'Start date',
    'تحتاج مراجعة': 'Needs review',
    'تصفية الأهداف': 'Filter goals',
    'تفاصيل اليوم': 'Day details',
    'تم اعتماد الوثيقة': 'Document approved',
    'تم التنفيذ': 'Executed',
    'جدول الأعمال': 'Agenda',
    'حالة التصويت': 'Poll status',
    'حالة الحفظ': 'Save status',
    'حالة المهمة': 'Task status',
    'حفظ كمسودة': 'Save as draft',
    'ذُكرت في تعليق': 'You were mentioned in a comment',
    'سجل الإصدارات': 'Version history',
    'شرط': 'Condition',
    'شهريًا - نمط يوم أسبوعي': 'Monthly — weekday pattern',
    'شهريًا - يوم ثابت من الشهر': 'Monthly — fixed day of month',
    'صوّتوا': 'Voted',
    'عرض الاجتماعات': 'Meeting view',
    'عرض المهام': 'Task view',
    'عمليات متعثرة': 'Failed runs',
    'عمليات ناجحة': 'Successful runs',
    'قائمة التركيز': 'Focus list',
    'قبل الاستحقاق بـ': 'Before due time by',
    'كل القواعد': 'All rules',
    'لا توجد أهداف ضمن هذا العرض': 'No goals in this view',
    'لا توجد تصويتات ضمن هذا العرض': 'No polls in this view',
    'لا توجد عمليات ضمن هذا العرض': 'No runs in this view',
    'لا توجد قواعد ضمن هذا العرض': 'No rules in this view',
    'للمراجعة': 'For review',
    'لم يصوّتوا': 'Not voted',
    'مثال: آخر خميس من كل شهر': 'Example: the last Thursday of every month',
    'محادثة': 'Chat',
    'محادثة عامة': 'General chat',
    'محادثة مهمة': 'Task chat',
    'محفظة الأهداف': 'Goal portfolio',
    'مدعوون للتصويت': 'Invited to vote',
    'مرات التنفيذ': 'Run count',
    'مراجعة قريبة': 'Review due soon',
    'مركز القرار جاهز': 'Decision center is ready',
    'مساحة الأتمتة جاهزة لأول قاعدة':
        'Automation workspace is ready for its first rule',
    'مساحة الأهداف جاهزة': 'Goals workspace is ready',
    'مساحة التركيز جاهزة': 'Focus workspace is ready',
    'مسودات': 'Drafts',
    'مشغّل': 'Trigger',
    'معتمدة': 'Approved',
    'ملاحظة المدير': 'Manager note',
    'ملاحظة الموظف': 'Employee note',
    'منتهية': 'Closed',
    'مهام': 'Tasks',
    'مهام الخطة': 'Planned tasks',
    'مهام اليوم': 'Today’s tasks',
    'مهام نشطة': 'Active tasks',
    'مهامك الخاصة مرتبة حسب الاستحقاق':
        'Your personal tasks ordered by due date',
    'مهمة خاصة بالمدير': 'Private manager task',
    'موضوعات التصويت': 'Poll topics',
    'موظفون': 'Employees',
    'موعد الإغلاق': 'Closing time',
    'موعد الاستحقاق': 'Due date',
    'موعد الانتهاء': 'End time',
    'نسبة المشاركة': 'Participation rate',
    'نشر الآن': 'Publish now',
    'نطاق الإسناد': 'Assignment scope',
    'نطاق العرض': 'View range',
    'نفّذ الإجراء': 'Run action',
    'نوع المعرفة': 'Knowledge type',
    'نوع المهمة': 'Task type',
    'نُفذت اليوم': 'Run today',
    'وثيقة بانتظار المراجعة': 'Document awaiting review',
    'وقت إنشاء التقرير': 'Report generated at',
    'يصبح التصويت نشطًا فورًا': 'The poll becomes active immediately',
    'يوم الشهر (1-31)': 'Day of month (1–31)',
  };
}
