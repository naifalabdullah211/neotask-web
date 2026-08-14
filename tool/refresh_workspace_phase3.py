from pathlib import Path


def replace_once(path_str: str, old: str, new: str, label: str) -> None:
    path = Path(path_str)
    text = path.read_text(encoding='utf-8')
    if old not in text:
        if new in text:
            return
        raise SystemExit(f'missing phase3 target: {label}')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')


def replace_between(path_str: str, start: str, end: str, replacement: str, label: str) -> None:
    path = Path(path_str)
    text = path.read_text(encoding='utf-8')
    start_i = text.find(start)
    if start_i < 0:
        if replacement.strip() in text:
            return
        raise SystemExit(f'missing phase3 start: {label}')
    end_i = text.find(end, start_i)
    if end_i < 0:
        raise SystemExit(f'missing phase3 end: {label}')
    path.write_text(text[:start_i] + replacement + text[end_i:], encoding='utf-8')


# ---------------------------------------------------------------------------
# 1) Main premium dashboard — remove dynamically-generated Arabic leakage.
# ---------------------------------------------------------------------------
path = 'lib/screens/manager/luxury_manager_dashboard.dart'
replace_once(
    path,
    "import '../../providers/meeting_provider.dart';\n",
    "import '../../providers/meeting_provider.dart';\nimport '../../providers/locale_provider.dart';\n",
    'dashboard locale import',
)
replace_once(
    path,
    """  String get _rangeLabel {
    final formatter = intl.DateFormat('yyyy/MM/dd');
    return switch (_range) {
      _LuxuryRange.day => formatter.format(_anchor),
      _LuxuryRange.week => () {
        final start = _anchor.subtract(Duration(days: _anchor.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${formatter.format(start)} — ${formatter.format(end)}';
      }(),
      _LuxuryRange.month =>
        '${_arabicMonths[_anchor.month - 1]} ${_anchor.year}',
    };
  }
""",
    """  String _rangeLabel(String languageCode) {
    final formatter = intl.DateFormat('yyyy/MM/dd');
    return switch (_range) {
      _LuxuryRange.day => formatter.format(_anchor),
      _LuxuryRange.week => () {
        final start = _anchor.subtract(Duration(days: _anchor.weekday - 1));
        final end = start.add(const Duration(days: 6));
        return '${formatter.format(start)} — ${formatter.format(end)}';
      }(),
      _LuxuryRange.month =>
        '${languageCode == 'en' ? _englishMonths[_anchor.month - 1] : _arabicMonths[_anchor.month - 1]} ${_anchor.year}',
    };
  }
""",
    'dashboard range label',
)
replace_once(
    path,
    "    final manager = context.watch<AuthProvider>().currentUser!;\n",
    "    final manager = context.watch<AuthProvider>().currentUser!;\n    final languageCode = context.watch<LocaleProvider>().languageCode;\n",
    'dashboard language binding',
)
replace_once(path, '                      rangeLabel: _rangeLabel,', '                      rangeLabel: _rangeLabel(languageCode),', 'dashboard range label call')
replace_once(
    path,
    """    final now = DateTime.now();
    final greeting = now.hour < 12 ? 'صباح الخير' : 'مساء الخير';
    final date =
        '${_weekdays[now.weekday - 1]} ${now.day} '
        '${_arabicMonths[now.month - 1]} ${now.year}';
""",
    """    final now = DateTime.now();
    final english = context.watch<LocaleProvider>().languageCode == 'en';
    final greeting = english
        ? (now.hour < 12 ? 'Good morning' : 'Good evening')
        : (now.hour < 12 ? 'صباح الخير' : 'مساء الخير');
    final date = english
        ? '${_englishWeekdays[now.weekday - 1]}, ${_englishMonths[now.month - 1]} ${now.day}, ${now.year}'
        : '${_weekdays[now.weekday - 1]} ${now.day} ${_arabicMonths[now.month - 1]} ${now.year}';
""",
    'dashboard greeting and date',
)
replace_once(
    path,
    """              Text(
                _arabicMonths[meeting.startTime.month - 1],
                style: TextStyle(color: dateColor, fontSize: 11),
              ),
""",
    """              Text(
                context.watch<LocaleProvider>().languageCode == 'en'
                    ? _englishMonths[meeting.startTime.month - 1]
                    : _arabicMonths[meeting.startTime.month - 1],
                style: TextStyle(color: dateColor, fontSize: 11),
              ),
""",
    'dashboard meeting month',
)
dash_path = Path(path)
dash_text = dash_path.read_text(encoding='utf-8')
if 'const _englishMonths = [' not in dash_text:
    dash_text += """

const _englishMonths = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

const _englishWeekdays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
];
"""
    dash_path.write_text(dash_text, encoding='utf-8')

