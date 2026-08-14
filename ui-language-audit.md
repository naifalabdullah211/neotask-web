# NeoTask UI + Language Audit

Automated static audit of `lib/screens` and `lib/widgets`, including runtime-composed Arabic strings that can leak into English mode.

| Score | File | Issues | Risk examples |
|---:|---|---|---|
| 18 | `lib/widgets/automation_workspace.dart` | 4 untranslated non-Text properties, 8 runtime-composed Arabic strings need review | message: أنشئ قاعدة تربط حدثًا بشرط وإجراء ليعمل NeoTask ; message: غيّر عامل التصفية لعرض بقية قواعد الأتمتة.; runtime: $visibleCount قاعدة; runtime: قبل الموعد بـ ${rule.dueWithinHours} ساعة |
| 18 | `lib/widgets/goals_workspace.dart` | 4 untranslated non-Text properties, 6 runtime-composed Arabic strings need review | message: أنشئ هدفًا وحدد معاييره وفترته لمتابعة التقدم من; message: غيّر عامل التصفية لعرض بقية الأهداف.; runtime: $visibleCount هدف في العرض; runtime: ${progress.completed}/${progress.total} معايير |
| 16 | `lib/widgets/polls_workspace.dart` | 3 untranslated non-Text properties, 5 runtime-composed Arabic strings need review | message: أنشئ موضوع تصويت وحدد الخيارات والمشاركين ووقت ا; message: غيّر عامل التصفية لعرض بقية التصويتات.; runtime: $visibleCount تصويت في العرض; runtime: ${poll.participantUids.length} مشارك |
| 15 | `lib/screens/manager/poll_report_screen.dart` | 6 runtime-composed Arabic strings need review, legacy ListView/ListTile presentation, legacy empty state | runtime: تعذّر حفظ القرار: $e; runtime: قائمة من صوّت (${report.voterUids.length}) |
| 13 | `lib/screens/manager/bulk_import_screen.dart` | 7 runtime-composed Arabic strings need review, legacy ListView/ListTile presentation | runtime: الملف: $_fileName; runtime: $validCount صالح |
| 13 | `lib/screens/manager/manager_ideas_screen.dart` | 4 runtime-composed Arabic strings need review, legacy ListView/ListTile presentation, legacy empty state | runtime: حياك الله ${widget.manager.name}. أنا مساعد المدير الذكي; runtime: تم إنشاء المهمة والتحقق منها في Firestore. رقم المهمة: $ |
| 13 | `lib/screens/manager/task_review_detail_screen.dart` | 5 runtime-composed Arabic strings need review, legacy ListView/ListTile presentation | runtime: تم تحديث الحالة إلى ${statusLabelAr(selected.name)}; runtime: الرقم الوظيفي ${user.employeeNumber} |
| 13 | `lib/widgets/date_nav_arrow_button.dart` | Arabic UI literals may bypass LocalizedText, 2 untranslated non-Text properties, 2 runtime-composed Arabic strings need review | tooltip: $periodLabel التالي; tooltip: $periodLabel السابق; runtime: $periodLabel التالي; runtime: $periodLabel السابق |
| 12 | `lib/screens/manager/custom_forms_screen.dart` | 1 untranslated non-Text properties, 6 runtime-composed Arabic strings need review | message: أنشئ نموذجًا وحدد حقوله ثم شارك رابطه وتابع الرد; runtime: سيُحذف نموذج «${form.title}» وجميع الردود المرتبطة به نه; runtime: تم حذف نموذج «${form.title}» |
| 12 | `lib/screens/shared/documents_screen.dart` | 5 runtime-composed Arabic strings need review, legacy empty state | runtime: ${provider.documents.length} وثيقة; runtime: تعذّر إنشاء الصفحة: $error |
| 12 | `lib/screens/shared/meetings_screen.dart` | 5 runtime-composed Arabic strings need review, legacy empty state | runtime: هل تريد حذف «${meeting.title}» ومحضره؟; runtime: ).format(meeting.startTime)}\n${meeting.decisions.length |
| 11 | `lib/screens/shared/chat_thread_screen.dart` | 3 runtime-composed Arabic strings need review, legacy ListView/ListTile presentation, legacy empty state | runtime: تعذّر إرسال الرسالة: $e; runtime: تعذّر رفع الملف: $e |
| 10 | `lib/screens/manager/automation_rules_screen.dart` | 5 runtime-composed Arabic strings need review | runtime: سيتم حذف «${rule.name}» نهائيًا.; runtime: ${source.name} - نسخة |
| 10 | `lib/screens/manager/manager_employees_tab.dart` | 1 untranslated non-Text properties, 4 runtime-composed Arabic strings need review | message: نسبة الإنجاز في الوقت المحدد; runtime: تغيير كلمة المرور — ${user.name}; runtime: تم تغيير كلمة مرور "${user.name}" بنجاح |
| 10 | `lib/screens/shared/knowledge_document_detail_screen.dart` | 9 runtime-composed Arabic strings need review | runtime: تعديل الإصدار ${document.version + 1}; runtime: ${documentKindLabelAr(document.kind)} · الإصدار ${docume |
| 10 | `lib/widgets/task_plan_summary.dart` | 6 runtime-composed Arabic strings need review | runtime: البداية ${intl.DateFormat(; runtime: النهاية ${intl.DateFormat( |
| 9 | `lib/screens/manager/employee_stats_detail_screen.dart` | 3 runtime-composed Arabic strings need review, legacy ListView/ListTile presentation | runtime: رقم وظيفي: ${widget.employee.employeeNumber}; runtime: ${onTime.onTimeCount} من ${onTime.completedCount} مهمة م |
| 8 | `lib/screens/shared/app_drawer.dart` | 4 runtime-composed Arabic strings need review | runtime: ${widget.completedThisWeek} مكتملة هذا الأسبوع; runtime: يحتاج انتباهك ${widget.overdue} مهمة متأخرة و |
| 8 | `lib/widgets/personal_tasks_workspace.dart` | 3 untranslated non-Text properties, 1 runtime-composed Arabic strings need review | message: أضف مهمة أو تذكيرًا شخصيًا؛ ولن تظهر ضمن تقارير ; message: غيّر عامل التصفية لعرض بقية مهامك الشخصية.; runtime: $visibleCount مهمة في العرض |
| 7 | `lib/screens/manager/manager_create_task_screen.dart` | 2 runtime-composed Arabic strings need review, legacy ListView/ListTile presentation | runtime: الرقم الوظيفي ${user.employeeNumber}; runtime: يوم ${index + 1} |
| 7 | `lib/screens/manager/project_plan_screen.dart` | 2 runtime-composed Arabic strings need review, legacy ListView/ListTile presentation | runtime: السعة الأسبوعية — ${user.name}; runtime: ${entry.plannedHours.toStringAsFixed(1)} / ${entry.capac |
| 7 | `lib/screens/shared/goal_detail_screen.dart` | 1 runtime-composed Arabic strings need review, legacy ListView/ListTile presentation, legacy empty state | runtime: ${ratio.completed} من ${ratio.total} مكتمل |
| 6 | `lib/screens/designer/designer_dashboard_tab.dart` | 3 runtime-composed Arabic strings need review | runtime: $_periodLabel التالي; runtime: $_periodLabel السابق |
| 6 | `lib/screens/designer/designer_home_screen.dart` | Arabic UI literals may bypass LocalizedText, small legacy screen shell |  |
| 6 | `lib/screens/employee/employee_poll_vote_screen.dart` | 2 runtime-composed Arabic strings need review, legacy empty state | runtime: صوتك الحالي: $currentChoice; runtime: النتيجة النهائية: $winnerLabel |
| 6 | `lib/screens/manager/manager_review_tab.dart` | 3 runtime-composed Arabic strings need review | runtime: أُرسلت: ${t.submittedAt != null ? intl.DateFormat(; runtime: ملاحظة الموظف: ${t.submissionNote} |
| 6 | `lib/screens/shared/neotask_assistant_screen.dart` | 3 runtime-composed Arabic strings need review | runtime: مرحبًا $name، أنا مساعد NeoTask; runtime: اختر أي تبويب أو أيقونة، أو اكتب اسمها، وسأوضح وظيفتها و |
| 6 | `lib/widgets/voice_message_recorder_button.dart` | 3 runtime-composed Arabic strings need review | runtime: تعذّر بدء التسجيل: $e; runtime: تعذّر إيقاف التسجيل: $e |
| 5 | `lib/screens/auth/pending_approval_screen.dart` | 2 runtime-composed Arabic strings need review, small legacy screen shell | runtime: مرحبًا ${user?.name ??; runtime: الرقم الوظيفي: ${user?.employeeNumber ?? |
| 5 | `lib/screens/shared/criterion_detail_screen.dart` | 1 runtime-composed Arabic strings need review, legacy ListView/ListTile presentation | runtime: ضمن الهدف: ${goal.title} |
| 5 | `lib/widgets/favorite_star_button.dart` | Arabic UI literals may bypass LocalizedText |  |
| 5 | `lib/widgets/language_toggle.dart` | Arabic UI literals may bypass LocalizedText |  |
| 5 | `lib/widgets/task_urgency_indicator.dart` | Arabic UI literals may bypass LocalizedText |  |
| 4 | `lib/screens/designer/designer_chat_tab.dart` | 2 runtime-composed Arabic strings need review | runtime: ${resolved.subtitle} · ${msg.text.isEmpty ? "(مرفق)" : m; runtime: ${resolved.subtitle} · عرض فقط |
| 4 | `lib/screens/employee/employee_tasks_tab.dart` | 2 runtime-composed Arabic strings need review | runtime: ملاحظة المدير: ${t.reviewNote}; runtime: سبب الرفض: ${t.reviewNote} |
| 4 | `lib/screens/manager/luxury_manager_dashboard.dart` | 2 runtime-composed Arabic strings need review | runtime: $greeting، $firstName; runtime: Arabic date/month array used at runtime |
| 4 | `lib/screens/manager/manager_dashboard_tab.dart` | 2 runtime-composed Arabic strings need review | runtime: المهام (${rangeTasks.length}); runtime: Arabic date/month array used at runtime |
| 4 | `lib/screens/manager/manager_reports_tab.dart` | 2 runtime-composed Arabic strings need review | runtime: الرقم الوظيفي ${employee.employeeNumber}; runtime: عدد المهام في هذا النطاق: ${tasks.length} |
| 4 | `lib/screens/public/public_form_screen.dart` | legacy ListView/ListTile presentation, small legacy screen shell |  |
| 4 | `lib/screens/shared/create_criterion_screen.dart` | legacy ListView/ListTile presentation, small legacy screen shell |  |
| 4 | `lib/screens/shared/notification_center_screen.dart` | 1 untranslated non-Text properties, 1 runtime-composed Arabic strings need review | message: ستظهر هنا التنبيهات والتحديثات المرتبطة بمهامك و; runtime: $unread غير مقروءة وتحتاج انتباهك |
| 4 | `lib/screens/shared/search_screen.dart` | 2 untranslated non-Text properties | message: اكتب اسم موظف أو رقمًا وظيفيًا أو عنوان هدف أو م; message: جرّب كلمة أقصر أو اسمًا أو رقمًا مختلفًا. |
| 4 | `lib/screens/shared/settings_screen.dart` | 2 runtime-composed Arabic strings need review | runtime: تعذّر رفع الصورة: $error; runtime: الرقم الوظيفي: ${user.employeeNumber} |
| 3 | `lib/screens/employee/task_detail_screen.dart` | legacy ListView/ListTile presentation |  |
| 3 | `lib/screens/manager/manager_my_tasks_screen.dart` | 1 runtime-composed Arabic strings need review, small legacy screen shell | runtime: هل تريد حذف «${task.title}» نهائيًا؟ |
| 3 | `lib/screens/manager/manager_poll_detail_screen.dart` | legacy ListView/ListTile presentation |  |
| 3 | `lib/screens/shared/create_poll_screen.dart` | legacy ListView/ListTile presentation |  |
| 2 | `lib/screens/employee/employee_calendar_tab.dart` | 1 runtime-composed Arabic strings need review | runtime: أحداث الشهر الحالي (${provider.events.length}) |
| 2 | `lib/screens/employee/employee_polls_tab.dart` | 1 untranslated non-Text properties | message: ستظهر هنا موضوعات التصويت التي تحتاج مشاركتك أو  |
| 2 | `lib/screens/manager/manager_calendar_screen.dart` | 1 untranslated non-Text properties | message: لا توجد مهام مستحقة في هذا اليوم. |
| 2 | `lib/screens/manager/manager_chat_tab.dart` | 1 runtime-composed Arabic strings need review | runtime: محادثة المهمة مع $employeeName |
| 2 | `lib/screens/manager/past_polls_screen.dart` | 1 untranslated non-Text properties | message: عند إغلاق أي تصويت سيبقى سجله ونتيجته هنا للرجوع |
| 2 | `lib/screens/manager/quick_add_task_sheet.dart` | 1 runtime-composed Arabic strings need review | runtime: الرقم الوظيفي ${user.employeeNumber} |
| 2 | `lib/screens/shared/contacts_screen.dart` | 1 runtime-composed Arabic strings need review | runtime: هل تريد حذف "${contact.name}"؟ |
| 2 | `lib/screens/shared/criterion_chat_body.dart` | 1 runtime-composed Arabic strings need review | runtime: تعذّر إرسال الرسالة: $e |
| 2 | `lib/screens/shared/favorites_screen.dart` | 1 untranslated non-Text properties | message: استخدم النجمة في أي مهمة لتضيفها إلى مساحة الترك |
| 2 | `lib/screens/shared/request_reassignment_dialog.dart` | 1 runtime-composed Arabic strings need review | runtime: الرقم الوظيفي ${user.employeeNumber} |
| 2 | `lib/widgets/linked_knowledge_card.dart` | 1 runtime-composed Arabic strings need review | runtime: ${document.department} · الإصدار ${document.version} |
| 2 | `lib/widgets/neo_selection_field.dart` | 1 runtime-composed Arabic strings need review | runtime: يرجى اختيار $label |
| 2 | `lib/widgets/user_avatar.dart` | 1 runtime-composed Arabic strings need review | runtime: الصورة الشخصية لـ $name |
| 1 | `lib/screens/auth/manager_setup_screen.dart` | small legacy screen shell |  |
| 1 | `lib/screens/auth/register_via_invite_screen.dart` | small legacy screen shell |  |
| 1 | `lib/screens/employee/employee_home_screen.dart` | small legacy screen shell |  |
| 1 | `lib/screens/manager/manager_polls_tab.dart` | small legacy screen shell |  |
| 1 | `lib/screens/shared/goals_list_screen.dart` | small legacy screen shell |  |

Flagged files: **65**
