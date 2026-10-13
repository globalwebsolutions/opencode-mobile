import 'package:flutter/material.dart';

import '../core/models.dart';

/// Inline card for a pending permission request with
/// allow-once / allow-always / reject actions.
class PermissionCard extends StatelessWidget {
  const PermissionCard({
    super.key,
    required this.request,
    required this.onReply,
  });

  final PermissionRequest request;
  final void Function(String decision) onReply;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.gpp_maybe_outlined,
                  size: 20, color: scheme.tertiary),
              const SizedBox(width: 8),
              Text(
                'طلب صلاحية',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            request.message ??
                'الموديل عايز ينفذ "${request.actionLabel}" — '
                'محتاج موافقتك.',
            style: theme.textTheme.bodyMedium,
          ),
          if (request.resources.isNotEmpty) ...[
            const SizedBox(height: 8),
            Directionality(
              textDirection: TextDirection.ltr,
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final resource in request.resources.take(4))
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _shortResource(resource),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                      ),
                    ),
                  if (request.resources.length > 4)
                    Text(
                      '+${request.resources.length - 4}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: () => onReply('once'),
                  child: const Text('سماح مرة'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.tonal(
                  onPressed: () => onReply('always'),
                  child: const Text('سماح دايمًا'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onReply('reject'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    side: BorderSide(color: scheme.error.withValues(alpha: 0.6)),
                  ),
                  child: const Text('رفض'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _shortResource(String resource) {
    final parts = resource.split(RegExp(r'[\\/]'));
    final name = parts.isEmpty || parts.last.isEmpty
        ? resource
        : parts.last;
    return name.length > 28 ? name.substring(0, 28) : name;
  }
}