# ---------------------------------------------------------------------------
# 2) Poll report — workspace visual hierarchy + translated runtime strings.
# ---------------------------------------------------------------------------
path = 'lib/screens/manager/poll_report_screen.dart'
replace_once(
    path,
    "import 'package:neotask_pro/widgets/localized_text.dart';\n",
    "import 'package:neotask_pro/widgets/localized_text.dart';\nimport 'package:neotask_pro/l10n/app_i18n.dart';\n",
    'poll report i18n import',
)
replace_once(
    path,
    "import '../../widgets/status_chip.dart' show AppPill;\n",
    "import '../../widgets/status_chip.dart' show AppPill;\nimport '../../widgets/neo_workspace_chrome.dart';\n",
    'poll report workspace import',
)
replace_once(
    path,
    "      appBar: AppBar(title: const Text('التقرير النهائي للتصويت')),",
    """      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'التقرير النهائي للتصويت',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),""",
    'poll report app bar',
)
replace_once(
    path,
    """              return const Center(
                child: Text('لا يوجد تقرير نهائي لهذا التصويت'),
              );
""",
    """              return const NeoWorkspaceEmptyState(
                icon: Icons.poll_outlined,
                title: 'لا يوجد تقرير نهائي لهذا التصويت',
                message: 'سيظهر التقرير هنا بعد إغلاق التصويت وحساب النتيجة.',
              );
""",
    'poll report empty state',
)
replace_between(
    path,
    "                Text(\n                  report.title,",
    "                // ---- summary cards ----",
    """                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.deepBlue.withValues(alpha: .08),
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: const Icon(
                              Icons.how_to_vote_outlined,
                              color: AppColors.deepBlue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  report.title,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if (report.description.isNotEmpty) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    report.description,
                                    style: AppTextStyles.bodySecondary.copyWith(
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (report.privacyWasEnabled) ...[
                        const SizedBox(height: 14),
                        AppPill(
                          color: AppColors.deepBlue,
                          label: 'الخصوصية كانت مفعّلة عند إجراء التصويت',
                          icon: Icons.privacy_tip_outlined,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

""",
    'poll report hero',
)
replace_between(
    path,
    "                // ---- summary cards ----",
    "                // ---- winner / tie ----",
    """                // ---- summary metrics ----
                NeoWorkspaceMetricsBar(
                  items: [
                    NeoWorkspaceMetric(
                      label: 'إجمالي المستحقّين',
                      value: '${report.totalEligible}',
                      icon: Icons.groups_outlined,
                      color: AppColors.deepBlue,
                    ),
                    NeoWorkspaceMetric(
                      label: 'صوّتوا',
                      value: '${report.totalVoted}',
                      icon: Icons.check_circle_outline,
                      color: AppColors.statusApproved,
                    ),
                    NeoWorkspaceMetric(
                      label: 'لم يصوّتوا',
                      value: '${report.totalNotVoted}',
                      icon: Icons.remove_circle_outline,
                      color: AppColors.statusRejected,
                    ),
                    NeoWorkspaceMetric(
                      label: 'نسبة المشاركة',
                      value: '${report.participationPercent.toStringAsFixed(1)}%',
                      icon: Icons.pie_chart_outline,
                      color: AppColors.statusPending,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  child: LinearProgressIndicator(
                    value: (report.participationPercent / 100).clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: AppColors.divider,
                    color: AppColors.statusApproved,
                  ),
                ),
                const SizedBox(height: 20),

""",
    'poll report metrics',
)
replace_once(
    path,
    """                const Text(
                  'نتائج كل اختيار',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
""",
    """                const NeoWorkspaceSectionHeader(
                  title: 'نتائج كل اختيار',
                  subtitle: 'توزيع الأصوات ونسب كل اختيار',
                ),
""",
    'poll report choice header',
)
replace_once(
    path,
    "        ).showSnackBar(SnackBar(content: Text('تعذّر حفظ القرار: $e')));",
    "        ).showSnackBar(SnackBar(content: Text('${context.tr('تعذّر حفظ القرار')}: $e')));",
    'poll report decision error',
)
replace_once(
    path,
    """                  'تعادل بين: '
                  '${report.tiedChoiceIndexes.map((i) => report.choices[i]).join(' و ')}',
""",
    """                  '${context.tr('تعادل بين')}: '
                  '${report.tiedChoiceIndexes.map((i) => report.choices[i]).join(Localizations.localeOf(context).languageCode == 'en' ? ', ' : ' و ')}',
""",
    'poll report tie runtime label',
)
replace_once(path, "        : 'غير محدد';", "        : context.tr('غير محدد');", 'poll report winner fallback')
replace_once(path, "                'الاختيار الفائز: $winnerLabel',", "                '${context.tr('الاختيار الفائز')}: $winnerLabel',", 'poll report winner runtime label')
replace_once(path, "                '$count صوت (${percent.toStringAsFixed(1)}%)',", "                '$count ${context.tr('صوت')} (${percent.toStringAsFixed(1)}%)',", 'poll report vote count')
replace_once(path, "            '$label: ',", "            '${context.tr(label)}: ',", 'poll report info row')
replace_once(path, "                  title: 'قائمة من صوّت (${report.voterUids.length})',", "                  title: '${context.tr('قائمة من صوّت')} (${report.voterUids.length})',", 'poll report voters title')
replace_once(path, "                  title: 'قائمة من لم يصوّت (${report.nonVoterUids.length})',", "                  title: '${context.tr('قائمة من لم يصوّت')} (${report.nonVoterUids.length})',", 'poll report non-voters title')

