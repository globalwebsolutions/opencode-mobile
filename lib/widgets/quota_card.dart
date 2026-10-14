import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../core/l10n.dart';
import '../core/quota.dart';
import '../state/quota_state.dart';

/// Compact "how much is left" chip for the home header — visible without
/// opening Settings. Tapping it opens the connection/usage sheet.
class QuotaChip extends StatelessWidget {
  const QuotaChip({super.key, this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final monthly = context.watch<QuotaState>().monthly;
    if (monthly == null) return const SizedBox.shrink();

    final color = quotaColor(scheme, monthly.percent);
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 5, top: 2, bottom: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          // Bounded so a narrow phone squeezes this chip, never the app bar.
          constraints: const BoxConstraints(maxWidth: 112),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              Text(
                L.tr('شهر فاضل ${monthly.remaining.round()}%',
                    '${monthly.remaining.round()}% left'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Green while there is plenty left, amber when it gets tight, red at the end.
Color quotaColor(ColorScheme scheme, double percent) => percent >= 90
    ? scheme.error
    : percent >= 70
        ? const Color(0xFFEAB308)
        : const Color(0xFF22C55E);

/// One usage window with its meter.
class QuotaCard extends StatelessWidget {
  const QuotaCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final quota = context.watch<QuotaState>();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 14),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.speed_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    L.tr('الكوتة الشهرية', 'Plan quota'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: quota.loading ? null : quota.refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  tooltip: L.tr('تحديث', 'Refresh'),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (quota.loading && quota.quota == null)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else if (quota.quotaError != null)
              Text(
                quota.quotaError!,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              )
            else
              for (final window in quota.quota?.windows ?? const <QuotaWindow>[])
                _QuotaRow(window: window),
            const SizedBox(height: 2),
            const Divider(height: 18),
            _UsageSection(state: quota),
          ],
        ),
      ),
    );
  }
}

class _QuotaRow extends StatelessWidget {
  const _QuotaRow({required this.window});

  final QuotaWindow window;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final reset = quotaResetLabel(window.resetsAt);
    final color = quotaColor(scheme, window.percent);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  window.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                L.tr('فاضل ${window.remaining.round()}%',
                    '${window.remaining.round()}% left'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (window.percent / 100).clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (reset.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              L.tr('بيتصفّر بعد $reset', 'Resets in $reset'),
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// What this machine has actually spent, straight from the server's records.
class _UsageSection extends StatelessWidget {
  const _UsageSection({required this.state});

  final QuotaState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (state.usageError != null) {
      return Text(
        state.usageError!,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant),
      );
    }
    final usage = state.usage;
    if (usage == null) {
      return const SizedBox(
        height: 18,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final days = usage.periodDays;
    final period = days == 0
        ? L.tr('الفترة الحالية', 'Current period')
        : L.tr('آخر $days يوم', 'Last $days days');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          L.tr('استهلاكك · $period', 'Your spend · $period'),
          style: theme.textTheme.bodySmall
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _Metric(
              label: L.tr('التكلفة', 'Cost'),
              value: '\$${usage.cost.toStringAsFixed(2)}',
              emphasize: true,
            ),
            _Metric(
              label: L.tr('توكنز داخل', 'Input'),
              value: compactCount(usage.inputTokens),
            ),
            _Metric(
              label: L.tr('توكنز خارج', 'Output'),
              value: compactCount(usage.outputTokens),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          L.tr(
              '${usage.sessions} محادثة · ${usage.prompts} رسالة · ${compactCount(usage.totalTokens)} توكن',
              '${usage.sessions} chats · ${usage.prompts} prompts · ${compactCount(usage.totalTokens)} tokens'),
          style:
              theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: emphasize
                ? theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800, color: scheme.primary)
                : theme.textTheme.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
