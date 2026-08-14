from pathlib import Path
from textwrap import dedent


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old not in text:
        raise SystemExit(f'missing anchor: {label}')
    return text.replace(old, new, 1)


def write(path: str, content: str) -> None:
    Path(path).write_text(dedent(content).lstrip(), encoding='utf-8')


# ---------------------------------------------------------------------------
# 1) Manager AI: make every visible product string pass through localization,
#    send the active language to the backend, and keep user/AI messages in the
#    selected language end-to-end.
# ---------------------------------------------------------------------------
path = Path('lib/screens/manager/manager_ideas_screen.dart')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    "import 'package:flutter/material.dart';\nimport 'package:provider/provider.dart';",
    "import 'package:flutter/material.dart' hide Text;\nimport 'package:neotask_pro/widgets/localized_text.dart';\nimport 'package:neotask_pro/l10n/app_i18n.dart';\nimport 'package:provider/provider.dart';",
    'manager ideas localized imports',
)
text = replace_once(
    text,
    "import '../../providers/task_provider.dart';",
    "import '../../providers/task_provider.dart';\nimport '../../providers/locale_provider.dart';",
    'manager ideas locale provider import',
)
text = replace_once(
    text,
    "    _messages.add(\n      _ChatMessage.agent(\n        'حياك الله ${widget.manager.name}. أنا مساعد المدير الذكي. '\n        'اطلب مني إنشاء مبادرة، تجهيز مهمة، تلخيص أداء الفريق، أو تعديل قواعد المساعد.',\n      ),\n    );",
    "    final english = context.read<LocaleProvider>().languageCode == 'en';\n    _messages.add(\n      _ChatMessage.agent(\n        english\n            ? 'Welcome ${widget.manager.name}. I am the NeoTask Manager AI Assistant. Ask me to create an initiative, prepare a task, summarize team performance, or update assistant rules.'\n            : 'حياك الله ${widget.manager.name}. أنا مساعد المدير الذكي. اطلب مني إنشاء مبادرة، تجهيز مهمة، تلخيص أداء الفريق، أو تعديل قواعد المساعد.',\n      ),\n    );",
    'manager ideas greeting',
)
text = replace_once(
    text,
    "        teamContext: _buildTeamContext(),\n        agentRules: await FirestoreService.loadManagerAgentRules(),",
    "        teamContext: _buildTeamContext(),\n        agentRules: await FirestoreService.loadManagerAgentRules(),\n        languageCode: context.read<LocaleProvider>().languageCode,",
    'manager AI send language',
)
text = replace_once(
    text,
    "                hintText: 'اكتب طلبك لمساعد المدير...',",
    "                hintText: context.tr('اكتب طلبك لمساعد المدير...'),",
    'manager AI composer hint',
)
text = replace_once(
    text,
    "                  tooltip: idea.isRuleRecord\n                      ? 'خيارات حذف القاعدة والسجل'\n                      : 'حذف سجل العملية',",
    "                  tooltip: context.tr(\n                    idea.isRuleRecord\n                        ? 'خيارات حذف القاعدة والسجل'\n                        : 'حذف سجل العملية',\n                  ),",
    'manager AI delete tooltip',
)
text = replace_once(
    text,
    "  static const items = [\n    'أنشئ مبادرة لتحسين متابعة المهام المتأخرة',\n    'جهز مسودة مهمة لفريق الجودة لمدة أسبوع',\n    'اقترح قاعدة تنبيه للمهام المتأخرة',\n  ];\n\n  @override\n  Widget build(BuildContext context) {\n    return SingleChildScrollView(",
    "  @override\n  Widget build(BuildContext context) {\n    final english = context.watch<LocaleProvider>().languageCode == 'en';\n    final items = english\n        ? const [\n            'Create an initiative to improve overdue-task follow-up',\n            'Prepare a one-week task draft for the Quality team',\n            'Suggest an alert rule for overdue tasks',\n          ]\n        : const [\n            'أنشئ مبادرة لتحسين متابعة المهام المتأخرة',\n            'جهز مسودة مهمة لفريق الجودة لمدة أسبوع',\n            'اقترح قاعدة تنبيه للمهام المتأخرة',\n          ];\n    return SingleChildScrollView(",
    'manager AI suggestions language',
)
# Approved actions produce real audit messages. Make these messages language-safe
# because they contain IDs/names and cannot be translated safely as an exact map.
text = replace_once(
    text,
    "        return 'تم إنشاء المهمة والتحقق منها في Firestore. رقم المهمة: '\n            '${task.taskId} — المسؤول: ${selectedAssignee.name} '\n            '(${selectedAssignee.employeeNumber}). يمكنك فتحها وتعديلها من سجل عمليات المساعد.';",
    "        final english = context.read<LocaleProvider>().languageCode == 'en';\n        return english\n            ? 'Task created and verified in Firestore. Task ID: ${task.taskId} — owner: ${selectedAssignee.name} (${selectedAssignee.employeeNumber}). You can open and edit it from the assistant activity log.'\n            : 'تم إنشاء المهمة والتحقق منها في Firestore. رقم المهمة: ${task.taskId} — المسؤول: ${selectedAssignee.name} (${selectedAssignee.employeeNumber}). يمكنك فتحها وتعديلها من سجل عمليات المساعد.';",
    'manager AI task execution confirmation',
)
text = replace_once(
    text,
    "        return 'تم حفظ القاعدة واعتمادها. سيطبقها الوكيل في الطلبات التالية.';",
    "        return context.read<LocaleProvider>().languageCode == 'en'\n            ? 'The rule was saved and approved. The agent will apply it to future requests.'\n            : 'تم حفظ القاعدة واعتمادها. سيطبقها الوكيل في الطلبات التالية.';",
    'manager AI rule confirmation',
)
text = replace_once(
    text,
    "        return 'تم اعتماد التحليل وحفظه في سجل عمليات المساعد.';",
    "        return context.read<LocaleProvider>().languageCode == 'en'\n            ? 'The analysis was approved and saved in the assistant activity log.'\n            : 'تم اعتماد التحليل وحفظه في سجل عمليات المساعد.';",
    'manager AI analysis confirmation',
)
text = replace_once(
    text,
    "      default:\n        throw ArgumentError('نوع الإجراء غير قابل للتنفيذ.');",
    "      default:\n        throw ArgumentError(\n          context.read<LocaleProvider>().languageCode == 'en'\n              ? 'This action type cannot be executed.'\n              : 'نوع الإجراء غير قابل للتنفيذ.',\n        );",
    'manager AI unsupported action',
)
text = replace_once(
    text,
    "      _messages.add(_ChatMessage.agent('تم إلغاء الإجراء ولم يُحفظ أي تغيير.'));",
    "      _messages.add(\n        _ChatMessage.agent(\n          context.read<LocaleProvider>().languageCode == 'en'\n              ? 'The action was cancelled and no change was saved.'\n              : 'تم إلغاء الإجراء ولم يُحفظ أي تغيير.',\n        ),\n      );",
    'manager AI cancel action',
)
path.write_text(text, encoding='utf-8')

