import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/opencode_client.dart';
import '../state/app_state.dart';

/// Connection details, live status, and pairing controls.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final scheme = Theme.of(context).colorScheme;
    final (statusColor, statusLabel) = switch (app.sseStatus) {
      SseStatus.connected => (const Color(0xFF22C55E), 'متصل — الأحداث بتوصل لحظيًا'),
      SseStatus.connecting => (const Color(0xFFEAB308), 'بيتصل...'),
      SseStatus.disconnected => (const Color(0xFFEF4444), 'الشبكة مقطوعة — هعيد المحاولة'),
    };

    return Scaffold(
      appBar: AppBar(title: const Text('الإعدادات')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _Section(title: 'الاتصال', scheme: scheme, children: [
            _Row(
              label: 'السيرفر',
              value: app.client?.baseUrl ?? '—',
              ltr: true,
              monospace: true,
            ),
            _Row(label: 'إصدار OpenCode', value: app.serverInfo?.version ?? '—'),
            _Row(
              label: 'الحالة',
              value: statusLabel,
              valueColor: statusColor,
            ),
          ]),
          _Section(title: 'إزاي تعيد التوصيل', scheme: scheme, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text(
                'لو الـ pairing باظ (مثلًا بعد تحديث أو تغيّر البورت)، اعمل من الكمبيوتر:\n\n'
                'opencode pair --url http://<IP-الكمبيوتر>:<PORT>\n\n'
                'وامسح الـ QR الجديد من شاشة البداية.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ]),
          _Section(title: 'عن التطبيق', scheme: scheme, children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text(
                'OpenCode Mobile — عميل غير رسمي مفتوح المصدر لسيرفر OpenCode.\n\n'
                '⚠️ المشروع ده مبني بجهود مجتمعية و مش من فريق OpenCode '
                'و منتاسبش بأي شكل مع أوبن كود.',
                style: TextStyle(height: 1.5),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.all(20),
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.error,
                side: BorderSide(color: scheme.error.withValues(alpha: 0.6)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.link_off_rounded),
              label: const Text('فصل والحذف (إعادة الـ pairing)'),
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('فصل الاتصال؟'),
                    content: const Text(
                        'هيمسح الـ token من الجهاز. هتحتاج تمسح QR جديد '
                        'عشان ترجع تتصل.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('إلغاء'),
                      ),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.error,
                          foregroundColor: scheme.onErrorContainer,
                        ),
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('فصل'),
                      ),
                    ],
                  ),
                );
                if (confirmed == true && context.mounted) {
                  await context.read<AppState>().unpair();
                  if (context.mounted) {
                    Navigator.of(context)
                        .popUntil((route) => route.isFirst);
                  }
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.scheme,
    required this.children,
  });

  final String title;
  final ColorScheme scheme;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
          child: Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        ...children,
        const Divider(indent: 20, endIndent: 20),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.label,
    required this.value,
    this.ltr = false,
    this.monospace = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool ltr;
  final bool monospace;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textDirection: ltr ? TextDirection.ltr : null,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontFamily: monospace ? 'monospace' : null,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