# ---------------------------------------------------------------------------
# 3) Goal details — workspace metrics and shared section chrome.
# ---------------------------------------------------------------------------
path = 'lib/screens/shared/goal_detail_screen.dart'
replace_once(
    path,
    "import '../../widgets/status_chip.dart';\n",
    "import '../../widgets/status_chip.dart';\nimport '../../widgets/neo_workspace_chrome.dart';\n",
    'goal workspace import',
)
replace_once(
    path,
    """          children: [
            // ---- Goal header card: colored border + icon avatar + large
""",
    """          children: [
            NeoWorkspaceMetricsBar(
              items: [
                NeoWorkspaceMetric(
                  label: 'إجمالي المعايير',
                  value: '${progress.total}',
                  icon: Icons.checklist_rtl_outlined,
                  color: AppColors.deepBlue,
                ),
                NeoWorkspaceMetric(
                  label: 'مكتملة',
                  value: '${progress.completed}',
                  icon: Icons.task_alt_rounded,
                  color: AppColors.statusApproved,
                ),
                NeoWorkspaceMetric(
                  label: 'المتبقية',
                  value: '${(progress.total - progress.completed).clamp(0, progress.total)}',
                  icon: Icons.pending_actions_outlined,
                  color: AppColors.statusPending,
                ),
                NeoWorkspaceMetric(
                  label: 'نسبة التقدم',
                  value: '$percent%',
                  icon: Icons.donut_large_rounded,
                  color: goalColor,
                ),
              ],
            ),
            const SizedBox(height: 16),
            // ---- Goal header card: colored border + icon avatar + large
""",
    'goal metrics bar',
)
replace_once(
    path,
    """            const Text(
              'المعايير',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
""",
    """            const NeoWorkspaceSectionHeader(
              title: 'المعايير',
              subtitle: 'المعايير المرتبطة بالهدف وحالة تنفيذ كل منها',
            ),
""",
    'goal criteria header',
)
replace_once(path, "        .map((uid) => FirestoreService.getUser(uid)?.name ?? 'موظف')", "        .map((uid) => FirestoreService.getUser(uid)?.name ?? context.tr('موظف'))", 'goal assignee fallback')
replace_once(path, "                assigneeNames.isEmpty ? 'بدون موظف' : assigneeNames,", "                assigneeNames.isEmpty ? context.tr('بدون موظف') : assigneeNames,", 'goal empty assignee')
replace_once(
    path,
    """        const Text(
          'تعليقات',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
""",
    """        const NeoWorkspaceSectionHeader(
          title: 'تعليقات',
          subtitle: 'ملاحظات ومتابعات مرتبطة بالهدف',
        ),
""",
    'goal comments header',
)
replace_once(path, "        FirestoreService.getUser(comment.authorUid)?.name ?? 'مستخدم';", "        FirestoreService.getUser(comment.authorUid)?.name ?? context.tr('مستخدم');", 'goal comment author fallback')

# ---------------------------------------------------------------------------
# 4) Public form — translate validator text rendered by TextFormField itself.
# ---------------------------------------------------------------------------
path = 'lib/screens/public/public_form_screen.dart'
replace_once(path, "            return 'أدخل رقمًا صحيحًا';", "            return context.tr('أدخل رقمًا صحيحًا');", 'public form number validation')
replace_once(path, "            return 'استخدم صيغة YYYY-MM-DD';", "            return context.tr('استخدم صيغة YYYY-MM-DD');", 'public form date validation')

# ---------------------------------------------------------------------------
# 5) Chat — preserve logic, only modernize the legacy empty state.
# ---------------------------------------------------------------------------
path = 'lib/screens/shared/chat_thread_screen.dart'
replace_once(
    path,
    "import '../../widgets/voice_message_recorder_button.dart';\n",
    "import '../../widgets/voice_message_recorder_button.dart';\nimport '../../widgets/neo_workspace_chrome.dart';\n",
    'chat workspace import',
)
replace_once(
    path,
    """                return const Center(
                  child: Text(
                    'لا توجد رسائل بعد — ابدأ المحادثة',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
""",
    """                return const NeoWorkspaceEmptyState(
                  icon: Icons.forum_outlined,
                  title: 'لا توجد رسائل بعد — ابدأ المحادثة',
                  message: 'ابدأ المحادثة بإرسال أول رسالة.',
                );
""",
    'chat empty state',
)

print('NeoTask workspace phase 3 refresh applied')
