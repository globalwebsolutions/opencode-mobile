import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/connection_store.dart';
import '../core/l10n.dart';
import '../core/opencode_client.dart';
import '../state/app_state.dart';
import '../state/settings_state.dart';
import 'connect_guide_screen.dart';
import 'welcome_screen.dart';

/// Server management, live status, and app info.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final settings = context.watch<SettingsState>();
    final scheme = Theme.of(context).colorScheme;
    final (statusColor, statusLabel) = switch (app.sseStatus) {
      SseStatus.connected => (const Color(0xFF22C55E), L.tr('متصل — الأحداث بتوصل لحظيًا', 'Connected — live events streaming')),
      SseStatus.connecting => (const Color(0xFFEAB308), L.tr('بيتصل...', 'Connecting...')),
      SseStatus.disconnected => (const Color(0xFFEF4444), L.tr('الشبكة مقطوعة — هعيد المحاولة', 'Offline — retrying')),
    };

    return Scaffold(
      appBar: AppBar(title: Text(L.tr('الإعدادات', 'Settings'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          _Section(
              title: L.tr('المظهر واللغة', 'Appearance & language'),
              scheme: scheme,
              children: [
                ListTile(
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(L.tr('المظهر', 'Theme')),
                  trailing: DropdownButton<ThemeMode>(
                    value: settings.themeMode,
                    underline: const SizedBox.shrink(),
                    onChanged: (v) {
                      if (v != null) settings.setThemeMode(v);
                    },
                    items: [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text(L.tr('النظام', 'System')),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text(L.tr('فاتح', 'Light')),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text(L.tr('غامق', 'Dark')),
                      ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.translate_rounded),
                  title: Text(L.tr('اللغة', 'Language')),
                  trailing: DropdownButton<AppLang>(
                    value: settings.lang,
                    underline: const SizedBox.shrink(),
                    onChanged: (v) {
                      if (v != null) settings.setLang(v);
                    },
                    items: [
                      DropdownMenuItem(
                        value: AppLang.system,
                        child: Text(L.tr('النظام', 'System')),
                      ),
                      const DropdownMenuItem(
                        value: AppLang.arabic,
                        child: Text('العربية'),
                      ),
                      const DropdownMenuItem(
                        value: AppLang.english,
                        child: Text('English'),
                      ),
                    ],
                  ),
                ),
              ]),
          _Section(title: L.tr('إشعارات الخلفية (Android)', 'Background notifications (Android)'), scheme: scheme, children: [
            FutureBuilder<bool>(
              future: app.isNotificationsEnabled,
              builder: (context, snap) {
                final enabled = snap.data ?? false;
                return SwitchListTile(
                  title: Text(L.tr('الإشعارات في الخلفية', 'Background notifications')),
                  subtitle: Text(
                    enabled
                        ? L.tr('متصل — هتوصلك تنبيهات طلبات الصلاحية ونهاية التنفيذ', 'On — permission requests and finished runs notify you')
                        : L.tr('اضغط للتفعيل — التطبيق هيشغل خدمة خلفية', 'Tap to enable — starts a background service'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: enabled,
                  onChanged: (val) async {
                    if (val) {
                      final ok = await app.enableNotifications(
                          lang: settings.effectiveLang.name,
                        );
                      if (!ok && context.mounted && app.error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(app.error!),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } else {
                      await app.disableNotifications();
                    }
                  },
                  secondary: const Icon(Icons.notifications_outlined),
                );
              },
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                L.tr('⚠️ iOS: مش متاح دلوقتي — الموبايل iOS بيحتاج push من السيرفر (في الـ roadmap)', '⚠️ iOS: not available yet — needs push infrastructure on the server (in the roadmap)'),
                style: TextStyle(fontSize: 11),
              ),
            ),
          ]),
          _Section(title: L.tr('مساعدة', 'Help'), scheme: scheme, children: [
            ListTile(
              leading: const Icon(Icons.help_outline_rounded),
              title: Text(L.tr('دليل التوصيل (من أي مكان)', 'Connection guide (from anywhere)')),
              trailing: const Icon(Icons.chevron_left),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ConnectGuideScreen()),
              ),
            ),
          ]),
          _Section(title: L.tr('سيرفري', 'My servers'), scheme: scheme, children: [
            if (app.connections.isEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Text(L.tr('لسه مفيش سيرفرات متوصلة.', 'No servers paired yet.')),
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
                label: Text(L.tr('وصّل سيرفر جديد (pairing)', 'Pair a new server')),
              ),
            ),
          ]),
          _Section(title: L.tr('الاتصال الحالي', 'Current connection'), scheme: scheme, children: [
            _Row(
              label: L.tr('السيرفر', 'Server'),
              value: app.client?.baseUrl ?? '—',
              ltr: true,
              monospace: true,
            ),
            _Row(label: L.tr('إصدار OpenCode', 'OpenCode version'), value: app.serverInfo?.version ?? '—'),
            _Row(
              label: L.tr('الحالة', 'Status'),
              value: statusLabel,
              valueColor: statusColor,
            ),
          ]),
          _Section(title: L.tr('عن التطبيق', 'About'), scheme: scheme, children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 10),
              child: Text(
                L.tr('OpenCode Mobile — عميل غير رسمي مفتوح المصدر لسيرفر OpenCode.\n\n', 'OpenCode Mobile — an unofficial open-source client for the OpenCode server.\n\n') +
                    L.tr('⚠️ المشروع ده مبني بجهود مجتمعية و مش من فريق OpenCode ', '⚠️ Community-built, not made by the OpenCode team ') +
                    L.tr('و منتاسبش بأي شكل مع أوبن كود.', ' and not affiliated with OpenCode in any way.'),
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
        title: Text(L.tr('اسم السيرفر', 'Server name')),
        content: TextField(
          controller: controller,
          autofocus: true,
          onSubmitted: (value) => Navigator.pop(dialogContext, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(L.tr('إلغاء', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: Text(L.tr('حفظ', 'Save')),
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
        title: Text(L.tr('حذف السيرفر؟', 'Delete server?')),
        content: Text(L.tr('هيتمسح "${server.label}" من التطبيق ', '"${server.label}" will be removed from the app ') +
            L.tr('(الجلسات نفسها محفوظة عند OpenCode).', '(the sessions themselves stay with OpenCode).')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(L.tr('إلغاء', 'Cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onErrorContainer,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(L.tr('حذف', 'Delete')),
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
                L.tr('نشط', 'active'),
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
                  tooltip: L.tr('تسمية', 'Rename'),
                  onPressed: onRename,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: L.tr('حذف', 'Delete'),
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
