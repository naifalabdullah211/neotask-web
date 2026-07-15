import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../models/criterion_chat_model.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

/// Dedicated chat widget for a single Criterion's chat thread.
///
/// CRITICAL DESIGN CONSTRAINT: this is a COMPLETELY SEPARATE chat system
/// from the existing Task-chat/general-DM `ChatMessage`/`MessageProvider`
/// infrastructure (see [ChatThreadBody] in chat_thread_screen.dart, kept
/// only as a visual/structural reference, NOT reused here). It reads and
/// writes exclusively via [FirestoreService.watchCriterionChat] /
/// [FirestoreService.sendCriterionChatMessage] against the Firestore
/// subcollection path `goals/{goalId}/criteria/{criteriaId}/chat/
/// {messageId}`, using the minimal [CriterionChatMessage] model
/// (senderId, text, timestamp only — no attachments, no read-receipts,
/// per the manager's literal spec).
class CriterionChatBody extends StatefulWidget {
  const CriterionChatBody({
    super.key,
    required this.goalId,
    required this.criterionId,
    required this.currentUserUid,
    this.readOnly = false,
  });

  final String goalId;
  final String criterionId;
  final String currentUserUid;

  /// When true, no message-input bar is rendered — used for the
  /// read-only `designer` observer role.
  final bool readOnly;

  @override
  State<CriterionChatBody> createState() => _CriterionChatBodyState();
}

class _CriterionChatBodyState extends State<CriterionChatBody> {
  static const _uuid = Uuid();
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

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
      final message = CriterionChatMessage(
        messageId: _uuid.v4(),
        senderId: widget.currentUserUid,
        text: text,
        timestamp: DateTime.now(),
      );
      await FirestoreService.sendCriterionChatMessage(
        goalId: widget.goalId,
        criterionId: widget.criterionId,
        message: message,
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
          child: StreamBuilder<List<CriterionChatMessage>>(
            stream: FirestoreService.watchCriterionChat(
              goalId: widget.goalId,
              criterionId: widget.criterionId,
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
              _scrollToBottomSoon();
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMine = msg.senderId == widget.currentUserUid;
                  return _CriterionMessageBubble(message: msg, isMine: isMine);
                },
              );
            },
          ),
        ),
        if (!widget.readOnly)
          _CriterionChatInputBar(
            controller: _controller,
            sending: _sending,
            onSend: _send,
          ),
      ],
    );
  }
}

class _CriterionMessageBubble extends StatelessWidget {
  const _CriterionMessageBubble({required this.message, required this.isMine});

  final CriterionChatMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? AppColors.deepBlue : Colors.white;
    final textColor = isMine ? Colors.white : AppColors.textPrimary;
    final timeLabel = DateFormat('HH:mm').format(message.timestamp);
    final senderName = FirestoreService.getUser(message.senderId)?.name;

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
            if (!isMine && senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  senderName,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.deepBlue,
                  ),
                ),
              ),
            Text(
              message.text,
              style: TextStyle(color: textColor, fontSize: 14),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                timeLabel,
                style: TextStyle(
                  color: isMine ? Colors.white70 : AppColors.textSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple text-only composer — no attachments per the literal spec
/// (senderId/text/timestamp only).
class _CriterionChatInputBar extends StatelessWidget {
  const _CriterionChatInputBar({
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