# ---------------------------------------------------------------------------
# 2) Manager AI service: pass locale to backend and keep TruthMode/error labels
#    fully English when English is selected.
# ---------------------------------------------------------------------------
path = Path('lib/services/manager_ai_service.dart')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    "    required List<Map<String, dynamic>> teamContext,\n    required List<String> agentRules,\n  }) async {",
    "    required List<Map<String, dynamic>> teamContext,\n    required List<String> agentRules,\n    String languageCode = 'ar',\n  }) async {",
    'manager AI service language parameter',
)
text = replace_once(
    text,
    "            'agentRules': effectiveRules,\n            'truthMode': true,",
    "            'agentRules': effectiveRules,\n            'truthMode': true,\n            'languageCode': languageCode == 'en' ? 'en' : 'ar',",
    'manager AI service language payload',
)
text = replace_once(
    text,
    "    final rawReply = body['reply']?.toString().trim().isNotEmpty == true\n        ? body['reply'].toString().trim()\n        : 'تم تحليل طلبك.';",
    "    final rawReply = body['reply']?.toString().trim().isNotEmpty == true\n        ? body['reply'].toString().trim()\n        : languageCode == 'en'\n            ? 'Your request was analyzed.'\n            : 'تم تحليل طلبك.';",
    'manager AI fallback reply',
)
text = replace_once(
    text,
    "    final truth = _classifyTruth(\n      action: action,\n      mode: mode,\n      requestId: body['requestId']?.toString(),\n    );\n    final agentLine = delegatedAgents.isEmpty\n        ? ''\n        : '\\n🤖 الوكلاء: ${delegatedAgents.map((agent) => agent.name).join(' ← ')}';",
    "    final truth = _classifyTruth(\n      action: action,\n      mode: mode,\n      requestId: body['requestId']?.toString(),\n      languageCode: languageCode,\n    );\n    final agentLine = delegatedAgents.isEmpty\n        ? ''\n        : languageCode == 'en'\n            ? '\\n🤖 Agents: ${delegatedAgents.map((agent) => agent.name).join(' ← ')}'\n            : '\\n🤖 الوكلاء: ${delegatedAgents.map((agent) => agent.name).join(' ← ')}';",
    'manager AI truth/agent line language',
)
text = replace_once(
    text,
    "      final code = body['error']?.toString() ?? '';\n      throw ManagerAiException(_messageForCode(code));",
    "      final code = body['error']?.toString() ?? '';\n      throw ManagerAiException(_messageForCode(code, languageCode));",
    'manager AI error language call',
)
old_truth = """  static _TruthClassification _classifyTruth({
    required ManagerAiAction? action,
    required String mode,
    required String? requestId,
  }) {
    if (action != null) {
      return const _TruthClassification(
        status: 'pending',
        label: '🟡 مقترح — لم يُنفذ بعد',
        note: 'أي تغيير ينتظر اعتماد المدير ثم نتيجة تنفيذ فعلية من NeoTask.',
      );
    }
    if (mode == 'resilient-local') {
      return const _TruthClassification(
        status: 'confirmed_local',
        label: '✅ محسوب من بيانات NeoTask المتاحة',
        note: 'النتيجة صادرة من المسار المحلي الحتمي وليست ادعاء تنفيذ.',
      );
    }
    if (mode == 'multi-agent' || mode == 'ai-gateway') {
      return _TruthClassification(
        status: 'ai_analysis',
        label: '🟡 تحليل AI — ليس دليل تنفيذ',
        note: requestId == null || requestId.isEmpty
            ? 'الرد تحليلي ويحتاج سجل NeoTask لإثبات أي تنفيذ.'
            : 'معرّف الاستجابة متاح، لكن التنفيذ لا يُثبت إلا بسجل NeoTask.',
      );
    }
    return const _TruthClassification(
      status: 'unverified',
      label: '🔴 غير متحقق',
      note: 'لم يصل تصنيف موثوق لمسار الاستجابة؛ لا تعتمد عليه كدليل تنفيذ.',
    );
  }

  static String _messageForCode(String code) {
    switch (code) {
      case 'manager-only':
        return 'هذه الميزة متاحة للمدير فقط';
      case 'rate-limit':
        return 'تم إرسال طلبات كثيرة. حاول بعد دقيقة';
      case 'invalid-message':
        return 'الطلب فارغ أو طويل جدًا';
      case 'missing-token':
      case 'invalid-token':
        return 'انتهت جلسة الدخول. سجّل الدخول مرة أخرى';
      default:
        return 'تعذر الاتصال بمساعد المدير الآن';
    }
  }
"""
new_truth = """  static _TruthClassification _classifyTruth({
    required ManagerAiAction? action,
    required String mode,
    required String? requestId,
    required String languageCode,
  }) {
    final english = languageCode == 'en';
    if (action != null) {
      return _TruthClassification(
        status: 'pending',
        label: english ? '🟡 Proposed — not executed yet' : '🟡 مقترح — لم يُنفذ بعد',
        note: english
            ? 'Any change waits for manager approval and an actual NeoTask execution result.'
            : 'أي تغيير ينتظر اعتماد المدير ثم نتيجة تنفيذ فعلية من NeoTask.',
      );
    }
    if (mode == 'resilient-local') {
      return _TruthClassification(
        status: 'confirmed_local',
        label: english ? '✅ Calculated from available NeoTask data' : '✅ محسوب من بيانات NeoTask المتاحة',
        note: english
            ? 'This result comes from deterministic local logic and is not an execution claim.'
            : 'النتيجة صادرة من المسار المحلي الحتمي وليست ادعاء تنفيذ.',
      );
    }
    if (mode == 'multi-agent' || mode == 'ai-gateway') {
      return _TruthClassification(
        status: 'ai_analysis',
        label: english ? '🟡 AI analysis — not execution evidence' : '🟡 تحليل AI — ليس دليل تنفيذ',
        note: requestId == null || requestId.isEmpty
            ? english
                ? 'This is analysis; only the NeoTask audit log can prove execution.'
                : 'الرد تحليلي ويحتاج سجل NeoTask لإثبات أي تنفيذ.'
            : english
                ? 'A response ID is available, but only the NeoTask audit log proves execution.'
                : 'معرّف الاستجابة متاح، لكن التنفيذ لا يُثبت إلا بسجل NeoTask.',
      );
    }
    return _TruthClassification(
      status: 'unverified',
      label: english ? '🔴 Unverified' : '🔴 غير متحقق',
      note: english
          ? 'The response path could not be verified; do not treat it as execution evidence.'
          : 'لم يصل تصنيف موثوق لمسار الاستجابة؛ لا تعتمد عليه كدليل تنفيذ.',
    );
  }

  static String _messageForCode(String code, String languageCode) {
    final english = languageCode == 'en';
    switch (code) {
      case 'manager-only':
        return english ? 'This feature is available to managers only' : 'هذه الميزة متاحة للمدير فقط';
      case 'rate-limit':
        return english ? 'Too many requests. Try again in a minute' : 'تم إرسال طلبات كثيرة. حاول بعد دقيقة';
      case 'invalid-message':
        return english ? 'The request is empty or too long' : 'الطلب فارغ أو طويل جدًا';
      case 'missing-token':
      case 'invalid-token':
        return english ? 'Your session expired. Sign in again' : 'انتهت جلسة الدخول. سجّل الدخول مرة أخرى';
      default:
        return english ? 'The Manager AI Assistant is unavailable right now' : 'تعذر الاتصال بمساعد المدير الآن';
    }
  }
"""
text = replace_once(text, old_truth, new_truth, 'manager AI truth classification block')
path.write_text(text, encoding='utf-8')

