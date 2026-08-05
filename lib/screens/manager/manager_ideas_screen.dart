import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';

import '../../models/manager_idea_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

/// Manager AI Agent workspace.
///
/// This screen replaces the old passive manager-ideas inbox with a safe,
/// action-oriented assistant. Existing ideas remain available as the agent's
/// initiative history. Actions that change NeoTask data are previewed before
/// execution; the current Spark-plan release implements initiative capture
/// immediately and keeps the remaining actions visibly staged until a secure
/// server-side AI execution endpoint is connected.
class ManagerIdeasScreen extends StatefulWidget {
  const ManagerIdeasScreen({
    super.key,
    required this.manager,
    this.readOnly = false,
  });

  final AppUser manager;
  final bool readOnly;

  @override
  State<ManagerIdeasScreen> createState() => _ManagerIdeasScreenState();
}

class _ManagerIdeasScreenState extends State<ManagerIdeasScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_AgentMessage> _messages = [];
  _PendingAgentAction? _pendingAction;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _AgentMessage.agent(
        'حياك الله ${widget.manager.name}. أنا مساعد المدير الذكي. '\
        'أقدر أحوّل أفكارك إلى مبادرات واضحة، وأجهز لك إجراءً قبل اعتماده.',
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final input = _controller.text.trim();
    if (input.isEmpty || _working || widget.readOnly) return;

    setState(() {
      _working = true;
      _messages.add(_AgentMessage.user(input));
      _controller.clear();
    });
    _scrollToBottom();

    await Future<void>.delayed(const Duration(milliseconds: 280));
    final analysis = _AgentInterpreter.interpret(input);

    if (!mounted) return;
    setState(() {
      _pendingAction = analysis.action;
      _messages.add(_AgentMessage.agent(analysis.reply));
      _working = false;
    });
    _scrollToBottom();
  }

  Future<void> _approvePendingAction() async {
    final action = _pendingAction;
    if (action == null || _working || widget.readOnly) return;

    setState(() => _working = true);
    try {
      if (action.type == _AgentActionType.createInitiative) {
        await FirestoreService.addManagerIdea(
          content: action.payload,
          manager: widget.manager,
        );
        if (!mounted) return;
        setState(() {
          _messages.add(
            _AgentMessage.agent(
              'تم اعتماد المبادرة وحفظها في سجل المساعد. '\
              'ستبقى ظاهرة للمتابعة والتحويل إلى مهمة عند ربط محرك التنفيذ الآمن.',
            ),
          );
          _pendingAction = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _messages.add(
            _AgentMessage.agent(
              'تم حفظ طلب الإجراء كمسودة آمنة. التنفيذ المباشر لهذا النوع '\
              'يتطلب نقطة خلفية محمية حتى لا تُكشف مفاتيح الذكاء الاصطناعي في المتصفح.',
            ),
          );
          _pendingAction = null;
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر تنفيذ الإجراء الآن')),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
      _scrollToBottom();
    }
  }

  void _cancelPendingAction() {
    setState(() {
      _messages.add(const _AgentMessage.agent('تم إلغاء الإجراء ولم يتغير شيء.'));
      _pendingAction = null;
    });
    _scrollToBottom();
  }

  void _usePrompt(String prompt) {
    if (widget.readOnly) return;
    _controller.text = prompt;
    _controller.selection = TextSelection.collapsed(offset: prompt.length);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text('مساعد المدير الذكي'),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        actions: [
          Container(
            margin: const EdgeInsetsDirectional.only(end: 14),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.mintAccent.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(
                color: AppColors.mintAccent.withValues(alpha: 0.45),
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, size: 15, color: AppColors.mintAccent),
                SizedBox(width: 5),
                Text(
                  'تنفيذ بموافقة المدير',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 980;
          final chat = _buildChatPanel();
          final history = _buildHistoryPanel();

          return Padding(
            padding: EdgeInsets.all(desktop ? 22 : 12),
            child: desktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 7, child: chat),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: history),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: chat),
                      const SizedBox(height: 12),
                      SizedBox(height: 230, child: history),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildChatPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE4EE)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.07),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const _AgentHeader(),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(18),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _MessageBubble(
                message: _messages[index],
              ),
            ),
          ),
          if (_pendingAction != null)
            _ActionPreview(
              action: _pendingAction!,
              working: _working,
              onApprove: _approvePendingAction,
              onCancel: _cancelPendingAction,
            ),
          if (!widget.readOnly) ...[
            _QuickPrompts(onSelected: _usePrompt),
            _Composer(
              controller: _controller,
              working: _working,
              onSend: _send,
            ),
          ] else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'وضع العرض فقط — لا يمكن تنفيذ أو تعديل إجراءات المساعد.',
                style: TextStyle(color: Color(0xFF6F7C8F)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE4EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Icon(Icons.history_rounded, color: AppColors.navy),
                SizedBox(width: 8),
                Text(
                  'المبادرات المحفوظة',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<ManagerIdea>>(
              stream: FirestoreService.watchManagerIdeas(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final ideas = snapshot.data ?? const <ManagerIdea>[];
                if (ideas.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(22),
                      child: Text(
                        'لا توجد مبادرات محفوظة حتى الآن',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF7D899A)),
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: ideas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) => _InitiativeTile(
                    idea: ideas[index],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AgentHeader extends StatelessWidget {
  const _AgentHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF102B52), Color(0xFF1B3A6B)],
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Color(0x2633D6A6),
            child: Icon(Icons.auto_awesome, color: AppColors.mintAccent),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manager AI Agent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'يفهم الطلب، يعرض الإجراء، ثم ينفّذ بعد موافقتك',
                  style: TextStyle(color: Color(0xFFC9D6E6), fontSize: 12),
                ),
              ],
            ),
          ),
          _StatusDot(),
        ],
      ),
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.mintAccent.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Row(
        children: [
          CircleAvatar(radius: 4, backgroundColor: AppColors.mintAccent),
          SizedBox(width: 6),
          Text(
            'جاهز',
            style: TextStyle(
              color: AppColors.mintAccent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.working,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool working;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE1E7EF))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 4,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'اكتب طلبك للمساعد…',
                filled: true,
                fillColor: const Color(0xFFF5F7FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: working ? null : onSend,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            icon: working
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}

class _QuickPrompts extends StatelessWidget {
  const _QuickPrompts({required this.onSelected});

  final ValueChanged<String> onSelected;

  static const prompts = [
    'حوّل هذه الفكرة إلى مبادرة',
    'لخص لي المهام المتأخرة',
    'اقترح توزيع المهام على الفريق',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          for (final prompt in prompts) ...[
            ActionChip(
              avatar: const Icon(Icons.bolt_outlined, size: 16),
              label: Text(prompt),
              onPressed: () => onSelected(prompt),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _AgentMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.role == _AgentRole.user;
    return Align(
      alignment: user ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: user ? AppColors.navy : const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: user ? Colors.white : const Color(0xFF26364A),
            height: 1.55,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ActionPreview extends StatelessWidget {
  const _ActionPreview({
    required this.action,
    required this.working,
    required this.onApprove,
    required this.onCancel,
  });

  final _PendingAgentAction action;
  final bool working;
  final VoidCallback onApprove;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9EC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE8B84B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'معاينة الإجراء قبل التنفيذ',
            style: TextStyle(
              color: Color(0xFF74510B),
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(action.summary, style: const TextStyle(height: 1.45)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(onPressed: working ? null : onCancel, child: const Text('إلغاء')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: working ? null : onApprove,
                icon: const Icon(Icons.verified_outlined, size: 18),
                label: const Text('اعتماد'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InitiativeTile extends StatelessWidget {
  const _InitiativeTile({required this.idea});

  final ManagerIdea idea;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E6EE)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tips_and_updates_outlined, color: Color(0xFFE8B84B), size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              idea.content,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF33445A),
                height: 1.45,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _AgentRole { user, agent }

class _AgentMessage {
  const _AgentMessage(this.role, this.content);
  const _AgentMessage.user(String content) : this(_AgentRole.user, content);
  const _AgentMessage.agent(String content) : this(_AgentRole.agent, content);

  final _AgentRole role;
  final String content;
}

enum _AgentActionType { createInitiative, stagedOperation }

class _PendingAgentAction {
  const _PendingAgentAction({
    required this.type,
    required this.summary,
    required this.payload,
  });

  final _AgentActionType type;
  final String summary;
  final String payload;
}

class _AgentInterpretation {
  const _AgentInterpretation({required this.reply, this.action});

  final String reply;
  final _PendingAgentAction? action;
}

class _AgentInterpreter {
  static _AgentInterpretation interpret(String input) {
    final normalized = input.toLowerCase();

    if (normalized.contains('فكرة') ||
        normalized.contains('مبادرة') ||
        normalized.contains('اقتراح')) {
      return _AgentInterpretation(
        reply: 'فهمت. سأحفظها كمبادرة للمدير حتى تصبح جزءًا من سجل التنفيذ، '\
            'ولن أغيّر أي بيانات أخرى قبل اعتمادك.',
        action: _PendingAgentAction(
          type: _AgentActionType.createInitiative,
          summary: 'إنشاء مبادرة جديدة بالنص التالي:\n$input',
          payload: input,
        ),
      );
    }

    if (normalized.contains('مهمة') ||
        normalized.contains('الموظف') ||
        normalized.contains('الفريق') ||
        normalized.contains('متأخر')) {
      return _AgentInterpretation(
        reply: 'جهزت طلبًا تشغيليًا. سأعرضه كمسودة آمنة أولًا؛ '\
            'تنفيذ إنشاء المهام أو تعديلها يحتاج اتصالًا خلفيًا محميًا.',
        action: _PendingAgentAction(
          type: _AgentActionType.stagedOperation,
          summary: 'طلب تشغيلي مقترح:\n$input',
          payload: input,
        ),
      );
    }

    return const _AgentInterpretation(
      reply: 'أقدر أساعدك في تحويل الكلام إلى مبادرة، تجهيز مهمة، '\
          'تلخيص المتأخرات، أو اقتراح توزيع العمل. اكتب الهدف بشكل مباشر.',
    );
  }
}
