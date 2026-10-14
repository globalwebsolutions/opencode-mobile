import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/l10n.dart';

/// A tool call card: name, status, expandable input and output.
class ToolCard extends StatelessWidget {
  const ToolCard({super.key, required this.part});

  final OcPart part;

  IconData get _icon {
    switch (part.toolName) {
      case 'read':
      case 'grep':
      case 'glob':
        return Icons.search_rounded;
      case 'edit':
        return Icons.edit_note_outlined;
      case 'write':
        return Icons.save_outlined;
      case 'shell':
        return Icons.terminal_rounded;
      case 'webfetch':
      case 'websearch':
        return Icons.travel_explore_rounded;
      case 'browser':
        return Icons.public_rounded;
      case 'task':
      case 'subagent':
        return Icons.account_tree_rounded;
      default:
        return Icons.construction_rounded;
    }
  }

  String get _statusLabel {
    switch (part.toolStatus) {
      case 'running':
        return L.tr('بيشتغل...', 'running...');
      case 'completed':
        return L.tr('خلص', 'done');
      case 'error':
        return L.tr('فشل', 'failed');
      default:
        return L.tr('معلق', 'pending');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final running = part.toolStatus == 'running' || part.toolStatus == 'pending';
    final failed = part.toolStatus == 'error';
    final hasDetails =
        (part.toolInput ?? '').isNotEmpty || (part.toolOutput ?? '').isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: failed
              ? scheme.error.withValues(alpha: 0.5)
              : scheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!hasDetails)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  if (running)
                    SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    )
                  else
                    Icon(_icon, size: 17, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Text(
                    part.toolName ?? 'tool',
                    textDirection: TextDirection.ltr,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    _statusLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: failed
                          ? scheme.error
                          : scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            )
          else
            Theme(
              data: theme.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                shape: const Border(),
                collapsedShape: const Border(),
                tilePadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                dense: true,
                leading: running
                    ? SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      )
                    : Icon(_icon, size: 17, color: scheme.onSurfaceVariant),
                title: Text(
                  part.toolName ?? 'tool',
                  textDirection: TextDirection.ltr,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  failed
                      ? (part.toolError ?? L.tr('فشل', 'failed'))
                      : _statusLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: failed
                        ? scheme.error
                        : scheme.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
                children: [
                  if ((part.toolInput ?? '').isNotEmpty)
                    _CodeBlock(
                      label: L.tr('الإدخال', 'Input'),
                      content: part.toolInput!,
                      scheme: scheme,
                    ),
                  if ((part.toolOutput ?? '').isNotEmpty)
                    _CodeBlock(
                      label: L.tr('النتيجة', 'Output'),
                      content: part.toolOutput!,
                      scheme: scheme,
                    ),
                  if (failed && (part.toolError ?? '').isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: Text(
                        part.toolError!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.error),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({
    required this.label,
    required this.content,
    required this.scheme,
  });

  final String label;
  final String content;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectionArea(
              child: SingleChildScrollView(
                child: Text(
                  content,
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.left,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