# One untranslated tooltip in the employee shell.
path = Path('lib/screens/employee/employee_home_screen.dart')
text = path.read_text(encoding='utf-8')
text = replace_once(
    text,
    "message: 'الملف الشخصي والقائمة',",
    "message: context.tr('صورة الحساب والقائمة'),",
    'employee profile tooltip',
)
path.write_text(text, encoding='utf-8')

# ---------------------------------------------------------------------------
# 3) Poll card: localize all dynamic countdown/status lines, not only Text.
# ---------------------------------------------------------------------------
write('lib/widgets/poll_card.dart', r'''
import 'dart:async';
import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import '../models/poll_model.dart';
import '../theme/app_theme.dart';
import 'status_chip.dart' show AppPill;

class PollCard extends StatefulWidget {
  const PollCard({super.key, required this.poll, required this.onTap});

  final AppPoll poll;
  final VoidCallback onTap;

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    if (widget.poll.status == PollStatus.active) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final poll = widget.poll;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _accentColor(poll).withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  Icons.how_to_vote_outlined,
                  color: _accentColor(poll),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(poll.title, style: AppTextStyles.cardTitle),
                    if (poll.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        poll.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySecondary,
                      ),
                    ],
                    const SizedBox(height: 9),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _PollStatusBadge(poll: poll),
                        Text(
                          _secondaryLabel(context, poll),
                          style: AppTextStyles.bodySecondary.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _accentColor(AppPoll poll) {
    switch (poll.status) {
      case PollStatus.draft:
        return AppColors.textSecondary;
      case PollStatus.active:
        return AppColors.statusApproved;
      case PollStatus.cancelled:
        return AppColors.statusRejected;
      case PollStatus.ended:
        return (poll.isTie ?? false)
            ? AppColors.statusPending
            : AppColors.steel;
    }
  }

  String _secondaryLabel(BuildContext context, AppPoll poll) {
    switch (poll.status) {
      case PollStatus.draft:
        return '${context.tr('مسودة')} — ${context.tr('غير مرئي للموظفين')}';
      case PollStatus.active:
        return _countdownLabel(context, poll.deadline);
      case PollStatus.cancelled:
        return '${context.tr('أُلغي')}: ${_formatDateTime(poll.cancelledAt ?? poll.deadline)}';
      case PollStatus.ended:
        return '${context.tr('أُغلق')}: ${_formatDateTime(poll.endedAt ?? poll.deadline)}';
    }
  }

  String _countdownLabel(BuildContext context, DateTime deadline) {
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) return context.tr('ينتهي الآن...');
    final d = remaining.inDays;
    final h = remaining.inHours % 24;
    final m = remaining.inMinutes % 60;
    final s = remaining.inSeconds % 60;
    if (d > 0) {
      return '${context.tr('يتبقى')}: $d ${context.tr('يوم')} $h ${context.tr('ساعة')}';
    }
    if (h > 0) {
      return '${context.tr('يتبقى')}: $h ${context.tr('ساعة')} $m ${context.tr('دقيقة')}';
    }
    if (m > 0) {
      return '${context.tr('يتبقى')}: $m ${context.tr('دقيقة')} $s ${context.tr('ثانية')}';
    }
    return '${context.tr('يتبقى')}: $s ${context.tr('ثانية')}';
  }

  String _formatDateTime(DateTime dt) {
    final two = (int n) => n.toString().padLeft(2, '0');
    return '${dt.year}/${two(dt.month)}/${two(dt.day)} '
        '${two(dt.hour)}:${two(dt.minute)}';
  }
}

class _PollStatusBadge extends StatelessWidget {
  const _PollStatusBadge({required this.poll});

  final AppPoll poll;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final String label;
    switch (poll.status) {
      case PollStatus.draft:
        color = AppColors.textSecondary;
        label = 'مسودة';
        break;
      case PollStatus.active:
        color = AppColors.statusApproved;
        label = 'نشط';
        break;
      case PollStatus.cancelled:
        color = AppColors.statusRejected;
        label = 'مُلغى';
        break;
      case PollStatus.ended:
        if (poll.isTie ?? false) {
          color = AppColors.statusPending;
          label = 'منتهي - تعادل';
        } else {
          color = AppColors.steel;
          label = 'منتهي';
        }
        break;
    }
    return AppPill(color: color, label: label);
  }
}
''')

