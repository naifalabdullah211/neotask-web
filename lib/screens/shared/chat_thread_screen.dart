import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/message_model.dart';
import '../../providers/message_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../theme/app_theme.dart';

/// Shared chat thread UI — reused for BOTH the general (task-independent)
/// manager<->employee conversation AND per-task conversation threads. The
/// caller supplies the already-resolved [conversationId] (see
/// ChatMessage.generalConversationId / taskConversationId) so this widget
/// itself has no branching logic between the two scopes.
///
/// ATTACHMENTS: a paperclip icon lets the user pick an image (camera-roll)
/// or an arbitrary file, which is uploaded directly to Cloudinary (unsigned
/// preset — see CloudinaryService) and the resulting URL is stored on the
/// message via [ChatMessage.attachmentUrl]/[attachmentName]/[attachmentType].
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
    this.readOnly = false,
  });

  final String conversationId;
  final String? taskId;
  final String currentUserUid;
  final String otherUserUid;

  /// When true, this becomes a pure viewer: no message-input bar is
  /// rendered (send/attach are fully absent, not just disabled) and
  /// `markConversationRead` is never invoked. Added specifically for the
  /// read-only `designer` role (see UserRole.designer doc comment) — a
  /// designer must never write to Firestore, including via the implicit
  /// "mark as read" side effect that the normal chat view performs on
  /// every other participant's messages. Default `false` preserves the
  /// exact existing behavior for every current call site.
  final bool readOnly;

  @override
  State<ChatThreadBody> createState() => _ChatThreadBodyState();
}

class _ChatThreadBodyState extends State<ChatThreadBody> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    if (widget.readOnly) return;
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

  Future<void> _pickAndSendImage() async {
    final picker = ImagePicker();
    final XFile? picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await _uploadAndSend(
      bytes: bytes,
      filename: picked.name,
      attachmentType: 'image',
    );
  }

  Future<void> _pickAndSendFile() async {
    final result = await FilePicker.pickFiles(withData: true);
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذّرت قراءة الملف المحدَّد')),
        );
      }
      return;
    }
    await _uploadAndSend(
      bytes: bytes,
      filename: file.name,
      attachmentType: 'file',
    );
  }

  Future<void> _uploadAndSend({
    required List<int> bytes,
    required String filename,
    required String attachmentType,
  }) async {
    setState(() => _uploading = true);
    final messageProvider = context.read<MessageProvider>();
    try {
      final url = await CloudinaryService.uploadBytes(
        bytes: bytes,
        filename: filename,
      );
      if (!mounted) return;
      await messageProvider.sendMessage(
        conversationId: widget.conversationId,
        taskId: widget.taskId,
        senderUid: widget.currentUserUid,
        recipientUid: widget.otherUserUid,
        text: '',
        attachmentUrl: url,
        attachmentName: filename,
        attachmentType: attachmentType,
      );
      if (mounted) _scrollToBottomSoon();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذّر رفع الملف: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.photo_outlined,
                color: AppColors.deepBlue,
              ),
              title: const Text('صورة'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage();
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file_outlined,
                color: AppColors.deepBlue,
              ),
              title: const Text('ملف'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendFile();
              },
            ),
          ],
        ),
      ),
    );
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
              if (!widget.readOnly) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    context.read<MessageProvider>().markConversationRead(
                      widget.conversationId,
                      widget.currentUserUid,
                    );
                  }
                });
              }
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
        if (_uploading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 6),
            child: SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (!widget.readOnly)
          _MessageInputBar(
            controller: _controller,
            sending: _sending,
            uploading: _uploading,
            onSend: _send,
            onAttach: _showAttachmentSheet,
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
    this.readOnly = false,
  });

  final String conversationId;
  final String? taskId;
  final String currentUserUid;
  final String otherUserUid;
  final String title;
  final String? subtitle;
  final bool readOnly;

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
        readOnly: readOnly,
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final ChatMessage message;
  final bool isMine;

  Future<void> _openAttachment() async {
    final url = message.attachmentUrl;
    if (url == null) return;
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? AppColors.deepBlue : Colors.white;
    final textColor = isMine ? Colors.white : AppColors.textPrimary;
    final timeLabel = DateFormat('HH:mm').format(message.timestamp);
    final hasAttachment = message.attachmentUrl != null;
    final isImage = message.attachmentType == 'image';

    return Align(
      alignment: isMine ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.symmetric(
          horizontal: hasAttachment && isImage ? 6 : 14,
          vertical: hasAttachment && isImage ? 6 : 10,
        ),
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
            if (hasAttachment && isImage)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: GestureDetector(
                  onTap: _openAttachment,
                  child: Image.network(
                    message.attachmentUrl!,
                    fit: BoxFit.cover,
                    height: 160,
                    width: double.infinity,
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 100,
                      color: Colors.black12,
                      alignment: Alignment.center,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
              )
            else if (hasAttachment)
              InkWell(
                onTap: _openAttachment,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.insert_drive_file_outlined,
                        size: 20,
                        color: textColor,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          message.attachmentName ?? 'ملف مرفق',
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            decoration: TextDecoration.underline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (message.text.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  top: hasAttachment ? 6 : 0,
                  left: hasAttachment && isImage ? 6 : 0,
                  right: hasAttachment && isImage ? 6 : 0,
                ),
                child: Text(
                  message.text,
                  style: TextStyle(color: textColor, fontSize: 14),
                ),
              ),
            Padding(
              padding: EdgeInsets.only(
                top: 4,
                left: hasAttachment && isImage ? 6 : 0,
                right: hasAttachment && isImage ? 6 : 0,
                bottom: hasAttachment && isImage ? 4 : 0,
              ),
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

/// Message composer — text field + attachment (paperclip) + send button.
class _MessageInputBar extends StatelessWidget {
  const _MessageInputBar({
    required this.controller,
    required this.sending,
    required this.uploading,
    required this.onSend,
    required this.onAttach,
  });

  final TextEditingController controller;
  final bool sending;
  final bool uploading;
  final VoidCallback onSend;
  final VoidCallback onAttach;

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
            IconButton(
              onPressed: uploading ? null : onAttach,
              icon: const Icon(Icons.attach_file_rounded),
              color: AppColors.textSecondary,
            ),
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
