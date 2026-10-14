import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/models.dart';
import '../core/l10n.dart';
import '../state/app_state.dart';
import '../state/chat_state.dart';
import '../state/sessions_state.dart';
import '../widgets/assistant_view.dart';
import '../widgets/chat_input_bar.dart';
import '../widgets/model_picker.dart';
import '../widgets/permission_card.dart';
import '../widgets/user_bubble.dart';

/// Chat screen for one session, with live streaming and permission handling.
class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key,
    required this.sessionID,
    this.initialMessage,
    this.initialAttachments = const [],
  });

  final String sessionID;

  /// First user message to send automatically after the history loads —
  /// used when the session is created from the home composer.
  final String? initialMessage;
  final List<OcAttachment> initialAttachments;

  @override
  Widget build(BuildContext context) {
    final app = context.read<AppState>();
    return ChangeNotifierProvider(
      create: (_) => ChatState(app: app, sessionID: sessionID)
        ..bootstrap(
            thenSend: initialMessage, attachments: initialAttachments),
      child: const _ChatView(),
    );
  }
}

class _ChatView extends StatefulWidget {
  const _ChatView();

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final _scrollController = ScrollController();
  bool _autoScroll = true;

  // Pending image attachments for the next message.
  final ImagePicker _picker = ImagePicker();
  final List<OcAttachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      final position = _scrollController.position;
      if (!position.hasPixels) return;
      // Stay pinned to the bottom while the user hasn't scrolled up.
      final distance = position.maxScrollExtent - position.pixels;
      if (position.userScrollDirection == ScrollDirection.reverse &&
          distance > 120) {
        _autoScroll = false;
      } else if (distance < 60) {
        _autoScroll = true;
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Bottom sheet offering camera or gallery.
  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: Text(L.tr('كاميرا', 'Camera')),
              onTap: () =>
                  Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(L.tr('من الاستوديو', 'From gallery')),
              onTap: () =>
                  Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    try {
      // Downscale + compress so the base64 payload stays reasonable.
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        maxHeight: 1280,
        imageQuality: 82,
      );
      if (file == null || !mounted) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      final mime = (file.mimeType ??
              (file.name.toLowerCase().endsWith('.png')
                  ? 'image/png'
                  : 'image/jpeg'));
      setState(() {
        _attachments.add(OcAttachment(
          dataBase64: base64Encode(bytes),
          mime: mime,
          name: file.name,
        ));
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L.tr('فشل اختيار الصورة: $e',
                'Could not pick image: $e')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _send(String text) async {
    final chat = context.read<ChatState>();
    if (text.trim().isEmpty && _attachments.isEmpty) return;
    final attachments = List<OcAttachment>.of(_attachments);
    setState(() => _attachments.clear());
    await chat.send(text, attachments: attachments);
  }

  void _jumpToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatState>();
    final sessions = context.watch<SessionsState>();
    OcSession? session;
    for (final s in sessions.sessions) {
      if (s.id == chat.sessionID) {
        session = s;
        break;
      }
    }
    final title =
        session?.title?.trim().isNotEmpty == true ? session!.title! : L.tr('محادثة', 'Chat');

    // Rebuilds arrive on every streamed delta; keep the view pinned to the
    // bottom while the user hasn't scrolled away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_autoScroll) _jumpToBottom(animated: false);
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            if (session?.model != null || session?.agent != null)
              Text(
                [
                  if (session?.agent != null) session!.agent!,
                  if (session?.model != null) session!.model!.id,
                  if (session?.directory != null)
                    session!.directory!.split('/').last,
                ].join(' · '),
                textDirection: TextDirection.ltr,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        actions: [
          if (chat.busy)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.smart_toy_outlined),
            tooltip: L.tr('تغيير الموديل', 'Switch model'),
            onPressed: () =>
                showModelPicker(context, chat, current: session?.model),
          ),
        ],
      ),
      body: Column(
        children: [
          if (chat.error != null)
            _ErrorBanner(message: chat.error!, onDismiss: chat.clearError),
          Expanded(
            child: chat.loading
                ? const Center(child: CircularProgressIndicator())
                : chat.messages.isEmpty
                    ? _EmptyChat(busy: chat.busy)
                    : _MessageList(
                        controller: _scrollController,
                        messages: chat.messages,
                        busy: chat.busy,
                      ),
          ),
          for (final request in chat.pendingPermissions)
            PermissionCard(
              request: request,
              onReply: (decision) =>
                  chat.replyPermission(request, decision),
            ),
          ChatInputBar(
            busy: chat.busy,
            onSend: _send,
            onInterrupt: chat.interrupt,
            onAttach: _pickImage,
            attachments: _attachments,
            onRemoveAttachment: (index) =>
                setState(() => _attachments.removeAt(index)),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({
    required this.controller,
    required this.messages,
    required this.busy,
  });

  final ScrollController controller;
  final List<OcMessage> messages;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final lastStreaming = messages.isNotEmpty && messages.last.streaming;
    return ListView.builder(
      controller: controller,
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      itemCount: messages.length + (busy && !lastStreaming ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= messages.length) {
          return const TypingIndicator();
        }
        final message = messages[index];
        return message.type == 'user'
            ? UserBubble(message: message)
            : AssistantView(message: message);
      },
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.busy});

  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.smart_toy_outlined,
              size: 64,
              color:
                  Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              L.tr('ابدأ المحادثة ✨', 'Start the chat ✨'),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              L.tr('اكتب طلبك و OpenCode هيشتغل على المشروع مباشرة', 'Type your request and OpenCode will work on your project right away'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: scheme.error),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          InkWell(
            onTap: onDismiss,
            child: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