# ---------------------------------------------------------------------------
# 4) Employee polls: workspace metrics + proper empty state + modern list.
# ---------------------------------------------------------------------------
write('lib/screens/employee/employee_polls_tab.dart', r'''
import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:provider/provider.dart';
import '../../models/poll_model.dart';
import '../../providers/poll_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_workspace_chrome.dart';
import '../../widgets/poll_card.dart';
import 'employee_poll_vote_screen.dart';

class EmployeePollsTab extends StatelessWidget {
  const EmployeePollsTab({super.key, required this.employeeUid});

  final String employeeUid;

  @override
  Widget build(BuildContext context) {
    final polls = context.watch<PollProvider>().pollsForEmployee(employeeUid);
    final now = DateTime.now();
    final active = polls.where((poll) => poll.status == PollStatus.active).length;
    final ended = polls.where((poll) => poll.status == PollStatus.ended).length;
    final closingSoon = polls.where((poll) {
      if (poll.status != PollStatus.active) return false;
      final remaining = poll.deadline.difference(now);
      return !remaining.isNegative && remaining <= const Duration(hours: 24);
    }).length;

    void openPoll(AppPoll poll) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EmployeePollVoteScreen(
            pollId: poll.pollId,
            employeeUid: employeeUid,
          ),
        ),
      );
    }

    return SafeArea(
      child: Column(
        children: [
          NeoWorkspaceMetricsBar(
            items: [
              NeoWorkspaceMetric(
                label: 'إجمالي التصويتات',
                value: '${polls.length}',
                icon: Icons.how_to_vote_outlined,
                color: const Color(0xFF1F6FD2),
              ),
              NeoWorkspaceMetric(
                label: 'نشطة',
                value: '$active',
                icon: Icons.campaign_outlined,
                color: AppColors.mintAccent,
              ),
              NeoWorkspaceMetric(
                label: 'تغلق خلال 24 ساعة',
                value: '$closingSoon',
                icon: Icons.timer_outlined,
                color: AppColors.statusPending,
              ),
              NeoWorkspaceMetric(
                label: 'منتهية',
                value: '$ended',
                icon: Icons.fact_check_outlined,
                color: AppColors.steel,
              ),
            ],
          ),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: polls.isEmpty
                  ? const NeoWorkspaceEmptyState(
                      icon: Icons.how_to_vote_outlined,
                      title: 'لا توجد تصويتات موجّهة إليك حاليًا',
                      message: 'ستظهر هنا موضوعات التصويت التي تحتاج مشاركتك أو نتائجها بعد الإغلاق.',
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const NeoWorkspaceSectionHeader(
                          title: 'تصويتاتي',
                          subtitle: 'الموضوعات النشطة والسابقة في مكان واحد',
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            itemCount: polls.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: AppSpacing.md),
                            itemBuilder: (context, index) => PollCard(
                              poll: polls[index],
                              onTap: () => openPoll(polls[index]),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
''')

# ---------------------------------------------------------------------------
# 5) Poll archive: metrics + workspace shell.
# ---------------------------------------------------------------------------
write('lib/screens/manager/past_polls_screen.dart', r'''
import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:provider/provider.dart';
import '../../models/poll_model.dart';
import '../../providers/poll_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_workspace_chrome.dart';
import '../../widgets/poll_card.dart';
import 'manager_poll_detail_screen.dart';

class PastPollsScreen extends StatelessWidget {
  const PastPollsScreen({super.key, this.readOnly = false});

  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final polls = context.watch<PollProvider>().endedPolls;
    final ties = polls.where((poll) => poll.isTie == true).length;
    final decided = polls
        .where(
          (poll) => poll.winningChoiceIndex != null || poll.managerDecisionBy != null,
        )
        .length;
    final eligible = polls.fold<int>(
      0,
      (sum, poll) => sum + poll.participantUids.length,
    );

    void openPoll(AppPoll poll) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ManagerPollDetailScreen(
            pollId: poll.pollId,
            readOnly: readOnly,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'التصويتات السابقة',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            NeoWorkspaceMetricsBar(
              items: [
                NeoWorkspaceMetric(
                  label: 'إجمالي التصويتات',
                  value: '${polls.length}',
                  icon: Icons.archive_outlined,
                  color: const Color(0xFF1F6FD2),
                ),
                NeoWorkspaceMetric(
                  label: 'نتيجة محسومة',
                  value: '$decided',
                  icon: Icons.verified_outlined,
                  color: AppColors.mintAccent,
                ),
                NeoWorkspaceMetric(
                  label: 'تعادل',
                  value: '$ties',
                  icon: Icons.balance_outlined,
                  color: AppColors.statusPending,
                ),
                NeoWorkspaceMetric(
                  label: 'إجمالي المستحقّين',
                  value: '$eligible',
                  icon: Icons.groups_outlined,
                  color: AppColors.deepBlue,
                ),
              ],
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: polls.isEmpty
                    ? const NeoWorkspaceEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'لا توجد تصويتات سابقة بعد',
                        message: 'عند إغلاق أي تصويت سيبقى سجله ونتيجته هنا للرجوع إليه.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const NeoWorkspaceSectionHeader(
                            title: 'أرشيف القرارات',
                            subtitle: 'السجل الدائم للتصويتات المنتهية ونتائجها',
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              itemCount: polls.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) => PollCard(
                                poll: polls[index],
                                onTap: () => openPoll(polls[index]),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
''')

