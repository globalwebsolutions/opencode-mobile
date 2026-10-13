import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app.dart';
import '../core/models.dart';
import '../core/opencode_client.dart' show SseStatus;
import '../state/app_state.dart';
import '../state/sessions_state.dart';
import '../widgets/session_tile.dart';
import 'chat_screen.dart';
import 'new_session_screen.dart';
import 'settings_screen.dart';

/// Conversations list — the main screen after pairing.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppState>();
    final sessions = context.watch<SessionsState>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const AppLogo(size: 30),
            const SizedBox(width: 10),
            const Text('OpenCode'),
            const Spacer(),
            _StatusDot(app: app),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.new_label_outlined),
            tooltip: 'جلسة جديدة',
            onPressed: () => _openNewSession(context),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'الإعدادات',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openNewSession(context),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('محادثة جديدة'),
      ),
      body: RefreshIndicator(
        onRefresh: () => context.read<SessionsState>().refresh(),
        child: sessions.loading && sessions.sessions.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : sessions.sessions.isEmpty
                ? ListView(
                    children: [
                      const SizedBox(height: 120),
                      _EmptyState(scheme: scheme),
                    ],
                  )
                : ListView.separated(
                    itemCount: sessions.sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions.sessions[index];
                      return SessionTile(
                        session: session,
                        busy: sessions.busySessions[session.id] ?? false,
                        onTap: () => _openChat(context, session),
                        onLongPress: () =>
                            _showSessionActions(context, session),
                      );
                    },
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 16, endIndent: 16),
                  ),
      ),
    );
  }

  void _openChat(BuildContext context, OcSession session) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatScreen(sessionID: session.id),
      ),
    );
  }

  Future<void> _openNewSession(BuildContext context) async {
    final created = await Navigator.of(context).push<OcSession>(
      MaterialPageRoute(builder: (_) => const NewSessionScreen()),
    );
    if (created != null && context.mounted) {
      _openChat(context, created);
    }
  }

  void _showSessionActions(BuildContext context, OcSession session) {
    final sessions = context.read<SessionsState>();
    final controller = TextEditingController(text: session.title ?? '');
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                leading: const Icon(Icons.drive_file_rename_outline),
                title: const Text('إعادة تسمية'),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final title = await _promptRename(context, controller);
                  if (title != null && title.trim().isNotEmpty) {
                    await sessions.renameSession(session.id, title.trim());
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('حذف الجلسة'),
                textColor: Theme.of(context).colorScheme.error,
                iconColor: Theme.of(context).colorScheme.error,
                onTap: () {
                  Navigator.pop(sheetContext);
                  sessions.deleteSession(session.id);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _promptRename(
      BuildContext context, TextEditingController controller) {
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('اسم الجلسة'),
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
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (app.sseStatus) {
      SseStatus.connected => (const Color(0xFF22C55E), 'متصل'),
      SseStatus.connecting => (const Color(0xFFEAB308), 'بيتصل...'),
      SseStatus.disconnected => (const Color(0xFFEF4444), 'قاطع'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.chat_bubble_outline_rounded,
            size: 72, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
        const SizedBox(height: 16),
        Text(
          'لسه مفيش محادثات',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Text(
          'اضغط "محادثة جديدة" وابدأ شغلك مع OpenCode',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
        ),
      ],
    );
  }
}
