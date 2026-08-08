import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/manager_idea_model.dart';
import '../../models/task_model.dart';
import '../../models/user_model.dart';
import '../../providers/task_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/manager_ai_service.dart';
import '../../theme/app_theme.dart';
import '../designer/designer_task_view_screen.dart';
import 'task_review_detail_screen.dart';

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
  bool? _agentOnline;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _ChatMessage.agent(
        'حياك الله ${widget.manager.name}. أنا مساعد المدير الذكي. '
        'اطلب مني إنشاء مبادرة، تجهيز مهمة، تلخيص أداء الفريق، أو تعديل قواعد المساعد.',
      ),
    );
    _checkAgentStatus();
  }

  Future<void> _checkAgentStatus() async {
    final online = await ManagerAiService.isAvailable();
    if (!mounted) return;
    setState(() => _agentOnline = online);
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
        teamContext: _buildTeamContext(),
        agentRules: await FirestoreService.loadManagerAgentRules(),
      );
      if (!mounted) return;
      setState(() {
        _agentOnline = true;
        _messages.add(_ChatMessage.agent(result.reply));
        _pendingAction = result.action;
      });
    } on ManagerAiException catch (error) {
      if (!mounted) return;
      setState(() {
        _agentOnline = false;
        _messages.add(_ChatMessage.error(error.message));
      });
    } catch (_) {
      if (!mounted) return;
      setState(
        () {
          _agentOnline = false;
          _messages.add(
            _ChatMessage.error('تعذر الاتصال بالمساعد. حاول مرة أخرى.'),
          );
        },
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
      final confirmation = await _executeApprovedAction(action);
      if (!mounted) return;
      setState(() {
        _messages.add(_ChatMessage.agent(confirmation));
        _pendingAction = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          _ChatMessage.error(
            error is ArgumentError
                ? error.message.toString()
                : 'تعذر تنفيذ الإجراء المعتمد.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _working = false);
      _scrollToBottom();
    }
  }

  List<Map<String, dynamic>> _buildTeamContext() {
    final employees = FirestoreService.getAllEmployees()
        .where((employee) => employee.accountStatus == AccountStatus.active)
        .toList();
    final tasks = FirestoreService.getAllTasks();
    final now = DateTime.now();

    return employees.map((employee) {
      final employeeTasks = tasks
          .where((task) => task.assignedTo == employee.uid && !task.isPersonal)
          .toList();
      final activeTasks = employeeTasks
          .where((task) => task.status != TaskStatus.approved)
          .toList();
      return {
        'uid': employee.uid,
        'name': employee.name,
        'employeeNumber': employee.employeeNumber,
        'weeklyCapacityHours': employee.weeklyCapacityHours,
        'activeTasks': activeTasks.length,
        'overdueTasks': activeTasks
            .where((task) => task.dueDate.isBefore(now))
            .length,
        'plannedHours': activeTasks.fold<double>(
          0,
          (sum, task) => sum + task.plannedHours,
        ),
      };
    }).toList(growable: false);
  }

  Future<String> _executeApprovedAction(ManagerAiAction action) async {
    switch (action.type) {
      case 'create_task_draft':
      case 'create_initiative':
        final employees = FirestoreService.getAllEmployees().where(
          (employee) => employee.accountStatus == AccountStatus.active,
        );
        AppUser? assignee;
        for (final employee in employees) {
          if (employee.uid == action.employeeUid) {
            assignee = employee;
            break;
          }
        }
        if (assignee == null) {
          throw ArgumentError(
            'لم يتم العثور على الموظف المحدد. اطلب من الوكيل تجهيز المهمة من جديد.',
          );
        }
        final selectedAssignee = assignee;

        final dueDate = DateTime.tryParse(action.dueDate);
        final today = DateTime.now();
        final todayOnly = DateTime(today.year, today.month, today.day);
        if (dueDate == null || dueDate.isBefore(todayOnly)) {
          throw ArgumentError(
            'موعد الاستحقاق غير صالح. اطلب من الوكيل تحديد موعد جديد.',
          );
        }

        final priority = switch (action.priority) {
          'low' => TaskPriority.low,
          'high' => TaskPriority.high,
          _ => TaskPriority.medium,
        };
        final historyContent = action.payload.length <= 1000
            ? action.payload
            : action.payload.substring(0, 1000);
        final task = await context.read<TaskProvider>().createTask(
          title: action.title,
          description: action.payload,
          assignedTo: selectedAssignee.uid,
          assignedBy: widget.manager.uid,
          dueDate: dueDate,
          plannedHours: action.plannedHours,
          priority: priority,
          category: action.category.isEmpty ? 'عام' : action.category,
          managerAgentRecordBuilder: (createdTask) => ManagerIdea(
            ideaId: createdTask.taskId,
            content: historyContent,
            authorUid: widget.manager.uid,
            authorName: widget.manager.name,
            createdAt: createdTask.createdAt,
            status: 'linked',
            recordType: 'task',
            actionType: action.type,
            taskId: createdTask.taskId,
            taskTitle: createdTask.title,
            assigneeUid: selectedAssignee.uid,
            assigneeName: selectedAssignee.name,
            employeeNumber: selectedAssignee.employeeNumber,
            dueDate: createdTask.dueDate,
            priority: createdTask.priority.name,
            plannedHours: createdTask.plannedHours,
          ),
        );
        return 'تم إنشاء المهمة والتحقق منها في Firestore. رقم المهمة: '
            '${task.taskId} — المسؤول: ${selectedAssignee.name} '
            '(${selectedAssignee.employeeNumber}). يمكنك فتحها وتعديلها من سجل المساعد.';

      case 'update_agent_rule':
        await FirestoreService.addManagerAgentRule(
          instruction: action.payload,
          manager: widget.manager,
        );
        await _archiveAction(action, 'قاعدة دائمة للوكيل');
        return 'تم حفظ القاعدة واعتمادها. سيطبقها الوكيل في الطلبات التالية.';

      case 'team_summary':
        await _archiveAction(action, 'ملخص فريق');
        return 'تم اعتماد التحليل وحفظه في سجل المساعد.';

      default:
        throw ArgumentError('نوع الإجراء غير قابل للتنفيذ.');
    }
  }

  Future<void> _archiveAction(ManagerAiAction action, String prefix) {
    final fullContent = '$prefix: ${action.title}\n${action.payload}';
    final content = fullContent.length <= 1000
        ? fullContent
        : fullContent.substring(0, 1000);
    return FirestoreService.addManagerIdea(
      content: content,
      manager: widget.manager,
    );
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
        content: Text(
          idea.isTaskRecord
              ? 'سيُحذف سجل المساعد فقط. المهمة الأصلية لن تُحذف.'
              : 'سيتم حذف هذا العنصر نهائيًا من سجل المساعد.',
        ),
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

  void _openTask(AppTask task) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => widget.readOnly
            ? DesignerTaskViewScreen(task: task)
            : TaskReviewDetailScreen(task: task),
      ),
    );
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
          _AgentHeader(online: _agentOnline),
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
                    if (idea.isTaskRecord) {
                      return StreamBuilder<AppTask?>(
                        stream: FirestoreService.watchTask(idea.taskId!),
                        builder: (context, taskSnapshot) {
                          final linkedTask = taskSnapshot.data;
                          final verifying = taskSnapshot.connectionState ==
                                  ConnectionState.waiting &&
                              !taskSnapshot.hasData;
                          return _HistoryRecordCard(
                            idea: idea,
                            linkedTask: linkedTask,
                            verifying: verifying,
                            readOnly: widget.readOnly,
                            onOpen: linkedTask == null
                                ? null
                                : () => _openTask(linkedTask),
                            onDelete: widget.readOnly
                                ? null
                                : () => _deleteIdea(idea),
                          );
                        },
                      );
                    }
                    return _HistoryRecordCard(
                      idea: idea,
                      linkedTask: null,
                      verifying: false,
                      readOnly: widget.readOnly,
                      onOpen: null,
                      onDelete: widget.readOnly
                          ? null
                          : () => _deleteIdea(idea),
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
  const _AgentHeader({required this.online});

  final bool? online;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: const BoxDecoration(
        color: Color(0xFF071D3B),
        borderRadius: BorderRadius.vertical(top: Radius.circular(19)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 24,
            backgroundColor: Color(0x2233D6A6),
            child: Icon(Icons.auto_awesome, color: Color(0xFF33D6A6)),
          ),
          const SizedBox(width: 12),
          const Expanded(
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
          _OnlineBadge(online: online),
        ],
      ),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge({required this.online});

  final bool? online;

  @override
  Widget build(BuildContext context) {
    final checking = online == null;
    final available = online == true;
    final dotColor = checking
        ? const Color(0xFFE8B84B)
        : available
            ? const Color(0xFF33D6A6)
            : const Color(0xFFFF8A80);
    final foreground = checking
        ? const Color(0xFFFFD77A)
        : available
            ? const Color(0xFF8EF0D1)
            : const Color(0xFFFFB4AE);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x2233D6A6),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(radius: 4, backgroundColor: dotColor),
          const SizedBox(width: 6),
          Text(
            checking ? 'جارٍ الفحص' : available ? 'جاهز' : 'غير متصل',
            style: TextStyle(
              color: foreground,
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
            maxLines: action.type == 'create_task_draft' ? 3 : 5,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF536174), height: 1.45),
          ),
          if (action.isTaskCreation) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionDetailChip(
                  icon: Icons.badge_outlined,
                  label: action.employeeName.isEmpty
                      ? 'موظف غير محدد'
                      : '${action.employeeName} (${action.employeeNumber})',
                ),
                _ActionDetailChip(
                  icon: Icons.event_outlined,
                  label: action.dueDate,
                ),
                _ActionDetailChip(
                  icon: Icons.flag_outlined,
                  label: switch (action.priority) {
                    'high' => 'أولوية مرتفعة',
                    'low' => 'أولوية منخفضة',
                    _ => 'أولوية متوسطة',
                  },
                ),
                _ActionDetailChip(
                  icon: Icons.schedule_outlined,
                  label: '${action.plannedHours.toStringAsFixed(action.plannedHours % 1 == 0 ? 0 : 1)} ساعة',
                ),
              ],
            ),
          ],
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
                onPressed: working ||
                        (action.isTaskCreation && !action.hasExecutionDetails)
                    ? null
                    : onApprove,
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

