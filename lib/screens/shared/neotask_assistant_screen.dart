import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../theme/app_theme.dart';

enum _HelpAudience { all, manager, employee, managerOrDesigner }

class _HelpTopic {
  const _HelpTopic({
    required this.title,
    required this.group,
    required this.icon,
    required this.purpose,
    required this.steps,
    required this.permission,
    required this.result,
    this.tip,
    this.keywords = const [],
    this.audience = _HelpAudience.all,
  });

  final String title;
  final String group;
  final IconData icon;
  final String purpose;
  final List<String> steps;
  final String permission;
  final String result;
  final String? tip;
  final List<String> keywords;
  final _HelpAudience audience;
}

/// Role-aware, explain-only product guide for NeoTask.
///
/// The assistant intentionally performs no writes and invokes no business
/// actions. Its catalogue mirrors the actual navigation and common action
/// icons so users can understand a control before using it.
class NeoTaskAssistantScreen extends StatefulWidget {
  const NeoTaskAssistantScreen({super.key});

  @override
  State<NeoTaskAssistantScreen> createState() =>
      _NeoTaskAssistantScreenState();
}

class _NeoTaskAssistantScreenState extends State<NeoTaskAssistantScreen> {
  final _questionController = TextEditingController();
  final _answerKey = GlobalKey();
  _HelpTopic? _selectedTopic;
  List<_HelpTopic> _suggestions = const [];
  String? _unmatchedQuestion;

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  List<_HelpTopic> _visibleTopics(AuthProvider auth) {
    return _topics.where((topic) {
      return switch (topic.audience) {
        _HelpAudience.all => true,
        _HelpAudience.manager => auth.isManager,
        _HelpAudience.employee => auth.isEmployee,
        _HelpAudience.managerOrDesigner => auth.isManager || auth.isDesigner,
      };
    }).toList(growable: false);
  }

  void _selectTopic(_HelpTopic topic, {bool scroll = true}) {
    setState(() {
      _selectedTopic = topic;
      _suggestions = const [];
      _unmatchedQuestion = null;
    });
    if (scroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final answerContext = _answerKey.currentContext;
        if (answerContext != null) {
          Scrollable.ensureVisible(
            answerContext,
            duration: AppMotion.slow,
            curve: AppMotion.standard,
            alignment: .05,
          );
        }
      });
    }
  }

  void _answerQuestion(List<_HelpTopic> visibleTopics) {
    FocusScope.of(context).unfocus();
    final rawQuestion = _questionController.text.trim();
    if (rawQuestion.isEmpty) return;

    final query = _normalize(rawQuestion);
    final ranked = visibleTopics
        .map((topic) => (topic: topic, score: _score(topic, query)))
        .where((match) => match.score > 0)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    if (ranked.isNotEmpty && ranked.first.score >= 5) {
      _selectTopic(ranked.first.topic);
      return;
    }

    setState(() {
      _selectedTopic = null;
      _unmatchedQuestion = rawQuestion;
      _suggestions = ranked.take(3).map((match) => match.topic).toList();
    });
  }

  static int _score(_HelpTopic topic, String query) {
    final title = _normalize(topic.title);
    if (query == title) return 100;
    if (query.contains(title)) return 50;

    var score = title.split(' ').where(query.contains).length * 4;
    for (final keyword in topic.keywords) {
      final normalizedKeyword = _normalize(keyword);
      if (query.contains(normalizedKeyword)) {
        score += normalizedKeyword.contains(' ') ? 8 : 5;
      }
    }
    return score;
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .replaceAll(RegExp(r'[ًٌٍَُِّْـ]'), '')
        .replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9 ]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final visibleTopics = _visibleTopics(auth);
    final groups = <String, List<_HelpTopic>>{};
    for (final topic in visibleTopics) {
      groups.putIfAbsent(topic.group, () => []).add(topic);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('مساعد NeoTask'),
        actions: const [
          Padding(
            padding: EdgeInsetsDirectional.only(end: AppSpacing.lg),
            child: Icon(Icons.support_agent_rounded, color: AppColors.goldLight),
          ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontalPadding = constraints.maxWidth >= 900
                ? (constraints.maxWidth - 860) / 2
                : AppSpacing.lg;
            return ListView(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                AppSpacing.xl,
                horizontalPadding,
                AppSpacing.xxl,
              ),
              children: [
                _AssistantIntro(
                  name: auth.currentUser?.name ?? '',
                  roleDescription: auth.isManager
                      ? 'سأشرح لك أدوات المدير وإجراءات إدارة الفريق.'
                      : auth.isDesigner
                      ? 'سأشرح لك الواجهات وحدود صلاحية العرض فقط.'
                      : 'سأشرح لك أدوات الموظف وطريقة إنجاز المهام.',
                ),
                const SizedBox(height: AppSpacing.lg),
                _QuestionBox(
                  controller: _questionController,
                  onSubmitted: (_) => _answerQuestion(visibleTopics),
                  onSend: () => _answerQuestion(visibleTopics),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_selectedTopic != null)
                  KeyedSubtree(
                    key: _answerKey,
                    child: _TopicExplanation(topic: _selectedTopic!),
                  )
                else if (_unmatchedQuestion != null)
                  KeyedSubtree(
                    key: _answerKey,
                    child: _NoExactAnswer(
                      question: _unmatchedQuestion!,
                      suggestions: _suggestions,
                      onSelect: _selectTopic,
                    ),
                  ),
                if (_selectedTopic != null || _unmatchedQuestion != null)
                  const SizedBox(height: AppSpacing.xxl),
                const _SectionHeading(
                  title: 'اختر ما تريد شرحه',
                  subtitle: 'الموضوعات الظاهرة مطابقة لصلاحية حسابك الحالية.',
                ),
                const SizedBox(height: AppSpacing.md),
                for (final entry in groups.entries) ...[
                  _TopicGroup(
                    title: entry.key,
                    topics: entry.value,
                    selectedTopic: _selectedTopic,
                    onSelect: _selectTopic,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _AssistantIntro extends StatelessWidget {
  const _AssistantIntro({required this.name, required this.roleDescription});

  final String name;
  final String roleDescription;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.navy,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppElevation.mediumShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: .16),
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: AppColors.goldLight.withValues(alpha: .35),
              ),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: AppColors.goldLight,
              size: 27,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty
                      ? 'مرحبًا، أنا مساعد NeoTask'
                      : 'مرحبًا $name، أنا مساعد NeoTask',
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'اختر أي تبويب أو أيقونة، أو اكتب اسمها، وسأوضح وظيفتها وطريقة استخدامها وما الذي يحدث بعدها. $roleDescription',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: .72),
                    fontFamily: 'IBMPlexSansArabic',
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionBox extends StatelessWidget {
  const _QuestionBox({
    required this.controller,
    required this.onSubmitted,
    required this.onSend,
  });

  final TextEditingController controller;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      textField: true,
      label: 'اسأل مساعد NeoTask عن تبويب أو أيقونة',
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
        decoration: InputDecoration(
          hintText: 'مثال: اشرح لي أيقونة المراجعة',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            tooltip: 'عرض الشرح',
            onPressed: onSend,
            icon: const Icon(Icons.send_rounded),
          ),
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppTextStyles.screenTitle),
        const SizedBox(height: AppSpacing.xs),
        Text(subtitle, style: AppTextStyles.bodySecondary),
      ],
    );
  }
}