# ---------------------------------------------------------------------------
# 6) Favorites: modern focus workspace instead of plain ListTiles.
# ---------------------------------------------------------------------------
write('lib/screens/shared/favorites_screen.dart', r'''
import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';
import '../../models/task_model.dart';
import '../../providers/favorite_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/favorite_star_button.dart';
import '../../widgets/neo_workspace_chrome.dart';
import '../../widgets/status_chip.dart';
import '../../widgets/task_urgency_indicator.dart';
import '../designer/designer_task_view_screen.dart';
import '../employee/task_detail_screen.dart';
import '../manager/task_review_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    super.key,
    required this.currentUserUid,
    required this.isManager,
    this.readOnly = false,
  });

  final String currentUserUid;
  final bool isManager;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final favorites = context
        .watch<FavoriteProvider>()
        .favoritesForUser(currentUserUid);
    final tasks = favorites
        .map((favorite) => FirestoreService.getTask(favorite.taskId))
        .whereType<AppTask>()
        .toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));

    final completed = tasks
        .where((task) => task.status == TaskStatus.approved)
        .length;
    final overdue = tasks.where((task) => task.isOverdue).length;
    final active = tasks.length - completed;

    void openTask(AppTask task) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => readOnly
              ? DesignerTaskViewScreen(task: task)
              : isManager
                  ? TaskReviewDetailScreen(task: task)
                  : TaskDetailScreen(task: task),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'المفضلة',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            NeoWorkspaceMetricsBar(
              items: [
                NeoWorkspaceMetric(
                  label: 'إجمالي المفضلة',
                  value: '${tasks.length}',
                  icon: Icons.star_rounded,
                  color: AppColors.favoriteGold,
                ),
                NeoWorkspaceMetric(
                  label: 'مهام نشطة',
                  value: '$active',
                  icon: Icons.play_circle_outline_rounded,
                  color: AppColors.mintAccent,
                ),
                NeoWorkspaceMetric(
                  label: 'مكتملة',
                  value: '$completed',
                  icon: Icons.task_alt_rounded,
                  color: AppColors.steel,
                ),
                NeoWorkspaceMetric(
                  label: 'متأخرة',
                  value: '$overdue',
                  icon: Icons.schedule_rounded,
                  color: AppColors.overdue,
                ),
              ],
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: tasks.isEmpty
                    ? const NeoWorkspaceEmptyState(
                        icon: Icons.star_border_rounded,
                        title: 'لا توجد مهام مفضّلة حتى الآن',
                        message: 'استخدم النجمة في أي مهمة لتضيفها إلى مساحة التركيز السريع.',
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const NeoWorkspaceSectionHeader(
                            title: 'قائمة التركيز',
                            subtitle: 'المهام التي اخترت الرجوع إليها بسرعة',
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              itemCount: tasks.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) =>
                                  _FavoriteTaskCard(
                                task: tasks[index],
                                currentUserUid: currentUserUid,
                                readOnly: readOnly,
                                onTap: () => openTask(tasks[index]),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteTaskCard extends StatelessWidget {
  const _FavoriteTaskCard({
    required this.task,
    required this.currentUserUid,
    required this.readOnly,
    required this.onTap,
  });

  final AppTask task;
  final String currentUserUid;
  final bool readOnly;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF9FBFD),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.divider),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: TaskUrgencyDot(task: task),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: AppTextStyles.cardTitle.copyWith(
                              fontSize: 15,
                            ),
                          ),
                        ),
                        if (readOnly)
                          const Icon(
                            Icons.star_rounded,
                            color: AppColors.favoriteGold,
                          )
                        else
                          FavoriteStarButton(
                            userUid: currentUserUid,
                            taskId: task.taskId,
                            size: 21,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        StatusChip(statusName: task.status.name),
                        PriorityBadge(
                          priorityName: task.priority.name,
                          compact: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '${task.category} · ${intl.DateFormat('yyyy/MM/dd').format(task.dueDate)}',
                      style: AppTextStyles.bodySecondary,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(AppRadius.pill),
                            child: LinearProgressIndicator(
                              value: task.progressPercent / 100,
                              minHeight: 6,
                              backgroundColor: AppColors.divider,
                              color: AppColors.deepBlue,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        Text(
                          '${task.progressPercent}%',
                          style: AppTextStyles.bodySecondary.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
''')

