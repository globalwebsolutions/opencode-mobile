import 'package:flutter/material.dart';
import 'package:gpt_markdown/gpt_markdown.dart';

import '../core/models.dart';
import 'tool_card.dart';

/// One assistant message: reasoning, markdown text, and tool cards,
/// rendered left-aligned like Claude/ChatGPT answers.
class AssistantView extends StatelessWidget {
  const AssistantView({super.key, required this.message});

  final OcMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final streaming = message.streaming;

    final children = <Widget>[
      for (final part in message.content)
        if (part.type == 'reasoning')
          _ReasoningTile(part: part, scheme: scheme)
        else if (part.type == 'text' && (part.text ?? '').trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: SelectionArea(
              child: GptMarkdown(
                part.text ?? '',
                style: theme.textTheme.bodyLarge!.copyWith(height: 1.5),
              ),
            ),
          )
        else if (part.type == 'tool')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ToolCard(part: part),
          ),
      if (streaming)
        const Padding(
          padding: EdgeInsets.only(top: 6, bottom: 2),
          child: _StreamingCursor(),
        ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Small header: agent + model.
          Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: scheme.primary.withValues(alpha: 0.15),
                child: Icon(
                  Icons.auto_awesome,
                  size: 13,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                [
                  if (message.agent != null) message.agent!,
                  if (message.model != null) message.model!.id,
                ].join(' · '),
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (message.cost != null)
                Text(
                  '\$${message.cost!.toStringAsFixed(message.cost! < 1 ? 3 : 2)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
          ...children,
        ],
      ),
    );
  }
}

/// Collapsible reasoning section, like the "thinking" chips in chat apps.
class _ReasoningTile extends StatefulWidget {
  const _ReasoningTile({required this.part, required this.scheme});

  final OcPart part;
  final ColorScheme scheme;

  @override
  State<_ReasoningTile> createState() => _ReasoningTileState();
}

class _ReasoningTileState extends State<_ReasoningTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = widget.scheme;
    final text = widget.part.text ?? '';
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: _expanded,
            onExpansionChanged: (v) => setState(() => _expanded = v),
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            dense: true,
            leading: Icon(
              Icons.psychology_outlined,
              size: 18,
              color: scheme.onSurfaceVariant,
            ),
            title: Text(
              text.isEmpty ? 'بيفكر...' : 'التفكير',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
            children: [
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SelectionArea(
                  child: Text(
                    text,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
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

/// Blinking cursor shown while the assistant streams text.
class _StreamingCursor extends StatefulWidget {
  const _StreamingCursor();

  @override
  State<_StreamingCursor> createState() => _StreamingCursorState();
}

class _StreamingCursorState extends State<_StreamingCursor>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FadeTransition(
      opacity: _controller,
      child: Container(
        width: 9,
        height: 18,
        decoration: BoxDecoration(
          color: scheme.primary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// Independent typing indicator shown while the agent works between messages.
class TypingIndicator extends StatelessWidget {
  const TypingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.auto_awesome,
              size: 14, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          const _Dots(),
        ],
      ),
    );
  }
}

class _Dots extends StatefulWidget {
  const _Dots();

  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final t = (_controller.value * 3 - i).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: 0.25 + 0.75 * t,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