class _TopicGroup extends StatelessWidget {
  const _TopicGroup({
    required this.title,
    required this.topics,
    required this.selectedTopic,
    required this.onSelect,
  });

  final String title;
  final List<_HelpTopic> topics;
  final _HelpTopic? selectedTopic;
  final ValueChanged<_HelpTopic> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppSpacing.xs,
              bottom: AppSpacing.sm,
            ),
            child: Text(title, style: AppTextStyles.sectionLabel),
          ),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: topics.map((topic) {
              final selected = identical(topic, selectedTopic);
              return ActionChip(
                avatar: Icon(
                  topic.icon,
                  size: 17,
                  color: selected ? Colors.white : AppColors.deepBlue,
                ),
                label: Text(topic.title),
                labelStyle: TextStyle(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontFamily: 'IBMPlexSansArabic',
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor:
                    selected ? AppColors.deepBlue : Colors.white,
                side: BorderSide(
                  color: selected ? AppColors.deepBlue : AppColors.divider,
                ),
                onPressed: () => onSelect(topic),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _TopicExplanation extends StatelessWidget {
  const _TopicExplanation({required this.topic});

  final _HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.gold.withValues(alpha: .36)),
        boxShadow: AppElevation.lowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: const BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg - 1),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                  child: Icon(topic.icon, color: AppColors.goldLight),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'شرح مساعد NeoTask',
                        style: TextStyle(
                          color: AppColors.goldLight,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        topic.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'IBMPlexSansArabic',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _ExplanationSection(
                  icon: Icons.info_outline_rounded,
                  title: 'وظيفتها',
                  child: Text(topic.purpose, style: AppTextStyles.body),
                ),
                _ExplanationSection(
                  icon: Icons.format_list_numbered_rounded,
                  title: 'طريقة الاستخدام',
                  child: Column(
                    children: [
                      for (var index = 0; index < topic.steps.length; index++)
                        _NumberedStep(
                          number: index + 1,
                          text: topic.steps[index],
                        ),
                    ],
                  ),
                ),
                _ExplanationSection(
                  icon: Icons.admin_panel_settings_outlined,
                  title: 'الصلاحية',
                  child: Text(topic.permission, style: AppTextStyles.body),
                ),
                _ExplanationSection(
                  icon: Icons.task_alt_rounded,
                  title: 'النتيجة',
                  child: Text(topic.result, style: AppTextStyles.body),
                ),
                if (topic.tip != null)
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: .08),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.tips_and_updates_outlined,
                          size: 19,
                          color: AppColors.gold,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            topic.tip!,
                            style: AppTextStyles.bodySecondary.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExplanationSection extends StatelessWidget {
  const _ExplanationSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 19, color: AppColors.deepBlue),
              const SizedBox(width: AppSpacing.sm),
              Text(title, style: AppTextStyles.cardTitle),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsetsDirectional.only(start: 27),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _NumberedStep extends StatelessWidget {
  const _NumberedStep({required this.number, required this.text});

  final int number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 23,
            height: 23,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: AppColors.deepBlue,
              shape: BoxShape.circle,
            ),
            child: Text(
              '$number',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(text, style: AppTextStyles.body)),
        ],
      ),
    );
  }
}

class _NoExactAnswer extends StatelessWidget {
  const _NoExactAnswer({
    required this.question,
    required this.suggestions,
    required this.onSelect,
  });

