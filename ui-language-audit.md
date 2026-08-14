# NeoTask UI + Language Audit

Automated static audit of `lib/screens` and `lib/widgets`.

| Score | File | Issues | Risk examples |
|---:|---|---|---|
| 9 | `lib/widgets/date_nav_arrow_button.dart` | Arabic UI literals may bypass LocalizedText, 2 untranslated non-Text properties | tooltip: $periodLabel التالي; tooltip: $periodLabel السابق |
| 8 | `lib/widgets/automation_workspace.dart` | 4 untranslated non-Text properties | message: أنشئ قاعدة تربط حدثًا بشرط وإجراء ليعمل NeoTask ; message: غيّر عامل التصفية لعرض بقية قواعد الأتمتة.; message: تظهر هنا نتائج تشغيل القواعد مع المهمة والتوقيت. |
| 8 | `lib/widgets/goals_workspace.dart` | 4 untranslated non-Text properties | message: أنشئ هدفًا وحدد معاييره وفترته لمتابعة التقدم من; message: غيّر عامل التصفية لعرض بقية الأهداف.; message: افتح الهدف لإضافة معايير قابلة للقياس والتوزيع. |
| 6 | `lib/screens/designer/designer_home_screen.dart` | Arabic UI literals may bypass LocalizedText, small legacy screen shell |  |
| 6 | `lib/widgets/personal_tasks_workspace.dart` | 3 untranslated non-Text properties | message: أضف مهمة أو تذكيرًا شخصيًا؛ ولن تظهر ضمن تقارير ; message: غيّر عامل التصفية لعرض بقية مهامك الشخصية.; message: غيّر عامل التصفية لعرض بقية مهامك الشخصية. |
| 6 | `lib/widgets/polls_workspace.dart` | 3 untranslated non-Text properties | message: أنشئ موضوع تصويت وحدد الخيارات والمشاركين ووقت ا; message: غيّر عامل التصفية لعرض بقية التصويتات.; message: غيّر عامل التصفية لعرض بقية التصويتات. |
| 5 | `lib/screens/manager/custom_forms_screen.dart` | legacy ListView/ListTile presentation, legacy empty state |  |
| 5 | `lib/screens/manager/manager_ideas_screen.dart` | legacy ListView/ListTile presentation, legacy empty state |  |
| 5 | `lib/screens/manager/poll_report_screen.dart` | legacy ListView/ListTile presentation, legacy empty state |  |
| 5 | `lib/screens/shared/chat_thread_screen.dart` | legacy ListView/ListTile presentation, legacy empty state |  |
| 5 | `lib/screens/shared/goal_detail_screen.dart` | legacy ListView/ListTile presentation, legacy empty state |  |
| 5 | `lib/screens/shared/notification_center_screen.dart` | legacy ListView/ListTile presentation, legacy empty state |  |
| 5 | `lib/widgets/favorite_star_button.dart` | Arabic UI literals may bypass LocalizedText |  |
| 5 | `lib/widgets/language_toggle.dart` | Arabic UI literals may bypass LocalizedText |  |
| 5 | `lib/widgets/task_urgency_indicator.dart` | Arabic UI literals may bypass LocalizedText |  |
| 4 | `lib/screens/employee/employee_poll_vote_screen.dart` | legacy ListView/ListTile presentation, small legacy screen shell |  |
| 4 | `lib/screens/public/public_form_screen.dart` | legacy ListView/ListTile presentation, small legacy screen shell |  |
| 4 | `lib/screens/shared/create_criterion_screen.dart` | legacy ListView/ListTile presentation, small legacy screen shell |  |
| 4 | `lib/screens/shared/search_screen.dart` | 2 untranslated non-Text properties | message: اكتب اسم موظف أو رقمًا وظيفيًا أو عنوان هدف أو م; message: جرّب كلمة أقصر أو اسمًا أو رقمًا مختلفًا. |
| 3 | `lib/screens/employee/task_detail_screen.dart` | legacy ListView/ListTile presentation |  |
| 3 | `lib/screens/manager/bulk_import_screen.dart` | legacy ListView/ListTile presentation |  |
| 3 | `lib/screens/manager/employee_stats_detail_screen.dart` | legacy ListView/ListTile presentation |  |
| 3 | `lib/screens/manager/manager_create_task_screen.dart` | legacy ListView/ListTile presentation |  |
| 3 | `lib/screens/manager/manager_poll_detail_screen.dart` | legacy ListView/ListTile presentation |  |
| 3 | `lib/screens/manager/project_plan_screen.dart` | legacy ListView/ListTile presentation |  |
| 3 | `lib/screens/manager/task_review_detail_screen.dart` | legacy ListView/ListTile presentation |  |
| 3 | `lib/screens/shared/create_poll_screen.dart` | legacy ListView/ListTile presentation |  |
| 3 | `lib/screens/shared/criterion_detail_screen.dart` | legacy ListView/ListTile presentation |  |
| 2 | `lib/screens/employee/employee_polls_tab.dart` | 1 untranslated non-Text properties | message: ستظهر هنا موضوعات التصويت التي تحتاج مشاركتك أو  |
| 2 | `lib/screens/manager/manager_calendar_screen.dart` | 1 untranslated non-Text properties | message: لا توجد مهام مستحقة في هذا اليوم. |
| 2 | `lib/screens/manager/manager_employees_tab.dart` | 1 untranslated non-Text properties | message: نسبة الإنجاز في الوقت المحدد |
| 2 | `lib/screens/manager/past_polls_screen.dart` | 1 untranslated non-Text properties | message: عند إغلاق أي تصويت سيبقى سجله ونتيجته هنا للرجوع |
| 2 | `lib/screens/shared/documents_screen.dart` | legacy empty state |  |
| 2 | `lib/screens/shared/favorites_screen.dart` | 1 untranslated non-Text properties | message: استخدم النجمة في أي مهمة لتضيفها إلى مساحة الترك |
| 2 | `lib/screens/shared/meetings_screen.dart` | legacy empty state |  |
| 1 | `lib/screens/auth/manager_setup_screen.dart` | small legacy screen shell |  |
| 1 | `lib/screens/auth/pending_approval_screen.dart` | small legacy screen shell |  |
| 1 | `lib/screens/auth/register_via_invite_screen.dart` | small legacy screen shell |  |
| 1 | `lib/screens/employee/employee_home_screen.dart` | small legacy screen shell |  |
| 1 | `lib/screens/manager/manager_my_tasks_screen.dart` | small legacy screen shell |  |
| 1 | `lib/screens/manager/manager_polls_tab.dart` | small legacy screen shell |  |
| 1 | `lib/screens/shared/goals_list_screen.dart` | small legacy screen shell |  |

Flagged files: **42**
