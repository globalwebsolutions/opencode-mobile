import 'dart:convert';

import 'package:flutter/material.dart';

import '../core/l10n.dart';
import '../core/models.dart';

/// Bottom message composer.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.busy,
    required this.onSend,
    required this.onInterrupt,
    this.onAttach,
    this.attachments = const [],
    this.onRemoveAttachment,
  });

  final bool busy;
  final ValueChanged<String> onSend;
  final VoidCallback onInterrupt;

  /// When non-null, a paperclip button appears to attach an image.
  final VoidCallback? onAttach;
  final List<OcAttachment> attachments;
  final ValueChanged<int>? onRemoveAttachment;

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if ((text.isEmpty && widget.attachments.isEmpty) || widget.busy) return;
    _controller.clear();
    widget.onSend(text);
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.attachments.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (var i = 0; i < widget.attachments.length; i++)
                      _AttachmentChip(
                        attachment: widget.attachments[i],
                        onRemove: widget.onRemoveAttachment == null
                            ? null
                            : () => widget.onRemoveAttachment!(i),
                      ),
                  ],
                ),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (widget.onAttach != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: IconButton(
                      onPressed: widget.busy ? null : widget.onAttach,
                      icon: const Icon(Icons.attach_file_rounded),
                      tooltip: L.tr('إرفاق صورة', 'Attach image'),
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    enabled: !widget.busy,
                    minLines: 1,
                    maxLines: 6,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: widget.busy
                          ? L.tr('الوكيل شغال حاليًا...', 'Agent is working...')
                          : L.tr('اكتب رسالتك لـ OpenCode...',
                              'Message OpenCode...'),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                widget.busy
                    ? IconButton.filled(
                        onPressed: widget.onInterrupt,
                        icon: const Icon(Icons.stop_rounded),
                        tooltip: L.tr('إيقاف', 'Stop'),
                        style: IconButton.styleFrom(
                          backgroundColor: scheme.errorContainer,
                          foregroundColor: scheme.onErrorContainer,
                        ),
                      )
                    : ValueListenableBuilder(
                        valueListenable: _controller,
                        builder: (context, TextEditingValue value, _) {
                          final ready = value.text.trim().isNotEmpty ||
                              widget.attachments.isNotEmpty;
                          return IconButton.filled(
                            onPressed: ready ? _send : null,
                            icon: const Icon(Icons.arrow_upward_rounded),
                            tooltip: L.tr('إرسال', 'Send'),
                            style: IconButton.styleFrom(
                              backgroundColor: ready
                                  ? scheme.primary
                                  : scheme.surfaceContainerHighest,
                              foregroundColor: ready
                                  ? scheme.onPrimary
                                  : scheme.onSurfaceVariant.withValues(
                                      alpha: 0.5),
                            ),
                          );
                        },
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Small image thumbnail with a remove button for pending attachments.
class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.attachment, this.onRemove});

  final OcAttachment attachment;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
        return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: attachment.isImage
              ? Image.memory(
                  base64Decode(attachment.dataBase64),
                  width: 64,
                  height: 64,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    width: 64,
                    height: 64,
                    color: scheme.surfaceContainerHighest,
                    child: const Icon(Icons.broken_image_outlined, size: 20),
                  ),
                )
              : Container(
                  width: 64,
                  height: 64,
                  color: scheme.surfaceContainerHighest,
                  child: Icon(Icons.insert_drive_file_outlined,
                      size: 22, color: scheme.onSurfaceVariant),
                ),
        ),
        if (onRemove != null)
          Positioned(
            top: -6,
            right: -6,
            child: InkWell(
              onTap: onRemove,
              customBorder: const CircleBorder(),
              child: Container(
                decoration: BoxDecoration(
                  color: scheme.error,
                  shape: BoxShape.circle,
                  border: Border.all(color: scheme.surface, width: 1.5),
                ),
                padding: const EdgeInsets.all(2),
                child: Icon(Icons.close, size: 14, color: scheme.onError),
              ),
            ),
          ),
      ],
    );
  }
}