# ---------------------------------------------------------------------------
# 7) Contacts: modern directory workspace, metrics and responsive add action.
# ---------------------------------------------------------------------------
write('lib/screens/shared/contacts_screen.dart', r'''
import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/contact_model.dart';
import '../../providers/contact_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_workspace_chrome.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({
    super.key,
    required this.currentUserUid,
    required this.isManager,
    this.readOnly = false,
  });

  final String currentUserUid;
  final bool isManager;
  final bool readOnly;

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _addContact() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final jobCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('جهة اتصال جديدة'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(labelText: context.tr('الاسم')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneCtrl,
                decoration: InputDecoration(labelText: context.tr('الهاتف')),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('البريد الإلكتروني'),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: jobCtrl,
                decoration: InputDecoration(
                  labelText: context.tr('المسمى الوظيفي'),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(labelText: context.tr('ملاحظات')),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              Navigator.pop(dialogContext, true);
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      await context.read<ContactProvider>().addContact(
        name: nameCtrl.text.trim(),
        phone: phoneCtrl.text.trim(),
        email: emailCtrl.text.trim(),
        jobTitle: jobCtrl.text.trim(),
        notes: notesCtrl.text.trim(),
        createdBy: widget.currentUserUid,
      );
    }
  }

  Future<void> _confirmDelete(ContactItem contact) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف جهة الاتصال'),
        content: Text('هل تريد حذف "${contact.name}"؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.statusRejected,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<ContactProvider>().deleteContact(contact.contactId);
    }
  }

  Future<void> _call(String phone) async {
    if (phone.isEmpty) return;
    await launchUrl(Uri.parse('tel:$phone'));
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ContactProvider>();
    final allContacts = provider.search('');
    final contacts = provider.search(_searchCtrl.text);
    final withPhone = allContacts.where((contact) => contact.phone.isNotEmpty).length;
    final withEmail = allContacts.where((contact) => contact.email.isNotEmpty).length;
    final compact = MediaQuery.sizeOf(context).width < 620;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'جهات الاتصال',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        actions: [
          if (!widget.readOnly)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: compact
                  ? IconButton.filled(
                      tooltip: context.tr('جهة اتصال جديدة'),
                      onPressed: _addContact,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.mintAccent,
                        foregroundColor: AppColors.navy,
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded),
                    )
                  : FilledButton.icon(
                      onPressed: _addContact,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.mintAccent,
                        foregroundColor: AppColors.navy,
                      ),
                      icon: const Icon(Icons.person_add_alt_1_rounded, size: 19),
                      label: const Text(
                        'جهة اتصال جديدة',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            NeoWorkspaceMetricsBar(
              items: [
                NeoWorkspaceMetric(
                  label: 'إجمالي جهات الاتصال',
                  value: '${allContacts.length}',
                  icon: Icons.people_alt_outlined,
                  color: const Color(0xFF1F6FD2),
                ),
                NeoWorkspaceMetric(
                  label: 'لديهم رقم هاتف',
                  value: '$withPhone',
                  icon: Icons.call_outlined,
                  color: AppColors.mintAccent,
                ),
                NeoWorkspaceMetric(
                  label: 'لديهم بريد إلكتروني',
                  value: '$withEmail',
                  icon: Icons.mail_outline_rounded,
                  color: AppColors.gold,
                ),
              ],
            ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const NeoWorkspaceSectionHeader(
                      title: 'دليل جهات الاتصال',
                      subtitle: 'ابحث واتصل بالجهات الداخلية والخارجية من مكان واحد',
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: TextField(
                        controller: _searchCtrl,
                        decoration: InputDecoration(
                          hintText: context.tr('ابحث بالاسم أو المسمى أو رقم الهاتف'),
                          prefixIcon: const Icon(Icons.search_rounded),
                          suffixIcon: _searchCtrl.text.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: context.tr('مسح البحث'),
                                  onPressed: () {
                                    _searchCtrl.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded),
                                ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: contacts.isEmpty
                          ? NeoWorkspaceEmptyState(
                              icon: _searchCtrl.text.isEmpty
                                  ? Icons.contacts_outlined
                                  : Icons.search_off_rounded,
                              title: _searchCtrl.text.isEmpty
                                  ? 'لا توجد جهات اتصال'
                                  : 'لا توجد نتائج مطابقة',
                              message: _searchCtrl.text.isEmpty
                                  ? 'أضف جهات الاتصال المهمة لفريقك لتكون متاحة من مكان واحد.'
                                  : 'جرّب اسمًا أو رقمًا مختلفًا.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(AppSpacing.lg),
                              itemCount: contacts.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: AppSpacing.md),
                              itemBuilder: (context, index) {
                                final contact = contacts[index];
                                final canDelete = !widget.readOnly &&
                                    (contact.createdBy == widget.currentUserUid ||
                                        widget.isManager);
                                return _ContactCard(
                                  contact: contact,
                                  canDelete: canDelete,
                                  onCall: () => _call(contact.phone),
                                  onDelete: () => _confirmDelete(contact),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.contact,
    required this.canDelete,
    required this.onCall,
    required this.onDelete,
  });

  final ContactItem contact;
  final bool canDelete;
  final VoidCallback onCall;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 23,
            backgroundColor: AppColors.deepBlue,
            foregroundColor: Colors.white,
            child: Text(
              contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  contact.name,
                  style: AppTextStyles.cardTitle.copyWith(fontSize: 15),
                ),
                if (contact.jobTitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(contact.jobTitle, style: AppTextStyles.bodySecondary),
                ],
                if (contact.phone.isNotEmpty || contact.email.isNotEmpty) ...[
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 7,
                    children: [
                      if (contact.phone.isNotEmpty)
                        _ContactFact(
                          icon: Icons.call_outlined,
                          value: contact.phone,
                        ),
                      if (contact.email.isNotEmpty)
                        _ContactFact(
                          icon: Icons.mail_outline_rounded,
                          value: contact.email,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (contact.phone.isNotEmpty)
            IconButton.filledTonal(
              tooltip: context.tr('اتصال'),
              onPressed: onCall,
              icon: const Icon(Icons.call_rounded),
            ),
          if (canDelete) ...[
            const SizedBox(width: 4),
            IconButton(
              tooltip: context.tr('حذف'),
              onPressed: onDelete,
              color: AppColors.statusRejected,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactFact extends StatelessWidget {
  const _ContactFact({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 5),
          Text(
            value,
            style: AppTextStyles.bodySecondary.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
''')

