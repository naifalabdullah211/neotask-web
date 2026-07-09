import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/message_model.dart';
import '../../providers/message_provider.dart';
import '../../theme/app_theme.dart';

/// Shared chat thread UI — reused for BOTH the general (task-independent)
/// manager<->employee conversation AND per-task conversation threads. The
/// caller supplies the already-resolved [conversationId] (see
/// ChatMessage.generalConversationId / taskConversationId) so this widget
/// itself has no branching logic between the two scopes.
///
/// INTENTIONAL SCOPE LIMITATION (per current product decision): this UI
/// renders a plain text input + send button ONLY. There is no attachment /
/// image / file icon anywhere. The underlying `ChatMessage` model already
/// reserves an `attachmentUrl` field so that attachment support can be
/// added later purely as a UI change (new icon + upload call), with zero
/// data-model migration — see message_model.dart.
///
/// [ChatThreadBody] contains no Scaffold/AppBar of its own so it can be
/// embedded directly inside an existing bottom-nav tab page (which already
/// has an AppBar supplied by its parent Scaffold). [ChatThreadScreen] wraps
/// [ChatThreadBody] in its own Scaffold+AppBar for the per-task use case,
/// which is pushed as a standalone route from a task detail screen.
class ChatThreadBody extends StatefulWidget {
  const ChatThreadBody({
    super.key,
    required this.conversationId,
    this.taskId,
    required this.currentUserUid,
    required this.otherUserUid,
  });

  final String conversationId;
  final String? taskId;
  final String currentUserUid;
  final String otherUserUid;

  @override
  State<ChatThreadBody> createState() => _ChatThreadBodyState();
}

class _ChatThreadBodyState extends State<ChatThreadBody> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<MessageProvider>().markConversationRead(
          widget.conversationId,
          widget.currentUserUid,
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      await context.read<MessageProvider>().sendMessage(
        conversationId: widget.conversationId,
        taskId: widget.taskId,
        senderUid: widget.currentUserUid,
        recipientUid: widget.otherUserUid,
        text: text,
      );
      if (mounted) _scrollToBottomSoon();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذّر إرسال الرسالة: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<ChatMessage>>(
            stream: context.read<MessageProvider>().watchConversation(
              widget.conversationId,
            ),
            initialData: context.read<MessageProvider>().conversation(
              widget.conversationId,
            ),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return const Center(
                  child: Text(
                    'لا توجد رسائل بعد — ابدأ المحادثة',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                );
              }
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  context.read<MessageProvider>().markConversationRead(
                    widget.conversationId,
                    widget.currentUserUid,
                  );
                }
              });
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMine = msg.senderUid == widget.currentUserUid;
                  return _MessageBubble(message: msg, isMine: isMine);
                },
              );
            },
          ),
        ),
        _MessageInputBar(
          controller: _controller,
          sending: _sending,
          onSend: _send,
        ),
      ],
    );
  }
}

/// Standalone pushed screen wrapper around [ChatThreadBody] — used for the
/// per-task conversation thread (opened from a task detail screen).
class ChatThreadScreen extends StatelessWidget {
  const ChatThreadScreen({
    super.key,
    required this.conversationId,
    this.taskId,
    required this.currentUserUid,
    required this.otherUserUid,
    required this.title,
    this.subtitle,
  });

  final String conversationId;
  final String? taskId;
  final String currentUserUid;
  final String otherUserUid;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        bottom: subtitle != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(20),
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    subtitle!,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              )
            : null,
      ),
      backgroundColor: AppColors.background,
      body: ChatThreadBody(
        conversationId: conversationId,
        taskId: taskId,
        currentUserUid: currentUserUid,
        otherUserUid: otherUserUid,
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? AppColors.deepBlue : Colors.white;
    final textColor = isMine ? Colors.white : AppColors.textPrimary;
    final timeLabel = DateFormat('HH:mm').format(message.timestamp);

    return Align(
      alignment: isMine ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(color: textColor, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              timeLabel,
              style: TextStyle(
                color: isMine ? Colors.white70 : AppColors.textSecondary,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Message composer — text field + send button ONLY. No attachment icon
/// exists in this widget by design (see class-level doc comment above).
class _MessageInputBar extends StatelessWidget {
  const _MessageInputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'اكتب رسالة...',
                  filled: true,
                  fillColor: AppColors.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              color: AppColors.deepBlue,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.background,
                shape: const CircleBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
