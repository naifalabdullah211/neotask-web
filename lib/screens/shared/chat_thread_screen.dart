import 'package:flutter/material.dart' hide Text;
import 'package:neotask_pro/widgets/localized_text.dart';
import 'package:neotask_pro/l10n/app_i18n.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/message_model.dart';
import '../../providers/message_provider.dart';
import '../../services/cloudinary_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/voice_message_recorder_button.dart';
import '../../widgets/voice_message_player.dart';
import 'voice_call_screen.dart';

/// Shared chat thread UI — reused for BOTH the general (task-independent)
/// manager<->employee conversation AND per-task conversation threads. The
/// caller supplies the already-resolved [conversationId] (see
/// ChatMessage.generalConversationId / taskConversationId) so this widget
/// itself has no branching logic between the two scopes. Works identically
/// for 1-to-1 general DMs and per-task threads (which, per the current
/// AppTask model, always have exactly one assignee — see
/// AppTask.assignedTo — so "group" chat here means a task thread viewed by
/// its two participants + the read-only `designer` role, not N employees;
/// the reply feature below has NO dependency on participant count and
/// works identically in both scopes).
///
/// ATTACHMENTS: a paperclip icon lets the user pick an image (camera-roll)
/// or an arbitrary file, which is uploaded directly to Cloudinary (unsigned
/// preset — see CloudinaryService) and the resulting URL is stored on the
/// message via [ChatMessage.attachmentUrl]/[attachmentName]/[attachmentType].
///
/// REPLY-TO-MESSAGE: long-pressing any bubble opens a quick action sheet
/// with "رد" (reply) as the first option. Selecting it populates
/// [_replyingTo] and shows a preview bar above the input field
/// (`_ReplyPreviewBar`). Sending while [_replyingTo] is set attaches
/// `replyToMessageId` to the new message (see MessageProvider.sendMessage).
/// Rendering the quoted block in a bubble resolves the ORIGINAL message
/// from the already-loaded `messages` list (no extra Firestore read) via
/// [_ChatThreadBodyState._messageById] passed down to `_MessageBubble`.
/// Tapping the quoted block scrolls the list to the original message's
/// position (tracked via a `GlobalKey` per messageId) and briefly
/// highlights it.
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
  /// exact existing behavior for every current call site. Long-press
  /// reply is ALSO suppressed when readOnly (a viewer cannot start a
  /// reply since they cannot send messages at all), but tapping a quoted
  /// block to jump to the original message remains available (read-only
  /// navigation, not a write).
  final bool readOnly;

  @override
  State<ChatThreadBody> createState() => _ChatThreadBodyState();
}