# ---------------------------------------------------------------------------
# 8) Global search: dedicated modern workspace with count metrics.
# ---------------------------------------------------------------------------
write('lib/screens/shared/search_screen.dart', r'''
import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:provider/provider.dart';
import '../../models/criterion_model.dart';
import '../../models/goal_model.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/criterion_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/neo_workspace_chrome.dart';
import '../../widgets/status_chip.dart';
import '../designer/designer_task_view_screen.dart';
import '../employee/task_detail_screen.dart';
import '../manager/employee_stats_detail_screen.dart';
import '../manager/task_review_detail_screen.dart';
import 'criterion_detail_screen.dart';
import 'goal_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim();
    final goalProvider = context.watch<GoalProvider>();
    final criterionProvider = context.watch<CriterionProvider>();
    final taskProvider = context.watch<TaskProvider>();

    List<AppUser> employees = [];
    List<Goal> goals = [];
    List<Criterion> criteria = [];
    List<AppTask> tasks = [];

    if (q.isNotEmpty) {
      final lower = q.toLowerCase();
      employees = FirestoreService.getAllEmployees()
          .where(
            (user) =>
                user.name.toLowerCase().contains(lower) ||
                user.employeeNumber.toLowerCase().contains(lower),
          )
          .toList();
      final employeeUids = employees.map((user) => user.uid).toSet();
      goals = goalProvider.allGoals
          .where((goal) => goal.title.toLowerCase().contains(lower))
          .toList();
      criteria = criterionProvider.allCriteria
          .where(
            (criterion) =>
                criterion.title.toLowerCase().contains(lower) ||
                criterion.assignees.any(employeeUids.contains),
          )
          .toList();
      tasks = taskProvider.allTasks
          .where(
            (task) =>
                task.title.toLowerCase().contains(lower) ||
                employeeUids.contains(task.assignedTo),
          )
          .toList();
    }

    final total = employees.length + goals.length + criteria.length + tasks.length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        centerTitle: false,
        title: const Text(
          'بحث شامل',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                decoration: InputDecoration(
                  hintText: context.tr(
                    'ابحث عن معيار، هدف، موظف، أو أعمال موظف...',
                  ),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: q.isEmpty
                      ? null
                      : IconButton(
                          tooltip: context.tr('مسح البحث'),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
            if (q.isNotEmpty)
              NeoWorkspaceMetricsBar(
                items: [
                  NeoWorkspaceMetric(
                    label: 'موظفون',
                    value: '${employees.length}',
                    icon: Icons.people_alt_outlined,
                    color: const Color(0xFF1F6FD2),
                  ),
                  NeoWorkspaceMetric(
                    label: 'أهداف',
                    value: '${goals.length}',
                    icon: Icons.flag_outlined,
                    color: AppColors.gold,
                  ),
                  NeoWorkspaceMetric(
                    label: 'معايير',
                    value: '${criteria.length}',
                    icon: Icons.checklist_rtl_outlined,
                    color: const Color(0xFF7656C8),
                  ),
                  NeoWorkspaceMetric(
                    label: 'مهام',
                    value: '${tasks.length}',
                    icon: Icons.task_alt_outlined,
                    color: AppColors.mintAccent,
                  ),
                ],
              ),
            Expanded(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: AppColors.divider)),
                ),
                child: q.isEmpty
                    ? const NeoWorkspaceEmptyState(
                        icon: Icons.manage_search_rounded,
                        title: 'ابحث في NeoTask',
                        message: 'اكتب اسم موظف أو رقمًا وظيفيًا أو عنوان هدف أو معيار أو مهمة.',
                      )
                    : total == 0
                        ? const NeoWorkspaceEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'لا توجد نتائج مطابقة',
                            message: 'جرّب كلمة أقصر أو اسمًا أو رقمًا مختلفًا.',
                          )
                        : ListView(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            children: [
                              if (employees.isNotEmpty)
                                _SearchSection(
                                  title: 'موظفون',
                                  icon: Icons.people_alt_outlined,
                                  children: employees
                                      .map((user) => _EmployeeResultTile(user: user))
                                      .toList(),
                                ),
                              if (goals.isNotEmpty)
                                _SearchSection(
                                  title: 'أهداف',
                                  icon: Icons.flag_outlined,
                                  children: goals
                                      .map(
                                        (goal) => _ResultTile(
                                          icon: Icons.flag_outlined,
                                          title: goal.title,
                                          onTap: () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => GoalDetailScreen(
                                                goalId: goal.goalId,
                                              ),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              if (criteria.isNotEmpty)
                                _SearchSection(
                                  title: 'معايير',
                                  icon: Icons.checklist_rtl_outlined,
                                  children: criteria
                                      .map(
                                        (criterion) => _CriterionResultTile(
                                          criterion: criterion,
                                        ),
                                      )
                                      .toList(),
                                ),
                              if (tasks.isNotEmpty)
                                _SearchSection(
                                  title: 'مهام',
                                  icon: Icons.task_alt_outlined,
                                  children: tasks
                                      .map((task) => _TaskResultTile(task: task))
                                      .toList(),
                                ),
                            ],
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchSection extends StatelessWidget {
  const _SearchSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.lg),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FBFD),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          NeoWorkspaceSectionHeader(
            title: title,
            trailing: Icon(icon, color: AppColors.deepBlue, size: 20),
          ),
          const Divider(height: 1),
          ...children,
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final Widget? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.deepBlue.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
        child: Icon(icon, color: AppColors.deepBlue, size: 20),
      ),
      title: Text(title, style: AppTextStyles.cardTitle),
      subtitle: subtitle,
      trailing: const Icon(
        Icons.arrow_forward_ios_rounded,
        size: 15,
        color: AppColors.textSecondary,
      ),
      onTap: onTap,
    );
  }
}

class _EmployeeResultTile extends StatelessWidget {
  const _EmployeeResultTile({required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final canOpenStats = auth.isManager || auth.isDesigner;
    final criterionCount = context
        .read<CriterionProvider>()
        .criteriaForEmployee(user.uid)
        .length;
    final taskCount = context.read<TaskProvider>().tasksForEmployee(user.uid).length;
    final subtitle = '${context.tr('رقم وظيفي')}: ${user.employeeNumber} • '
        '$taskCount ${context.tr('مهام')} • '
        '$criterionCount ${context.tr('معايير')}';

    return _ResultTile(
      icon: Icons.person_outline_rounded,
      title: user.name,
      subtitle: Text(subtitle, style: AppTextStyles.bodySecondary),
      onTap: canOpenStats
          ? () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => EmployeeStatsDetailScreen(employee: user),
                ),
              )
          : () {},
    );
  }
}

class _CriterionResultTile extends StatelessWidget {
  const _CriterionResultTile({required this.criterion});

  final Criterion criterion;

  @override
  Widget build(BuildContext context) {
    return _ResultTile(
      icon: Icons.checklist_rtl_outlined,
      title: criterion.title,
      subtitle: Align(
        alignment: AlignmentDirectional.centerStart,
        child: StatusChip(
          statusName: criterion.aggregateStatus.name,
          fontSize: 10,
        ),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CriterionDetailScreen(
            goalId: criterion.goalId,
            criterionId: criterion.criterionId,
          ),
        ),
      ),
    );
  }
}

class _TaskResultTile extends StatelessWidget {
  const _TaskResultTile({required this.task});

  final AppTask task;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final Widget destination = auth.isDesigner
        ? DesignerTaskViewScreen(task: task)
        : auth.isManager
            ? TaskReviewDetailScreen(task: task)
            : TaskDetailScreen(task: task);
    return _ResultTile(
      icon: Icons.task_outlined,
      title: task.title,
      subtitle: Wrap(
        spacing: 6,
        runSpacing: 5,
        children: [
          StatusChip(statusName: task.status.name, fontSize: 10),
          PriorityBadge(priorityName: task.priority.name, compact: true),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => destination),
      ),
    );
  }
}
''')

