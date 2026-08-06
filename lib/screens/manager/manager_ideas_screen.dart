import 'package:flutter/material.dart';

import '../../models/manager_idea_model.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../services/manager_ai_service.dart';
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
  final List<_ChatMessage> _messages = [];
  ManagerAiAction? _pendingAction;
  bool _working = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage.agent(
        'حياك الله ${widget.manager.name}. أنا مساعد المدير الذكي. '
        'اطلب مني إنشاء مبادرة، تجهيز مهمة، تلخيص أداء الفريق، أو تعديل قواعد المساعد.',
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggested]) async {
    final input = (suggested ?? _controller.text).trim();
    if (input.isEmpty || _working || widget.readOnly) return;

    setState(() {
      _working = true;
      _pendingAction = null;
      _messages.add(_ChatMessage.user(input));
      _controller.clear();
    });
    _scrollToBottom();

    try {
      final result = await ManagerAiService.send(
        message: input,
        history: _messages
            .take(_messages.length - 1)
            .map((message) => {
                  'role': message.fromAgent ? 'assistant' : 'user',
                  'content': message.text,
                })
            .toList(),
      );
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage.agent(result.reply));
        _pendingAction = result.action;
      });
    } on ManagerAiException catch (error) {
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage.error(error.message)));
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          _ChatMessage.error('تعذر الاتصال بالمساعد. حاول مرة أخرى.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
      _scrollToBottom();
    }
  }

  Future<void> _approveAction() async {
    final action = _pendingAction;
    if (action == null || _working || widget.readOnly) return;

    setState(() => _working = true);
    try {
      final prefix = switch (action.type) {
        'create_task_draft' => 'مسودة مهمة',
        'update_agent_rule' => 'قاعدة للمساعد',
        'team_summary' => 'ملخص فريق',
        _ => 'مبادرة',
      };
      await FirestoreService.addManagerIdea(
        content: '$prefix: ${action.title}\n${action.payload}',
        manager: widget.manager,
      );
      if (!mounted) return;
      setState(() {
        _messages.add(
          _ChatMessage.agent(
            action.type == 'create_task_draft'
                ? 'تم اعتماد مسودة المهمة وحفظها في سجل المساعد. يمكنك مراجعتها وتحويلها إلى مهمة نهائية.'
                : 'تم اعتماد الإجراء وحفظه في سجل المساعد.',
          ),
        );
        _pendingAction = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          _ChatMessage.error('تعذر حفظ الإجراء المعتمد.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
      _scrollToBottom();
    }
  }

  void _cancelAction() {
    setState(() {
      _pendingAction = null;
      _messages.add(_ChatMessage.agent('تم إلغاء الإجراء ولم يُحفظ أي تغيير.'));
    });
    _scrollToBottom();
  }

  Future<void> _deleteIdea(ManagerIdea idea) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف السجل؟'),
        content: const Text('سيتم حذف هذا العنصر نهائيًا من سجل المساعد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirestoreService.deleteManagerIdea(idea.ideaId);
    }
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
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: const Text('مساعد المدير الذكي'),
        backgroundColor: const Color(0xFF071D3B),
        foregroundColor: Colors.white,
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
                      Expanded(flex: 4, child: history),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(flex: 7, child: chat),
                      const SizedBox(height: 12),
                      SizedBox(height: 260, child: history),
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
        boxShadow: const [
          BoxShadow(
            color: Color(0x12071D3B),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          const _AgentHeader(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) => _MessageBubble(
                message: _messages[index],
              ),
            ),
          ),
          if (_pendingAction != null)
            _ApprovalCard(
              action: _pendingAction!,
              working: _working,
              onApprove: _approveAction,
              onCancel: _cancelAction,
            ),
          if (!widget.readOnly) ...[
            _Suggestions(onSelected: _send),
            _Composer(
              controller: _controller,
              working: _working,
              onSend: _send,
            ),
          ] else
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'وضع العرض فقط',
                style: TextStyle(color: Color(0xFF758195)),
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
                Icon(Icons.history, color: AppColors.navy),
                SizedBox(width: 8),
                Text(
                  'سجل المساعد',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
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
                if (snapshot.hasError) {
                  return const _EmptyHistory('تعذر تحميل سجل المساعد');
                }
                final ideas = snapshot.data ?? const <ManagerIdea>[];
                if (ideas.isEmpty) {
                  return const _EmptyHistory('لا توجد إجراءات محفوظة');
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: ideas.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final idea = ideas[index];
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.auto_awesome_outlined,
                            color: Color(0xFF138B68),
                            size: 20,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Text(
                              idea.content,
                              maxLines: 5,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Color(0xFF26364A),
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (!widget.readOnly)
                            IconButton(
                              tooltip: 'حذف',
                              onPressed: () => _deleteIdea(idea),
                              icon: const Icon(Icons.delete_outline, size: 20),
                              color: AppColors.statusRejected,
                            ),
                        ],
                      ),
                    );
                  },
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
        color: Color(0xFF071D3B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
      ),
      child: const Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: Color(0x2233D6A6),
            child: Icon(Icons.auto_awesome, color: Color(0xFF33D6A6)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Executive AI Agent',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'يحلل الطلب ويعرض الإجراء قبل التنفيذ',
                  style: TextStyle(color: Color(0xFFB9C7D9)),
                ),
              ],
            ),
          ),
          _OnlineBadge(),
        ],
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x2233D6A6),
        borderRadius: BorderRadius.circular(99),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: Color(0xFF33D6A6)),
          SizedBox(width: 6),
          Text(
            'متصل',
            style: TextStyle(
              color: Color(0xFF8EF0D1),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final alignment = message.fromAgent
        ? AlignmentDirectional.centerStart
        : AlignmentDirectional.centerEnd;
    final background = message.isError
        ? const Color(0xFFFFEEEE)
        : message.fromAgent
            ? const Color(0xFFF0F5FA)
            : AppColors.navy;
    final foreground = message.isError
        ? AppColors.statusRejected
        : message.fromAgent
            ? const Color(0xFF26364A)
            : Colors.white;

    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Text(
          message.text,
          style: TextStyle(color: foreground, height: 1.5),
        ),
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  const _ApprovalCard({
    required this.action,
    required this.working,
    required this.onApprove,
    required this.onCancel,
  });

  final ManagerAiAction action;
  final bool working;
  final VoidCallback onApprove;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFAEC),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE8B84B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Color(0xFF9A6810)),
              SizedBox(width: 8),
              Text(
                'بانتظار اعتماد المدير',
                style: TextStyle(
                  color: Color(0xFF7B560F),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          Text(
            action.title,
            style: const TextStyle(
              color: AppColors.navy,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            action.payload,
            maxLines: 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF536174), height: 1.45),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: working ? null : onCancel,
                child: const Text('إلغاء'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: working ? null : onApprove,
                icon: const Icon(Icons.check_circle_outline),
                label: Text(working ? 'جارٍ الاعتماد' : 'اعتماد'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({required this.onSelected});

  final ValueChanged<String> onSelected;

  static const items = [
    'أنشئ مبادرة لتحسين متابعة المهام المتأخرة',
    'جهز مسودة مهمة لفريق الجودة لمدة أسبوع',
    'اقترح قاعدة تنبيه للمهام المتأخرة',
  ];

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          for (final item in items)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: ActionChip(
                label: Text(item),
                onPressed: () => onSelected(item),
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
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              minLines: 1,
              maxLines: 5,
              onSubmitted: (_) => onSend(),
              decoration: InputDecoration(
                hintText: 'اكتب طلبك لمساعد المدير...',
                filled: true,
                fillColor: const Color(0xFFF7F9FC),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: Color(0xFFDCE4EE)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          IconButton.filled(
            onPressed: working ? null : onSend,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.navy,
              foregroundColor: Colors.white,
              minimumSize: const Size(50, 50),
            ),
            icon: working
                ? const SizedBox.square(
                    dimension: 20,
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

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF758195)),
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.fromAgent,
    this.isError = false,
  });

  final String text;
  final bool fromAgent;
  final bool isError;

  factory _ChatMessage.agent(String text) =>
      _ChatMessage(text: text, fromAgent: true);

  factory _ChatMessage.user(String text) =>
      _ChatMessage(text: text, fromAgent: false);

  factory _ChatMessage.error(String text) =>
      _ChatMessage(text: text, fromAgent: true, isError: true);
}
