import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/connection_store.dart';
import '../core/opencode_client.dart';
import '../state/app_state.dart';
import 'welcome_screen.dart';

/// Server management, live status, and app info.
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
          _Section(title: 'إشعارات الخلفية (Android)', scheme: scheme, children: [
            FutureBuilder<bool>(
              future: app.isNotificationsEnabled,
              builder: (context, snap) {
                final enabled = snap.data ?? false;
                return SwitchListTile(
                  title: const Text('الإشعارات في الخلفية'),
                  subtitle: Text(
                    enabled
                        ? 'متصل — هتوصلك تنبيهات طلبات الصلاحية ونهاية التنفيذ'
                        : 'اضغط للتفعيل — التطبيق هيشغل خدمة خلفية',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: enabled,
                  onChanged: (val) async {
                    if (val) {
                      await app.enableNotifications();
                    } else {
                      await app.disableNotifications();
                    }
                  },
                  secondary: const Icon(Icons.notifications_outlined),
                );
              },
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                '⚠️ iOS: مش متاح دلوقتي — الموبايل iOS بيحتاج push من السيرفر (في الـ roadmap)',
                style: TextStyle(fontSize: 11),
              ),
            ),
          ]),
          _Section(title: 'سيرفري', scheme: scheme, children: [
            if (app.connections.isEmpty)
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text('لسه مفيش سيرفرات متوصلة.'),
              ),
            for (final server in app.connections)
              _ServerTile(
                server: server,
                isActive: server.id == app.activeId,
                onActivate: () => app.switchServer(server.id),
                onRename: () => _rename(context, app, server),
                onDelete: () => _confirmDelete(context, app, server),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WelcomeScreen(addMode: true)),
                ),
                icon: const Icon(Icons.add_link_rounded),
                label: const Text('وصّل سيرفر جديد (pairing)'),
              ),
            ),
          ]),
          _Section(title: 'الاتصال الحالي', scheme: scheme, children: [
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
        ],
      ),
    );
  }

  Future<void> _rename(
      BuildContext context, AppState app, StoredConnection server) async {
    final controller = TextEditingController(text: server.name ?? server.label);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اسم السيرفر'),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await app.renameServer(server.id, name.trim());
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, AppState app, StoredConnection server) async {
    final scheme = Theme.of(context).colorScheme;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف السيرفر؟'),
        content: Text('هيتمسح "${server.label}" من التطبيق '
            '(الجلسات نفسها محفوظة عند OpenCode).'),
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
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await app.removeServer(server.id);
      if (context.mounted && app.phase == AppPhase.unpaired) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }
}

class _ServerTile extends StatelessWidget {
  const _ServerTile({
    required this.server,
    required this.isActive,
    required this.onActivate,
    required this.onRename,
    required this.onDelete,
  });

  final StoredConnection server;
  final bool isActive;
  final VoidCallback onActivate;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return ListTile(
      selected: isActive,
      onTap: isActive ? null : onActivate,
      leading: Icon(
        isActive ? Icons.dns_rounded : Icons.dns_outlined,
        color: isActive ? scheme.primary : scheme.onSurfaceVariant,
      ),
      title: Text(
        server.label,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        server.baseUrl,
        textDirection: TextDirection.ltr,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: scheme.onSurfaceVariant),
      ),
      trailing: isActive
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'نشط',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onPrimaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.drive_file_rename_outline),
                  tooltip: 'تسمية',
                  onPressed: onRename,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'حذف',
                  onPressed: onDelete,
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