# ---------------------------------------------------------------------------
# 9) Add translations for refreshed workspaces + Manager AI static chrome.
# ---------------------------------------------------------------------------
path = Path('lib/l10n/app_i18n.dart')
text = path.read_text(encoding='utf-8')
marker = "    // Extended screen copy\n"
translation_block = """    // Workspace refresh + Manager AI
    'مساعد المدير الذكي': 'Manager AI Assistant',
    'يحلل الطلب ويعرض الإجراء قبل التنفيذ': 'Analyzes requests and previews actions before execution',
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
    'دليل لما حفظه أو أنشأه الوكيل فعليًا': 'Evidence of what the agent actually saved or created',
    'تعذر تحميل سجل عمليات المساعد': 'Could not load the assistant activity log',
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
    'هذه القاعدة تؤثر على طلبات الوكيل القادمة.': 'This rule affects future agent requests.',
    'حذف هذا السجل القديم لا يضمن إيقاف القاعدة.': 'Deleting this legacy record does not guarantee the rule is disabled.',
    'اكتب طلبك لمساعد المدير...': 'Ask the Manager AI Assistant…',
    'وضع العرض فقط': 'View-only mode',
    'إضافة للمفضلة': 'Add to favorites',
    'إزالة من المفضلة': 'Remove from favorites',
    'إجمالي المفضلة': 'Total favorites',
    'استخدم النجمة في أي مهمة لتضيفها إلى مساحة التركيز السريع.': 'Use the star on any task to add it to your quick-focus workspace.',
    'المهام التي اخترت الرجوع إليها بسرعة': 'Tasks you chose for quick access',
    'إجمالي جهات الاتصال': 'Total contacts',
    'لديهم رقم هاتف': 'With phone number',
    'لديهم بريد إلكتروني': 'With email',
    'دليل جهات الاتصال': 'Contact directory',
    'ابحث واتصل بالجهات الداخلية والخارجية من مكان واحد': 'Search and call internal and external contacts from one place',
    'ابحث بالاسم أو المسمى أو رقم الهاتف': 'Search by name, job title, or phone number',
    'مسح البحث': 'Clear search',
    'أضف جهات الاتصال المهمة لفريقك لتكون متاحة من مكان واحد.': 'Add important team contacts so they are available in one place.',
    'جرّب اسمًا أو رقمًا مختلفًا.': 'Try a different name or number.',
    'اتصال': 'Call',
    'تغلق خلال 24 ساعة': 'Closing within 24 hours',
    'تصويتاتي': 'My polls',
    'الموضوعات النشطة والسابقة في مكان واحد': 'Active and past poll topics in one place',
    'ستظهر هنا موضوعات التصويت التي تحتاج مشاركتك أو نتائجها بعد الإغلاق.': 'Polls that need your participation, or their results after closing, will appear here.',
    'نتيجة محسومة': 'Resolved result',
    'تعادل': 'Tie',
    'أرشيف القرارات': 'Decision archive',
    'السجل الدائم للتصويتات المنتهية ونتائجها': 'Permanent archive of closed polls and their results',
    'عند إغلاق أي تصويت سيبقى سجله ونتيجته هنا للرجوع إليه.': 'When a poll closes, its record and result remain here for reference.',
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
    'اكتب اسم موظف أو رقمًا وظيفيًا أو عنوان هدف أو معيار أو مهمة.': 'Enter an employee name or ID, or a goal, criterion, or task title.',
    'جرّب كلمة أقصر أو اسمًا أو رقمًا مختلفًا.': 'Try a shorter keyword, name, or number.',
    'رقم وظيفي': 'Employee ID',
"""
if "    // Workspace refresh + Manager AI\n" not in text:
    text = replace_once(text, marker, translation_block + marker, 'i18n workspace marker')
path.write_text(text, encoding='utf-8')

print('NeoTask workspace refresh applied')