class _HistoryRecordCard extends StatelessWidget {
  const _HistoryRecordCard({
    required this.idea,
    required this.linkedTask,
    required this.verifying,
    required this.readOnly,
    required this.onOpen,
    required this.onDelete,
  });

  final ManagerIdea idea;
  final AppTask? linkedTask;
  final bool verifying;
  final bool readOnly;
  final VoidCallback? onOpen;
  final VoidCallback? onDelete;

  String _dateTime(DateTime value) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${value.year}/${two(value.month)}/${two(value.day)} '
        '${two(value.hour)}:${two(value.minute)}';
  }

  String _date(DateTime value) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${value.year}/${two(value.month)}/${two(value.day)}';
  }

  @override
  Widget build(BuildContext context) {
    final taskExists = linkedTask != null;
    final status = taskExists
        ? statusLabelAr(linkedTask!.status.name)
        : idea.isTaskRecord
            ? verifying
                ? 'جارٍ التحقق'
                : 'المهمة محذوفة'
            : null;
    final dueDate = linkedTask?.dueDate ?? idea.dueDate;
    final assignee = idea.assigneeName ?? 'غير محدد';
    final employeeNumber = idea.employeeNumber ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: idea.isTaskRecord
              ? const Color(0x5533D6A6)
              : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                idea.isTaskRecord
                    ? Icons.task_alt_rounded
                    : Icons.auto_awesome_outlined,
                color: taskExists
                    ? const Color(0xFF138B68)
                    : const Color(0xFF8A94A3),
                size: 20,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      idea.taskTitle ?? idea.content,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF26364A),
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (idea.isTaskRecord) ...[
                      const SizedBox(height: 4),
                      Text(
                        'رقم المهمة: ${idea.taskId}',
                        style: const TextStyle(
                          color: Color(0xFF66758A),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'حذف السجل',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: AppColors.statusRejected,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (idea.isTaskRecord) ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                _HistoryFact(
                  icon: Icons.badge_outlined,
                  text: employeeNumber.isEmpty
                      ? assignee
                      : '$assignee ($employeeNumber)',
                ),
                if (dueDate != null)
                  _HistoryFact(
                    icon: Icons.event_outlined,
                    text: _date(dueDate),
                  ),
                if (status != null)
                  _HistoryFact(
                    icon: taskExists
                        ? Icons.sync_alt_rounded
                        : verifying
                            ? Icons.hourglass_top_rounded
                            : Icons.link_off_rounded,
                    text: status,
                    danger: !taskExists && !verifying,
                  ),
                _HistoryFact(
                  icon: Icons.schedule_outlined,
                  text: _dateTime(idea.createdAt),
                ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: onOpen,
              icon: Icon(taskExists ? Icons.open_in_new : Icons.link_off),
              label: Text(
                taskExists
                    ? readOnly
                        ? 'فتح المهمة'
                        : 'فتح المهمة وتعديلها'
                    : verifying
                        ? 'جارٍ التحقق من المهمة'
                        : 'المهمة غير موجودة',
              ),
            ),
          ] else ...[
            const SizedBox(height: 5),
            Text(
              idea.content,
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF536174),
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryFact extends StatelessWidget {
  const _HistoryFact({
    required this.icon,
    required this.text,
    this.danger = false,
  });

  final IconData icon;
  final String text;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? AppColors.statusRejected : const Color(0xFF526378);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFFEEEE) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE1E7EF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionDetailChip extends StatelessWidget {
  const _ActionDetailChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: const Color(0x33E8B84B)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF8B6418)),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5F4819),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
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
