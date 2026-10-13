import 'package:flutter/material.dart';

/// Bottom message composer.
class ChatInputBar extends StatefulWidget {
  const ChatInputBar({
    super.key,
    required this.busy,
    required this.onSend,
    required this.onInterrupt,
  });

  final bool busy;
  final ValueChanged<String> onSend;
  final VoidCallback onInterrupt;

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
    if (text.isEmpty || widget.busy) return;
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
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
                      ? 'الوكيل شغال حاليًا...'
                      : 'اكتب رسالتك لـ OpenCode...',
                ),
              ),
            ),
            const SizedBox(width: 8),
            widget.busy
                ? IconButton.filled(
                    onPressed: widget.onInterrupt,
                    icon: const Icon(Icons.stop_rounded),
                    tooltip: 'إيقاف',
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.errorContainer,
                      foregroundColor: scheme.onErrorContainer,
                    ),
                  )
                : ValueListenableBuilder(
                    valueListenable: _controller,
                    builder: (context, TextEditingValue value, _) {
                      final ready = value.text.trim().isNotEmpty;
                      return IconButton.filled(
                        onPressed: ready ? _send : null,
                        icon: const Icon(Icons.arrow_upward_rounded),
                        tooltip: 'إرسال',
                        style: IconButton.styleFrom(
                          backgroundColor: ready
                              ? scheme.primary
                              : scheme.surfaceContainerHighest,
                          foregroundColor: ready
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                        ),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