  final String question;
  final List<_HelpTopic> suggestions;
  final ValueChanged<_HelpTopic> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.support_agent_rounded, color: AppColors.deepBlue),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'أحتاج تحديد الأيقونة أو التبويب',
                  style: AppTextStyles.cardTitle,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'لم أجد تطابقًا مؤكدًا لسؤالك «$question». اكتب اسم الأيقونة كما يظهر في NeoTask أو اخترها من القائمة أدناه.',
            style: AppTextStyles.bodySecondary,
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Text('هل تقصد:', style: AppTextStyles.cardTitle),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: suggestions
                  .map(
                    (topic) => ActionChip(
                      avatar: Icon(topic.icon, size: 17),
                      label: Text(topic.title),
                      onPressed: () => onSelect(topic),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

const List<_HelpTopic> _topics = [
  _HelpTopic(
    title: 'ملخص المدير',
    group: 'التبويبات الرئيسية',
    icon: Icons.insights_outlined,
    purpose:
        'يعرض في أعلى القائمة الجانبية أهم الحالات التي تحتاج انتباه المدير دون فتح لوحة التحكم.',
    steps: [
      'افتح القائمة الجانبية من صورة الحساب أو زر القائمة.',
      'راجع أعداد قيد الانتظار وبانتظار المراجعة والمهام المتأخرة.',
      'اضغط «ملخص المدير» لفتح نص ملخص اليوم أو الأسبوع وإغلاقه.',
    ],
    permission: 'يظهر للمدير فقط، ولا يظهر للموظف أو المصمم.',
    result:
        'يحصل المدير على قراءة تشغيلية سريعة من البيانات نفسها المستخدمة في لوحة التحكم.',
    tip: 'عبارة «تحديث مباشر» تعني أن الأرقام تتغير مع بيانات المهام الحالية.',
    keywords: ['الملخص', 'ملخص اليوم', 'ملخص الاسبوع', 'قيد الانتظار'],
    audience: _HelpAudience.manager,
  ),
  _HelpTopic(
    title: 'الرئيسية',
    group: 'التبويبات الرئيسية',
    icon: Icons.home_outlined,
    purpose: 'تعرض ملخص العمل الحالي والمؤشرات المهمة، وتجمع لك أسرع الطرق للوصول إلى المهام التي تحتاج متابعة.',
    steps: [
      'افتح «الرئيسية» من شريط التنقل.',
      'اختر الفترة الزمنية إذا كانت متاحة، ثم راجع البطاقات والمؤشرات.',
      'اضغط على المؤشر أو المهمة للانتقال إلى تفاصيلها.',
    ],
    permission: 'تظهر لجميع الحسابات، لكن محتواها يتغير بحسب دور المستخدم وصلاحياته.',
    result: 'تحصل على صورة سريعة للحالة الحالية دون فتح كل شاشة منفصلة.',
    keywords: ['لوحه التحكم', 'داشبورد', 'الصفحه الرئيسيه', 'البيت'],
  ),
  _HelpTopic(
    title: 'المراجعة',
    group: 'التبويبات الرئيسية',
    icon: Icons.fact_check_outlined,
    purpose: 'تجمع المهام التي أرسلها الموظفون بعد الإنجاز وتنتظر قرار المدير.',
    steps: [
      'افتح «المراجعة» لترى المهام المرسلة.',
      'افتح المهمة وراجع نسبة الإنجاز والملاحظات والمرفقات والمحادثة.',
      'اعتمد المهمة إذا اكتملت، أو أعدها للموظف مع ملاحظة واضحة عند الحاجة.',
    ],
    permission: 'القرار متاح للمدير. المصمم يستطيع العرض فقط ولا يعتمد أو يعيد مهمة.',
    result: 'ينتقل وضع المهمة بحسب القرار، ويظهر القرار ضمن سجلها للمتابعة.',
    tip: 'رقم الشارة على الأيقونة هو عدد المهام المنتظرة للمراجعة.',
    keywords: ['اعتماد', 'رفض', 'ارجاع', 'بانتظار المراجعه', 'تدقيق المهمه'],
    audience: _HelpAudience.managerOrDesigner,
  ),
  _HelpTopic(
    title: 'الموظفون',
    group: 'التبويبات الرئيسية',
    icon: Icons.groups_outlined,
    purpose: 'إدارة حسابات الفريق ومتابعة حالة كل موظف والمهام والإحصاءات المرتبطة به.',
    steps: [
      'افتح «الموظفون» لرؤية الحسابات والطلبات المعلقة.',
      'اختر موظفًا لعرض بياناته وإحصاءاته أو إدارة حسابه.',
      'استخدم الإجراء المطلوب مثل الموافقة على الحساب أو تحديث البيانات حسب الصلاحية.',
    ],
    permission: 'الإدارة للمدير فقط، بينما حساب المصمم يعرض البيانات دون تعديل.',
    result: 'تتحدث حالة الحساب أو بيانات الموظف وتنعكس على صلاحية دخوله وظهوره في الفريق.',
    tip: 'الشارة تعني وجود حسابات موظفين تنتظر موافقة المدير.',
    keywords: ['الموظفين', 'اضافه موظف', 'حساب موظف', 'قبول الموظف', 'الفريق'],
    audience: _HelpAudience.managerOrDesigner,
  ),
  _HelpTopic(
    title: 'التقارير',
    group: 'التبويبات الرئيسية',
    icon: Icons.bar_chart_outlined,
    purpose: 'إنشاء تقارير تشغيلية عن المهام والإنجاز والتأخر حسب الفترة أو الموظف.',
    steps: [
      'افتح «التقارير».',
      'اختر نوع التقرير والفترة أو الموظف المطلوب.',
      'راجع النتائج ثم استخدم خيارات التصدير أو الطباعة المتاحة.',
    ],
    permission: 'المدير ينشئ ويصدر التقارير، والمصمم يطّلع عليها بصلاحية القراءة فقط.',
    result: 'يظهر تقرير مركز يساعد في المتابعة واتخاذ القرار.',
    keywords: ['تقرير', 'احصائيات', 'طباعه', 'تصدير', 'اداء'],
    audience: _HelpAudience.managerOrDesigner,
  ),
  _HelpTopic(
    title: 'المحادثات',
    group: 'التبويبات الرئيسية',
    icon: Icons.chat_bubble_outline,
    purpose: 'عرض المحادثات المرتبطة بالعمل والتواصل مع الأطراف المصرح بها داخل NeoTask.',
    steps: [
      'افتح «المحادثات».',
      'اختر المحادثة أو المهمة المرتبطة بها.',
      'اكتب الرسالة أو أرفق الملف ثم أرسلها.',
    ],
    permission: 'متاحة للحسابات المسجلة ضمن نطاق المحادثات التي يحق لكل حساب رؤيتها.',
    result: 'تُحفظ الرسالة داخل المحادثة ويظهر تنبيه للطرف الآخر.',
    tip: 'الشارة على الأيقونة تعرض عدد الرسائل غير المقروءة.',
    keywords: ['المحادثه', 'شات', 'رساله', 'رسائل', 'تعليق'],
  ),
  _HelpTopic(
    title: 'مهامي',
    group: 'التبويبات الرئيسية',
    icon: Icons.checklist_outlined,
    purpose: 'تعرض كل المهام المسندة للموظف مع حالتها وأولويتها وموعد استحقاقها.',
    steps: [
      'افتح «مهامي» واختر الفترة أو حالة المهمة.',
      'افتح المهمة لقراءة التعليمات وتحديث نسبة الإنجاز وإضافة ملاحظة أو مرفق.',
      'عند اكتمال العمل أرسل المهمة للمراجعة.',
    ],
    permission: 'متاحة للموظف، ويستطيع تحديث المهام المسندة إليه فقط.',
    result: 'يُحفظ التقدم، وعند الإرسال تنتقل المهمة إلى قائمة مراجعة المدير.',
    keywords: ['مهمتي', 'المهام', 'انجاز', 'ارسال للمراجعه', 'نسبه الانجاز'],
    audience: _HelpAudience.employee,
  ),
  _HelpTopic(
    title: 'التقويم',
    group: 'التخطيط والتنفيذ',
    icon: Icons.calendar_month_outlined,
    purpose: 'يعرض المهام والمواعيد على تقويم زمني لمعرفة ما هو قادم وما تأخر.',
    steps: [
      'افتح «التقويم».',
      'انتقل بين الأيام أو الأسابيع أو الأشهر.',
      'اضغط على الحدث لفتح تفاصيله، ويستطيع المدير إدارة الأحداث المتاحة له.',
    ],
    permission: 'الموظف يرى عناصره، والمدير يدير تقويم العمل، والمصمم يعرضه فقط.',
    result: 'تظهر المواعيد حسب تاريخها لتسهيل التخطيط ومنع نسيان الاستحقاقات.',
    keywords: ['تاريخ', 'موعد', 'مواعيد', 'استحقاق', 'كالندر'],
  ),
  _HelpTopic(
    title: 'تصويت',
    group: 'التبويبات الرئيسية',
    icon: Icons.how_to_vote_outlined,
    purpose: 'يعرض التصويتات المتاحة للموظف ويتيح تسجيل اختياره خلال الفترة المحددة.',
    steps: [
      'افتح «تصويت» واختر التصويت النشط.',
      'اقرأ السؤال والخيارات وموعد الإغلاق.',
      'حدد اختيارك ثم أكّد التصويت.',
    ],
    permission: 'الموظف يصوّت في التصويتات التي أدرجه المدير ضمن المستحقين لها.',
    result: 'يُسجل الاختيار ويُحتسب ضمن النتيجة وفق إعدادات خصوصية التصويت.',
    keywords: ['التصويت', 'اختيار', 'صوت', 'استطلاع'],
    audience: _HelpAudience.employee,
  ),
  _HelpTopic(
    title: 'خطة العمل',
    group: 'التخطيط والتنفيذ',
    icon: Icons.view_timeline_outlined,
    purpose: 'تنظم المهام على خط زمني وتوضح ترابط المهام الرئيسية والفرعية وعبء العمل على الموظفين.',
    steps: [
      'افتح «خطة العمل» واختر الخط الزمني أو عبء العمل.',
      'أنشئ مهمة أو افتح مهمة موجودة وحدد تواريخها وعلاقتها بالمهمة الرئيسية.',
      'راجع التداخلات والسعة الأسبوعية ثم عدّل التوزيع عند الحاجة.',
    ],
    permission: 'المدير ينشئ ويعدّل، والمصمم يعرض الخطة فقط.',
    result: 'تظهر الخطة زمنيًا ويصبح توزيع العمل والاعتماد بين المهام واضحًا.',
    keywords: ['الخطه', 'الخط الزمني', 'عبء العمل', 'تايم لاين', 'مهمه رئيسيه'],
    audience: _HelpAudience.managerOrDesigner,
  ),
  _HelpTopic(
    title: 'الأتمتة الشرطية',
    group: 'التخطيط والتنفيذ',
    icon: Icons.bolt_outlined,
    purpose: 'تشغّل إجراءات تلقائية عند تحقق شروط محددة، مثل تغير حالة مهمة أو اقتراب موعدها.',
    steps: [
      'افتح «الأتمتة الشرطية» وأنشئ قاعدة جديدة.',
      'حدد الحدث والشرط والإجراء الناتج بدقة.',
      'راجع القاعدة ثم فعّلها وراقب سجل تشغيلها.',
    ],
    permission: 'الإنشاء والتعديل للمدير، والمصمم يطّلع على القواعد دون تشغيل أو تغيير.',
    result: 'ينفذ NeoTask الإجراء تلقائيًا عند تحقق الشرط الفعلي.',
    tip: 'اجعل الشرط محددًا وتأكد من عدم تكرار قاعدة تؤدي الإجراء نفسه.',
    keywords: ['اتمته', 'قاعده', 'شرط', 'تلقائي', 'اوتوميشن'],
    audience: _HelpAudience.managerOrDesigner,
  ),
  _HelpTopic(
    title: 'الأهداف',
    group: 'التخطيط والتنفيذ',
    icon: Icons.flag_outlined,
    purpose: 'تحوّل النتائج المطلوبة إلى أهداف قابلة للقياس بمعايير واضحة وتقدم يمكن متابعته.',
    steps: [
      'افتح «الأهداف» واختر هدفًا أو أنشئ هدفًا إذا كانت صلاحيتك تسمح.',
      'راجع المعايير ونسب الإنجاز والمسؤولين والمواعيد.',
      'حدّث تقدم المعيار وأضف الملاحظات أو النقاش المرتبط به.',
    ],
    permission: 'الظهور متاح بحسب عضوية المستخدم في الهدف، وإجراءات الإنشاء والتعديل تحكمها الصلاحيات داخل الهدف.',
    result: 'يتحدث تقدم الهدف وتبقى تفاصيل كل معيار موثقة وقابلة للمتابعة.',
    keywords: ['هدف', 'معيار', 'مؤشر', 'نسبه الهدف', 'okr'],
  ),
  _HelpTopic(
    title: 'مهامي الشخصية',
    group: 'التخطيط والتنفيذ',
    icon: Icons.checklist_rounded,
    purpose: 'مساحة للمدير لتنظيم مهامه الخاصة بعيدًا عن مهام الفريق، مع إمكانية تطوير المهمة لاحقًا إلى عمل مشترك.',
    steps: [
      'افتح «مهامي الشخصية» واضغط إضافة مهمة.',
      'اكتب العنوان والتفاصيل والموعد ثم احفظ.',
      'افتح المهمة لاحقًا لتعديلها أو التعليق عليها أو تحويلها لموظف أو فريق.',
    ],
    permission: 'متاحة للمدير، والمصمم يطّلع عليها وفق وضع القراءة فقط.',
    result: 'تُحفظ المهمة ضمن مساحة المدير، وإذا حُولت تصبح جزءًا من سير عمل الفريق.',
    keywords: ['مهمه شخصيه', 'خاصه', 'تحويل لموظف', 'تحويل لفريق'],
    audience: _HelpAudience.managerOrDesigner,
  ),
  _HelpTopic(
    title: 'التصويت',
    group: 'الإدارة والتواصل',
    icon: Icons.how_to_vote_outlined,
    purpose: 'إنشاء التصويتات وتحديد المستحقين والفترة والخصوصية، ثم متابعة المشاركة والنتيجة النهائية.',
    steps: [
      'افتح «التصويت» ثم أنشئ تصويتًا وحدد السؤال والخيارات.',
      'حدد الموظفين ووقت البدء والانتهاء وإعداد الخصوصية.',
      'بعد الإغلاق افتح التقرير النهائي واتخذ قرار المدير عند التعادل إذا لزم.',
    ],
    permission: 'الإدارة للمدير، والمصمم يعرض التصويتات وتقاريرها فقط.',
    result: 'يصل التصويت للمستحقين وتظهر النتيجة والتقرير بعد انتهاء الفترة.',
    keywords: ['انشاء تصويت', 'استطلاع', 'نتيجه التصويت', 'تقرير التصويت', 'تعادل'],
    audience: _HelpAudience.managerOrDesigner,
  ),
  _HelpTopic(
    title: 'أفكار المدير',
    group: 'الإدارة والتواصل',
    icon: Icons.lightbulb_outline_rounded,
    purpose: 'مساحة يسجل فيها المدير أفكار التطوير والاحتياجات المقترحة قبل تحويلها إلى عمل فعلي.',
    steps: [
      'افتح «أفكار المدير».',
      'اكتب الفكرة بوضوح واحفظها.',
      'ارجع إليها للتعديل أو المتابعة أو الحذف حسب الحاجة.',
    ],
    permission: 'الكتابة والتعديل للمدير، والمصمم يطّلع فقط.',
    result: 'تُحفظ الفكرة في قائمة منظمة بدل ضياعها بين المحادثات أو الملاحظات.',
    keywords: ['فكره', 'افكار', 'اقتراح', 'تطوير'],
    audience: _HelpAudience.managerOrDesigner,
  ),
  _HelpTopic(
    title: 'النماذج المخصصة',
    group: 'الإدارة والتواصل',
    icon: Icons.dynamic_form_outlined,
    purpose: 'إنشاء نماذج تناسب احتياج العمل، وإدارة عنوان النموذج ووصفه وحقوله وردوده.',
    steps: [
      'افتح «النماذج المخصصة» وأنشئ نموذجًا أو افتح نموذجًا موجودًا.',
      'عدّل اسم النموذج ووصفه، ثم أضف الحقول وحدد نوع كل حقل وما إذا كان مطلوبًا.',
      'انشر الرابط لاستقبال الردود، أو استخدم تعديل النموذج وحذفه من بطاقة النموذج.',
    ],
    permission: 'الإدارة والحذف للمدير. المصمم يرى النماذج دون تغييرها.',
    result: 'يصبح النموذج جاهزًا لجمع الردود، وتُحفظ الردود مرتبطة به داخل NeoTask.',
    tip: 'حذف النموذج يحذف ردوده المرتبطة بعد رسالة التأكيد.',
    keywords: ['نموذج', 'فورم', 'حقول', 'تعديل النموذج', 'حذف النموذج', 'رابط النموذج'],
    audience: _HelpAudience.managerOrDesigner,
  ),
  _HelpTopic(
    title: 'استيراد Excel / CSV',
    group: 'الإدارة والتواصل',
    icon: Icons.upload_file_outlined,
    purpose: 'إضافة عدد كبير من الموظفين أو المهام دفعة واحدة من ملف منظم بدل الإدخال اليدوي.',
    steps: [
      'افتح «استيراد Excel / CSV» وحدد نوع البيانات: موظفون أو مهام.',
      'اختر الملف وراجع مطابقة الأعمدة والبيانات قبل الاعتماد.',
      'نفذ الاستيراد ثم راجع ملخص السجلات الناجحة والأخطاء.',
    ],
    permission: 'التنفيذ للمدير فقط، والمصمم يرى الشاشة دون استيراد.',
    result: 'تُضاف السجلات الصحيحة، وتظهر الأخطاء التي تحتاج تصحيحًا دون إخفائها.',
    tip: 'لا تعتمد الملف قبل مراجعة أسماء الأعمدة وأرقام الموظفين والتواريخ.',
    keywords: ['اكسل', 'excel', 'csv', 'رفع ملف', 'استيراد موظفين', 'استيراد مهام'],
    audience: _HelpAudience.managerOrDesigner,
  ),
  _HelpTopic(
    title: 'مركز المعرفة',
    group: 'المعرفة والموارد',
    icon: Icons.auto_stories_outlined,
    purpose: 'يحفظ السياسات والأدلة والملفات المرجعية في مكان واحد يمكن الرجوع إليه داخل العمل.',
    steps: [
      'افتح «مركز المعرفة» وابحث عن المستند أو اختر التصنيف.',
      'افتح المستند لقراءة محتواه ومرفقاته ومعلومات مراجعته.',
      'أضف أو حدّث المحتوى إذا كانت صلاحيتك تسمح بذلك.',
    ],
    permission: 'العرض للحسابات المصرح بها، وإدارة المحتوى للمدير، والمصمم قراءة فقط.',
    result: 'يبقى المرجع محفوظًا ومتاحًا للفريق مع بياناته وتحديثاته.',
    keywords: ['المعرفه', 'وثيقه', 'مستند', 'سياسه', 'دليل', 'ملف مرجعي'],
  ),
  _HelpTopic(
    title: 'الاجتماعات',
    group: 'المعرفة والموارد',
    icon: Icons.groups_2_outlined,
    purpose: 'تنظيم الاجتماعات وحفظ موعدها والمشاركين ومحاورها ومخرجاتها.',
    steps: [
      'افتح «الاجتماعات» واختر اجتماعًا أو أنشئ اجتماعًا حسب صلاحيتك.',
      'أدخل الموعد والمشاركين والمحاور المطلوبة.',
      'بعد الاجتماع حدّث الملاحظات والقرارات والمهام الناتجة.',
    ],
    permission: 'يرى المستخدم الاجتماعات التي يحق له الوصول إليها، والإدارة بحسب الدور، والمصمم قراءة فقط.',
    result: 'يصبح سجل الاجتماع وقراراته متاحًا للمتابعة بدل بقائه شفهيًا.',
    keywords: ['اجتماع', 'موعد اجتماع', 'محضر', 'مشاركين', 'قرارات'],
  ),
  _HelpTopic(
    title: 'جهات الاتصال',
    group: 'المعرفة والموارد',
    icon: Icons.contact_phone_outlined,
    purpose: 'دليل موحد لحفظ بيانات التواصل المهنية التي يحتاجها الفريق.',
    steps: [
      'افتح «جهات الاتصال».',
      'ابحث بالاسم أو الجهة، ثم افتح بطاقة جهة الاتصال.',
      'أضف أو عدّل البيانات إذا كانت صلاحيتك تسمح.',
    ],
    permission: 'العرض للمستخدمين المصرح لهم، والإدارة للمدير، والمصمم قراءة فقط.',
    result: 'تتوفر بيانات الاتصال الصحيحة للفريق من مصدر واحد.',
    keywords: ['اتصال', 'رقم', 'جوال', 'هاتف', 'دليل الموظفين'],
  ),
  _HelpTopic(
    title: 'المفضلة',
    group: 'المعرفة والموارد',
    icon: Icons.star_border_rounded,
    purpose: 'تجمع العناصر التي وضعت عليها علامة النجمة للوصول السريع إليها لاحقًا.',
    steps: [
      'اضغط أيقونة النجمة على العنصر الذي تريد حفظه.',
      'افتح «المفضلة» من القائمة لرؤية العناصر المحفوظة.',
      'أزل النجمة عندما لا تعود بحاجة للوصول السريع إلى العنصر.',
    ],
    permission: 'كل مستخدم يدير مفضلته الخاصة، والمصمم يتعامل معها ضمن حدود القراءة فقط.',
    result: 'يظهر العنصر في قائمة مختصرة دون تغيير محتواه الأصلي أو مشاركته.',
    keywords: ['نجمه', 'حفظ', 'المحفوظات', 'favorite', 'star'],
  ),
  _HelpTopic(
    title: 'البحث',
    group: 'الأيقونات والإجراءات',
    icon: Icons.search_rounded,
    purpose: 'البحث الشامل عن عناصر NeoTask المسموح للحساب برؤيتها.',
    steps: [
      'اضغط أيقونة العدسة في أعلى الشاشة.',
      'اكتب كلمة من اسم المهمة أو الموظف أو العنصر المطلوب.',
      'اختر النتيجة للانتقال إلى تفاصيلها.',
    ],
    permission: 'متاح للجميع، ولا يعرض نتائج خارج صلاحية الحساب.',
    result: 'تصل إلى العنصر مباشرة دون التنقل بين عدة تبويبات.',
    keywords: ['عدسه', 'بحث شامل', 'ادور', 'ابحث'],
  ),
  _HelpTopic(
    title: 'الإشعارات',
    group: 'الأيقونات والإجراءات',
    icon: Icons.notifications_outlined,
    purpose: 'تعرض التنبيهات الناتجة عن المهام والمراجعات والرسائل والتحديثات المهمة.',
    steps: [
      'اضغط أيقونة الجرس.',
      'راجع التنبيهات غير المقروءة واختر أحدها.',
      'سينقلك NeoTask إلى العنصر المرتبط بالتنبيه متى كان ذلك متاحًا.',
    ],
    permission: 'كل مستخدم يرى إشعارات حسابه فقط.',
    result: 'تُفتح تفاصيل الحدث ويُحدّث وضع القراءة للتنبيه.',
    keywords: ['جرس', 'تنبيه', 'اشعار', 'نوتفكيشن', 'الشاره'],
  ),
  _HelpTopic(
    title: 'صورة الحساب والقائمة',
    group: 'الأيقونات والإجراءات',
    icon: Icons.account_circle_outlined,
    purpose: 'تفتح القائمة الجانبية التي تحتوي بيانات الحساب والتبويبات الإضافية والإعدادات والمساعدة.',
    steps: [
      'اضغط صورة الحساب في أعلى الشاشة.',
      'راجع بيانات الحساب والدور، ثم اختر التبويب المطلوب.',
      'استخدم الإعدادات أو المساعدة أو تسجيل الخروج من أسفل القائمة.',
    ],
    permission: 'متاحة لكل حساب، وتختلف عناصر القائمة بحسب صلاحية المستخدم.',
    result: 'تنتقل إلى الوجهة المختارة دون إظهار أدوات لا يملكها الحساب.',
    keywords: ['الصوره', 'الملف الشخصي', 'القائمه', 'منيو', 'حسابي'],
  ),
  _HelpTopic(
    title: 'إضافة مهمة',
    group: 'الأيقونات والإجراءات',
    icon: Icons.add_rounded,
    purpose: 'إنشاء مهمة جديدة وتحديد مسؤولها وأولويتها وتواريخها وتكرارها.',
    steps: [
      'اضغط زر الإضافة الدائري في الشاشة الرئيسية أو المراجعة.',
      'اكتب بيانات المهمة وحدد هل هي للفريق أو شخصية، ثم اختر الموظف والأولوية والتواريخ.',
      'راجع البيانات واضغط الحفظ أو الإسناد.',
    ],
    permission: 'متاحة للمدير. المصمم لا يستطيع إنشاء مهمة.',
    result: 'تُنشأ المهمة وتظهر للمسؤول عنها، ويبدأ سجل المتابعة الخاص بها.',
    keywords: ['علامه الزائد', 'بلس', 'مهمه جديده', 'انشاء مهمه', 'اسناد'],
    audience: _HelpAudience.manager,
  ),
  _HelpTopic(
    title: 'تحديث نسبة الإنجاز',
    group: 'الأيقونات والإجراءات',
    icon: Icons.percent_rounded,
    purpose: 'تسجيل مستوى التقدم الفعلي في المهمة قبل إرسالها للمراجعة.',
    steps: [
      'افتح المهمة من «مهامي».',
      'حرّك مؤشر نسبة الإنجاز أو أدخل النسبة المطلوبة.',
      'احفظ التحديث، وعند اكتمال العمل أرسل المهمة للمراجعة.',
    ],
    permission: 'الموظف المكلّف بالمهمة يحدّث تقدمها ضمن حالتها المسموح بها.',
    result: 'تظهر النسبة الجديدة للموظف والمدير ضمن تفاصيل المهمة والمؤشرات.',
    keywords: ['نسبه', 'تقدم', 'اكمال', 'انجاز المهمه'],
    audience: _HelpAudience.employee,
  ),
  _HelpTopic(
    title: 'إرسال المهمة للمراجعة',
    group: 'الأيقونات والإجراءات',
    icon: Icons.send_rounded,
    purpose: 'إبلاغ المدير بأن تنفيذ المهمة اكتمل وأصبحت جاهزة للفحص والاعتماد.',
    steps: [
      'افتح المهمة وتأكد من تحديث نسبة الإنجاز وإضافة الملاحظات أو المرفقات اللازمة.',
      'اضغط «إرسال المهمة للمراجعة».',
      'أكّد الإرسال؛ بعدها لا تعتبر المهمة معتمدة حتى يراجعها المدير.',
    ],
    permission: 'الموظف المكلّف يرسل المهمة التي يعمل عليها.',
    result: 'تنتقل المهمة إلى «بانتظار المراجعة» وتظهر في تبويب مراجعة المدير.',
    keywords: ['ارسال', 'للمراجعه', 'خلصت المهمه', 'تسليم المهمه'],
    audience: _HelpAudience.employee,
  ),
  _HelpTopic(
    title: 'المرفقات',
    group: 'الأيقونات والإجراءات',
    icon: Icons.attach_file_rounded,
    purpose: 'إضافة صورة أو ملف يدعم المهمة أو المحادثة أو المستند المرتبط بالعمل.',
    steps: [
      'افتح العنصر واضغط أيقونة المشبك أو خيار المرفق.',
      'اختر الصورة أو الملف من جهازك وانتظر اكتمال الرفع.',
      'أرسل الرسالة أو احفظ العنصر حتى يرتبط المرفق به.',
    ],
    permission: 'متاحة عندما يملك الحساب حق الإضافة أو الرد داخل العنصر.',
    result: 'يظهر الملف داخل العنصر ويمكن للأطراف المصرح لها فتحه.',
    keywords: ['مشبك', 'ملف', 'صوره', 'ارفاق', 'رفع'],
  ),
  _HelpTopic(
    title: 'تعديل',
    group: 'الأيقونات والإجراءات',
    icon: Icons.edit_outlined,
    purpose: 'فتح العنصر الحالي لتغيير بياناته القابلة للتعديل.',
    steps: [
      'اضغط أيقونة القلم أو زر «تعديل».',
      'غيّر البيانات المطلوبة مع إبقاء الحقول الإلزامية مكتملة.',
      'اضغط حفظ لتثبيت التغييرات.',
    ],
    permission: 'لا تظهر إلا لمن يملك حق تعديل العنصر؛ المصمم لا يملك التعديل.',
    result: 'تُحفظ النسخة الجديدة وتظهر في الشاشة، وقد يُسجل التغيير في سجل العمليات حسب نوع العنصر.',
    keywords: ['قلم', 'تحرير', 'تغيير', 'edit'],
  ),
  _HelpTopic(
    title: 'حذف',
    group: 'الأيقونات والإجراءات',
    icon: Icons.delete_outline_rounded,
    purpose: 'إزالة العنصر عندما لم تعد هناك حاجة إليه، بعد تأكيد صريح لتقليل الحذف بالخطأ.',
    steps: [
      'اضغط أيقونة سلة المهملات أو زر «حذف».',
      'اقرأ رسالة التأكيد لأنها تذكر العنصر والبيانات المتأثرة.',
      'أكّد الحذف فقط إذا كنت متأكدًا، أو اختر إلغاء للرجوع.',
    ],
    permission: 'تظهر فقط للدور المخول بالحذف، وغالبًا المدير. المصمم لا يحذف.',
    result: 'يُزال العنصر والبيانات التابعة المحددة في رسالة التأكيد حسب نوعه.',
    tip: 'الحذف إجراء مختلف عن الإغلاق أو الإكمال؛ راجع رسالة التأكيد قبل المتابعة.',
    keywords: ['سله', 'مسح', 'ازاله', 'delete'],
  ),
  _HelpTopic(
    title: 'الإعدادات',
    group: 'الحساب والنظام',
    icon: Icons.settings_outlined,
    purpose: 'إدارة الصورة الشخصية وتفضيلات الأصوات والتذكيرات وكلمة مرور الحساب.',
    steps: [
      'افتح القائمة الجانبية ثم «الإعدادات».',
      'اختر القسم المطلوب: الملف الشخصي أو الإشعارات الصوتية أو التذكيرات أو الحساب.',
      'غيّر الإعداد واحفظه، واتبع حقول التحقق عند تغيير كلمة المرور.',
    ],
    permission: 'كل مستخدم يدير إعدادات حسابه فقط.',
    result: 'تُحفظ التفضيلات على الحساب وتُطبق عند استخدام NeoTask.',
    keywords: ['ترس', 'الصوت', 'تذكير', 'كلمه المرور', 'الصوره الشخصيه'],
  ),
  _HelpTopic(
    title: 'تسجيل الخروج',
    group: 'الحساب والنظام',
    icon: Icons.logout_rounded,
    purpose: 'إنهاء جلسة الحساب الحالي والعودة إلى شاشة تسجيل الدخول.',
    steps: [
      'افتح القائمة الجانبية.',
      'اضغط «تسجيل الخروج» في أسفلها.',
      'سيفتح NeoTask شاشة تسجيل الدخول لاستخدام حساب آخر أو إنهاء الاستخدام.',
    ],
    permission: 'متاح لجميع الحسابات.',
    result: 'تُغلق الجلسة الحالية ولا تبقى شاشات الحساب مفتوحة.',
    keywords: ['خروج', 'تبديل حساب', 'اقفال', 'logout'],
  ),
];