class _ChatThreadBodyState extends State<ChatThreadBody> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  bool _uploading = false;

  /// The message currently being replied to (set via the long-press "رد"
  /// action, cleared on send / on explicit "×" cancel). Null => not
  /// currently composing a reply.
  ChatMessage? _replyingTo;

  /// One GlobalKey per rendered message bubble, keyed by messageId — used
  /// by `_scrollToMessage` to locate & highlight the original message
  /// when a quoted block is tapped. Rebuilt (entries added) every build()
  /// as new messages stream in; stale keys for messages no longer in the
  /// list are harmless (simply never looked up again).
  final Map<String, GlobalKey> _bubbleKeys = {};

  /// messageId of a bubble currently in its brief "just jumped here"
  /// highlight flash (see _scrollToMessage) — used purely for the visual
  /// flash effect on `_MessageBubble`.
  String? _highlightedMessageId;

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

  GlobalKey _keyFor(String messageId) {
    return _bubbleKeys.putIfAbsent(messageId, () => GlobalKey());
  }

  /// Scrolls the list so the bubble for [messageId] is visible, then
  /// briefly flashes a highlight on it (1 second) — used when the user
  /// taps a quoted "replying to..." block inside another message.
  Future<void> _scrollToMessage(String messageId) async {
    final key = _bubbleKeys[messageId];
    final ctx = key?.currentContext;
    if (ctx == null) {
      // The original message isn't currently mounted in the list (e.g.
      // scrolled far out of the lazy-built ListView.builder range). Best
      // effort: nothing to scroll to yet — a real implementation could
      // retry after jumping near it, but for this conversation's typical
      // (small) message volume the ListView.builder keeps all items
      // built, so this path is not expected to trigger in practice.
      return;
    }
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      alignment: 0.5,
    );
    if (!mounted) return;
    setState(() => _highlightedMessageId = messageId);
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted && _highlightedMessageId == messageId) {
        setState(() => _highlightedMessageId = null);
      }
    });
  }

  void _startReply(ChatMessage message) {
    setState(() => _replyingTo = message);
  }

  void _cancelReply() {
    setState(() => _replyingTo = null);
  }

  /// Long-press quick-actions sheet — "رد" (reply) is always the first
  /// option per the product spec. Suppressed entirely in read-only mode
  /// (see ChatThreadBody.readOnly doc comment).
  void _showMessageActions(ChatMessage message) {
    if (widget.readOnly) return;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(
                Icons.reply_rounded,
                color: AppColors.deepBlue,
              ),
              title: const Text('رد'),
              onTap: () {
                Navigator.pop(context);
                _startReply(message);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    final replyToMessageId = _replyingTo?.messageId;
    _controller.clear();
    setState(() => _replyingTo = null);
    try {
      await context.read<MessageProvider>().sendMessage(
        conversationId: widget.conversationId,
        taskId: widget.taskId,
        senderUid: widget.currentUserUid,
        recipientUid: widget.otherUserUid,
        text: text,
        replyToMessageId: replyToMessageId,
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

  Future<void> _sendVoiceMessage(
    List<int> bytes,
    String filename,
    int durationSeconds,
  ) async {
    await _uploadAndSend(
      bytes: bytes,
      filename: filename,
      attachmentType: 'voice',
    );
  }

  Future<void> _uploadAndSend({
    required List<int> bytes,
    required String filename,
    required String attachmentType,
  }) async {
    setState(() => _uploading = true);
    final messageProvider = context.read<MessageProvider>();
    final replyToMessageId = _replyingTo?.messageId;
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
        replyToMessageId: replyToMessageId,
      );
      if (mounted) {
        setState(() => _replyingTo = null);
        _scrollToBottomSoon();
      }
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
              // Lookup map for resolving a reply's original message by id
              // WITHOUT an extra Firestore read — the full conversation is
              // already loaded here.
              final byId = <String, ChatMessage>{
                for (final m in messages) m.messageId: m,
              };
              return ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isMine = msg.senderUid == widget.currentUserUid;
                  final quoted = msg.replyToMessageId != null
                      ? byId[msg.replyToMessageId]
                      : null;
                  return _MessageBubble(
                    key: _keyFor(msg.messageId),
                    message: msg,
                    isMine: isMine,
                    quotedMessage: quoted,
                    highlighted: _highlightedMessageId == msg.messageId,
                    onLongPress: widget.readOnly
                        ? null
                        : () => _showMessageActions(msg),
                    onTapQuoted: msg.replyToMessageId == null
                        ? null
                        : () => _scrollToMessage(msg.replyToMessageId!),
                  );
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
        if (!widget.readOnly && _replyingTo != null)
          _ReplyPreviewBar(message: _replyingTo!, onCancel: _cancelReply),
        if (!widget.readOnly)
          _MessageInputBar(
            controller: _controller,
            sending: _sending,
            uploading: _uploading,
            onSend: _send,
            onAttach: _showAttachmentSheet,
            onVoiceRecorded: _sendVoiceMessage,
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
        actions: [
          if (!readOnly)
            IconButton(
              tooltip: context.tr('اتصال صوتي'),
              icon: const Icon(Icons.call_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => VoiceCallScreen.outgoing(
                      conversationId: conversationId,
                      taskId: taskId,
                      currentUserUid: currentUserUid,
                      otherUserUid: otherUserUid,
                      otherUserName:
                          FirestoreService.getUser(otherUserUid)?.name ?? title,
                    ),
                  ),
                );
              },
            ),
        ],
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

/// Preview bar shown above the input field while composing a reply — shows
/// the original sender's name + a one-line-truncated preview of their
/// message, with an "×" button to cancel the reply.
class _ReplyPreviewBar extends StatelessWidget {
  const _ReplyPreviewBar({required this.message, required this.onCancel});

  final ChatMessage message;
  final VoidCallback onCancel;

  String get _senderName {
    final user = FirestoreService.getUser(message.senderUid);
    return user?.name ?? 'مستخدم';
  }

  String get _preview {
    if (message.text.isNotEmpty) return message.text;
    switch (message.attachmentType) {
      case 'image':
        return '📷 صورة';
      case 'voice':
        return '🎤 رسالة صوتية';
      case 'file':
        return '📎 ${message.attachmentName ?? 'ملف مرفق'}';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(width: 3, height: 34, color: AppColors.gold),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الرد على $_senderName',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.deepBlue,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onCancel,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: AppColors.textSecondary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

/// Quoted-original-message block rendered INSIDE a reply bubble, above the
/// reply's own text — full (non-truncated) original text per the product
/// spec, with a colored accent bar on the leading edge. Tapping it invokes
/// [onTap] (wired by the caller to `_scrollToMessage`).
class _QuotedMessageBlock extends StatelessWidget {
  const _QuotedMessageBlock({
    required this.quotedMessage,
    required this.isMine,
    this.onTap,
  });

  final ChatMessage? quotedMessage;
  final bool isMine;
  final VoidCallback? onTap;

  String get _senderName {
    if (quotedMessage == null) return '';
    final user = FirestoreService.getUser(quotedMessage!.senderUid);
    return user?.name ?? 'مستخدم';
  }

  String get _quotedText {
    final q = quotedMessage;
    if (q == null) return 'الرسالة الأصلية غير متاحة';
    if (q.text.isNotEmpty) return q.text;
    switch (q.attachmentType) {
      case 'image':
        return '📷 صورة';
      case 'voice':
        return '🎤 رسالة صوتية';
      case 'file':
        return '📎 ${q.attachmentName ?? 'ملف مرفق'}';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Secondary color distinct from the reply's own text color, adapted to
    // the bubble's background (dark navy bubble for "mine" vs. white
    // bubble for the other participant) so the quoted block always reads
    // clearly as a lighter/secondary tone relative to the reply text.
    final quoteTextColor = isMine
        ? Colors.white.withValues(alpha: 0.75)
        : AppColors.textSecondary;
    final nameColor = isMine ? AppColors.goldLight : AppColors.deepBlue;
    final barColor = isMine ? AppColors.goldLight : AppColors.gold;
    final bgColor = isMine
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.background;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              constraints: const BoxConstraints(minHeight: 28),
              decoration: BoxDecoration(
                color: barColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (quotedMessage != null)
                    Text(
                      _senderName,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: nameColor,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    _quotedText,
                    // Full text, not truncated — per the product spec.
                    style: TextStyle(
                      fontSize: 12.5,
                      color: quoteTextColor,
                      fontStyle: quotedMessage == null
                          ? FontStyle.italic
                          : FontStyle.normal,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.quotedMessage,
    this.highlighted = false,
    this.onLongPress,
    this.onTapQuoted,
  });

  final ChatMessage message;
  final bool isMine;

  /// Resolved original message this bubble is replying to (null if this
  /// message isn't a reply, or if the original could not be resolved —
  /// see `_QuotedMessageBlock._quotedText`'s fallback text for the latter
  /// case).
  final ChatMessage? quotedMessage;

  /// True for a brief moment right after the user taps a quoted block to
  /// jump to this bubble — drives a temporary highlight overlay.
  final bool highlighted;

  final VoidCallback? onLongPress;
  final VoidCallback? onTapQuoted;

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
    final isVoice = message.attachmentType == 'voice';
    final isCall = message.attachmentType == 'call';
    final isReply = message.replyToMessageId != null;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
        alignment: isMine ? Alignment.centerLeft : Alignment.centerRight,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.symmetric(
            horizontal: hasAttachment && isImage ? 6 : 14,
            vertical: hasAttachment && isImage ? 6 : 10,
          ),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          decoration: BoxDecoration(
            color: highlighted
                ? (isMine
                      ? AppColors.deepBlue.withValues(alpha: 0.7)
                      : AppColors.gold.withValues(alpha: 0.18))
                : bubbleColor,
            borderRadius: BorderRadius.circular(16),
            border: highlighted
                ? Border.all(color: AppColors.gold, width: 1.5)
                : null,
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
              if (isReply)
                _QuotedMessageBlock(
                  quotedMessage: quotedMessage,
                  isMine: isMine,
                  onTap: onTapQuoted,
                ),
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
              else if (hasAttachment && isVoice)
                VoiceMessagePlayer(url: message.attachmentUrl!, isMine: isMine)
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
              if (isCall)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.call_outlined,
                      size: 20,
                      color: isMine ? AppColors.mintAccent : AppColors.deepBlue,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        message.text,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                )
              else if (message.text.isNotEmpty)
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
      ),
    );
  }
}

/// Message composer — text field + attachment (paperclip) + voice
/// recorder (mic) + send button.
class _MessageInputBar extends StatelessWidget {
  const _MessageInputBar({
    required this.controller,
    required this.sending,
    required this.uploading,
    required this.onSend,
    required this.onAttach,
    required this.onVoiceRecorded,
  });

  final TextEditingController controller;
  final bool sending;
  final bool uploading;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final void Function(List<int> bytes, String filename, int durationSeconds)
  onVoiceRecorded;

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
            VoiceMessageRecorderButton(
              enabled: !uploading,
              onRecorded: onVoiceRecorded,
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: context.tr('اكتب رسالة...'),
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
