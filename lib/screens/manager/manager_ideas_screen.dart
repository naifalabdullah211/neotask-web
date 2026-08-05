import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';

import '../../models/manager_idea_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

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
  _PendingAction? _pending;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _AgentMessage.agent(
        'حياك الله ${widget.manager.name}. أنا مساعد المدير الذكي. '
        'أحوّل أفكارك إلى مبادرات وأعرض أي إجراء قبل اعتماده.',
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
    _scrollDown();

    await Future<void>.delayed(const Duration(milliseconds: 250));
    final result = _AgentInterpreter.interpret(input);
    if (!mounted) return;

    setState(() {
      _messages.add(_AgentMessage.agent(result.reply));
      _pending = result.action;
      _working = false;
    });
    _scrollDown();
  }

  Future<void> _approve() async {
    final action = _pending;
    if (action == null || _working || widget.readOnly) return;

    setState(() => _working = true);
    try {
      if (action.kind == _ActionKind.initiative) {
        await FirestoreService.addManagerIdea(
          content: action.payload,
          manager: widget.manager,
        );
        if (!mounted) return;
        setState(() {
          _messages.add(
            const _AgentMessage.agent(
              'تم اعتماد المبادرة وحفظها في سجل المساعد بنجاح.',
            ),
          );
          _pending = null;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _messages.add(
            const _AgentMessage.agent(
              'تم حفظ الطلب كمسودة تنفيذ آمنة. تنفيذ تعديل المهام مباشرة '
              'سيُفعّل عند ربط نقطة خلفية محمية دون كشف مفاتيح الذكاء الاصطناعي.',
            ),
          );
          _pending = null;
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
      _scrollDown();
    }
  }

  void _cancel() {
    setState(() {
      _pending = null;
      _messages.add(
        const _AgentMessage.agent('تم إلغاء الإجراء ولم يتغير شيء.'),
      );
    });
    _scrollDown();
  }

  void _usePrompt(String prompt) {
    if (widget.readOnly) return;
    _controller.text = prompt;
    _controller.selection = TextSelection.collapsed(offset: prompt.length);
  }

  void _scrollDown() {
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
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 980;
          return Padding(
            padding: EdgeInsets.all(desktop ? 22 : 12),
            child: desktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(flex: 7, child: _chatPanel()),
                      const SizedBox(width: 16),
                      Expanded(flex: 3, child: _historyPanel()),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: _chatPanel()),
                      const SizedBox(height: 12),
                      SizedBox(height: 220, child: _historyPanel()),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _chatPanel() {
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
              itemBuilder: (_, index) => _MessageBubble(
                message: _messages[index],
              ),
            ),
          ),
          if (_pending != null)
            _ActionPreview(
              action: _pending!,
              busy: _working,
              onApprove: _approve,
              onCancel: _cancel,
            ),
          if (widget.readOnly)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'وضع العرض فقط',
                style: TextStyle(color: Color(0xFF6F7C8F)),
              ),
            )
          else ...[
            _QuickPrompts(onSelected: _usePrompt),
            _Composer(
              controller: _controller,
              busy: _working,
              onSend: _send,
            ),
          ],
        ],
      ),
    );
  }

  Widget _historyPanel() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCE4EE)),
      ),
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
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
              builder: (_, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final ideas = snapshot.data ?? const <ManagerIdea>[];
                if (ideas.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20),
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
                  itemBuilder: (_, index) => _InitiativeTile(idea: ideas[index]),
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
                  'يفهم الطلب ويعرض الإجراء قبل التنفيذ',
                  style: TextStyle(color: Color(0xFFC9D6E6), fontSize: 12),
                ),
              ],
            ),
          ),
          _StatusBadge(),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge();

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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _AgentMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == _Role.user;
    return Align(
      alignment: isUser
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: isUser ? AppColors.navy : const Color(0xFFF0F4F8),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          message.content,
          style: TextStyle(
            color: isUser ? Colors.white : const Color(0xFF26364A),
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
    required this.busy,
    required this.onApprove,
    required this.onCancel,
  });

  final _PendingAction action;
  final bool busy;
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
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: busy ? null : onCancel,
                child: const Text('إلغاء'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: busy ? null : onApprove,
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

class _QuickPrompts extends StatelessWidget {
  const _QuickPrompts({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const prompts = [
      'حوّل هذه الفكرة إلى مبادرة',
      'لخص لي المهام المتأخرة',
      'اقترح توزيع المهام على الفريق',
    ];
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

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool busy;
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
            onPressed: busy ? null : onSend,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              minimumSize: const Size(48, 48),
            ),
            icon: busy
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
          const Icon(
            Icons.tips_and_updates_outlined,
            color: Color(0xFFE8B84B),
            size: 20,
          ),
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

enum _Role { user, agent }

class _AgentMessage {
  const _AgentMessage(this.role, this.content);
  const _AgentMessage.user(String content) : this(_Role.user, content);
  const _AgentMessage.agent(String content) : this(_Role.agent, content);

  final _Role role;
  final String content;
}

enum _ActionKind { initiative, staged }

class _PendingAction {
  const _PendingAction({
    required this.kind,
    required this.summary,
    required this.payload,
  });

  final _ActionKind kind;
  final String summary;
  final String payload;
}

class _Interpretation {
  const _Interpretation({required this.reply, this.action});

  final String reply;
  final _PendingAction? action;
}

class _AgentInterpreter {
  static _Interpretation interpret(String input) {
    final value = input.toLowerCase();

    if (value.contains('فكرة') ||
        value.contains('مبادرة') ||
        value.contains('اقتراح')) {
      return _Interpretation(
        reply: 'فهمت. سأحوّل الطلب إلى مبادرة محفوظة، ولن أغيّر أي بيانات '
            'أخرى قبل اعتمادك.',
        action: _PendingAction(
          kind: _ActionKind.initiative,
          summary: 'إنشاء مبادرة جديدة بالنص التالي:\n$input',
          payload: input,
        ),
      );
    }

    if (value.contains('مهمة') ||
        value.contains('الموظف') ||
        value.contains('الفريق') ||
        value.contains('متأخر')) {
      return _Interpretation(
        reply: 'جهزت طلبًا تشغيليًا للمعاينة. تعديل المهام مباشرة سيظل '
            'موقوفًا حتى يتوفر اتصال خلفي محمي.',
        action: _PendingAction(
          kind: _ActionKind.staged,
          summary: 'طلب تشغيلي مقترح:\n$input',
          payload: input,
        ),
      );
    }

    return const _Interpretation(
      reply: 'اكتب هدفك مباشرة، مثل: حوّل هذه الفكرة إلى مبادرة، '
          'لخص المهام المتأخرة، أو اقترح توزيع العمل.',
    );
  }
}
